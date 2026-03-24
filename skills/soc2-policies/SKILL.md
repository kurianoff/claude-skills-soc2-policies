---
name: soc2-policies
description: >
  SOC 2 policy management dashboard with persistent progress tracking across
  sessions. Use this skill whenever the user mentions SOC 2 policies, compliance
  templates, policy dashboard, or wants to manage a set of governance/compliance
  policy documents as a collection. Triggers on: "SOC 2 dashboard", "show my
  policies", "policy templates", "SOC 2 readiness", "compliance dashboard",
  "open the dashboard", "where did I leave off", "resume my policy review",
  "export my policies", "audit trail", or any request to view, manage, or track
  progress across multiple policy documents. Also triggers when the user uploads
  multiple policy files at once and wants to organize them. This skill chains
  with the policy-review skill — use this skill for the dashboard/collection
  layer and hand off to policy-review for individual document review.
---

# SOC 2 policy management dashboard

A persistent dashboard for managing a collection of SOC 2 policy documents.
Displays policies as cards with status tracking, enables drill-down into
individual policy review (via the policy-review skill), persists all progress
across sessions using artifact storage, and exports completed policies as Word
documents (via the policy-export skill).

**All policy content is HTML throughout the entire pipeline.** Templates are
stored as HTML. Working copies are HTML. Review state stores HTML. Exports
receive HTML. No markdown-to-HTML conversion happens at runtime.

---

## Architecture overview

```
soc2-policies (this skill)
  ├── Dashboard UI (card grid, status, progress)
  ├── HTML templates (references/templates/*.html) — read-only, read on demand
  ├── Persistent storage (working copies, review state)
  └── Hands off to:
      ├── policy-review skill (per-document review)
      └── policy-export skill (Word document generation)
```

---

## CRITICAL: Lazy initialization — do NOT pre-create all working copies

The dashboard does NOT need working copies of all 17 policies to render. It
only needs the hardcoded policy manifest (titles, descriptions, categories)
and review status from `soc2:review:{id}` in persistent storage.

**Working copies are created lazily — only when a user first reviews a policy.**

### Why this matters

Previous implementations tried to read all 17 HTML template files, write them
all to persistent storage, then render the dashboard. This caused:
- Multi-step initialization with helper widgets/scripts
- Race conditions between storage writes and dashboard reads
- Confusing "loading" states that broke the UX

The fix: **the dashboard renders immediately from hardcoded metadata + storage
reads for review status. No template files are read at dashboard launch time.**

### When working copies ARE created

A working copy is created at drill-down time (Step 3), not at dashboard launch:
1. User clicks "Review" on a policy card
2. Claude receives the sendPrompt with the policy ID
3. Claude reads the ONE template file for that policy from `references/templates/`
4. Claude applies company name replacement
5. Claude saves the HTML working copy to `soc2:working:{policy-id}`
6. Claude hands the HTML to the policy-review skill

On subsequent reviews of the same policy, the working copy already exists in
storage — Claude reads it from there instead of the template file.

---

## Step 1: Determine company name and launch

When this skill triggers, Claude must determine the company name before
rendering the dashboard (because the dashboard template needs it as an
injection variable).

### Decision flow

1. **Check if the company name is already known** — from the current
   conversation context (user said it, prior message included it, or a
   `POLICY_REVIEW_COMPLETE` message mentioned it).
2. **If known** → go directly to Step 2 (render the dashboard).
3. **If NOT known** → render the welcome widget (COPY-AND-INJECT from
   `references/welcome-widget.md`). This widget:
   - Shows "Welcome to SOC 2 policy manager"
   - Has a text input for company name
   - On "Get started", saves the name to `soc2:company-name` in storage
     and sends a `sendPrompt()` that triggers Step 2

**Claude should NEVER ask for the company name in prose or via ask_user_input.**
Always use the welcome widget. It provides a consistent first-run experience.

### After the welcome widget

