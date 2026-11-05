# Agentic reviews run independently of ordinary ci.
ci-ai:
    @echo ""
    @bash scripts/ai-review/review.sh help && printf '\033[32m✓ AI review help displayed\033[0m\n' || { printf '\033[31m✗ AI review help failed\033[0m\n'; exit 1; }
    @echo ""

ci-ai-codex scope="" agent="" commit="":
    @just _ci-ai-run codex {{quote(scope)}} {{quote(agent)}} {{quote(commit)}}

ci-ai-claude scope="" agent="" commit="":
    @just _ci-ai-run claude {{quote(scope)}} {{quote(agent)}} {{quote(commit)}}

ci-ai-grok scope="" agent="" commit="":
    @just _ci-ai-run grok {{quote(scope)}} {{quote(agent)}} {{quote(commit)}}

[private]
_ci-ai-run provider scope agent commit:
    #!/usr/bin/env bash
    set -uo pipefail
    provider={{quote(provider)}}; scope={{quote(scope)}}; agent={{quote(agent)}}; commit={{quote(commit)}}
    config=config/ai-review/config.json
    usage() { printf 'just ci-ai-%s [scope] [agent] [commit]\n' "$provider"; }
    scopes() { printf '  scope:  diff, commit, global\n'; }
    agents() { printf '  agent:  all, %s\n' "$(jq -r '[.agents[] | select(.enabled) | .name] | join(", ")' "$config")"; }
    commits() { printf '  commit: a commit hash\n'; }
    error() { printf '\033[31m%s\033[0m\n' "$1"; }
    if [ -z "$scope" ]; then
        usage; scopes; agents; commits
        printf "Next step: just ci-ai-%s diff correctness\n" "$provider"
        exit 0
    fi
    case "$scope" in
        diff | commit | global) ;;
        *) error "Unknown scope: $scope"; usage; scopes; printf "Next step: just ci-ai-%s diff correctness\n" "$provider"; exit 1 ;;
    esac
    if [ -z "$agent" ]; then
        usage; agents; printf 'Next step: just ci-ai-%s %s correctness   (or "all" for every agent)\n' "$provider" "$scope"; exit 0
    fi
    if [ "$agent" = all ]; then agent=""; fi
    if [ -n "$agent" ] && ! jq -e --arg a "$agent" 'any(.agents[]; .name == $a and .enabled)' "$config" >/dev/null; then
        error "Unknown agent: $agent"; usage; agents; printf "Next step: just ci-ai-%s %s %s\n" "$provider" "$scope" "$(jq -r "[.agents[] | select(.enabled)][0].name" "$config")"; exit 1
    fi
    if [ -z "$(jq -r --arg p "$provider" '.providers[$p].model // ""' "$config")" ]; then
        error "No model set for $provider."
        printf 'Next step: set providers.%s.model in %s, then rerun.\n' "$provider" "$config"; exit 1
    fi
    if [ -n "$commit" ] && [ "$scope" != commit ]; then
        error "A commit hash is only valid with the commit scope"; usage; printf "Next step: just ci-ai-%s commit \"%s\" %s\n" "$provider" "$agent" "$commit"; exit 1
    fi
    echo ""
    bash scripts/ai-review/review.sh run "$provider" "$scope" "$agent" "$commit" \
        && printf '\033[32m✓ %s review passed\033[0m\n' "$provider" \
        || { printf '\033[31m✗ %s review failed\033[0m\n' "$provider"; exit 1; }
    echo ""
