---
name: policy-review
description: >
  Interactive policy document review workflow with AI-assisted rewrites. Use this
  skill whenever the user uploads a policy document (markdown, docx, PDF, or text)
  and wants to review, approve, rewrite, or reject individual statements. Triggers
  on: "review this policy", "help me approve this document", "policy review",
  "review these statements", "go through this policy with me", or any request to
  systematically walk through a governance/compliance/HR/security policy and make
  approve/reject/rewrite decisions on each part. Also triggers when the user uploads
  a file that looks like a policy and asks to "edit", "refine", "clean up", or
  "improve" it statement by statement. Use this skill even if the user only wants
  to review part of a policy or a single section.
---

# Policy review skill

Presents an interactive carousel-based review board for any policy document. The
user reviews each statement one at a time — approving, rejecting (with
justification), rewriting manually, or requesting an AI-assisted rewrite with
iterative refinement.

**All policy content is HTML.** The widget renders HTML directly via `innerHTML`.
No markdown parsing happens at runtime. AI rewrites produce HTML. Manual edits
save as HTML. Working copies in persistent storage are HTML.

---

## When this skill triggers

1. User uploads a policy file and asks to review it.
2. User references an already-uploaded policy.
3. User pastes policy text directly into the conversation.
4. The soc2-policies skill hands off a policy for review.

---

## HTML-only working copies — lazy creation

This skill operates on **HTML working copies** of policies.

**If launched from soc2-policies (typical flow):** The handoff prompt says
"load from soc2:working:{id} in persistent storage. If no working copy exists,
read the HTML template from references/templates/ and apply company name
replacement to create one."

Claude should:
1. First, try to read `soc2:working:{policy-id}` from persistent storage.
   If found, this is the working copy (may contain prior edits). Use it.
2. If NOT found (first time reviewing this policy), read the HTML template
   file from the soc2-policies skill's `references/templates/` directory.
   Apply company name replacement (`[COMPANY NAME]` → actual name).
   This HTML becomes the working copy. The review carousel will save it
   to `soc2:working:{policy-id}` on export — do not save it now.
3. Parse the HTML into sections and statements (Step 1), then render.

**If launched standalone** (user uploads a file directly):
1. If the file is markdown, convert to HTML once. If already HTML, use as-is.
2. Check `soc2:company-name` in storage. If not found and the text contains
   `[COMPANY NAME]` placeholders, ask the user. Store at `soc2:company-name`.
3. Apply company name replacement on the HTML string.

**Critical:** Never write back to template files. Never store markdown in
working copies. All working copies are HTML in persistent storage.

---

## Step 1: Parse the HTML policy into sections and statements

Read the HTML working copy. Extract the hierarchical structure:

- **Sections** correspond to `<h1>` or `<h2>` elements in the HTML.
- **Statements** are the content blocks between headings: `<p>`, `<ul>`, `<ol>`,
  `<table>` elements, or groups of these that form a single reviewable item.

Build a JavaScript array for the carousel widget. Each statement's `text` field
is an **HTML string** that the widget renders directly via `innerHTML`:

```javascript
var sections = [
  { id: 'core-policy', title: 'Core policy', items: [
    { id: 1, label: "Purpose", text: "<p>The aim of this plan is to...</p>" },
    { id: 2, label: "Scope", text: "<p>This policy covers...</p><ul><li>Item</li></ul>" }
  ]}
];
```

### Parsing guidelines
- Use the document's own heading structure. Don't invent groupings.
- Each statement should be a single reviewable unit.
- Preserve the HTML exactly as-is — don't convert to plain text.
- Give each statement a short descriptive label from its heading or content.
- Sequential numeric IDs starting from 1.

---

## Step 2: Build the interactive review carousel (COPY-AND-INJECT)

Read `references/review-widget.md` — it contains the COMPLETE runnable widget
code with all CSS, event handlers, storage logic, sendPrompt calls, and
audit logging built in. Claude's job is:

1. Read the template file
2. Set the injection variables at the top of the script block:
   - `var POLICY_ID` — e.g. "incident-response"
   - `var POLICY_TITLE` — e.g. "Incident response plan"
   - `var COMPANY` — e.g. "Acme Corp"
   - `var SECTIONS` — the parsed sections array from Step 1
   - `var AI_SUGGESTION` — null (or {id: N, html: "..."} for AI rewrite re-renders)
   - `var INITIAL_IDX` — 0 (or specific index for AI rewrite re-renders)
   - `var INITIAL_VIEW` — "statements" (or "sections")
3. Copy the entire widget code into `visualize:show_widget` VERBATIM

**Do NOT modify any CSS, HTML, event handlers, button labels, or storage logic.**
**Do NOT add functions, rename classes, or change the layout.**

The only things Claude changes are the injection variables. Everything else —
the carousel navigation, action buttons, version history form, export function,
audit logging — is fixed template code that works identically every time.

---

## Step 3: Handle AI rewrite requests (TWO mandatory sub-steps)

When the user triggers an AI rewrite, you receive a `POLICY_REWRITE_REQUEST`
message with the statement's current HTML text and the user's instructions.

### Step 3a: Generate the rewrite as HTML

Rewrite the statement based on the user's instructions. **Produce HTML output.**
Preserve structural elements: `<ul><li>`, `<ol><li>`, `<table>`, `<p>` etc.
The rewrite will be inserted directly into the widget via `innerHTML`.

### Step 3b: Re-render the carousel (MANDATORY — NOT OPTIONAL)

Immediately after generating the rewrite, call `visualize:show_widget` to
render a **fresh carousel** with:
1. All sections and statements from the original widget.
2. All prior state preserved (approvals, rejections, manual edits).
3. `state[statementId].aiSuggestion` set to the rewritten HTML.
4. `currentIdx` set to the correct position.

