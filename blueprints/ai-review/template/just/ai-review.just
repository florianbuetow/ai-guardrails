# Imported additive AI review recipes. Ordinary ci is intentionally independent.
ci-ai-help:
    @echo ""
    @printf 'AI review (five independent specialists per provider):\n'
    @printf '  just ci-ai <claude|codex|grok|agy> <base> <head> <new-report.json>\n'
    @printf '  just ci-ai-claude <base> <head> <new-report.json>\n'
    @printf '  just ci-ai-codex <base> <head> <new-report.json>\n'
    @printf '  just ci-ai-grok <base> <head> <new-report.json>\n'
    @printf '  just ci-ai-agy <base> <head> <new-report.json>\n'
    @printf '\033[32m✓ See docs/ai-review.md for configuration and isolation requirements\033[0m\n'
    @echo ""

ci-ai provider base head report:
    @echo ""
    @uv run --no-project python scripts/ai-review/review.py {{quote(provider)}} --base {{quote(base)}} --head {{quote(head)}} --report {{quote(report)}} && printf '\033[32m✓ AI review passed\033[0m\n' || { printf '\033[31m✗ AI review failed\033[0m\n'; exit 1; }
    @echo ""

ci-ai-claude base head report:
    @echo ""
    @just ci-ai claude {{quote(base)}} {{quote(head)}} {{quote(report)}} && printf '\033[32m✓ claude review passed\033[0m\n' || { printf '\033[31m✗ claude review failed\033[0m\n'; exit 1; }
    @echo ""

ci-ai-codex base head report:
    @echo ""
    @just ci-ai codex {{quote(base)}} {{quote(head)}} {{quote(report)}} && printf '\033[32m✓ codex review passed\033[0m\n' || { printf '\033[31m✗ codex review failed\033[0m\n'; exit 1; }
    @echo ""

ci-ai-grok base head report:
    @echo ""
    @just ci-ai grok {{quote(base)}} {{quote(head)}} {{quote(report)}} && printf '\033[32m✓ grok review passed\033[0m\n' || { printf '\033[31m✗ grok review failed\033[0m\n'; exit 1; }
    @echo ""

ci-ai-agy base head report:
    @echo ""
    @just ci-ai agy {{quote(base)}} {{quote(head)}} {{quote(report)}} && printf '\033[32m✓ agy review passed\033[0m\n' || { printf '\033[31m✗ agy review failed\033[0m\n'; exit 1; }
    @echo ""
