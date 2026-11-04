# Agentic reviews run independently of ordinary ci.
ci-ai:
    @echo ""
    @bash scripts/ai-review/review.sh help && printf '\033[32m✓ AI review help displayed\033[0m\n' || { printf '\033[31m✗ AI review help failed\033[0m\n'; exit 1; }
    @echo ""

ci-ai-codex scope agent="" commit="":
    @echo ""
    @bash scripts/ai-review/review.sh run codex {{quote(scope)}} {{quote(agent)}} {{quote(commit)}} && printf '\033[32m✓ Codex review passed\033[0m\n' || { printf '\033[31m✗ Codex review failed\033[0m\n'; exit 1; }
    @echo ""

ci-ai-claude scope agent="" commit="":
    @echo ""
    @bash scripts/ai-review/review.sh run claude {{quote(scope)}} {{quote(agent)}} {{quote(commit)}} && printf '\033[32m✓ Claude review passed\033[0m\n' || { printf '\033[31m✗ Claude review failed\033[0m\n'; exit 1; }
    @echo ""

ci-ai-grok scope agent="" commit="":
    @echo ""
    @bash scripts/ai-review/review.sh run grok {{quote(scope)}} {{quote(agent)}} {{quote(commit)}} && printf '\033[32m✓ Grok review passed\033[0m\n' || { printf '\033[31m✗ Grok review failed\033[0m\n'; exit 1; }
    @echo ""