**Do NOT just return plain text. ALWAYS render the full carousel.**

---

## Step 4: Handle export (save and return to dashboard)

When the user clicks "Save and return to dashboard", the widget's JavaScript:

1. **Reconstructs the full HTML document** from all statements' current HTML.
2. **Builds the per-policy audit log** — a chronological list of every action
   taken during this review session:
   - Each approve, rewrite (manual or AI), and reject is logged with timestamp,
     statement label, action type, and for rewrites a summary of what changed.
   - The audit log is stored at `soc2:audit:{policyId}` as an array of entries.
   - New entries are appended to any existing audit log (from prior sessions).
3. **Reads version history fields** from the form (version, date, description,
   author, approved by) and captures them in the export data.
4. **Saves to persistent storage** (all as HTML, await all writes):
   - `soc2:working:{policyId}` — full reconstructed HTML document
   - `soc2:review:{policyId}` — statement decisions with full HTML text
   - `soc2:versions:{policyId}` — version history (all prior + current)
   - `soc2:audit:{policyId}` — per-policy audit trail
5. **Sends `POLICY_REVIEW_COMPLETE`** with change summary, version metadata,
   AND explicit dashboard state data:

```
POLICY_REVIEW_COMPLETE
Policy: Acceptable Use Policy
Policy ID: acceptable-use
Version: 1.1
Date: 2026-03-23
Author: Jane Smith
Approved by: John Doe
Description: Annual review and update

REVIEW STATUS: completed
STATEMENTS TOTAL: 15
STATEMENTS REVIEWED: 15

CHANGE SUMMARY:
- 14 statements approved as-is
- 1 statement rewritten: "Confidentiality and data protection"
- 0 statements rejected

Please render the SOC 2 dashboard. When building the dashboard widget, inject
this policy's status directly into the widget state as a fallback:
  { id: "acceptable-use", status: "completed", reviewed: 15, total: 15 }
The widget should ALSO read from persistent storage for all other policies.
This dual-source approach ensures the dashboard renders correctly even if
storage writes from this widget haven't fully propagated yet.
```

**Why dual-source matters:** The `sendPrompt()` call creates a new widget in
a new iframe. Storage writes from the previous widget may not have completed
before the new widget tries to read them. By including explicit status data
in the prompt, Claude can inject it directly into the dashboard widget as
a known-state override. The widget merges this with whatever it reads from
storage for the other 16 policies.

The version metadata MUST also be included in this message so the dashboard
and export skill can use it without relying on storage reads.

### Per-policy audit trail

The widget tracks actions during the review session. Each audit entry has:
- `timestamp` — ISO datetime
- `action` — "approved", "rewritten (manual)", "rewritten (AI)", "rejected"
- `statementLabel` — which statement was acted on
- `details` — for rewrites, a brief note; for rejections, the justification

The audit log is saved to `soc2:audit:{policyId}` and included in the exported
Word document as an "Audit trail" appendix — a chronological table that gives
SOC 2 auditors a self-contained provenance record for each policy.

This skill does NOT generate Word documents. The **policy-export skill** handles
that by reading the HTML working copy, version history, and audit log from storage.

### Session persistence (survives AI rewrite roundtrips)

The widget saves review progress to `soc2:review-session:{policyId}` after
EVERY action — approve, reject, rewrite, undo, bulk approve, discard, and
version history edits. This is separate from the final `soc2:review:{policyId}`
which is written only on export.

**Why this matters:** When the user triggers an AI rewrite, `sendPrompt()`
creates a new widget in a new iframe. Without session persistence, all prior
approvals/rejections would be lost. With it, the new widget loads the session
state on `init()` and the user continues where they left off.

**Storage keys:**
- `soc2:review-session:{id}` — live working state, written after every action,
  contains: statement decisions, audit log, view mode, carousel position,
  version metadata. Cleared on final export.
- `soc2:review:{id}` — final state, written only on "Save and return to
  dashboard". This is what the dashboard and export skill read.

**The session state stores:**
```javascript
{
  decisions: {
    "1": { status: "approved", text: "...", justification: "", aiSuggestion: null },
    "6": { status: "rewritten", text: "<table>new...</table>", justification: "", aiSuggestion: null }
  },
  auditLog: [ { ts: "...", action: "approved", label: "Purpose", details: "" }, ... ],
  viewMode: "statements",
  currentIdx: 5,
  versionMeta: { version: "1.0", date: "...", author: "...", ... }
}
```

Only non-pending decisions are stored (to keep the payload small). On load,
any statement ID not in `decisions` stays at its default pending state.

---

## Data format rule (enforced everywhere)

**HTML is the only format for policy content in this system.**

- Statement `text` fields are HTML strings.
- `state[id].text`, `state[id].originalText`, `state[id].aiSuggestion` are HTML.
- Working copies in `soc2:working:{id}` are HTML.
- AI rewrites must produce HTML, not markdown.
- Manual edit saves convert plain text to basic HTML (`<p>` wrapping).
- The widget uses `innerHTML` for rendering — never `textContent` + `esc()`.

---

## Integration with soc2-policies skill

When launched from soc2-policies (prompt includes "Policy ID" and "WORKING
COPY (HTML)"), the export step persists everything to `window.storage`. The
soc2-policies dashboard reads it back when re-rendered.

---

## Edge cases

- **Partial review**: Unreviewed statements treated as approved on export.
- **Very long policies**: Suggest reviewing by section if >30 statements.
- **Non-standard structure**: Create a single "Policy statements" section.
- **Multiple rounds**: Each export updates the HTML working copy. Next review
  starts from the latest approved HTML version.
- **AI rewrite preserves state**: Re-rendering the carousel after an AI rewrite
  must carry forward all prior decisions.
