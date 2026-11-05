<!-- AI-REVIEW:START -->
## Agentic review

Requirements: Bash, Git, jq, just and the selected authenticated CLI. Set explicit
provider models in `config/ai-review/config.json`. No Python or uv is required.

```sh
just ci-ai                            # Show configured providers and agents
just ci-ai-codex diff all             # All enabled reviewers
just ci-ai-claude global specs-review # One reviewer
just ci-ai-grok commit security       # One reviewer at the latest commit
just ci-ai-claude commit security abc123 # One reviewer at a commit
just ci-ai-codex commit all abc123    # All reviewers at a commit
```

Scope and agent are required; nothing runs until both are given. Pass `all` to run every enabled reviewer. `diff` covers tracked changes against HEAD plus nonignored
untracked files. `commit` covers the latest commit (HEAD) or the supplied hash,
compared with its first parent; an initial commit is compared with an empty tree.
For a historical commit, reviewers receive a temporary filesystem of that revision.
Commit scope currently refuses trees containing symlinks or submodules, rather than
following links or silently omitting context. Export attributes do not alter the
reviewed files.
`global` covers current tracked and nonignored untracked project files. Related
code and documentation may be inspected as context. Coverage reports may be read
from ignored output directories as evidence when relevant, with freshness checked.

Agents investigate the project with read tools. They must not modify project files,
execute commands/tests, commit or push. Each agent has one exception: write its
assigned Markdown report under `~/reports/ai-review/`. The shared report instructions
specify its unique timestamped path. Reviewers run in parallel; fresh finding
verifiers then independently check candidates in parallel. No candidates means no
verification calls. Authentication and model usage belong to the selected CLI;
model calls can incur charges.

The registry contains correctness, security, performance, architecture,
test-coverage, error-handling, adversarial and specs-review. The specs reviewer
first establishes project intent, then checks documentation for logical
contradictions/gaps and correlates claims with code. The test reviewer examines
behavioral coverage and existing reports; absent reports produce a warning.

Prompt files live in `config/ai-review/prompts/`. `{{BASENAME}}` includes
`BASENAME.md` from prompts or fragments. Expansion is recursive, and missing,
ambiguous, malformed or circular references fail before CLI launch. Each session
receives a complete expanded prompt. Severity is defined in
`config/ai-review/fragments/severity-levels.md` and included in every prompt:

- **high:** Contradicts established project intent, documentation, architecture,
  requirements or explicitly stated goals; requires cited project evidence.
- **medium:** Violates an engineering principle without an established project-goal
  contradiction.
- **low:** Minor, readily corrected issues.

Only independently confirmed high findings fail CI. CLI failures, timeouts,
malformed or incomplete reports and incomplete verification also fail, distinctly
from severity. JSON results and session logs are saved in a unique run directory
under the configured `report_directory`; Markdown reports are written by the agents.
Reports preserve confirmed/rejected findings and reasons. Ordinary `ci` is unchanged.

Installation preserves the existing README and justfile and appends this section
and a recipe import. It creates those files if absent, refuses conflicts and rolls
back failures. Reinstallation refuses to overwrite existing assets. No automatic
update, source modification, commit or push is performed by the review package.

### Provider validation and boundaries

Real synthetic-project integration checks on 2026-11-02 completed the reviewer,
independent verifier, Markdown report writes and high-severity failure gate for
Claude Code 2.1.285 (`sonnet`), Codex 0.166.0 (`gpt-6-astra`) and Grok 1.0.70
(`grok-4.6`). The fixture's source files remained unchanged. These are transport
and workflow checks, not an accuracy benchmark for arbitrary projects.

Codex uses the package's small filesystem MCP helper with command tools disabled.
Only its three read/search operations and its fixed-path report writer are approved.
Claude and Grok use native tool restrictions.
These controls govern model tool calls. They are not an OS sandbox for independently
installed CLI hooks or extensions; those remain part of the trusted CLI environment.

To repeat an opt-in live check from the AI Guardrails repository, run
`just test-ai-review-live PROVIDER MODEL`. It uses disposable synthetic code,
records the CLI version and artifacts, and fails if the version changes during
the run. It never commits or pushes the real project. Model calls can incur costs.

### Sources and licenses

The adversarial prompt adapts only the supplied Codex built-in review prompt text
from Codex CLI 0.157.1, extracted 2026-09-27. The extraction instructions were not
included. Its output schema, scope and permission instructions were adapted for
this package. OpenAI Codex: Copyright 2025 OpenAI, Apache License 2.0.

