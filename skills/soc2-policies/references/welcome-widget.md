# Welcome widget template

## How Claude uses this template

This widget renders when no company name exists in persistent storage.
It captures the company name and triggers the dashboard render.

1. Copy the ENTIRE widget code below into `visualize:show_widget` VERBATIM
2. Do NOT modify any CSS, HTML structure, or logic
3. There are ZERO injection points — this template is used as-is

### show_widget parameters

```
title: "soc2_welcome"
loading_messages: ["Setting up SOC 2 Policy Manager"]
```

### When to render this widget

Before rendering the dashboard, Claude should instruct the dashboard widget
to check for `soc2:company-name` in storage. BUT since the dashboard widget
template has the company name as an injection point, Claude needs to know the
name BEFORE rendering the dashboard.

**Flow:**
1. Claude checks if it already knows the company name (from the conversation,
   from memory, or from a prior message).
2. If YES → render the dashboard directly with `var COMPANY = "Known Name";`
3. If NO → render this welcome widget. The widget saves the name to storage
   and sends a `sendPrompt()` that triggers the dashboard render.

**Claude should NOT ask for the company name in prose.** Always use this widget.

## Complete widget code

```html
<div id="welcome" style="padding:2rem 0;font-family:var(--font-sans);max-width:480px;margin:0 auto;text-align:center"></div>
<style>
.w-title{font-size:22px;font-weight:500;color:var(--color-text-primary);margin-bottom:8px}
.w-desc{font-size:15px;color:var(--color-text-secondary);line-height:1.6;margin-bottom:1.5rem}
.w-input{width:100%;box-sizing:border-box;font-size:16px;font-family:var(--font-sans);padding:12px 16px;border:.5px solid var(--color-border-secondary);border-radius:var(--border-radius-lg);background:var(--color-background-primary);color:var(--color-text-primary);margin-bottom:1.25rem;text-align:left}
.w-input:focus{outline:none;box-shadow:0 0 0 2px var(--color-border-info)}
.w-input::placeholder{color:var(--color-text-tertiary)}
.w-btn{font-size:15px;padding:10px 32px;border-radius:var(--border-radius-md);cursor:pointer;font-weight:500;border:.5px solid var(--color-border-secondary);background:transparent;color:var(--color-text-primary);transition:background .15s,transform .1s}
.w-btn:hover{background:var(--color-background-secondary)}
.w-btn:active{transform:scale(.98)}
.w-btn:disabled{opacity:.4;cursor:default}
.w-btn:disabled:hover{background:transparent}
</style>
<script>
function checkInput(){
  var v=document.getElementById("co-name").value.trim();
  document.getElementById("go-btn").disabled=!v;
}
async function start(){
  var name=document.getElementById("co-name").value.trim();
  if(!name)return;
  document.getElementById("go-btn").disabled=true;
  document.getElementById("go-btn").textContent="Loading...";
  try{await window.storage.set("soc2:company-name",JSON.stringify(name))}catch(e){}
  sendPrompt("Company name set to: "+name+"\nPlease render the SOC 2 policy dashboard for "+name+".");
}
function handleKey(e){if(e.key==="Enter"){e.preventDefault();start().catch(console.error)}}
var el=document.getElementById("welcome");
el.innerHTML='<div class="w-title">Welcome to SOC 2 policy manager</div><div class="w-desc">Before we begin, what is your company name? This will be used to personalize all 17 policy templates.</div><input type="text" class="w-input" id="co-name" placeholder="Your company name" oninput="checkInput()" onkeydown="handleKey(event)" autofocus><br><button class="w-btn" id="go-btn" onclick="start().catch(console.error)" disabled>Get started</button>';
setTimeout(function(){var i=document.getElementById("co-name");if(i)i.focus()},100);
</script>
```
