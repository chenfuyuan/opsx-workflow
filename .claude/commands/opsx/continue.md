---
name: "OPSX: Continue"
description: Continue working on a change - create the next artifact (Experimental)
category: Workflow
tags: [workflow, artifacts, experimental]
---

Continue working on a change by creating the next artifact.

**Input**: Optionally specify a change name after `/opsx:continue` (e.g., `/opsx:continue add-auth`). If omitted, check if it can be inferred from conversation context. If vague or ambiguous you MUST prompt for available changes.

**Steps**

1. **If no change name provided, prompt for selection**

   Run `openspec list --json` to get available changes sorted by most recently modified. Then use the **AskUserQuestion tool** to let the user select which change to work on.

   Present the top 3-4 most recently modified changes as options, showing:
   - Change name
   - Schema (from `schema` field if present, otherwise "spec-driven")
   - Status (e.g., "0/5 tasks", "complete", "no tasks")
   - How recently it was modified (from `lastModified` field)

   Mark the most recently modified change as "(Recommended)" since it's likely what the user wants to continue.

   **IMPORTANT**: Do NOT guess or auto-select a change. Always let the user choose.

2. **Check current status**
   ```bash
   openspec status --change "<name>" --json
   ```
   Parse the JSON to understand current state. The response includes:
   - `schemaName`: The workflow schema being used (e.g., "spec-driven")
   - `artifacts`: Array of artifacts with their status ("done", "ready", "blocked")
   - `isComplete`: Boolean indicating if all artifacts are complete

3. **Act based on status**:

   ---

   **If all artifacts are complete (`isComplete: true`)**:
   - Congratulate the user
   - Show final status including the schema used
   - Suggest: "All artifacts created! You can now implement this change with `/opsx:apply` using the default TDD workflow, or archive it with `/opsx:archive`."
   - STOP

   ---

   **If artifacts are ready to create** (status shows artifacts with `status: "ready"`):
   - **Check for pre_design**: Read `openspec/changes/<name>/pre_design.md` if it exists (and any sibling `pre_design.*.md` volume files). This is the **binding upstream constraint** for artifact generation.
   - Pick the FIRST artifact with `status: "ready"` from the status output
   - Get its instructions:
     ```bash
     openspec instructions <artifact-id> --change "<name>" --json
     ```
   - Parse the JSON. The key fields are:
     - `context`: Project background (constraints for you - do NOT include in output)
     - `rules`: Artifact-specific rules (constraints for you - do NOT include in output)
     - `template`: The structure to use for your output file
     - `instruction`: Schema-specific guidance
     - `outputPath`: Where to write the artifact
     - `dependencies`: Completed artifacts to read for context
   - **Create the artifact file**:
     - Read any completed dependency files for context
     - **If pre_design exists**: apply pre_design constraints (see "Pre-Design Constraint Rules" section below)
     - Use `template` as the structure - fill in its sections
     - Apply `context` and `rules` as constraints when writing - but do NOT copy them into the file
     - Write to the output path specified in instructions
   - Show what was created and what's now unlocked
   - If pre_design was used, note: "Generated under pre_design constraints."
   - STOP after creating ONE artifact

   ---

   **If no artifacts are ready (all blocked)**:
   - This shouldn't happen with a valid schema
   - Show status and suggest checking for issues

4. **After creating an artifact, show progress**
   ```bash
   openspec status --change "<name>"
   ```

**Output**

After each invocation, show:
- Which artifact was created
- Schema workflow being used
- Current progress (N/M complete)
- What artifacts are now unlocked
- Prompt: "Run `/opsx:continue` to create the next artifact"

**Artifact Creation Guidelines**

The artifact types and their purpose depend on the schema. Use the `instruction` field from the instructions output to understand what to create.

Common artifact patterns:

**spec-driven schema** (proposal → specs → design → tasks):
- **proposal.md**: Ask user about the change if not clear. Fill in Why, What Changes, Capabilities, Impact.
  - The Capabilities section is critical - each capability listed will need a spec file.
- **specs/<capability>/spec.md**: Create one spec per capability listed in the proposal's Capabilities section (use the capability name, not the change name).
- **design.md**: Document technical decisions, architecture, and implementation approach.
- **tasks.md**: Break down implementation into checkboxed tasks.

For other schemas, follow the `instruction` field from the CLI output.

**Pre-Design Constraint Rules**

When `pre_design.md` exists in the change directory, it is the **primary upstream constraint** for artifact generation. Apply the following rules:

1. **Binding sections** — The following sections in `pre_design` are hard constraints that downstream artifacts must not contradict:
   - Problem framing / Goals / Non-goals
   - Constraints / Invariants
   - Key decisions / Trade-offs
   - Generation guardrails → "Must follow" items
   - Generation guardrails → "Forbidden to invent" items

2. **Mapping guidance** — The `OpenSpec mapping` section in `pre_design` explicitly describes what each downstream artifact should focus on:
   - Use `What proposal.md should cover` to guide `proposal.md` content
   - Use `What design.md should cover` to guide `design.md` content
   - Use `What tasks.md should cover` to guide `tasks.md` content

3. **Allowed elaboration** — The "Allowed to elaborate" section defines the space where downstream artifacts may add detail without violating `pre_design` constraints.

4. **Scope control** — If `pre_design` lists explicit Non-goals, downstream artifacts must NOT introduce work that falls within those Non-goals.

5. **Contract fidelity** — If `pre_design` defines contract drafts (request/response fields, API surface), downstream artifacts must not expand the public contract beyond what `pre_design` specifies.

6. **Priority** — When `pre_design` constraints conflict with `openspec instructions` context, `pre_design` takes precedence.

**Guardrails**
- Create ONE artifact per invocation
- Always read dependency artifacts before creating a new one
- If pre_design exists, read it first and treat it as the highest-priority constraint
- Never skip artifacts or create out of order
- If context is unclear, ask the user before creating
- Verify the artifact file exists after writing before marking progress
- Use the schema's artifact sequence, don't assume specific artifact names
- **IMPORTANT**: `context` and `rules` are constraints for YOU, not content for the file
  - Do NOT copy `<context>`, `<rules>`, `<project_context>` blocks into the artifact
  - These guide what you write, but should never appear in the output
