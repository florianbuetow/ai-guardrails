## Severity levels

Use exactly low, medium or high. Severity measures the kind of requirement violated,
not how alarming the reviewer finds the issue. Do not substitute P0/P1 or error/warning.

- **high (severe):** Contradicts the project's established intent, documentation,
  architecture, requirements or explicitly stated goals. Cite the exact expectation,
  its source and the evidence of the contradiction. Do not invent a goal or infer
  high severity merely from the reviewer's specialty. A verified high finding fails CI.
- **medium:** Violates an identifiable engineering principle without an established
  contradiction of project intent or goals. Name the principle and show the concrete
  violation. Report it; it does not fail CI.
- **low:** A minor, readily corrected issue. Explain the small concrete improvement.
  Report it; it does not fail CI.

Missing supporting evidence, inaccessible context and unavailable coverage reports
belong in warnings or an incomplete-review result, not fabricated high findings.
Execution errors and incomplete verification fail CI separately from severity.
