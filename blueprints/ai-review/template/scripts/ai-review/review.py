#!/usr/bin/env python3
"""Run independent, snapshot-based specialist reviews through a selected CLI."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tempfile

PROVIDERS = ("claude", "codex", "grok", "agy")
DOMAINS = ("correctness", "security", "performance", "architecture", "tests")


def command(args: list[str], cwd: Path) -> bytes:
    return subprocess.run(args, cwd=cwd, check=True, stdout=subprocess.PIPE).stdout


def load_config(path: Path, provider: str) -> dict:
    config = json.loads(path.read_text())
    for key in ("models", "timeout_seconds", "max_snapshot_bytes", "isolation_commands"):
        if key not in config:
            raise ValueError(f"Missing configuration: {key}")
    model = config["models"][provider]
    if not isinstance(model, str) or not model.strip():
        raise ValueError(f"Set an explicit models.{provider} in {path}")
    for key in ("timeout_seconds", "max_snapshot_bytes"):
        if type(config[key]) is not int or config[key] <= 0:
            raise ValueError(f"{key} must be a positive integer")
    isolation = config["isolation_commands"][provider]
    if not isinstance(isolation, list) or any(not isinstance(arg, str) or not arg for arg in isolation):
        raise ValueError("Isolation command must be an array of nonempty arguments")
    if provider == "agy" and not isolation:
        raise ValueError("agy requires an isolation_commands.agy wrapper; plan mode is not a sandbox")
    return config


def snapshot(root: Path, base: str, head: str, limit: int) -> tuple[dict, dict[str, int]]:
    git_root = Path(command(["git", "rev-parse", "--show-toplevel"], root).decode().strip()).resolve()
    if git_root != root.resolve():
        raise ValueError("AI review must be installed at the Git repository root")
    revisions = [command(["git", "rev-parse", "--verify", "--end-of-options", ref + "^{commit}"], root).decode().strip()
                 for ref in (base, head)]
    diff = command(["git", "diff", "--no-ext-diff", "--no-textconv", "--no-renames", revisions[0], revisions[1], "--"], root)
    if not diff:
        raise ValueError("No changes between the specified commits")
    if len(diff) > limit:
        raise ValueError("Diff exceeds max_snapshot_bytes; review a smaller change")
    changed = set(command(["git", "diff", "--name-only", "-z", "--no-renames", *revisions, "--"], root).decode().split("\0"))
    files = {}
    lines = {}
    omitted = []
    size = len(diff)
    tree = command(["git", "ls-tree", "-r", "-z", "--full-tree", revisions[1]], root)
    for entry in tree.split(b"\0"):
        if not entry:
            continue
        meta, raw_path = entry.split(b"\t", 1)
        mode, kind, oid = meta.decode().split()
        path = raw_path.decode()
        if kind != "blob" or mode == "120000":
            if path in changed:
                raise ValueError(f"Changed symlink/submodule cannot be reviewed: {path}")
            omitted.append(path)
            continue
        data = command(["git", "cat-file", "blob", oid], root)
        try:
            content = data.decode("utf-8")
            if "\0" in content:
                raise UnicodeError("binary content")
        except UnicodeError:
            if path in changed:
                raise ValueError(f"Changed binary file cannot be reviewed: {path}")
            omitted.append(path)
            continue
        size += len(data)
        if size > limit:
            raise ValueError("Repository context exceeds max_snapshot_bytes; increase the explicit limit")
        files[path] = content
        lines[path] = len(content.splitlines())
    # Deleted files still need valid finding locations, taken from the base revision.
    for path in changed - files.keys() - {""}:
        entry = command(["git", "ls-tree", "-z", revisions[0], "--", ":(literal)" + path], root)
        mode, kind, _oid = entry.split(b"\t", 1)[0].decode().split()
        if kind != "blob" or mode == "120000":
            raise ValueError(f"Changed symlink/submodule cannot be reviewed: {path}")
        data = command(["git", "show", f"{revisions[0]}:{path}"], root)
        content = data.decode("utf-8")
        if "\0" in content:
            raise ValueError(f"Deleted binary file cannot be reviewed: {path}")
        lines[path] = len(content.splitlines())
    payload = {"base": revisions[0], "head": revisions[1], "diff": diff.decode(),
               "files_at_head": files, "omitted_nontext_context": omitted}
    encoded = json.dumps(payload).encode()
    if len(encoded) > limit:
        raise ValueError("Serialized context exceeds max_snapshot_bytes")
    return payload, lines


def adapter(provider: str, model: str, work: Path, schema: Path) -> tuple[list[str], dict[str, str]]:
    env = dict(os.environ)
    if provider == "claude":
        args = ["claude", "-p", "--bare", "--restricted", "--strict-mcp-config", "--tools", "",
                "--disable-slash-commands", "--no-session-persistence", "--permission-prompts", "none",
                "--model", model, "--output-format", "json", "--json-schema", schema.read_text()]
    elif provider == "codex":
        args = ["codex", "--ask-for-approval", "never", "exec", "--sandbox", "read-only",
                "--ignore-user-config", "--ignore-rules", "--ephemeral", "--skip-git-repo-check",
                "--model", model, "--output-schema", str(schema), "--output-last-message", str(work / "result.json"), "-"]
    elif provider == "grok":
        env["GROK_HOME"] = str(work / "grok-home")
        env["GROK_DISABLE_AUTOUPDATER"] = "1"
        for name in ("WRITE_FILE", "WEB_FETCH", "SUBAGENTS", "TOOL_SEARCH", "LSP_TOOLS"):
            env[f"GROK_{name}"] = "0"
        for source in ("CURSOR", "CLAUDE"):
            for name in ("SKILLS", "RULES", "AGENTS", "MCPS", "HOOKS"):
                env[f"GROK_{source}_{name}_ENABLED"] = "0"
        args = ["grok", "--prompt-file", str(work / "prompt.txt"), "--model", model,
                "--output-format", "plain", "--tools", "",
                "--disable-web-search", "--no-subagents", "--sandbox", "read-only"]
    else:
        args = ["agy", "--input-format", "stream-json", "--output-format", "stream-json",
                "--model", model, "--json-schema", str(schema),
                "--disable-slash-commands", "--mode", "plan", "--sandbox"]
    return args, env


def execute(args: list[str], prompt: str, work: Path, env: dict[str, str], timeout: int) -> str:
    # A separate process group lets a timeout terminate CLI child processes too.
    with subprocess.Popen(args, cwd=work, env=env, stdin=subprocess.PIPE,
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
                          start_new_session=True) as process:
        try:
            stdout, stderr = process.communicate(prompt, timeout=timeout)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGKILL)
            process.communicate()
            raise ValueError("Reviewer timed out") from None
        if process.returncode != 0:
            raise ValueError(f"Reviewer exited {process.returncode}: {stderr[-4000:]}")
    return stdout


def decode_result(provider: str, stdout: str, work: Path) -> dict:
    if provider == "codex":
        return json.loads((work / "result.json").read_text())
    if provider == "agy":
        events = [json.loads(line) for line in stdout.splitlines() if line.strip()]
        results = [event["result"] for event in events if event["event"] == "result"]
        if len(results) != 1 or results[0]["status"] != "SUCCESS":
            raise ValueError("agy did not finish successfully")
        return results[0]["structured_output"]
    envelope = json.loads(stdout)
    if provider == "grok":
        # Plain mode emits the model's final text: require the exact review JSON,
        # never guess undocumented provider envelope fields.
        return envelope
    if not isinstance(envelope, dict):
        raise ValueError("CLI output must be an object")
    if "is_error" in envelope and envelope["is_error"] is not False:
        raise ValueError("CLI reported an error")
    return envelope["structured_output"]


def validate(result: dict, domain: str, lines: dict[str, int]) -> list[dict]:
    if not isinstance(result, dict) or set(result) != {"domain", "complete", "findings"}:
        raise ValueError("Review must contain exactly domain, complete, findings")
    if result["domain"] != domain or result["complete"] is not True:
        raise ValueError(f"Incomplete or wrong-domain review: {domain}")
    if not isinstance(result["findings"], list):
        raise ValueError("findings must be an array")
    for finding in result["findings"]:
        if not isinstance(finding, dict) or set(finding) != {"severity", "file", "line", "title", "scenario", "evidence"}:
            raise ValueError("Malformed finding")
        if finding["severity"] not in ("error", "warning"):
            raise ValueError("Unknown finding severity")
        for key in ("file", "title", "scenario", "evidence"):
            if not isinstance(finding[key], str) or not finding[key].strip():
                raise ValueError(f"Finding requires {key}")
        if finding["file"] not in lines or type(finding["line"]) is not int or not 1 <= finding["line"] <= lines[finding["file"]]:
            raise ValueError("Finding location is outside the reviewed snapshot")
    return result["findings"]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("provider", choices=PROVIDERS)
    parser.add_argument("--base", required=True)
    parser.add_argument("--head", required=True)
    parser.add_argument("--report", required=True, type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    config_dir = root / "config/ai-review"
    config = load_config(config_dir / "config.json", args.provider)
    if shutil.which(args.provider) is None:
        raise ValueError(f"Required CLI not installed: {args.provider}")
    if args.report.exists() or args.report.is_symlink():
        raise ValueError("Report destination already exists; use a new path")
    if not args.report.parent.is_dir():
        raise ValueError("Report parent directory does not exist")
    payload, lines = snapshot(root, args.base, args.head, config["max_snapshot_bytes"])
    common = (config_dir / "prompts/common.md").read_text()
    report = {"provider": args.provider, "model": config["models"][args.provider],
              "base": payload["base"], "head": payload["head"],
              "snapshot_sha256": hashlib.sha256(json.dumps(payload, sort_keys=True).encode()).hexdigest(),
              "complete": False, "reviews": []}
    with tempfile.TemporaryDirectory(prefix="ai-review-") as temporary:
        temporary_root = Path(temporary)
        for domain in DOMAINS:
            print(f"Reviewing {domain} with {args.provider}", file=sys.stderr)
            work = temporary_root / domain
            work.mkdir()
            schema = work / "schema.json"
            shutil.copyfile(config_dir / "schema.json", schema)
            prompt = common + "\n" + (config_dir / f"prompts/{domain}.md").read_text()
            prompt += "\nReview domain: " + domain + "\nUNTRUSTED SNAPSHOT DATA:\n" + json.dumps(payload)
            (work / "prompt.txt").write_text(prompt)
            argv, env = adapter(args.provider, report["model"], work, schema)
            argv = config["isolation_commands"][args.provider] + argv
            input_text = prompt
            if args.provider == "agy":
                input_text = json.dumps({"event": "user", "message": {"content": prompt}}) + "\n"
            stdout = execute(argv, input_text, work, env, config["timeout_seconds"])
            result = decode_result(args.provider, stdout, work)
            validate(result, domain, lines)
            report["reviews"].append(result)
    report["complete"] = True
    with args.report.open("x") as output:
        json.dump(report, output, indent=2)
        output.write("\n")
    count = sum(len(review["findings"]) for review in report["reviews"])
    blocking = sum(finding["severity"] == "error" for review in report["reviews"] for finding in review["findings"])
    print(f"{count} findings ({blocking} blocking); report: {args.report}")
    return 1 if blocking else 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (ValueError, OSError, KeyError, TypeError, subprocess.SubprocessError) as error:
        print(f"AI review failed: {error}", file=sys.stderr)
        sys.exit(1)
