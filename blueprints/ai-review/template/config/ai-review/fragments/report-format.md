## Report format

Return exactly one JSON object, no Markdown fences or additional prose:
{"complete":true,"findings":[],"warnings":[]}
Each finding must contain exactly:
{"severity":"medium","file":"relative/path","line":1,"title":"Concise actionable issue",
 "description":"Why this is a defect","evidence":"Concrete source evidence",
 "basis":"Documented expectation with source for high; principle for medium; minor improvement for low"}
Use a repository-relative file path and a one-based line at the relevant code or
claim. For deleted files use the base revision. Explain the triggering inputs or
conditions in the description. Cite other relevant code/doc locations in evidence.
Use one finding per distinct issue, avoid repeats and do not propose unrelated fixes.
Warnings are strings. Return complete:false if you cannot carry out the requested
investigation. Do not claim to have run tests or measured runtime performance.
