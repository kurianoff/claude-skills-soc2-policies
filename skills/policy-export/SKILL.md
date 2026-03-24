---
name: policy-export
description: >
  Export a reviewed policy document as a Word (.docx) file. Use this skill whenever
  the user wants to export, download, or generate a Word document from a completed
  policy review. Triggers on: "export as Word", "download this policy", "generate
  a docx", "export policy", or any request to produce a final Word document from
  a reviewed policy. This skill receives the finalized policy content as HTML and
  converts it directly to a professional Word document. It is designed to be invoked
  by the soc2-policies skill or the policy-review skill after a review is complete,
  but can also be used standalone if the user provides HTML policy content.
---

# Policy export skill

Converts a finalized policy document (HTML) into a professional Word (.docx)
file. This is the final step in the policy review pipeline.

**Input is always HTML.** The soc2-policies and policy-review skills store all
policy content as HTML. This skill receives HTML and converts it directly to
Word format — no markdown intermediate step is involved at any point.

---

## When this skill triggers

1. User clicks "Export as Word" on a completed policy in the soc2-dashboard.
2. User asks to download or export a policy after completing a review.
3. User provides HTML policy content and asks for a Word document.

---

## Input format

This skill expects a `POLICY_EXPORT_REQUEST` message containing:

```
POLICY_EXPORT_REQUEST
Policy: Acceptable Use Policy
Policy ID: acceptable-use
Company name: Acme Corp

VERSION HISTORY:
| Version | Date | Description | Author | Approved by |
| 1.0 | 2026-03-23 | Initial review | Jane Smith | John Doe |

FULL DOCUMENT (HTML):
<h1>Acceptable Use Policy</h1>
<h2>Purpose and Scope</h2>
<p>The purpose of this policy is to...</p>
[the entire finalized policy as HTML]

REJECTED STATEMENTS (if any):
- Statement label: "original text" — Reason: justification
```

The FULL DOCUMENT section contains the complete policy as HTML with all user
rewrites already applied. This is the source of truth.

---

## Step 1: Validate the input

Before generating the document, verify:
1. The FULL DOCUMENT section is present and non-empty.
2. No `[COMPANY NAME]` placeholders remain in the HTML.
3. The HTML is well-formed (check for unclosed tags).
4. If anything looks wrong, ask the user to confirm before proceeding.

---

## Step 2: Generate the Word document

Use the docx skill to create a professional Word document. The docx skill
accepts HTML input, so pass the HTML content directly — no conversion to
markdown is needed.

The document should include:
1. **Title page**: Policy name, company name, version, date, author, approver.
   Get version metadata from the export request message (Version, Date, Author,
   Approved by fields) or from `soc2:versions:{policy-id}` in storage.
2. **Table of contents**: See TOC instructions below.
3. **Policy body**: The full HTML content converted to Word formatting.
   - `<h1>` → Document title / Heading 1
   - `<h2>` → Heading 2 (section headers)
   - `<h3>` → Heading 3 (subsection headers)
   - `<p>` → Body text
   - `<ul>/<ol>` → Bulleted/numbered lists
   - `<table>` → Word tables with header row styling
4. **Rejected statements appendix** (if any): Listed at the end with the
   original text and rejection reason for each.
5. **Version history table**: Generated from `soc2:versions:{policy-id}` in
   storage, or from the VERSION HISTORY data in the export request. Shows all
   prior versions plus the current revision. Columns: Version, Date,
   Description, Author, Approved by.
6. **Audit trail table**: Read from `soc2:audit:{policy-id}` in storage. This
   is a chronological table of all review actions taken on this policy. Columns:
   Date/time, Action, Statement, Details. This gives SOC 2 auditors a
   self-contained provenance record showing exactly what was reviewed, approved,
   rewritten, or rejected, and when.

### Table of contents (TOC) — important

The `docx-js` library's `TableOfContents` field code creates an empty TOC that
requires Word to update it. LibreOffice headless mode also cannot reliably
populate TOC field codes.

**Build the TOC manually** using styled paragraphs instead of `TableOfContents`.
For each `<h1>` in the document, add a TOC line at normal indent. For each
`<h2>`, add an indented line (indent left: 360 DXA). For `<h3>`, indent at
720 DXA. Use a muted color (e.g., "444444") for sub-entries.

```javascript
// H1 entry (top-level section)
new Paragraph({ spacing: { after: 60 },
  children: [new TextRun({ text: "Core policy", font: "Arial", size: 22 })] }),
// H2 entry (indented sub-section)
new Paragraph({ spacing: { after: 60 }, indent: { left: 360 },
  children: [new TextRun({ text: "Purpose", font: "Arial", size: 22, color: "444444" })] }),
```

This approach renders correctly immediately in Word, Google Docs, and Preview
without any field updates. The trade-off is the TOC won't auto-update if
sections change — but for finalized policy exports this is acceptable since
the document represents a completed review.

Place the TOC after the title page (start of second section), followed by a
page break before the policy body begins.

---

## Step 3: Present the file

Save the final `.docx` file to `/mnt/user-data/outputs/` and use `present_files`
to make it available for download.

---

## Important notes

- This skill receives HTML, not markdown. The HTML has already been through
  the review pipeline and contains the user's approved/rewritten content.
- Do NOT read from policy template files. The HTML in the export request is
  the only source of truth.
- Do NOT convert HTML to markdown as an intermediate step. The docx skill
  can work with HTML directly via pandoc.
- If the HTML contains `<table>` elements, ensure they are properly converted
  to Word tables with visible borders and header row formatting.