The welcome widget sends:
```
Company name set to: Acme Corp
Please render the SOC 2 policy dashboard for Acme Corp.
```

Claude receives this and renders the dashboard (Step 2) with
`var COMPANY = "Acme Corp";`.

### Bundled policy templates (HTML, read-only)

This skill ships with 17 pre-converted HTML templates in
`references/templates/`. They are read-only and only read when a specific
policy is drilled into for the first time.

| File | Policy ID | Policy | Category |
|------|-----------|--------|----------|
| `acceptable_use_policy.html` | acceptable-use | Acceptable use policy | Governance |
| `access_control_policy.html` | access-control | Access control policy | Access |
| `asset_management_policy.html` | asset-management | Asset management policy | Operations |
| `business_continuity_and_disaster_recovery_plan.html` | business-continuity | Business continuity and disaster recovery plan | Operations |
| `code_of_conduct.html` | code-of-conduct | Code of conduct | HR |
| `cryptography_policy.html` | cryptography | Cryptography policy | Security |
| `data_management_policy.html` | data-management | Data management policy | Data |
| `human_resources_security_policy.html` | hr-security | Human resources security policy | HR |
| `incident_response_plan.html` | incident-response | Incident response plan | Security |
| `information_security_policy.html` | info-security | Information security policy | Security |
| `information_security_roles_and_responsibilities.html` | roles-responsibilities | Information security roles and responsibilities | Governance |
| `operations_security_policy.html` | operations-security | Operations security policy | Operations |
| `physical_security_policy.html` | physical-security | Physical security policy | Security |
| `removable_media_policy.html` | removable-media | Removable media policy | Security |
| `risk_management_policy.html` | risk-management | Risk management policy | Risk |
| `secure_development_policy.html` | secure-development | Secure development policy | Operations |
| `third_party_management_policy.html` | third-party | Third-party management policy | Risk |

---

## Step 2: Build the dashboard widget (COPY-AND-INJECT)

Read `references/dashboard-widget.md` — it contains the COMPLETE runnable
widget code. Claude's job is:

1. Read the template file
2. Set `var COMPANY = "Actual Company Name";` (injection point 1)
3. Set `var INJECTED = { ... };` with any known policy statuses (injection point 2)
4. Copy the entire widget code into `visualize:show_widget` VERBATIM

**Do NOT modify any CSS, HTML, event handlers, button labels, or storage logic.**
**Do NOT add functions, rename classes, or change the layout.**

The only two things Claude changes are the COMPANY and INJECTED variables.
Everything else is fixed template code that renders identically every time.

### Dashboard features

- Card grid with title, category badge, description, status, progress bar
- Top-level stats: readiness %, completed/in-progress/not-started counts
- Category filter buttons
- Per-card actions: Review, Export as Word (completed only), Reset

### Persistent storage keys

- `soc2:company-name` — the customer's company name
- `soc2:manifest` — (optional) policy metadata, but the widget hardcodes this
- `soc2:working:{policy-id}` — HTML working copy (created lazily on first review)
- `soc2:review:{policy-id}` — review decisions with HTML text per statement
- `soc2:versions:{policy-id}` — version history entries
- `soc2:audit:{policy-id}` — per-policy audit trail

---

## Step 3: Handle drill-down to policy review (LAZY WORKING COPY CREATION)

When the user clicks "Review" on a card, the widget sends a `sendPrompt()`.
Claude receives it and must:

1. **Check storage for an existing working copy** at `soc2:working:{policy-id}`.
2. **If found**: Use it directly — it may contain edits from a prior review.
3. **If not found**: Read the HTML template file from `references/templates/`,
   apply company name replacement (`[COMPANY NAME]` → actual name), and this
   becomes the working copy. Do NOT save it to storage yet — the policy-review
   carousel will save it on export.
4. **Hand off to policy-review**: Parse the HTML into sections and statements,
   then render the review carousel.

