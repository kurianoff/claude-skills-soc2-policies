# Review carousel widget template

## How Claude uses this template

1. Read this file
2. Parse the policy HTML into sections and statements
3. Set the injection variables at the top of the script block:
   - `var POLICY_ID` — the policy storage key (e.g. "incident-response")
   - `var POLICY_TITLE` — display title
   - `var COMPANY` — company name
   - `var SECTIONS` — the parsed sections/statements array (see format below)
   - `var AI_SUGGESTION` — null on first render, or {id: N, html: "..."} for AI rewrite
   - `var INITIAL_IDX` — starting carousel index (0 on first render)
   - `var INITIAL_VIEW` — "statements" or "sections"
4. Copy the ENTIRE widget code below into `visualize:show_widget` VERBATIM
5. Do NOT modify any CSS, HTML structure, event handlers, or storage logic
6. Do NOT add, remove, or rename any functions
7. Do NOT change class names, button labels, or layout

### SECTIONS format

```javascript
var SECTIONS = [
  { id: "overview", title: "Overview and definitions", items: [
    { id: 1, label: "Purpose", text: "<p>This document establishes...</p>" },
    { id: 2, label: "Scope", text: "<p>This policy covers...</p>" }
  ]},
  { id: "roles", title: "Roles and responsibilities", items: [
    { id: 3, label: "Response team", text: "<table>...</table>" }
  ]}
];
```

Each item's `text` field is HTML. The widget renders it via innerHTML — no parsing.

### AI_SUGGESTION format

When re-rendering after an AI rewrite:
```javascript
var AI_SUGGESTION = { id: 6, html: "<table>...(rewritten)...</table>" };
```

On first render or non-rewrite renders:
```javascript
var AI_SUGGESTION = null;
```

### show_widget parameters

```
title: "policy_review_{POLICY_ID}"
loading_messages: ["Parsing policy sections", "Building review carousel"]
```

## State persistence model

This widget persists review progress to `soc2:review-session:{POLICY_ID}`
after EVERY action (approve, reject, rewrite, undo). This ensures:

- AI rewrite roundtrips don't lose prior approvals/rejections
- Closing the browser mid-review preserves progress
- Audit log entries survive widget re-renders

On `init()`, the widget checks for saved session state BEFORE falling back to
the default all-pending state. On final export, the session key is cleared
and the final state is written to `soc2:review:{POLICY_ID}`.

### Storage keys used

- `soc2:review-session:{id}` — live working state (written after every action)
- `soc2:review:{id}` — final export state (written only on "Save and return")
- `soc2:working:{id}` — final HTML document (written only on export)
- `soc2:versions:{id}` — version history (written only on export)
- `soc2:audit:{id}` — cumulative audit trail (appended on export)

## Complete widget code

