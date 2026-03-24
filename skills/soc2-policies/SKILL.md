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
and audit history across sessions using artifact storage, and exports completed
policies as Word documents (via the policy-export skill).

**All policy content is HTML throughout the entire pipeline.** Templates are
stored as HTML. Working copies are HTML. Review state stores HTML. Exports
receive HTML. No markdown-to-HTML conversion happens at runtime.

---

## Architecture overview

```
soc2-policies (this skill)
  ├── Dashboard UI (card grid, status, progress)
  ├── HTML templates (references/templates/*.html)
  ├── Persistent storage (working copies, review state, audit trail)
  └── Hands off to:
      ├── policy-review skill (per-document review)
      └── policy-export skill (Word document generation)
```

---

## Step 1: Detect context and load state

When this skill triggers, first check if there's existing saved state:

1. Build the dashboard widget (Step 2). The widget itself will attempt to load
   saved state from `window.storage` on initialization.
2. If the user is uploading new policy templates, parse them and merge with any
   existing state (don't overwrite completed reviews).
3. If the user is returning ("where did I leave off", "open the dashboard"),
   the widget loads persisted state automatically.

### Company name

Before launching the dashboard for the first time, politely ask the user for
their company name. This is used to replace all `[COMPANY NAME]` and
`[Company Name]` placeholders in the policy templates.

Store the company name in persistent storage at key `soc2:company-name`.
On subsequent visits, load it from storage — don't ask again.

When drilling down to a policy review (Step 3), always include the company name
in the handoff prompt so the policy-review skill can apply the replacement.

### Bundled SOC 2 policy templates (HTML, read-only)

This skill ships with 17 pre-converted HTML policy templates in
`references/templates/`. These are already HTML — no markdown conversion is
needed at any point.

The bundled templates are:

| File | Policy | Category |
|------|--------|----------|
| `acceptable_use_policy.html` | Acceptable use policy | Governance |
| `access_control_policy.html` | Access control policy | Access |
| `asset_management_policy.html` | Asset management policy | Operations |
| `business_continuity_and_disaster_recovery_plan.html` | Business continuity and disaster recovery plan | Operations |
| `code_of_conduct.html` | Code of conduct | HR |
| `cryptography_policy.html` | Cryptography policy | Security |
| `data_management_policy.html` | Data management policy | Data |
| `human_resources_security_policy.html` | Human resources security policy | HR |
| `incident_response_plan.html` | Incident response plan | Security |
| `information_security_policy.html` | Information security policy | Security |
| `information_security_roles_and_responsibilities.html` | Information security roles and responsibilities | Governance |
| `operations_security_policy.html` | Operations security policy | Operations |
| `physical_security_policy.html` | Physical security policy | Security |
| `removable_media_policy.html` | Removable media policy | Security |
| `risk_management_policy.html` | Risk management policy | Risk |
| `secure_development_policy.html` | Secure development policy | Operations |
| `third_party_management_policy.html` | Third-party management policy | Risk |

### Working copies as HTML (customer workspace)

On first initialization, the dashboard creates **working copies** from the HTML
templates and stores them in persistent storage. Since the templates are already
HTML, initialization is just: read template HTML → apply company name
replacement → save to storage. No conversion step.

Storage keys for working copies:

- `soc2:working:{policy-id}` — the full working copy as HTML

**Initialization flow:**
1. Read each template `.html` file from `references/templates/`.
2. Apply company name replacement (`[COMPANY NAME]` → actual name) via string
   replacement on the HTML.
3. Save each HTML result to `soc2:working:{policy-id}` in persistent storage.
4. On subsequent visits, load working copies from storage — don't re-read
   templates unless the user explicitly requests a reset.

**When drilling down to policy review (Step 3):** Always pass the HTML working
copy from `soc2:working:{policy-id}`, never the raw template.

**When a review completes:** The policy-review skill saves the updated HTML
working copy back to `soc2:working:{policy-id}`.

### Uploading custom templates

Users can also upload their own policy files. If they upload markdown (`.md`),
convert to HTML before saving as the working copy. If they upload `.html`, save
directly. The working copy in storage is always HTML.

---

## Step 2: Build the dashboard widget

Use `visualize:show_widget` to render the dashboard. Read
`references/dashboard-template.md` for the complete HTML/CSS/JS template.

The dashboard provides:

### Card grid
- Each policy is a card showing: title, category badge, description snippet,
  review status (not started / in progress / completed), and progress stats.
- Cards are color-coded by status.

### Top-level stats
- Overall readiness: percentage of policies completed
- Counts: completed / in progress / not started

### Persistent storage
The widget uses `window.storage` to save and load:
- `soc2:manifest` — the list of policies with their metadata
- `soc2:working:{policy-id}` — the full HTML working copy of each policy
- `soc2:review:{policy-id}` — review decisions with full HTML text per statement
- `soc2:versions:{policy-id}` — version history entries
- `soc2:audit:{policy-id}` — per-policy audit trail (actions taken during review)
- `soc2:company-name` — the customer's company name

Note: audit tracking is per-policy, not global. Each policy carries its own
audit log which gets included in the exported Word document.

### Actions
- **Review** (on each card): launches policy-review for that document
- **Export as Word**: invokes the policy-export skill
- **Reset**: clears review state and working copy for a policy

---

## Step 3: Handle drill-down to policy review

When the user clicks "Review" on a card, the dashboard must pass the **HTML
working copy**, not the template. The widget loads the working copy from
`soc2:working:{policy-id}` and sends a prompt like:

```
Review the following policy document using the policy-review skill.
This is a WORKING COPY (HTML) — do not read from templates.

Policy ID: info-security-policy
Policy title: Information Security Policy
Company name: Acme Corp

[full HTML working copy here]
```

---

## Step 4: Save review results back to dashboard (DUAL-SOURCE STATE)

When a policy review completes, you'll receive a `POLICY_REVIEW_COMPLETE`
message containing explicit status data for the reviewed policy:

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

The carousel widget saves review data to `window.storage` before sending
`sendPrompt()`, but storage writes are async and may not have propagated by
the time the new dashboard widget reads them. To prevent the "Not started"
bug, the dashboard gets state from TWO sources:

1. **Injected state (from the prompt)** — Claude hardcodes the known policy
   status directly into the widget's JavaScript as an override object:

```javascript
var INJECTED = {
  "incident-response": { status: "completed", reviewed: 23, total: 23 }
};
```

2. **Storage state (for everything else)** — The widget reads
   `soc2:review:{id}` for all 17 policies on init, same as before.

### How the widget merges them

In the widget's `init()` function, after loading from storage, merge injected
state so it takes priority:

```javascript
async function init() {
  // Load from storage for all policies
  for (var i = 0; i < P.length; i++) {
    var r = await SL('soc2:review:' + P[i].id);
    if (r) ST[P[i].id] = r;
  }
  // Injected state overrides storage (belt and suspenders)
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

- **After a POLICY_REVIEW_COMPLETE message**: Always inject the completed
  policy's status. This is the primary use case.
- **When re-opening the dashboard mid-session**: If Claude knows from the
  conversation history that certain policies have been reviewed, inject
  those statuses too.
- **On first launch with no prior state**: `INJECTED = {}` (empty) — the
  widget relies entirely on storage.

### Critical rule

**Never render a dashboard that relies solely on storage reads after a review
completes.** Always inject the just-completed policy's status. Storage is the
backup, not the primary source for the policy that was just reviewed.

---

## Step 5: Export completed policies as Word documents

When the user requests a Word export, hand off to the **policy-export skill**.

The dashboard widget's export button loads the HTML working copy from
`soc2:working:{policy-id}` and sends a `POLICY_EXPORT_REQUEST` prompt with the
full HTML document. The policy-export skill converts HTML directly to `.docx`.

**The dashboard never generates Word documents itself.** It always delegates
to the policy-export skill.

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

If any input arrives as markdown (e.g., a user uploads a `.md` file), convert
it to HTML once at the point of entry, then work exclusively with HTML from
that point forward.

---

## Edge cases

- **Returning with no prior state**: If `window.storage` has no saved data and
  the user hasn't uploaded files, explain that they need to upload their policy
  templates to get started (or use the bundled set).
- **Uploading additional policies later**: Merge new uploads with existing state.
  Don't overwrite policies that are already in progress or completed.
- **Re-reviewing a completed policy**: Allow it — reset the policy's review state
  but log the re-review start in the audit trail. The working copy retains prior
  edits so the user starts from their last approved version.
- **Large policy sets**: If more than 20 policies, add category filtering.