The handoff prompt from the widget looks like:

```
I want to review the policy: "Incident Response Plan".
Please use the policy-review skill...

Policy ID: incident-response
Company name: Acme Corp
This is a WORKING COPY (HTML) — load from soc2:working:incident-response
in persistent storage. If no working copy exists, read the HTML template
from references/templates/ and apply company name replacement.
```

**Claude reads ONE template file at this point — not all 17.** This is the
lazy initialization in action.

---

## Step 4: Save review results back to dashboard (DUAL-SOURCE STATE)

When a policy review completes, you'll receive a `POLICY_REVIEW_COMPLETE`
message containing explicit status data:

```
POLICY_REVIEW_COMPLETE
Policy: Incident Response Plan
Policy ID: incident-response
REVIEW STATUS: completed
STATEMENTS TOTAL: 23
STATEMENTS REVIEWED: 23
...
```

**You MUST use dual-source state when re-rendering the dashboard.**

### What "dual-source" means

The carousel widget saves review data to storage before `sendPrompt()`, but
writes are async and may not have propagated. The dashboard gets state from:

1. **Injected state (from the prompt)** — Claude hardcodes the known policy
   status directly into the widget JavaScript:

```javascript
var INJECTED = {
  "incident-response": { status: "completed", reviewed: 23, total: 23 }
};
```

2. **Storage state (for everything else)** — Widget reads `soc2:review:{id}`
   for all 17 policies.

### How the widget merges them

```javascript
async function init() {
  // Load from storage
  for (var i = 0; i < P.length; i++) {
    var r = await SL('soc2:review:' + P[i].id);
    if (r) ST[P[i].id] = r;
  }
  // Injected state overrides storage
  Object.keys(INJECTED).forEach(function(id) {
    var inj = INJECTED[id];
    if (!ST[id] || inj.status === 'completed') {
      ST[id] = {
        status: inj.status,
        statements: Array.from({length: inj.total}, function(_, i) {
          return { id: i+1, status: i < inj.reviewed ? 'approved' : 'pending' };
        })
      };
    }
  });
  loaded = true; render();
}
```

### When to inject

- **After POLICY_REVIEW_COMPLETE**: Always inject the completed policy.
- **Mid-session re-open**: If conversation history shows reviewed policies,
  inject those too.
- **First launch / no known state**: `var INJECTED = {};`

### Critical rule

**Never render a dashboard that relies solely on storage reads after a review
completes.** Always inject the just-completed policy's status.

---

## Step 5: Export completed policies as Word documents

When the user requests a Word export, hand off to the **policy-export skill**.

The export button sends a prompt including the policy ID, company name, and
instructions to read the HTML working copy, version history, and audit trail
from persistent storage.

**The dashboard never generates Word documents itself.**

---

## Data format rule (enforced everywhere)

**HTML is the only format for policy content in this system.**

- Templates in `references/templates/` are `.html` files.
- Working copies in `soc2:working:{id}` are HTML strings.
- Statement text in `soc2:review:{id}` is HTML.
- AI rewrites produce HTML.
- Manual edits save as HTML.
- Export receives HTML.
- The widget renders HTML directly via `innerHTML` — no parsing at runtime.

If any input arrives as markdown (e.g., user uploads a `.md` file), convert
to HTML once at point of entry, then work exclusively with HTML.

---

## Edge cases

- **Returning with no prior state**: Dashboard renders all 17 cards as "Not
  started" from the hardcoded manifest. No initialization needed.
- **Uploading custom policies**: Convert to HTML, save as working copy,
  add to manifest in storage.
- **Re-reviewing a completed policy**: Allow it — the working copy retains
  prior edits so the user starts from their last approved version.
- **Resetting a policy**: Delete `soc2:review:{id}`, `soc2:working:{id}`,
  `soc2:versions:{id}`, and `soc2:audit:{id}`. Card reverts to "Not started".
