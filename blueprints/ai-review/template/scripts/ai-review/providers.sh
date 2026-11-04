#!/usr/bin/env bash
# Native CLI transports and session-scoped permissions; prompts own review behavior.
provider_launch() (
  local provider=$1 model=$2 workspace=$3 prompt=$4 schema=$5 directory=$6 report=$7
  local report_dir input_path mcp_args
  report_dir=$(dirname "$report")
  cd "$workspace" || return 1
  case "$provider" in
  claude)
    claude --safe-mode --restricted --strict-mcp-config --tools 'Read,Grep,Glob,Write' \
      --add-dir "$report_dir" --add-dir "$RUN_DIR" --allowedTools "Edit(/$report)" \
      --permission-mode dontAsk --permission-prompts none --disable-slash-commands \
      --no-session-persistence --model "$model" --output-format json \
      --json-schema "$(cat "$schema")" -p <"$prompt" >"$directory/stdout" 2>"$directory/stderr"
    ;;
  codex)
    input_path="$RUN_DIR/diff.patch"
    mcp_args=$(jq -cn --arg helper "$SCRIPT_DIR/read-tools.sh" --arg workspace "$workspace" \
      --arg diff "$input_path" --arg report "$report" --arg schema "$schema" '[$helper,$workspace,$diff,$report,$schema]')
    codex --ask-for-approval never exec --cd "$workspace" --sandbox read-only \
      --ignore-user-config --ignore-rules --ephemeral --skip-git-repo-check \
      --disable shell_tool --disable unified_exec --disable hooks --disable plugins --disable apps --disable multi_agent \
      -c 'web_search="disabled"' \
      -c 'mcp_servers.ai_review_files.command="bash"' \
      -c "mcp_servers.ai_review_files.args=$mcp_args" \
      -c 'mcp_servers.ai_review_files.enabled_tools=["read_file","list_files","search","write_report"]' \
      -c 'mcp_servers.ai_review_files.tools.read_file.approval_mode="approve"' \
      -c 'mcp_servers.ai_review_files.tools.list_files.approval_mode="approve"' \
      -c 'mcp_servers.ai_review_files.tools.search.approval_mode="approve"' \
      -c 'mcp_servers.ai_review_files.tools.write_report.approval_mode="approve"' \
      --model "$model" --output-schema "$schema" --output-last-message "$directory/answer.json" \
      - <"$prompt" >"$directory/stdout" 2>"$directory/stderr"
    ;;
  grok)
    grok --cwd "$workspace" --prompt-file "$prompt" --model "$model" --output-format streaming-messages-json \
      --permission-mode dontAsk --tools 'read_file,grep,list_dir,write' \
      --disallowed-tools 'Agent,CallMcpTool,FetchMcpResource,ListMcpResources,search_tool,use_tool' --deny 'MCPTool(*)' \
      --allow "Write($report)" --allow "Edit($report)" \
      --deny "Write($workspace/**)" --deny "Edit($workspace/**)" \
      --disable-web-search --no-subagents --no-plan \
      >"$directory/stdout" 2>"$directory/stderr"
    ;;
  *)
    printf 'Unsupported provider: %s\n' "$provider" >&2
    return 1
    ;;
  esac
)
provider_decode() {
  local provider=$1 directory=$2
  case "$provider" in
  codex) jq -e . "$directory/answer.json" ;;
  claude) jq -e 'select(.is_error != true) | .structured_output | select(type == "object")' "$directory/stdout" ;;
  grok)
    # Grok's plain/JSON text concatenates progress and final messages. Its
    # message stream preserves the terminal assistant message boundary.
    jq -s -e '
      [.[] | select(.type == "assistant" and .message.stop_reason == "end_turn")]
      | select(length == 1) | .[0].message.content
      | map(select(.type == "text") | .text) | join("") | fromjson
      | select(type == "object")
    ' "$directory/stdout"
    ;;
  *) return 1 ;;
  esac
}
