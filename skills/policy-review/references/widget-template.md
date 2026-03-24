# Widget template for policy review carousel

This is the full HTML/CSS/JS template for the interactive policy review widget.
It uses a **carousel** layout — one statement per view with Previous/Next
navigation and dot indicators.

## How to use this template

1. Parse the policy document into sections and statements.
2. Build the `sections` JavaScript array from the parsed data.
3. Copy the full template below into a `visualize:show_widget` call.
4. Replace `const sections = [...]` with the real data.
5. Replace `policyId` and `policyTitle` with the actual values.
6. If there is an AI suggestion to inject (from a POLICY_REWRITE_REQUEST
   roundtrip), set `state[id].aiSuggestion = "..."` after state initialization
   and set `currentIdx` to the correct statement index.

## Key behaviors

### Carousel navigation
- One statement per view in "By statement" mode.
- All statements in a section in "By section" mode.
- Dot indicators at the bottom: gray = pending, green = approved, blue =
  rewritten, red = rejected. Current position has a ring outline.
- Auto-advance: after Approve, Accept AI, or Reject, the carousel moves to
  the next statement.

### AI rewrite via sendPrompt roundtrip
- User clicks "Rewrite with AI" and types instructions, then clicks submit.
- Widget sends a `sendPrompt()` with a structured `POLICY_REWRITE_REQUEST`
  message including statement ID, current index, view mode, and current text.
- Claude receives it, rewrites the statement, and renders a **new carousel
  widget** at the bottom of chat with the AI suggestion pre-injected into
  `state[id].aiSuggestion`. The user continues from the new widget.

### HTML-direct rendering (no markdown parsing)
All statement text is pre-converted to HTML before reaching the widget. The
widget renders statement text directly via `innerHTML`:

```javascript
h += '<div class="card-txt">' + st.text + '</div>';
```

No `renderMd()` function is needed. No `esc()` on statement text. The HTML
is ready to display as-is. The `esc()` function is only used for short inline
values like labels and justification text.

CSS rules for proper HTML display in `.card-txt`:
```css
.card-txt p { margin: 0 0 0.75rem 0; }
.card-txt ul, .card-txt ol { margin: 0.5rem 0; padding-left: 1.5rem; }
.card-txt li { margin-bottom: 0.35rem; line-height: 1.6; }
.card-txt table { width: 100%; border-collapse: collapse; font-size: 14px; }
.card-txt th { text-align: left; font-weight: 500; padding: 8px 12px; ... }
.card-txt td { padding: 10px 12px; vertical-align: top; line-height: 1.5; }
```

### Version history
- Appears at the bottom when all statements are reviewed, or on demand via
  "Edit version history" button.
- Shows prior versions as a read-only table, current revision as editable form.
- Auto-increments version number from prior versions.

### Persistent storage and export

The widget must track an **audit log** during the review session. Every action
(approve, rewrite, reject) is logged with a timestamp and statement label.

On export, the widget's JavaScript function must:
1. Reconstruct the FULL policy document as HTML from all statements.
2. Read version history form fields (version, date, author, approved by, description).
3. **Await all storage writes** before calling `sendPrompt()`:
   - `soc2:working:{policyId}` — the full reconstructed HTML document
   - `soc2:review:{policyId}` — statement-level decisions with full HTML text
   - `soc2:versions:{policyId}` — all version history entries (prior + current)
   - `soc2:audit:{policyId}` — per-policy audit trail (appended, not replaced)
4. Send `POLICY_REVIEW_COMPLETE` with change summary, version metadata,
   AND explicit dashboard injection data:

```
POLICY_REVIEW_COMPLETE
Policy: Acceptable Use Policy
Policy ID: acceptable-use
Version: 1.1
Date: 2026-03-23
Author: Jane Smith
Approved by: John Doe
Description: Annual review

REVIEW STATUS: completed
STATEMENTS TOTAL: 15
STATEMENTS REVIEWED: 15

CHANGE SUMMARY:
- 14 approved, 1 rewritten: "Confidentiality", 0 rejected

Please render the SOC 2 dashboard and inject this policy's status directly
into the widget: { id: "acceptable-use", status: "completed", reviewed: 15, total: 15 }
```