```html
<div id="app" style="padding:1rem 0;font-family:var(--font-sans)"></div>
<style>
.top{display:flex;justify-content:space-between;align-items:center;margin-bottom:1rem;flex-wrap:wrap;gap:8px}
.back{font-size:13px;padding:6px 16px;border-radius:var(--border-radius-md);cursor:pointer;font-weight:500;border:.5px solid var(--color-border-secondary);background:transparent;color:var(--color-text-secondary)}
.back:hover{background:var(--color-background-secondary)}
.vt{display:flex;border:.5px solid var(--color-border-secondary);border-radius:var(--border-radius-md);overflow:hidden}
.vt button{font-size:12px;padding:6px 14px;cursor:pointer;font-weight:500;border:none;background:transparent;color:var(--color-text-secondary);border-right:.5px solid var(--color-border-secondary)}
.vt button:last-child{border-right:none}
.vt button.active{background:var(--color-background-secondary);color:var(--color-text-primary)}
.pb{display:flex;gap:8px;align-items:center;margin-bottom:1rem;flex-wrap:wrap}
.ps{font-size:13px;color:var(--color-text-secondary);padding:4px 12px;background:var(--color-background-secondary);border-radius:var(--border-radius-md)}
.ps b{color:var(--color-text-primary);font-weight:500}
.nb{display:flex;align-items:center;justify-content:space-between;margin-bottom:1rem}
.nv{font-size:13px;padding:8px 16px;border-radius:var(--border-radius-md);cursor:pointer;font-weight:500;border:.5px solid var(--color-border-secondary);background:transparent;color:var(--color-text-primary);min-width:90px}
.nv:hover{background:var(--color-background-secondary)}
.nv:disabled{opacity:.3;cursor:default}
.nv:disabled:hover{background:transparent}
.ni{font-size:13px;color:var(--color-text-secondary);text-align:center}
.ni b{color:var(--color-text-primary);font-weight:500}
.card{background:var(--color-background-primary);border:.5px solid var(--color-border-tertiary);border-radius:var(--border-radius-lg);padding:1.5rem}
.card-sec{font-size:12px;font-weight:500;color:var(--color-text-secondary);margin-bottom:4px;text-transform:uppercase;letter-spacing:.5px}
.card-lbl{font-size:18px;font-weight:500;color:var(--color-text-primary);margin-bottom:8px}
.badge{display:inline-block;font-size:11px;font-weight:500;padding:2px 10px;border-radius:var(--border-radius-md);margin-bottom:12px}
.b-ok{background:#E1F5EE;color:#085041}
.b-rw{background:#E6F1FB;color:#0C447C}
.b-rj{background:#FCEBEB;color:#791F1F}
.b-pn{background:var(--color-background-secondary);color:var(--color-text-secondary)}
.b-ai{background:#EEEDFE;color:#3C3489}
.ct{font-size:15px;line-height:1.7;color:var(--color-text-primary);margin-bottom:1.25rem}
.ct p{margin:0 0 .75rem}
.ct p:last-child{margin-bottom:0}
.ct ul,.ct ol{margin:.5rem 0;padding-left:1.5rem}
.ct li{margin-bottom:.35rem;line-height:1.6}
.ct table{width:100%;border-collapse:collapse;font-size:14px;margin:.75rem 0}
.ct th{text-align:left;font-weight:500;color:var(--color-text-secondary);padding:8px 12px;border-bottom:.5px solid var(--color-border-secondary);font-size:13px;background:var(--color-background-secondary)}
.ct th:first-child{border-radius:var(--border-radius-md) 0 0 0}
.ct th:last-child{border-radius:0 var(--border-radius-md) 0 0}
.ct td{padding:10px 12px;border-bottom:.5px solid var(--color-border-tertiary);color:var(--color-text-primary);vertical-align:top;line-height:1.5}
.ct td:first-child{font-weight:500}
.ct tr:last-child td{border-bottom:none}
.orig{font-size:13px;color:var(--color-text-secondary);margin-bottom:10px;padding:10px 12px;background:var(--color-background-secondary);border-radius:var(--border-radius-md);line-height:1.5}
.rejr{font-size:13px;padding:10px 12px;background:#FCEBEB;border-radius:var(--border-radius-md);color:#791F1F;margin-bottom:10px;line-height:1.5}
.acts{display:flex;gap:8px;flex-wrap:wrap}
.acts button{font-size:13px;padding:8px 18px;border-radius:var(--border-radius-md);cursor:pointer;font-weight:500;border:.5px solid var(--color-border-secondary);background:transparent;color:var(--color-text-primary);transition:background .15s,transform .1s}
.acts button:hover{background:var(--color-background-secondary)}
.acts button:active{transform:scale(.98)}
.ba{border-color:#5DCAA5!important;color:#0F6E56!important}
.ba:hover{background:#E1F5EE!important}
.bw{border-color:#AFA9EC!important;color:#534AB7!important}
.bw:hover{background:#EEEDFE!important}
.bm{border-color:#85B7EB!important;color:#185FA5!important}
.bm:hover{background:#E6F1FB!important}
.bj{border-color:#F09595!important;color:#A32D2D!important}
.bj:hover{background:#FCEBEB!important}
.ta{width:100%;box-sizing:border-box;min-height:80px;font-size:14px;font-family:var(--font-sans);padding:10px;border:.5px solid var(--color-border-secondary);border-radius:var(--border-radius-md);background:var(--color-background-primary);color:var(--color-text-primary);margin-bottom:8px;resize:vertical;line-height:1.5}
.ta:focus{outline:none;box-shadow:0 0 0 2px var(--color-border-info)}
.ais{border:.5px solid #AFA9EC;border-radius:var(--border-radius-md);padding:12px;margin-bottom:10px;background:#EEEDFE}
.ais-l{font-size:11px;font-weight:500;color:#534AB7;text-transform:uppercase;letter-spacing:.5px;margin-bottom:6px}
.ais-t{font-size:14px;line-height:1.6;color:#26215C}
.ais-t table{width:100%;border-collapse:collapse;font-size:13px;margin:.5rem 0}
.ais-t th{text-align:left;font-weight:500;padding:6px 10px;border-bottom:.5px solid #AFA9EC;font-size:12px}
.ais-t td{padding:6px 10px;border-bottom:.5px solid #CECBF6;vertical-align:top}
.ais-t td:first-child{font-weight:500}
.ais-t tr:last-child td{border-bottom:none}
.dots{display:flex;gap:6px;justify-content:center;margin-top:1rem;flex-wrap:wrap}
.dot{width:8px;height:8px;border-radius:50%;cursor:pointer}
.d-pn{background:var(--color-border-tertiary)}
.d-ok{background:#5DCAA5}
.d-rw{background:#85B7EB}
.d-rj{background:#F09595}
.d-cur{box-shadow:0 0 0 2px var(--color-text-primary)}
.vh{background:var(--color-background-primary);border:.5px solid var(--color-border-tertiary);border-radius:var(--border-radius-lg);padding:1.25rem;margin-bottom:1rem}
.vh-t{font-size:14px;font-weight:500;color:var(--color-text-primary);margin-bottom:12px}
.vh-sep{font-size:12px;font-weight:500;color:var(--color-text-secondary);margin:12px 0 8px;text-transform:uppercase;letter-spacing:.5px}
.vh-g{display:grid;grid-template-columns:repeat(auto-fill,minmax(150px,1fr));gap:12px}
.vh-f label{font-size:12px;color:var(--color-text-secondary);display:block;margin-bottom:4px}
.vh-f input{width:100%;box-sizing:border-box;font-size:14px;font-family:var(--font-sans);padding:8px 10px;border:.5px solid var(--color-border-secondary);border-radius:var(--border-radius-md);background:var(--color-background-primary);color:var(--color-text-primary)}
.vh-d{width:100%;box-sizing:border-box;font-size:14px;font-family:var(--font-sans);padding:8px 10px;border:.5px solid var(--color-border-secondary);border-radius:var(--border-radius-md);background:var(--color-background-primary);color:var(--color-text-primary);margin-top:12px}
</style>
<script>
/* ======= INJECTION POINT 1: Policy metadata ======= */
var POLICY_ID = "REPLACE_POLICY_ID";
var POLICY_TITLE = "REPLACE_POLICY_TITLE";
var COMPANY = "REPLACE_COMPANY_NAME";
/* ======= INJECTION POINT 2: Parsed sections and statements (HTML text) ======= */
var SECTIONS = [];
/* ======= INJECTION POINT 3: AI suggestion (null or {id:N, html:"..."}) ======= */
var AI_SUGGESTION = null;
/* ======= INJECTION POINT 4: Carousel position ======= */
var INITIAL_IDX = 0;
var INITIAL_VIEW = "statements";
/* ======= END INJECTION — DO NOT MODIFY ANYTHING BELOW ======= */

var SESSION_KEY = "soc2:review-session:" + POLICY_ID;
var today=new Date(),dateStr=today.getFullYear()+"-"+String(today.getMonth()+1).padStart(2,"0")+"-"+String(today.getDate()).padStart(2,"0");
var priorVersions=[],currentVersion={version:"1.0",date:dateStr,description:"Reviewed and updated via SOC 2 dashboard",author:"",approvedBy:""};
var allItems=SECTIONS.reduce(function(a,s){return a.concat(s.items)},[]);
var state={};
var currentIdx=INITIAL_IDX,viewMode=INITIAL_VIEW,activeMode=null,activeId=null,showVersions=false;
var auditLog=[];
var loaded=false;

function esc(t){var d=document.createElement("div");d.textContent=t;return d.innerHTML}
function stripTags(h){var d=document.createElement("div");d.innerHTML=h;return d.textContent||d.innerText||""}
function getCounts(){var c={approved:0,rewritten:0,rejected:0,pending:0};allItems.forEach(function(s){c[state[s.id].status==="rewritten"?"rewritten":state[s.id].status]++});return c}
function getSecForItem(item){for(var i=0;i<SECTIONS.length;i++){if(SECTIONS[i].items.find(function(x){return x.id===item.id}))return SECTIONS[i]}return SECTIONS[0]}
function logAction(action,label,details){auditLog.push({ts:new Date().toISOString(),action:action,label:label,details:details||""})}

function saveSession(){
  var data={};
  allItems.forEach(function(s){
    if(state[s.id].status!=="pending"||state[s.id].aiSuggestion!==null){
      data[s.id]={status:state[s.id].status,text:state[s.id].text,justification:state[s.id].justification||"",aiSuggestion:state[s.id].aiSuggestion}
    }
  });
  var payload={decisions:data,auditLog:auditLog,viewMode:viewMode,currentIdx:currentIdx,versionMeta:currentVersion};
  try{window.storage.set(SESSION_KEY,JSON.stringify(payload))}catch(e){}
}

function loadSession(saved){
  if(!saved||!saved.decisions)return;
  Object.keys(saved.decisions).forEach(function(id){
    var nid=parseInt(id);
    if(!state[nid])return;
    var d=saved.decisions[id];
    state[nid].status=d.status||"pending";
    if(d.text)state[nid].text=d.text;
    state[nid].justification=d.justification||"";
    if(d.aiSuggestion)state[nid].aiSuggestion=d.aiSuggestion;
  });
  if(saved.auditLog&&saved.auditLog.length)auditLog=saved.auditLog;
  if(saved.versionMeta){
    if(saved.versionMeta.author)currentVersion.author=saved.versionMeta.author;
    if(saved.versionMeta.approvedBy)currentVersion.approvedBy=saved.versionMeta.approvedBy;
    if(saved.versionMeta.description)currentVersion.description=saved.versionMeta.description;
    if(saved.versionMeta.version)currentVersion.version=saved.versionMeta.version;
    if(saved.versionMeta.date)currentVersion.date=saved.versionMeta.date;
  }
}

function render(){
  if(!loaded){document.getElementById("app").innerHTML='<div style="text-align:center;padding:3rem;color:var(--color-text-secondary)">Loading review state...</div>';return}
  var app=document.getElementById("app"),c=getCounts(),navItems=viewMode==="statements"?allItems:SECTIONS,total=navItems.length;
  var h='<div class="top"><button class="back" onclick="goBack()">\u2190 Dashboard</button><div class="vt"><button class="'+(viewMode==="statements"?"active":"")+'" onclick="setView(\'statements\')">By statement</button><button class="'+(viewMode==="sections"?"active":"")+'" onclick="setView(\'sections\')">By section</button></div></div>';
  h+='<div class="pb"><div class="ps"><b>'+c.approved+'</b> approved</div><div class="ps"><b>'+c.rewritten+'</b> rewritten</div><div class="ps"><b>'+c.rejected+'</b> rejected</div><div class="ps"><b>'+c.pending+'</b> pending</div></div>';
  h+='<div class="nb"><button class="nv" onclick="navPrev()" '+(currentIdx===0?"disabled":"")+">"+'\u2190 Previous</button><div class="ni"><b>'+(currentIdx+1)+"</b> of <b>"+total+"</b>";
  if(viewMode==="statements")h+='<br><span style="font-size:12px">'+esc(getSecForItem(allItems[currentIdx]).title)+"</span>";
  h+='</div><button class="nv" onclick="navNext()" '+(currentIdx>=total-1?"disabled":"")+">Next \u2192</button></div>";
  if(viewMode==="statements"){h+=renderCard(allItems[currentIdx])}
  else{var sec=SECTIONS[currentIdx];sec.items.forEach(function(item,i){h+=renderCard(item);if(i<sec.items.length-1)h+='<div style="height:8px"></div>'});var sp=sec.items.filter(function(i){return state[i.id].status==="pending"}).length;if(sp>0)h+='<div style="margin-top:12px"><button class="ba" onclick="bulkApprove(\''+sec.id+'\')">Approve all '+sp+" pending in this section</button></div>"}
  h+='<div class="dots">';
  (viewMode==="statements"?allItems:SECTIONS).forEach(function(item,i){
    var st=viewMode==="statements"?state[item.id].status:(function(){var s=item.items,d=s.filter(function(x){return state[x.id].status!=="pending"}).length;if(!d)return"pending";return d>=s.length?"approved":"rewritten"})();
    h+='<div class="dot d-'+(st==="approved"?"ok":st==="rewritten"?"rw":st==="rejected"?"rj":"pn")+(i===currentIdx?" d-cur":"")+'" onclick="goTo('+i+')"></div>'});
  h+="</div>";
  var allDone=c.pending===0;
  if(allDone||showVersions){
    h+='<div class="vh" style="margin-top:1.5rem"><div class="vh-t">Version history</div><div class="vh-sep">Current revision</div><div class="vh-g">';
    h+='<div class="vh-f"><label>Version</label><input type="text" id="vh-ver" value="'+esc(currentVersion.version)+'" onchange="updateVH(\'version\',this.value)"></div>';
    h+='<div class="vh-f"><label>Date</label><input type="date" id="vh-date" value="'+esc(currentVersion.date)+'" onchange="updateVH(\'date\',this.value)"></div>';
    h+='<div class="vh-f"><label>Author</label><input type="text" id="vh-author" value="'+esc(currentVersion.author)+'" placeholder="Your name" onchange="updateVH(\'author\',this.value)"></div>';
    h+='<div class="vh-f"><label>Approved by</label><input type="text" id="vh-approved" value="'+esc(currentVersion.approvedBy)+'" placeholder="Approver name" onchange="updateVH(\'approvedBy\',this.value)"></div>';
    h+='</div><input type="text" class="vh-d" id="vh-desc" value="'+esc(currentVersion.description)+'" placeholder="Description of changes" onchange="updateVH(\'description\',this.value)"></div>';
  }
  if(allDone)h+='<div style="text-align:center;margin-top:1rem"><button onclick="exportReview()" style="font-size:14px;padding:10px 24px;border-radius:var(--border-radius-md);cursor:pointer;font-weight:500;border:.5px solid var(--color-border-secondary);background:transparent;color:var(--color-text-primary)">Save and return to dashboard \u2197</button></div>';
  else if(!showVersions)h+='<div style="text-align:center;margin-top:1rem"><button onclick="showVersions=true;render()" style="font-size:12px;padding:4px 12px;border-radius:var(--border-radius-md);cursor:pointer;border:.5px solid var(--color-border-secondary);background:transparent;color:var(--color-text-secondary)">Edit version history</button></div>';
  app.innerHTML=h;
}

function renderCard(item){
  var st=state[item.id],sec=getSecForItem(item),isAi=st.aiSuggestion!==null;
  var bc=st.status==="approved"?"b-ok":st.status==="rewritten"?"b-rw":st.status==="rejected"?"b-rj":"b-pn";
  var bl=st.status==="approved"?"approved":st.status==="rewritten"?"rewritten":st.status==="rejected"?"rejected":"pending";
  var h='<div class="card"><div class="card-sec">'+esc(sec.title)+'</div><div class="card-lbl">'+esc(item.label)+"</div>";
  h+='<span class="badge '+(isAi&&st.status==="pending"?"b-ai":bc)+'">'+(isAi&&st.status==="pending"?"AI suggestion ready":bl)+"</span>";
  h+='<div class="ct">'+st.text+"</div>";
  if(st.status==="rejected"&&st.justification)h+='<div class="rejr"><b>Rejection reason:</b> '+esc(st.justification)+"</div>";
  if(st.status==="rewritten")h+='<div class="orig"><b>Original:</b> '+stripTags(st.originalText)+"</div>";
  if(activeMode==="ai-prompt"&&activeId===item.id){h+='<textarea class="ta" id="ai-'+item.id+'" placeholder="Tell me what to change, add, or remove..."></textarea><div class="acts"><button class="bw" onclick="submitAi('+item.id+')">Rewrite with AI \u2197</button><button onclick="cancelA()">Cancel</button></div>'}
  else if(activeMode==="manual"&&activeId===item.id){h+='<textarea class="ta" id="man-'+item.id+'">'+stripTags(st.text)+'</textarea><div class="acts"><button class="bm" onclick="submitMan('+item.id+')">Save rewrite</button><button onclick="cancelA()">Cancel</button></div>'}
  else if(activeMode==="reject"&&activeId===item.id){h+='<textarea class="ta" id="rej-'+item.id+'" placeholder="Why are you rejecting this statement?"></textarea><div class="acts"><button class="bj" onclick="submitRej('+item.id+')">Confirm rejection</button><button onclick="cancelA()">Cancel</button></div>'}
  else if(st.aiSuggestion!==null){h+='<div class="ais"><div class="ais-l">AI suggested rewrite</div><div class="ais-t">'+st.aiSuggestion+'</div></div><div class="acts"><button class="ba" onclick="acceptAi('+item.id+')">Accept</button><button class="bw" onclick="startAi('+item.id+')">Refine further</button><button class="bm" onclick="startManAi('+item.id+')">Edit manually</button><button onclick="discardAi('+item.id+')">Discard</button></div>'}
  else if(st.status!=="pending"){h+='<div class="acts"><button onclick="resetS('+item.id+')">Undo</button></div>'}
  else{h+='<div class="acts"><button class="ba" onclick="approve('+item.id+')">Approve</button><button class="bw" onclick="startAi('+item.id+')">Rewrite with AI</button><button class="bm" onclick="startMan('+item.id+')">Edit manually</button><button class="bj" onclick="startRej('+item.id+')">Reject</button></div>'}
  h+="</div>";return h;
}

function updateVH(f,v){currentVersion[f]=v;saveSession()}
function setView(v){viewMode=v;currentIdx=0;activeMode=null;activeId=null;saveSession();render()}
function navPrev(){if(currentIdx>0){currentIdx--;activeMode=null;activeId=null;render()}}
function navNext(){var max=(viewMode==="statements"?allItems:SECTIONS).length-1;if(currentIdx<max){currentIdx++;activeMode=null;activeId=null;render()}}
function goTo(i){currentIdx=i;activeMode=null;activeId=null;render()}
function autoAdv(){if(viewMode==="statements"){var max=allItems.length-1;if(currentIdx<max)currentIdx++}}

function approve(id){state[id].status="approved";state[id].aiSuggestion=null;activeMode=null;activeId=null;var it=allItems.find(function(x){return x.id===id});logAction("approved",it?it.label:"","");autoAdv();saveSession();render()}
function bulkApprove(sid){var sec=SECTIONS.find(function(s){return s.id===sid});if(sec)sec.items.forEach(function(i){if(state[i.id].status==="pending"){state[i.id].status="approved";logAction("approved",i.label,"bulk approve")}});saveSession();render()}
function startAi(id){activeMode="ai-prompt";activeId=id;render();setTimeout(function(){var e=document.getElementById("ai-"+id);if(e)e.focus()},50)}
function submitAi(id){var ta=document.getElementById("ai-"+id);var p=ta?ta.value.trim():"";if(!p)return;activeMode=null;activeId=null;saveSession();var cur=state[id].aiSuggestion!==null?state[id].aiSuggestion:state[id].text;var item=allItems.find(function(x){return x.id===id});sendPrompt("POLICY_REWRITE_REQUEST\nPolicy: "+POLICY_TITLE+"\nPolicy ID: "+POLICY_ID+"\nCompany name: "+COMPANY+"\nStatement ID: "+id+"\nStatement: "+item.label+"\nCurrent index: "+currentIdx+"\nView mode: "+viewMode+"\nCurrent text (HTML): "+cur+"\nInstructions: "+p+"\n\nPlease rewrite this statement and render an updated policy review carousel with the AI suggestion shown inline.")}
function startMan(id){activeMode="manual";activeId=id;render();setTimeout(function(){var e=document.getElementById("man-"+id);if(e){e.focus();e.setSelectionRange(e.value.length,e.value.length)}},50)}
function startManAi(id){state[id].text=state[id].aiSuggestion||state[id].text;state[id].aiSuggestion=null;activeMode="manual";activeId=id;render();setTimeout(function(){var e=document.getElementById("man-"+id);if(e){e.focus();e.setSelectionRange(e.value.length,e.value.length)}},50)}
function submitMan(id){var ta=document.getElementById("man-"+id);if(ta&&ta.value.trim()){var nt="<p>"+ta.value.trim().replace(/\n\n/g,"</p><p>").replace(/\n/g,"<br>")+"</p>";state[id].text=nt;state[id].status="rewritten";state[id].aiSuggestion=null;var it=allItems.find(function(x){return x.id===id});logAction("rewritten (manual)",it?it.label:"")}activeMode=null;activeId=null;saveSession();render()}
function startRej(id){activeMode="reject";activeId=id;render();setTimeout(function(){var e=document.getElementById("rej-"+id);if(e)e.focus()},50)}
function submitRej(id){var ta=document.getElementById("rej-"+id);state[id].justification=ta?ta.value.trim():"";state[id].status="rejected";state[id].aiSuggestion=null;activeMode=null;activeId=null;var it=allItems.find(function(x){return x.id===id});logAction("rejected",it?it.label:"",state[id].justification);autoAdv();saveSession();render()}
function acceptAi(id){state[id].text=state[id].aiSuggestion;state[id].status="rewritten";state[id].aiSuggestion=null;activeMode=null;activeId=null;var it=allItems.find(function(x){return x.id===id});logAction("rewritten (AI)",it?it.label:"");autoAdv();saveSession();render()}
function discardAi(id){state[id].aiSuggestion=null;saveSession();render()}
function cancelA(){activeMode=null;activeId=null;render()}
function resetS(id){state[id]={status:"pending",text:state[id].originalText,originalText:state[id].originalText,justification:"",aiSuggestion:null};activeMode=null;activeId=null;var it=allItems.find(function(x){return x.id===id});logAction("reset to pending",it?it.label:"");saveSession();render()}
function goBack(){sendPrompt("Open the SOC 2 dashboard and show my current progress.")}

async function exportReview(){
  var ve=document.getElementById("vh-ver"),de=document.getElementById("vh-date"),ae=document.getElementById("vh-author"),ab=document.getElementById("vh-approved"),ds=document.getElementById("vh-desc");
  if(ve)currentVersion.version=ve.value;if(de)currentVersion.date=de.value;if(ae)currentVersion.author=ae.value;if(ab)currentVersion.approvedBy=ab.value;if(ds)currentVersion.description=ds.value;
  var allVersions=priorVersions.concat([currentVersion]);
  var fullHtml="<h1>"+POLICY_TITLE+"</h1>";
  SECTIONS.forEach(function(sec){fullHtml+="<h2>"+sec.title+"</h2>";sec.items.forEach(function(item){if(state[item.id].status!=="rejected")fullHtml+="<h3>"+item.label+"</h3>"+state[item.id].text})});
  var stmts=allItems.map(function(s){return{id:s.id,label:s.label,status:state[s.id].status,text:state[s.id].text,originalText:state[s.id].originalText,justification:state[s.id].justification||""}});
  await window.storage.set("soc2:working:"+POLICY_ID,JSON.stringify(fullHtml));
  await window.storage.set("soc2:review:"+POLICY_ID,JSON.stringify({status:"completed",statements:stmts,versionMeta:currentVersion}));
  await window.storage.set("soc2:versions:"+POLICY_ID,JSON.stringify({versions:allVersions}));
  try{var existing=await window.storage.get("soc2:audit:"+POLICY_ID);var prev=existing?JSON.parse(existing.value):[];auditLog=prev.concat(auditLog)}catch(e){}
  await window.storage.set("soc2:audit:"+POLICY_ID,JSON.stringify(auditLog));
  try{await window.storage.delete(SESSION_KEY)}catch(e){}
  var approved=stmts.filter(function(s){return s.status==="approved"});
  var rewritten=stmts.filter(function(s){return s.status==="rewritten"});
  var rejected=stmts.filter(function(s){return s.status==="rejected"});
  var reviewed=stmts.filter(function(s){return s.status!=="pending"}).length;
  var msg="POLICY_REVIEW_COMPLETE\nPolicy: "+POLICY_TITLE+"\nPolicy ID: "+POLICY_ID+"\nVersion: "+currentVersion.version+"\nDate: "+currentVersion.date+"\nAuthor: "+currentVersion.author+"\nApproved by: "+currentVersion.approvedBy+"\nDescription: "+currentVersion.description+"\n\nREVIEW STATUS: completed\nSTATEMENTS TOTAL: "+stmts.length+"\nSTATEMENTS REVIEWED: "+reviewed+"\n\nCHANGE SUMMARY:\n- "+approved.length+" statements approved as-is\n- "+rewritten.length+" statements rewritten";
  if(rewritten.length)msg+=": "+rewritten.map(function(s){return'"'+s.label+'"'}).join(", ");
  msg+="\n- "+rejected.length+" statements rejected";
  if(rejected.length)msg+=": "+rejected.map(function(s){return'"'+s.label+'"'}).join(", ");
  msg+="\n\nAll data saved to persistent storage (HTML working copy, review decisions, version history, audit trail).\nPlease render the SOC 2 dashboard and inject this policy status directly into the widget: { id: \""+POLICY_ID+'", status: "completed", reviewed: '+reviewed+", total: "+stmts.length+" }";
  sendPrompt(msg);
}

async function init(){
  allItems.forEach(function(s){state[s.id]={status:"pending",text:s.text,originalText:s.text,justification:"",aiSuggestion:null}});
  try{
    var saved=await window.storage.get(SESSION_KEY);
    if(saved)loadSession(JSON.parse(saved.value));
  }catch(e){}
  if(AI_SUGGESTION&&AI_SUGGESTION.id&&state[AI_SUGGESTION.id]){state[AI_SUGGESTION.id].aiSuggestion=AI_SUGGESTION.html}
  try{var sv=await window.storage.get("soc2:versions:"+POLICY_ID);if(sv){var data=JSON.parse(sv.value);if(data.versions&&data.versions.length>0){priorVersions=data.versions;var last=priorVersions[priorVersions.length-1];var parts=last.version.split(".");currentVersion.version=parts[0]+"."+(parseInt(parts[1]||"0")+1)}}}catch(e){}
  loaded=true;
  render();
}
init();
</script>
```
