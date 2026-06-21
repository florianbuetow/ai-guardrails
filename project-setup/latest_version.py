#!/usr/bin/env python3
"""Resolve latest available package versions from public registries."""

from __future__ import annotations

from dataclasses import dataclass
import json
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET


REGISTRY_CARGO = "cargo"
REGISTRY_GITHUB_TAGS = "github-tags"
REGISTRY_GO = "go"
REGISTRY_HEX = "hex"
REGISTRY_MAVEN = "maven"
REGISTRY_NPM = "npm"
REGISTRY_PYPI = "pypi"
REQUEST_TIMEOUT_SECONDS = 20
USER_AGENT = "ai-guardrails-show-libs/1.0"


class LatestVersionError(RuntimeError):
    """Raised when a latest-version lookup cannot be completed."""


@dataclass(frozen=True)
class LatestVersionRequest:
    registry: str
    identifier: str


def resolve_latest_versions(requests: list[LatestVersionRequest]) -> dict[LatestVersionRequest, str]:
    latest_versions: dict[LatestVersionRequest, str] = {}
    for request in requests:
        if request in latest_versions:
            continue
        latest_versions[request] = resolve_latest_version(request)
    return latest_versions


def resolve_latest_version(request: LatestVersionRequest) -> str:
    if request.registry == REGISTRY_CARGO:
        return resolve_cargo_latest(request.identifier)
    if request.registry == REGISTRY_GITHUB_TAGS:
        return resolve_github_tags_latest(request.identifier)
    if request.registry == REGISTRY_GO:
        return resolve_go_latest(request.identifier)
    if request.registry == REGISTRY_HEX:
        return resolve_hex_latest(request.identifier)
    if request.registry == REGISTRY_MAVEN:
        return resolve_maven_latest(request.identifier)
    if request.registry == REGISTRY_NPM:
        return resolve_npm_latest(request.identifier)
    if request.registry == REGISTRY_PYPI:
        return resolve_pypi_latest(request.identifier)
    raise LatestVersionError(f"Unsupported latest-version registry: {request.registry}")


def resolve_cargo_latest(crate_name: str) -> str:
    payload = fetch_json(f"https://crates.io/api/v1/crates/{url_quote(crate_name)}")
    crate = require_mapping(payload, "crate")
    if "max_stable_version" in crate and is_non_empty_string(crate["max_stable_version"]):
        return crate["max_stable_version"]
    return require_string(crate, "max_version")


def resolve_github_tags_latest(repository_url: str) -> str:
    owner, repository = parse_github_repository(repository_url)
    latest_release_url = f"https://api.github.com/repos/{owner}/{repository}/releases/latest"
    try:
        payload = fetch_json(latest_release_url)
    except LatestVersionError:
        tags_url = f"https://api.github.com/repos/{owner}/{repository}/tags?per_page=100"
        tags_payload = fetch_json(tags_url)
        tags = require_sequence(tags_payload)
        return latest_semver_tag(tags, repository_url)

    if not isinstance(payload, dict):
        raise LatestVersionError(f"Expected JSON object from {latest_release_url}")
    return require_string(payload, "tag_name")


def resolve_go_latest(module_path: str) -> str:
    escaped_module = escape_go_module_path(module_path)
    payload = fetch_json(f"https://proxy.golang.org/{urllib.parse.quote(escaped_module, safe='/!.-_~')}/@latest")
    return require_string(payload, "Version")


def resolve_hex_latest(package_name: str) -> str:
    payload = fetch_json(f"https://hex.pm/api/packages/{url_quote(package_name)}")
    if not isinstance(payload, dict):
        raise LatestVersionError(f"Expected Hex package metadata object for {package_name}")
    if "latest_stable_version" in payload and is_non_empty_string(payload["latest_stable_version"]):
        return payload["latest_stable_version"]
    return require_string(payload, "latest_version")


def resolve_maven_latest(coordinate: str) -> str:
    group_id, artifact_id = split_maven_coordinate(coordinate)
    metadata_url = (
        "https://repo1.maven.org/maven2/"
        f"{group_id.replace('.', '/')}/{artifact_id}/maven-metadata.xml"
    )
    metadata = fetch_text(metadata_url)
    try:
        root = ET.fromstring(metadata)
    except ET.ParseError as error:
        raise LatestVersionError(f"Invalid Maven metadata XML for {coordinate}") from error

    release = root.findtext("./versioning/release")
    if is_non_empty_string(release):
        return release

    latest = root.findtext("./versioning/latest")
    if is_non_empty_string(latest):
        return latest

    versions = [element.text for element in root.findall("./versioning/versions/version") if is_non_empty_string(element.text)]
    if not versions:
        raise LatestVersionError(f"Maven metadata for {coordinate} does not contain any versions")
    return versions[-1]