The `REVIEW STATUS`, `STATEMENTS TOTAL`, and `STATEMENTS REVIEWED` lines are
critical — they tell Claude exactly what to inject into the dashboard widget
so it doesn't rely solely on storage reads (which may not have propagated).

Here is the export function pattern for the widget:
```javascript
async function exportReview() {
  // ... read form fields, build HTML, build audit log ...
  // Await ALL storage writes
  await window.storage.set('soc2:working:' + policyId, JSON.stringify(fullHtml));
  await window.storage.set('soc2:review:' + policyId, JSON.stringify({status:'completed', statements:stmts}));
  await window.storage.set('soc2:versions:' + policyId, JSON.stringify({versions:allVersions}));
  await window.storage.set('soc2:audit:' + policyId, JSON.stringify(auditLog));

  var reviewed = stmts.filter(function(s){return s.status!=='pending';}).length;
  var msg = 'POLICY_REVIEW_COMPLETE\n'
    + 'Policy: ' + policyTitle + '\n'
    + 'Policy ID: ' + policyId + '\n'
    + 'Version: ' + currentVersion.version + '\n'
    + 'Date: ' + currentVersion.date + '\n'
    + 'Author: ' + currentVersion.author + '\n'
    + 'Approved by: ' + currentVersion.approvedBy + '\n'
    + 'Description: ' + currentVersion.description + '\n\n'
    + 'REVIEW STATUS: completed\n'
    + 'STATEMENTS TOTAL: ' + stmts.length + '\n'
    + 'STATEMENTS REVIEWED: ' + reviewed + '\n\n'
    + 'CHANGE SUMMARY:\n- ' + approved.length + ' approved, '
    + rewritten.length + ' rewritten, '
    + rejected.length + ' rejected\n\n'
    + 'Please render the SOC 2 dashboard and inject this policy status directly '
    + 'into the widget: { id: "' + policyId + '", status: "completed", '
    + 'reviewed: ' + reviewed + ', total: ' + stmts.length + ' }';
  sendPrompt(msg);
}
```

### Audit log implementation in the widget

Track actions in a JavaScript array during the session:
```javascript
var auditLog = [];
function logAction(action, label, details) {
  auditLog.push({
    ts: new Date().toISOString(),
    action: action,    // "approved", "rewritten (manual)", "rewritten (AI)", "rejected"
    label: label,      // statement label
    details: details   // justification for reject, "AI rewrite" note, etc.
  });
}
```

Call `logAction()` in every `approve()`, `acceptAi()`, `submitMan()`, and
`submitRej()` function. On export, append `auditLog` to any existing entries
loaded from `soc2:audit:{policyId}` and save back.

## Statement text format: HTML

Since templates are pre-converted to HTML, each statement's `text` field is an
HTML string. Examples:

**Role descriptions (bullet list):**
```javascript
{ id: 5, label: "CEO responsibilities",
  text: "<ul><li>Oversight of Cyber-Risk and internal control</li><li>Approves Capital Expenditures</li></ul>" }
```

**Multi-paragraph statements:**
```javascript
{ id: 2, label: "Data classification",
  text: "<p>The company classifies data by sensitivity.</p><p>Data owners identify additional requirements.</p>" }
```

**Tables:**
```javascript
{ id: 6, label: "Roles and responsibilities",
  text: "<table><thead><tr><th>Role</th><th>Responsibility</th></tr></thead><tbody><tr><td>CISO</td><td>Leads BC/DR efforts.</td></tr></tbody></table>" }
```

The widget renders these directly: `h += '<div class="card-txt">' + st.text + '</div>';`

No `renderMd()` function is needed. No runtime parsing. Just `innerHTML`.
