## Required Markdown report file

Every reviewer and finding verifier must itself write a Markdown report to the exact
absolute `report_path` supplied in REVIEW_INPUT_JSON. It is under
`~/reports/ai-review/` and named `YYYYMMDDhhmmss_provider_phase_agent_run-id.md`.
Use the provided file-write tool, or the dedicated write_report tool when available.
This is the only permitted file write. Never overwrite another report or write to
project files. Do not use shell commands to write the report.

Include review scope, project intent/goals used as evidence, findings grouped by
high/medium/low severity, concrete source references and warnings/limitations. A
verifier must include the decision and reasoning for every candidate. Explicitly
state when there are no findings. Write the report before returning your final JSON.
If the write tool is unavailable or fails, return complete:false and explain why;
never claim the report exists without successful tool confirmation.