def resolve_npm_latest(package_name: str) -> str:
    encoded_package = urllib.parse.quote(package_name, safe="@")
    payload = fetch_json(f"https://registry.npmjs.org/{encoded_package}")
    dist_tags = require_mapping(payload, "dist-tags")
    return require_string(dist_tags, "latest")


def resolve_pypi_latest(package_name: str) -> str:
    payload = fetch_json(f"https://pypi.org/pypi/{url_quote(package_name)}/json")
    info = require_mapping(payload, "info")
    return require_string(info, "version")


def fetch_json(url: str) -> object:
    try:
        return json.loads(fetch_text(url))
    except json.JSONDecodeError as error:
        raise LatestVersionError(f"Invalid JSON from {url}") from error


def fetch_text(url: str) -> str:
    request = urllib.request.Request(
        url,
        headers={
            "Accept": "application/json, application/xml, text/xml, */*",
            "User-Agent": USER_AGENT,
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=REQUEST_TIMEOUT_SECONDS) as response:
            content = response.read()
    except urllib.error.HTTPError as error:
        raise LatestVersionError(f"HTTP {error.code} while fetching {url}") from error
    except urllib.error.URLError as error:
        raise LatestVersionError(f"Failed to fetch {url}: {error.reason}") from error
    return content.decode("utf-8")


def require_mapping(payload: object, key: str) -> dict[str, object]:
    if not isinstance(payload, dict):
        raise LatestVersionError(f"Expected JSON object while reading {key}")
    if key not in payload:
        raise LatestVersionError(f"Missing key '{key}' in registry response")
    value = payload[key]
    if not isinstance(value, dict):
        raise LatestVersionError(f"Expected '{key}' to be an object in registry response")
    return value


def require_sequence(payload: object) -> list[object]:
    if not isinstance(payload, list):
        raise LatestVersionError("Expected JSON array in registry response")
    return payload


def require_string(payload: dict[str, object], key: str) -> str:
    if key not in payload:
        raise LatestVersionError(f"Missing key '{key}' in registry response")
    value = payload[key]
    if not is_non_empty_string(value):
        raise LatestVersionError(f"Expected non-empty string for '{key}' in registry response")
    return value


def is_non_empty_string(value: object) -> bool:
    return isinstance(value, str) and len(value.strip()) > 0


def split_maven_coordinate(coordinate: str) -> tuple[str, str]:
    parts = coordinate.split(":")
    if len(parts) != 2:
        raise LatestVersionError(f"Expected Maven coordinate in group:artifact form: {coordinate}")
    group_id = parts[0]
    artifact_id = parts[1]
    if not group_id or not artifact_id:
        raise LatestVersionError(f"Expected non-empty Maven group and artifact: {coordinate}")
    return group_id, artifact_id


def parse_github_repository(repository_url: str) -> tuple[str, str]:
    match = re.fullmatch(r"https://github\.com/([^/]+)/([^/]+?)(?:\.git)?", repository_url)
    if match is None:
        raise LatestVersionError(f"Unsupported GitHub repository URL: {repository_url}")
    return match.group(1), match.group(2)


def latest_semver_tag(tags: list[object], repository_url: str) -> str:
    candidates: list[tuple[tuple[int, int, int], str]] = []
    for tag in tags:
        if not isinstance(tag, dict):
            raise LatestVersionError(f"Expected GitHub tag object for {repository_url}")
        tag_name = require_string(tag, "name")
        version_match = re.fullmatch(r"v?([0-9]+)\.([0-9]+)\.([0-9]+)", tag_name)
        if version_match is None:
            continue
        version_tuple = (int(version_match.group(1)), int(version_match.group(2)), int(version_match.group(3)))
        candidates.append((version_tuple, tag_name))

    if not candidates:
        raise LatestVersionError(f"No semantic version tags found for {repository_url}")
    return max(candidates, key=lambda candidate: candidate[0])[1]


def escape_go_module_path(module_path: str) -> str:
    escaped = []
    for char in module_path:
        if char.isupper():
            escaped.append(f"!{char.lower()}")
            continue
        escaped.append(char)
    return "".join(escaped)


def url_quote(value: str) -> str:
    return urllib.parse.quote(value, safe="")


def main() -> int:
    if len(sys.argv) != 3:
        print("Usage: latest_version.py <registry> <identifier>", file=sys.stderr)
        return 1

    request = LatestVersionRequest(sys.argv[1], sys.argv[2])
    try:
        print(resolve_latest_version(request))
    except LatestVersionError as error:
        print(f"Error: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
