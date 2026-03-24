# Dashboard widget template for SOC 2 policy management

This is the full HTML/CSS/JS template for the SOC 2 dashboard. When building
the widget, inject the parsed policy manifest into the `const policies = [...]`
array at the top of the script block.

## How to use this template

1. Parse all uploaded policy files into the manifest format.
2. Inject the manifest into the `policies` array.
3. Render via `visualize:show_widget`.
4. The widget handles its own persistence via `window.storage`.

## Storage keys

- `soc2:manifest` — JSON array of policy metadata (id, title, description, category, status)
- `soc2:content:{id}` — full policy text for each policy
- `soc2:review:{id}` — review decisions: `{ status, statements: [{id, label, status, text, originalText, justification}] }`
- `soc2:audit` — JSON array of audit entries: `{ timestamp, action, policyId, policyTitle, details }`

## Full template

Use loading messages like:
```
["Loading your policy dashboard", "Checking saved progress", "Rendering policy cards"]
```

Title: `soc2_policy_dashboard`

```html
<div id="dashboard" style="padding: 1rem 0; font-family: var(--font-sans);"></div>

<style>
.dash-stats { display: flex; gap: 12px; margin-bottom: 1.5rem; flex-wrap: wrap; }
.dash-stat { background: var(--color-background-secondary); border-radius: var(--border-radius-md); padding: 0.75rem 1rem; min-width: 120px; }
.dash-stat-label { font-size: 12px; color: var(--color-text-secondary); margin-bottom: 2px; }
.dash-stat-value { font-size: 20px; font-weight: 500; color: var(--color-text-primary); }
.dash-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(280px, 1fr)); gap: 12px; margin-bottom: 1.5rem; }
.policy-card {
  background: var(--color-background-primary);
  border: 0.5px solid var(--color-border-tertiary);
  border-radius: var(--border-radius-lg);
  padding: 1.25rem;
  cursor: pointer;
  transition: border-color 0.15s, background 0.15s;
  display: flex;
  flex-direction: column;
  gap: 8px;
}
.policy-card:hover { border-color: var(--color-border-secondary); background: var(--color-background-secondary); }
.policy-card-title { font-size: 15px; font-weight: 500; color: var(--color-text-primary); line-height: 1.3; }
.policy-card-desc { font-size: 13px; color: var(--color-text-secondary); line-height: 1.5; display: -webkit-box; -webkit-line-clamp: 2; -webkit-box-orient: vertical; overflow: hidden; }
.policy-card-footer { display: flex; justify-content: space-between; align-items: center; margin-top: auto; padding-top: 8px; }
.cat-badge { font-size: 11px; font-weight: 500; padding: 2px 10px; border-radius: var(--border-radius-md); }
.cat-security { background: #E6F1FB; color: #0C447C; }
.cat-access { background: #EEEDFE; color: #3C3489; }
.cat-operations { background: #E1F5EE; color: #085041; }
.cat-hr { background: #FAEEDA; color: #633806; }
.cat-risk { background: #FCEBEB; color: #791F1F; }
.cat-general { background: var(--color-background-secondary); color: var(--color-text-secondary); }
.status-badge { font-size: 11px; font-weight: 500; padding: 2px 10px; border-radius: var(--border-radius-md); }
.status-not-started { background: var(--color-background-secondary); color: var(--color-text-secondary); }
.status-in-progress { background: #EEEDFE; color: #3C3489; }
.status-completed { background: #E1F5EE; color: #085041; }
.progress-mini { width: 100%; height: 4px; background: var(--color-background-secondary); border-radius: 2px; margin-top: 6px; overflow: hidden; }
.progress-mini-fill { height: 100%; border-radius: 2px; transition: width 0.3s; }
.progress-fill-progress { background: #7F77DD; }
.progress-fill-done { background: #5DCAA5; }
.card-actions { display: flex; gap: 8px; margin-top: 8px; }
.card-actions button {
  font-size: 12px; padding: 5px 12px; border-radius: var(--border-radius-md); cursor: pointer; font-weight: 500;
  border: 0.5px solid var(--color-border-secondary); background: transparent; color: var(--color-text-primary);
  transition: background 0.15s, transform 0.1s;
}
.card-actions button:hover { background: var(--color-background-secondary); }
.card-actions button:active { transform: scale(0.98); }
.btn-review { border-color: #AFA9EC !important; color: #534AB7 !important; }
.btn-review:hover { background: #EEEDFE !important; }
.btn-export { border-color: #5DCAA5 !important; color: #0F6E56 !important; }
.btn-export:hover { background: #E1F5EE !important; }
.audit-panel { margin-top: 1.5rem; }
.audit-toggle {
  font-size: 14px; font-weight: 500; color: var(--color-text-secondary); cursor: pointer;
  padding-bottom: 6px; border-bottom: 0.5px solid var(--color-border-tertiary);
  display: flex; align-items: center; gap: 8px; user-select: none; margin-bottom: 1rem;
}
.audit-entry {
  font-size: 13px; color: var(--color-text-secondary); padding: 8px 0;
  border-bottom: 0.5px solid var(--color-border-tertiary); line-height: 1.5;
}
.audit-entry:last-child { border-bottom: none; }
.audit-time { font-size: 11px; color: var(--color-text-tertiary); margin-right: 8px; }
.audit-action { color: var(--color-text-primary); font-weight: 500; }
.filter-bar { display: flex; gap: 8px; margin-bottom: 1rem; flex-wrap: wrap; }
.filter-bar button {
  font-size: 12px; padding: 4px 12px; border-radius: var(--border-radius-md); cursor: pointer;
  border: 0.5px solid var(--color-border-secondary); background: transparent; color: var(--color-text-secondary);
  transition: background 0.15s;
}
.filter-bar button.active { background: var(--color-background-secondary); color: var(--color-text-primary); }
.filter-bar button:hover { background: var(--color-background-secondary); }
.chevron { display: inline-block; transition: transform 0.2s; font-size: 12px; }
.chevron.open { transform: rotate(90deg); }
.empty-state { text-align: center; padding: 3rem 1rem; color: var(--color-text-secondary); }
.empty-state p { font-size: 15px; line-height: 1.6; margin: 0; }
</style>

<script>
// === INJECT PARSED POLICY MANIFEST HERE ===
// Replace with actual policies parsed from uploaded files.
// If empty, the widget will attempt to load from storage.
const injectedPolicies = [];

// === STORAGE ENGINE ===
const STORAGE = {
  async load(key) {
    try { const r = await window.storage.get(key); return r ? JSON.parse(r.value) : null; }
    catch { return null; }
  },
  async save(key, val) {
    try { await window.storage.set(key, JSON.stringify(val)); return true; }
    catch { return false; }
  },
  async delete(key) {
    try { await window.storage.delete(key); return true; }
    catch { return false; }
  },
  async listKeys(prefix) {
    try { const r = await window.storage.list(prefix); return r ? r.keys : []; }
    catch { return []; }
  }
};

// === STATE ===
let policies = [];
let reviews = {};
let auditLog = [];
let activeFilter = 'all';
let auditOpen = false;
let loaded = false;

function esc(t) { const d = document.createElement('div'); d.textContent = t; return d.innerHTML; }

const catMap = {
  'Security': 'cat-security', 'Access': 'cat-access', 'Access control': 'cat-access',
  'Operations': 'cat-operations', 'HR': 'cat-hr', 'Human resources': 'cat-hr',
  'Risk': 'cat-risk', 'Risk management': 'cat-risk'
};
function catClass(cat) { return catMap[cat] || 'cat-general'; }

function getStatus(policyId) {
  const rev = reviews[policyId];
  if (!rev || !rev.statements || rev.statements.length === 0) return 'not-started';
  const total = rev.statements.length;
  const decided = rev.statements.filter(s => s.status !== 'pending').length;
  if (decided === 0) return 'not-started';
  if (decided >= total) return 'completed';
  return 'in-progress';
}

function getProgress(policyId) {
  const rev = reviews[policyId];
  if (!rev || !rev.statements) return { decided: 0, total: 0 };
  return { decided: rev.statements.filter(s => s.status !== 'pending').length, total: rev.statements.length };
}

function statusLabel(s) {
  if (s === 'not-started') return 'Not started';
  if (s === 'in-progress') return 'In progress';
  return 'Completed';
}

function addAudit(action, policyId, policyTitle, details) {
  auditLog.unshift({ timestamp: new Date().toISOString(), action, policyId, policyTitle, details: details || '' });
  STORAGE.save('soc2:audit', auditLog);
}

// === INIT ===
async function init() {
  const savedManifest = await STORAGE.load('soc2:manifest');
  const savedAudit = await STORAGE.load('soc2:audit');
  if (savedAudit) auditLog = savedAudit;

  if (injectedPolicies.length > 0) {
    const existingIds = savedManifest ? savedManifest.map(p => p.id) : [];
    policies = injectedPolicies.map(p => ({
      id: p.id, title: p.title, description: p.description, category: p.category || 'General'
    }));
    for (const p of injectedPolicies) {
      if (p.content) await STORAGE.save('soc2:content:' + p.id, p.content);
      if (!existingIds.includes(p.id)) {
        addAudit('Policy added', p.id, p.title);
      }
    }
    // Merge: keep existing review data for policies that already exist
    await STORAGE.save('soc2:manifest', policies);
  } else if (savedManifest) {
    policies = savedManifest;
  }

  // Load all review states
  for (const p of policies) {
    const rev = await STORAGE.load('soc2:review:' + p.id);
    if (rev) reviews[p.id] = rev;
  }

  loaded = true;
  render();
}

// === RENDER ===
function render() {
  const dash = document.getElementById('dashboard');
  if (!loaded) {
    dash.innerHTML = '<div class="empty-state"><p>Loading dashboard...</p></div>';
    return;
  }
  if (policies.length === 0) {
    dash.innerHTML = '<div class="empty-state"><p>No policies loaded yet.<br>Upload your SOC 2 policy templates to get started.</p></div>';
    return;
  }

  const completed = policies.filter(p => getStatus(p.id) === 'completed').length;
  const inProgress = policies.filter(p => getStatus(p.id) === 'in-progress').length;
  const notStarted = policies.filter(p => getStatus(p.id) === 'not-started').length;
  const readiness = Math.round((completed / policies.length) * 100);

  const categories = [...new Set(policies.map(p => p.category))].sort();
  const filtered = activeFilter === 'all' ? policies :
    activeFilter === 'completed' ? policies.filter(p => getStatus(p.id) === 'completed') :
    activeFilter === 'in-progress' ? policies.filter(p => getStatus(p.id) === 'in-progress') :
    activeFilter === 'not-started' ? policies.filter(p => getStatus(p.id) === 'not-started') :
    policies.filter(p => p.category === activeFilter);

  let html = '<div class="dash-stats">' +
    '<div class="dash-stat"><div class="dash-stat-label">SOC 2 readiness</div><div class="dash-stat-value">' + readiness + '%</div></div>' +
    '<div class="dash-stat"><div class="dash-stat-label">Completed</div><div class="dash-stat-value">' + completed + '</div></div>' +
    '<div class="dash-stat"><div class="dash-stat-label">In progress</div><div class="dash-stat-value">' + inProgress + '</div></div>' +
    '<div class="dash-stat"><div class="dash-stat-label">Not started</div><div class="dash-stat-value">' + notStarted + '</div></div>' +
    '</div>';

  // Filter bar
  html += '<div class="filter-bar">';
  html += '<button class="' + (activeFilter === 'all' ? 'active' : '') + '" onclick="setFilter(\'all\')">All (' + policies.length + ')</button>';
  if (completed) html += '<button class="' + (activeFilter === 'completed' ? 'active' : '') + '" onclick="setFilter(\'completed\')">Completed (' + completed + ')</button>';
  if (inProgress) html += '<button class="' + (activeFilter === 'in-progress' ? 'active' : '') + '" onclick="setFilter(\'in-progress\')">In progress (' + inProgress + ')</button>';
  if (notStarted) html += '<button class="' + (activeFilter === 'not-started' ? 'active' : '') + '" onclick="setFilter(\'not-started\')">Not started (' + notStarted + ')</button>';
  categories.forEach(cat => {
    const count = policies.filter(p => p.category === cat).length;
    html += '<button class="' + (activeFilter === cat ? 'active' : '') + '" onclick="setFilter(\'' + esc(cat) + '\')">' + esc(cat) + ' (' + count + ')</button>';
  });
  html += '</div>';

  // Card grid
  html += '<div class="dash-grid">';
  filtered.forEach(p => {
    const status = getStatus(p.id);
    const prog = getProgress(p.id);
    const pct = prog.total > 0 ? Math.round((prog.decided / prog.total) * 100) : 0;

    html += '<div class="policy-card">' +
      '<div style="display:flex;justify-content:space-between;align-items:flex-start;">' +
      '<div class="policy-card-title">' + esc(p.title) + '</div>' +
      '</div>' +
      '<div style="display:flex;gap:6px;align-items:center;">' +
      '<span class="cat-badge ' + catClass(p.category) + '">' + esc(p.category) + '</span>' +
      '<span class="status-badge status-' + status + '">' + statusLabel(status) + '</span>' +
      '</div>' +
      '<div class="policy-card-desc">' + esc(p.description) + '</div>';

    if (prog.total > 0) {
      html += '<div class="progress-mini"><div class="progress-mini-fill ' +
        (status === 'completed' ? 'progress-fill-done' : 'progress-fill-progress') +
        '" style="width:' + pct + '%"></div></div>' +
        '<div style="font-size:11px;color:var(--color-text-secondary);">' + prog.decided + '/' + prog.total + ' statements reviewed</div>';
    }

    html += '<div class="card-actions">' +
      '<button class="btn-review" onclick="reviewPolicy(\'' + p.id + '\')">Review ↗</button>';
    if (status === 'completed') {
      html += '<button class="btn-export" onclick="exportPolicy(\'' + p.id + '\')">Export as Word ↗</button>';
    }
    if (status !== 'not-started') {
      html += '<button onclick="resetPolicy(\'' + p.id + '\')">Reset</button>';
    }
    html += '</div></div>';
  });
  html += '</div>';

  // Audit trail
  if (auditLog.length > 0) {
    html += '<div class="audit-panel">' +
      '<div class="audit-toggle" onclick="toggleAudit()"><span class="chevron ' + (auditOpen ? 'open' : '') + '">▶</span> Audit trail (' + auditLog.length + ' entries)</div>';
    if (auditOpen) {
      const displayLog = auditLog.slice(0, 50);
      displayLog.forEach(entry => {
        const dt = new Date(entry.timestamp);
        const timeStr = dt.toLocaleDateString() + ' ' + dt.toLocaleTimeString([], {hour:'2-digit',minute:'2-digit'});
        html += '<div class="audit-entry"><span class="audit-time">' + timeStr + '</span>' +
          '<span class="audit-action">' + esc(entry.action) + '</span>' +
          (entry.policyTitle ? ' — ' + esc(entry.policyTitle) : '') +
          (entry.details ? '<br><span style="margin-left:90px;font-size:12px;">' + esc(entry.details) + '</span>' : '') +
          '</div>';
      });
      if (auditLog.length > 50) html += '<div class="audit-entry" style="font-style:italic;">...and ' + (auditLog.length - 50) + ' more entries</div>';
    }
    html += '</div>';
  }

  dash.innerHTML = html;
}

function setFilter(f) { activeFilter = f; render(); }
function toggleAudit() { auditOpen = !auditOpen; render(); }

function reviewPolicy(id) {
  const p = policies.find(x => x.id === id);
  if (!p) return;
  addAudit('Review started', id, p.title);
  STORAGE.load('soc2:content:' + id).then(content => {
    if (content) {
      sendPrompt('Review the following policy document using the policy-review skill. When the review is complete, save the results back to the SOC 2 dashboard.\n\nPolicy ID: ' + id + '\nPolicy title: ' + p.title + '\n\n' + content);
    } else {
      sendPrompt('I want to review the policy "' + p.title + '" (ID: ' + id + ') but the content was not found in storage. Can you help me re-upload it?');
    }
  });
}

function exportPolicy(id) {
  const p = policies.find(x => x.id === id);
  if (!p) return;
  addAudit('Export requested', id, p.title, 'Word document');
  sendPrompt('Export the completed policy "' + p.title + '" (ID: ' + id + ') as a Word document. Use the saved review decisions from the SOC 2 dashboard to build the final version with approved/rewritten statements and a rejected statements appendix.');
}

async function resetPolicy(id) {
  const p = policies.find(x => x.id === id);
  if (!p) return;
  delete reviews[id];
  await STORAGE.delete('soc2:review:' + id);
  addAudit('Review reset', id, p.title);
  render();
}

// Exposed for Claude to call after a policy review completes
window.savePolicyReview = async function(policyId, reviewData) {
  reviews[policyId] = reviewData;
  await STORAGE.save('soc2:review:' + policyId, reviewData);
  const p = policies.find(x => x.id === policyId);
  if (p) addAudit('Review saved', policyId, p.title, reviewData.statements.filter(s => s.status !== 'pending').length + ' statements reviewed');
  render();
};

init();
</script>
```
