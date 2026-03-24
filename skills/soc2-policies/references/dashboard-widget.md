# Dashboard widget template

## How Claude uses this template

1. Read this file
2. Set the TWO injection variables at the top of the script block:
   - `var COMPANY` — the company name string
   - `var INJECTED` — known policy statuses from POLICY_REVIEW_COMPLETE messages
3. Copy the ENTIRE widget code below into `visualize:show_widget` VERBATIM
4. Do NOT modify any CSS, HTML structure, event handlers, or storage logic
5. Do NOT add, remove, or rename any functions
6. Do NOT change class names, button labels, or layout

### Injection examples

First launch (no known state):
```javascript
var COMPANY = "Acme Corp";
var INJECTED = {};
```

After a review completes:
```javascript
var COMPANY = "Acme Corp";
var INJECTED = {
  "incident-response": { status: "completed", reviewed: 23, total: 23 },
  "business-continuity": { status: "completed", reviewed: 11, total: 11 }
};
```

### show_widget parameters

```
title: "soc2_policy_dashboard"
loading_messages: ["Loading policy dashboard", "Checking saved progress"]
```

## Complete widget code

```html
<div id="root" style="padding:1rem 0;font-family:var(--font-sans)"></div>
<style>
.hdr{font-size:18px;font-weight:500;color:var(--color-text-primary);margin-bottom:.25rem}
.sub{font-size:13px;color:var(--color-text-secondary);margin-bottom:1.5rem}
.stats{display:flex;gap:12px;margin-bottom:1.5rem;flex-wrap:wrap}
.stat{background:var(--color-background-secondary);border-radius:var(--border-radius-md);padding:.75rem 1rem;min-width:100px}
.stat-l{font-size:12px;color:var(--color-text-secondary);margin-bottom:2px}
.stat-v{font-size:20px;font-weight:500;color:var(--color-text-primary)}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(280px,1fr));gap:12px;margin-bottom:1.5rem}
.pc{background:var(--color-background-primary);border:.5px solid var(--color-border-tertiary);border-radius:var(--border-radius-lg);padding:1.25rem;display:flex;flex-direction:column;gap:8px}
.pc:hover{border-color:var(--color-border-secondary)}
.pc-t{font-size:15px;font-weight:500;color:var(--color-text-primary);line-height:1.3}
.pc-d{font-size:13px;color:var(--color-text-secondary);line-height:1.5;display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden}
.pc-f{display:flex;gap:6px;align-items:center;flex-wrap:wrap}
.cb{font-size:11px;font-weight:500;padding:2px 10px;border-radius:var(--border-radius-md)}
.c-Security{background:#E6F1FB;color:#0C447C}
.c-Access{background:#EEEDFE;color:#3C3489}
.c-Operations{background:#E1F5EE;color:#085041}
.c-HR{background:#FAEEDA;color:#633806}
.c-Risk{background:#FCEBEB;color:#791F1F}
.c-Governance{background:#FBEAF0;color:#72243E}
.c-Data{background:#FAECE7;color:#712B13}
.sb{font-size:11px;font-weight:500;padding:2px 10px;border-radius:var(--border-radius-md)}
.s-ns{background:var(--color-background-secondary);color:var(--color-text-secondary)}
.s-ip{background:#EEEDFE;color:#3C3489}
.s-dn{background:#E1F5EE;color:#085041}
.bar{width:100%;height:4px;background:var(--color-background-secondary);border-radius:2px;margin-top:4px;overflow:hidden}
.bar-f{height:100%;border-radius:2px}
.bar-ip{background:#7F77DD}
.bar-dn{background:#5DCAA5}
.acts{display:flex;gap:8px;margin-top:auto;padding-top:8px;flex-wrap:wrap}
.acts button{font-size:12px;padding:5px 12px;border-radius:var(--border-radius-md);cursor:pointer;font-weight:500;border:.5px solid var(--color-border-secondary);background:transparent;color:var(--color-text-primary);transition:background .15s,transform .1s}
.acts button:hover{background:var(--color-background-secondary)}
.acts button:active{transform:scale(.98)}
.b-rv{border-color:#AFA9EC!important;color:#534AB7!important}
.b-rv:hover{background:#EEEDFE!important}
.b-ex{border-color:#5DCAA5!important;color:#0F6E56!important}
.b-ex:hover{background:#E1F5EE!important}
.fbar{display:flex;gap:8px;margin-bottom:1rem;flex-wrap:wrap}
.fbar button{font-size:12px;padding:4px 12px;border-radius:var(--border-radius-md);cursor:pointer;border:.5px solid var(--color-border-secondary);background:transparent;color:var(--color-text-secondary)}
.fbar button.active{background:var(--color-background-secondary);color:var(--color-text-primary)}
.fbar button:hover{background:var(--color-background-secondary)}
</style>
<script>
/* ======= INJECTION POINT 1: Company name ======= */
var COMPANY = "REPLACE_COMPANY_NAME";
/* ======= INJECTION POINT 2: Known state from POLICY_REVIEW_COMPLETE ======= */
var INJECTED = {};
/* ======= END INJECTION — DO NOT MODIFY ANYTHING BELOW ======= */

var P=[
{id:"acceptable-use",t:"Acceptable use policy",d:"Communicates acceptable use and protection of information and assets. Covers unacceptable use, email activities, and related policies.",c:"Governance"},
{id:"access-control",t:"Access control policy",d:"Restricts access to information, systems, networks, and facilities to authorized individuals based on least privilege.",c:"Access"},
{id:"asset-management",t:"Asset management policy",d:"Identifies organizational assets, assigns protection responsibilities, and prevents unauthorized disclosure or destruction.",c:"Operations"},
{id:"business-continuity",t:"Business continuity and disaster recovery plan",d:"Prepares for service outages due to uncontrollable factors and restores services as broadly and quickly as possible.",c:"Operations"},
{id:"code-of-conduct",t:"Code of conduct",d:"Creates an inclusive, collaborative, and safe working environment with expectations for behavior and consequences.",c:"HR"},
{id:"cryptography",t:"Cryptography policy",d:"Ensures proper use of cryptography to protect confidentiality, authenticity, and integrity of information.",c:"Security"},
{id:"data-management",t:"Data management policy",d:"Ensures information is classified, protected, retained, and securely disposed of based on its significance.",c:"Data"},
{id:"hr-security",t:"Human resources security policy",d:"Ensures employees and contractors meet security requirements, understand responsibilities, and are suitable for roles.",c:"HR"},
{id:"incident-response",t:"Incident response plan",d:"Establishes the plan for managing information security incidents with severity levels, escalation, and response procedures.",c:"Security"},
{id:"info-security",t:"Information security policy",d:"Communicates information security policies and outlines acceptable use and protection of information and assets.",c:"Security"},
{id:"roles-responsibilities",t:"Information security roles and responsibilities",d:"Defines roles and responsibilities critical for effective communication of security policies and standards.",c:"Governance"},
{id:"operations-security",t:"Operations security policy",d:"Ensures correct and secure operation of information processing systems and facilities.",c:"Operations"},
{id:"physical-security",t:"Physical security policy",d:"Prevents unauthorized physical access or damage to information and processing facilities.",c:"Security"},
{id:"removable-media",t:"Removable media policy",d:"Minimizes risk of loss or exposure of sensitive information and reduces exposure to malware from removable media.",c:"Security"},
{id:"risk-management",t:"Risk management policy",d:"Defines actions to address information security risks and opportunities and achieve security objectives.",c:"Risk"},
{id:"secure-development",t:"Secure development policy",d:"Ensures information security is designed and implemented within the development lifecycle.",c:"Operations"},
{id:"third-party",t:"Third-party management policy",d:"Ensures protection of data and assets shared with or accessible to suppliers and external parties.",c:"Risk"}
];

var ST={},flt="all",loaded=false;

function esc(t){var d=document.createElement("div");d.textContent=t;return d.innerHTML}
async function SL(k){try{var r=await window.storage.get(k);return r?JSON.parse(r.value):null}catch(e){return null}}
async function SS(k,v){try{await window.storage.set(k,JSON.stringify(v));return true}catch(e){return false}}
async function SD(k){try{await window.storage.delete(k);return true}catch(e){return false}}

function gs(id){
  var r=ST[id];
  if(!r)return"ns";
  if(r.status==="completed")return"dn";
  if(r.status==="in-progress")return"ip";
  if(!r.statements||!r.statements.length)return"ns";
  var t=r.statements.length,d=r.statements.filter(function(s){return s.status!=="pending"}).length;
  if(!d)return"ns";
  return d>=t?"dn":"ip";
}

function gp(id){
  var r=ST[id];
  if(!r||!r.statements)return{d:0,t:0};
  return{d:r.statements.filter(function(s){return s.status!=="pending"}).length,t:r.statements.length};
}

async function init(){
  await SS("soc2:company-name",COMPANY);
  for(var i=0;i<P.length;i++){
    var r=await SL("soc2:review:"+P[i].id);
    if(r)ST[P[i].id]=r;
  }
  Object.keys(INJECTED).forEach(function(id){
    var inj=INJECTED[id];
    if(!ST[id]||inj.status==="completed"){
      ST[id]={status:inj.status,statements:Array.from({length:inj.total},function(_,i){return{id:i+1,status:i<inj.reviewed?"approved":"pending"}})};
    }
  });
  loaded=true;
  render();
}

function render(){
  var el=document.getElementById("root");
  if(!loaded){el.innerHTML='<div style="text-align:center;padding:3rem;color:var(--color-text-secondary)">Loading...</div>';return}
  var dn=0,ip=0,ns=0;
  P.forEach(function(p){var s=gs(p.id);if(s==="dn")dn++;else if(s==="ip")ip++;else ns++});
  var pct=Math.round(dn/P.length*100);
  var cats={};P.forEach(function(p){cats[p.c]=(cats[p.c]||0)+1});

  var h='<div class="hdr">'+esc(COMPANY)+' \u2014 SOC 2 policy dashboard</div>';
  h+='<div class="sub">17 policies \u2022 '+dn+' completed</div>';
  h+='<div class="stats">';
  h+='<div class="stat"><div class="stat-l">SOC 2 readiness</div><div class="stat-v">'+pct+'%</div></div>';
  h+='<div class="stat"><div class="stat-l">Completed</div><div class="stat-v">'+dn+'</div></div>';
  h+='<div class="stat"><div class="stat-l">In progress</div><div class="stat-v">'+ip+'</div></div>';
  h+='<div class="stat"><div class="stat-l">Not started</div><div class="stat-v">'+ns+'</div></div>';
  h+='</div>';

  h+='<div class="fbar">';
  h+='<button class="'+(flt==="all"?"active":"")+'" onclick="sf(\'all\')">All ('+P.length+')</button>';
  if(dn)h+='<button class="'+(flt==="dn"?"active":"")+'" onclick="sf(\'dn\')">Completed ('+dn+')</button>';
  if(ip)h+='<button class="'+(flt==="ip"?"active":"")+'" onclick="sf(\'ip\')">In progress ('+ip+')</button>';
  if(ns)h+='<button class="'+(flt==="ns"?"active":"")+'" onclick="sf(\'ns\')">Not started ('+ns+')</button>';
  Object.keys(cats).sort().forEach(function(c){
    h+='<button class="'+(flt===c?"active":"")+'" onclick="sf(\''+c+'\')">'+c+' ('+cats[c]+')</button>';
  });
  h+='</div>';

  var fp=P.filter(function(p){
    if(flt==="all")return true;
    if(flt==="dn")return gs(p.id)==="dn";
    if(flt==="ip")return gs(p.id)==="ip";
    if(flt==="ns")return gs(p.id)==="ns";
    return p.c===flt;
  });

  h+='<div class="grid">';
  fp.forEach(function(p){
    var s=gs(p.id),pr=gp(p.id),pp=pr.t>0?Math.round(pr.d/pr.t*100):0;
    var sl=s==="ns"?"Not started":s==="ip"?"In progress":"Completed";
    h+='<div class="pc">';
    h+='<div class="pc-t">'+esc(p.t)+'</div>';
    h+='<div class="pc-f"><span class="cb c-'+p.c+'">'+esc(p.c)+'</span><span class="sb s-'+s+'">'+sl+'</span></div>';
    h+='<div class="pc-d">'+esc(p.d)+'</div>';
    if(pr.t>0){
      h+='<div class="bar"><div class="bar-f bar-'+(s==="dn"?"dn":"ip")+'" style="width:'+pp+'%"></div></div>';
      h+='<div style="font-size:11px;color:var(--color-text-secondary)">'+pr.d+'/'+pr.t+' statements reviewed</div>';
    }
    h+='<div class="acts">';
    h+='<button class="b-rv" onclick="rv(\''+p.id+'\')">Review \u2197</button>';
    if(s==="dn")h+='<button class="b-ex" onclick="ex(\''+p.id+'\')">Export as Word \u2197</button>';
    if(s!=="ns")h+='<button onclick="rs(\''+p.id+'\').catch(console.error)">Reset</button>';
    h+='</div></div>';
  });
  h+='</div>';
  el.innerHTML=h;
}

function sf(f){flt=f;render()}

function rv(id){
  var p=P.find(function(x){return x.id===id});
  if(!p)return;
  sendPrompt("I want to review the policy: \""+p.t+"\". Please use the policy-review skill to parse it into sections and statements, then launch the interactive review carousel.\n\nPolicy ID: "+id+"\nCompany name: "+COMPANY+"\nThis is a WORKING COPY (HTML) \u2014 load from soc2:working:"+id+" in persistent storage. If no working copy exists, read the HTML template from references/templates/ and apply company name replacement to create one.");
}

function ex(id){
  var p=P.find(function(x){return x.id===id});
  if(!p)return;
  sendPrompt("Export the completed policy \""+p.t+"\" (ID: "+id+") as a Word document using the policy-export skill.\nRead the HTML working copy from soc2:working:"+id+", version history from soc2:versions:"+id+", and audit trail from soc2:audit:"+id+".\nCompany name: "+COMPANY);
}

async function rs(id){
  var p=P.find(function(x){return x.id===id});
  if(!p)return;
  delete ST[id];
  await SD("soc2:review:"+id);
  await SD("soc2:working:"+id);
  await SD("soc2:audit:"+id);
  await SD("soc2:versions:"+id);
  render();
}

init();
</script>
```