Review procedures also draw on Anthropic's PR Review Toolkit (test analysis,
silent-failure and comment analysis), Apache-2.0, and Every's documentation review
coherence procedures, MIT. Project-specific logging conventions and output formats
were replaced by this package's scope, severity and result contracts.

Sources:
- https://github.com/openai/codex
- https://github.com/anthropics/claude-plugins-official/tree/main/plugins/pr-review-toolkit
- https://github.com/EveryInc/compound-engineering-plugin/tree/main/skills/ce-doc-review
- https://developers.google.com/tech-writing/two/large-docs

The applicable license texts are included here so they accompany generated projects.

<details>
<summary>Apache License 2.0 (Codex and Anthropic prompt adaptations)</summary>

```text
                                 Apache License
                           Version 2.0, January 2004
                        http://www.apache.org/licenses/

TERMS AND CONDITIONS FOR USE, REPRODUCTION, AND DISTRIBUTION

1.  Definitions.

    "License" shall mean the terms and conditions for use, reproduction,
    and distribution as defined by Sections 1 through 9 of this document.

    "Licensor" shall mean the copyright owner or entity authorized by
    the copyright owner that is granting the License.

    "Legal Entity" shall mean the union of the acting entity and all
    other entities that control, are controlled by, or are under common
    control with that entity. For the purposes of this definition,
    "control" means (i) the power, direct or indirect, to cause the
    direction or management of such entity, whether by contract or
    otherwise, or (ii) ownership of fifty percent (50%) or more of the
    outstanding shares, or (iii) beneficial ownership of such entity.

    "You" (or "Your") shall mean an individual or Legal Entity
    exercising permissions granted by this License.

    "Source" form shall mean the preferred form for making modifications,
    including but not limited to software source code, documentation
    source, and configuration files.

    "Object" form shall mean any form resulting from mechanical
    transformation or translation of a Source form, including but
    not limited to compiled object code, generated documentation,
    and conversions to other media types.

    "Work" shall mean the work of authorship, whether in Source or
    Object form, made available under the License, as indicated by a
    copyright notice that is included in or attached to the work
    (an example is provided in the Appendix below).

    "Derivative Works" shall mean any work, whether in Source or Object
    form, that is based on (or derived from) the Work and for which the
    editorial revisions, annotations, elaborations, or other modifications
    represent, as a whole, an original work of authorship. For the purposes
    of this License, Derivative Works shall not include works that remain
    separable from, or merely link (or bind by name) to the interfaces of,
    the Work and Derivative Works thereof.

    "Contribution" shall mean any work of authorship, including
    the original version of the Work and any modifications or additions
    to that Work or Derivative Works thereof, that is intentionally
    submitted to Licensor for inclusion in the Work by the copyright owner
    or by an individual or Legal Entity authorized to submit on behalf of
    the copyright owner. For the purposes of this definition, "submitted"
    means any form of electronic, verbal, or written communication sent
    to the Licensor or its representatives, including but not limited to
    communication on electronic mailing lists, source code control systems,
    and issue tracking systems that are managed by, or on behalf of, the
    Licensor for the purpose of discussing and improving the Work, but
    excluding communication that is conspicuously marked or otherwise
    designated in writing by the copyright owner as "Not a Contribution."

    "Contributor" shall mean Licensor and any individual or Legal Entity
    on behalf of whom a Contribution has been received by Licensor and
    subsequently incorporated within the Work.

2.  Grant of Copyright License. Subject to the terms and conditions of
    this License, each Contributor hereby grants to You a perpetual,
    worldwide, non-exclusive, no-charge, royalty-free, irrevocable
    copyright license to reproduce, prepare Derivative Works of,
    publicly display, publicly perform, sublicense, and distribute the
    Work and such Derivative Works in Source or Object form.

3.  Grant of Patent License. Subject to the terms and conditions of
    this License, each Contributor hereby grants to You a perpetual,
    worldwide, non-exclusive, no-charge, royalty-free, irrevocable
    (except as stated in this section) patent license to make, have made,
    use, offer to sell, sell, import, and otherwise transfer the Work,
    where such license applies only to those patent claims licensable
    by such Contributor that are necessarily infringed by their
    Contribution(s) alone or by combination of their Contribution(s)
    with the Work to which such Contribution(s) was submitted. If You
    institute patent litigation against any entity (including a
    cross-claim or counterclaim in a lawsuit) alleging that the Work
    or a Contribution incorporated within the Work constitutes direct
    or contributory patent infringement, then any patent licenses
    granted to You under this License for that Work shall terminate
    as of the date such litigation is filed.

4.  Redistribution. You may reproduce and distribute copies of the
    Work or Derivative Works thereof in any medium, with or without
    modifications, and in Source or Object form, provided that You
    meet the following conditions:

    (a) You must give any other recipients of the Work or
    Derivative Works a copy of this License; and

    (b) You must cause any modified files to carry prominent notices
    stating that You changed the files; and

    (c) You must retain, in the Source form of any Derivative Works
    that You distribute, all copyright, patent, trademark, and
    attribution notices from the Source form of the Work,
    excluding those notices that do not pertain to any part of
    the Derivative Works; and

    (d) If the Work includes a "NOTICE" text file as part of its
    distribution, then any Derivative Works that You distribute must
    include a readable copy of the attribution notices contained
    within such NOTICE file, excluding those notices that do not
    pertain to any part of the Derivative Works, in at least one
    of the following places: within a NOTICE text file distributed
    as part of the Derivative Works; within the Source form or
    documentation, if provided along with the Derivative Works; or,
    within a display generated by the Derivative Works, if and
    wherever such third-party notices normally appear. The contents
    of the NOTICE file are for informational purposes only and
    do not modify the License. You may add Your own attribution
    notices within Derivative Works that You distribute, alongside
    or as an addendum to the NOTICE text from the Work, provided
    that such additional attribution notices cannot be construed
    as modifying the License.

    You may add Your own copyright statement to Your modifications and
    may provide additional or different license terms and conditions
    for use, reproduction, or distribution of Your modifications, or
    for any such Derivative Works as a whole, provided Your use,
    reproduction, and distribution of the Work otherwise complies with
    the conditions stated in this License.

5.  Submission of Contributions. Unless You explicitly state otherwise,
    any Contribution intentionally submitted for inclusion in the Work
    by You to the Licensor shall be under the terms and conditions of
    this License, without any additional terms or conditions.
    Notwithstanding the above, nothing herein shall supersede or modify
    the terms of any separate license agreement you may have executed
    with Licensor regarding such Contributions.

6.  Trademarks. This License does not grant permission to use the trade
    names, trademarks, service marks, or product names of the Licensor,
    except as required for reasonable and customary use in describing the
    origin of the Work and reproducing the content of the NOTICE file.

7.  Disclaimer of Warranty. Unless required by applicable law or
    agreed to in writing, Licensor provides the Work (and each
    Contributor provides its Contributions) on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
    implied, including, without limitation, any warranties or conditions
    of TITLE, NON-INFRINGEMENT, MERCHANTABILITY, or FITNESS FOR A
    PARTICULAR PURPOSE. You are solely responsible for determining the
    appropriateness of using or redistributing the Work and assume any
    risks associated with Your exercise of permissions under this License.

8.  Limitation of Liability. In no event and under no legal theory,
    whether in tort (including negligence), contract, or otherwise,
    unless required by applicable law (such as deliberate and grossly
    negligent acts) or agreed to in writing, shall any Contributor be
    liable to You for damages, including any direct, indirect, special,
    incidental, or consequential damages of any character arising as a
    result of this License or out of the use or inability to use the
    Work (including but not limited to damages for loss of goodwill,
    work stoppage, computer failure or malfunction, or any and all
    other commercial damages or losses), even if such Contributor
    has been advised of the possibility of such damages.

9.  Accepting Warranty or Additional Liability. While redistributing
    the Work or Derivative Works thereof, You may choose to offer,
    and charge a fee for, acceptance of support, warranty, indemnity,
    or other liability obligations and/or rights consistent with this
    License. However, in accepting such obligations, You may act only
    on Your own behalf and on Your sole responsibility, not on behalf
    of any other Contributor, and only if You agree to indemnify,
    defend, and hold each Contributor harmless for any liability
    incurred by, or claims asserted against, such Contributor by reason
    of your accepting any such warranty or additional liability.

END OF TERMS AND CONDITIONS

APPENDIX: How to apply the Apache License to your work.

      To apply the Apache License to your work, attach the following
      boilerplate notice, with the fields enclosed by brackets "[]"
      replaced with your own identifying information. (Don't include
      the brackets!)  The text should be enclosed in the appropriate
      comment syntax for the file format. We also recommend that a
      file or class name and description of purpose be included on the
      same "printed page" as the copyright notice for easier
      identification within third-party archives.

Copyright 2025 OpenAI

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```
</details>

<details>
<summary>MIT License (Every documentation review adaptations)</summary>

```text
MIT License

Copyright (c) 2025 Every

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
</details>
<!-- AI-REVIEW:END -->
