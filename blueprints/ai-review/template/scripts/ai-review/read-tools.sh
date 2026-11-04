#!/usr/bin/env bash
# Minimal stdio MCP: project reads/searches and one explicitly assigned report write.
set -euo pipefail
[ "$#" -eq 4 ] || exit 1
ROOT=$1
DIFF=$2
REPORT=$3
SCHEMA=$4
safe_path() {
  local requested=$1 current component
  case "$requested" in "$DIFF" | "$SCHEMA")
    printf '%s\n' "$requested"
    return
    ;;
  esac
  case "$requested" in "$ROOT") requested=. ;; "$ROOT"/*) requested=${requested#"$ROOT"/} ;; /*) return 1 ;; esac
  current=$ROOT
  local components=()
  IFS=/ read -r -a components <<<"$requested"
  for component in "${components[@]}"; do
    case "$component" in ..) return 1 ;; . | '') continue ;; esac
    current="$current/$component"
    [ ! -L "$current" ] || return 1
  done
  printf '%s\n' "$current"
}
while IFS= read -r message; do
  jq -e 'type == "object"' <<<"$message" >/dev/null || exit 1
  if ! jq -e 'has("id")' <<<"$message" >/dev/null; then continue; fi
  id=$(jq -c .id <<<"$message")
  method=$(jq -r .method <<<"$message")
  case "$method" in
  initialize)
    result='{"protocolVersion":"2024-11-05","capabilities":{"tools":{}},"serverInfo":{"name":"ai-review-files","version":"1.0.0"}}'
    ;;
  ping) result='{}' ;;
  tools/list)
    result='{"tools":[{"name":"read_file","description":"Read a UTF-8 project file or the supplied diff/schema. No symlink traversal.","inputSchema":{"type":"object","properties":{"path":{"type":"string"}},"required":["path"],"additionalProperties":false}},{"name":"list_files","description":"List files under a project directory, including ignored coverage reports. Does not follow symlinks.","inputSchema":{"type":"object","properties":{"path":{"type":"string"}},"required":["path"],"additionalProperties":false}},{"name":"search","description":"Search project file contents for literal text.","inputSchema":{"type":"object","properties":{"text":{"type":"string"}},"required":["text"],"additionalProperties":false}},{"name":"write_report","description":"Write your final Markdown review report to the one assigned destination. No path argument; no other file can be written.","inputSchema":{"type":"object","properties":{"markdown":{"type":"string","minLength":1}},"required":["markdown"],"additionalProperties":false}}]}'
    ;;
  tools/call)
    tool=$(jq -r .params.name <<<"$message")
    error=false
    content=""
    case "$tool" in
    read_file | list_files)
      requested=$(jq -er '.params.arguments.path | select(type == "string")' <<<"$message")
      if path=$(safe_path "$requested"); then
        if [ "$tool" = read_file ] && [ -f "$path" ]; then
          if content=$(cat "$path"); then :; else
            error=true
            content='File could not be read'
          fi
        elif [ "$tool" = list_files ] && [ -d "$path" ]; then
          if content=$(find "$path" -name .git -prune -o -type f -print); then :; else
            error=true
            content='Directory could not be listed'
          fi
        else
          error=true
          content='Path has the wrong type or does not exist'
        fi
      else
        error=true
        content='Path outside project or traverses a symlink'
      fi
      ;;
    search)
      query=$(jq -er '.params.arguments.text | select(type == "string" and length > 0)' <<<"$message")
      # grep -r does not follow encountered symlink directories; exclude Git state.
      if content=$(grep -r -n -I -F --exclude-dir=.git -- "$query" "$ROOT"); then
        :
      else
        status=$?
        if [ "$status" -eq 1 ]; then content='No matches'; else
          error=true
          content='Search failed'
        fi
      fi
      ;;
    write_report)
      markdown=$(jq -er '.params.arguments.markdown | select(type == "string" and length > 0)' <<<"$message")
      if [ -L "$REPORT" ] || [ -e "$REPORT" ]; then
        error=true
        content='Report already exists; refusing to overwrite'
      elif (
        set -C
        printf '%s\n' "$markdown" >"$REPORT"
      ); then
        content="Report written: $REPORT"
      else
        error=true
        content='Unable to write assigned report'
      fi
      ;;
    *)
      error=true
      content='Unknown tool'
      ;;
    esac
    result=$(printf '%s' "$content" | jq -Rs --argjson error "$error" '{content:[{type:"text",text:.}],isError:$error}')
    ;;
  *)
    jq -cn --argjson id "$id" '{jsonrpc:"2.0",id:$id,error:{code:-32601,message:"Method not found"}}'
    continue
    ;;
  esac
  printf '%s\n' "$result" | jq -c --argjson id "$id" '{jsonrpc:"2.0",id:$id,result:.}'
done
