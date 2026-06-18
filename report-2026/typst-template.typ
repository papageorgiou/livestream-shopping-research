// Custom Typst template for the 2026 Live Shopping report.
// Goal: larger, more legible body text; clear heading hierarchy; branded title
// page and footer. Body = serif (editorial, readable); headings = sans, branded red.

#let brand_red = rgb("#CD0000")
#let brand_ink = rgb("#2E2E2E")
#let brand_gray = rgb("#6E6E6E")
#let brand_light = rgb("#F2F2F2")
#let brand_rule = rgb("#D8D8D8")

#let redrule(w: 100%, thick: 1.4pt) = {
  line(length: w, stroke: thick + brand_red)
}

#let report(
  title: none,
  subtitle: none,
  date: none,
  author: "Alex Papageorgiou",
  abstract: none,
  doc,
) = {
  // ---- page geometry + footer -------------------------------------------------
  set page(
    paper: "us-letter",
    margin: (top: 2.2cm, bottom: 2.4cm, x: 2.3cm),
    footer: context {
      let page_num = counter(page).get().first()
      if page_num > 1 {
        line(length: 100%, stroke: 0.5pt + brand_rule)
        v(3pt)
        grid(
          columns: (1fr, 1fr),
          align(left)[#text(size: 8pt, fill: brand_gray)[Live Shopping in the United States · 2026]],
          align(right)[#text(size: 8pt, fill: brand_gray)[#page_num]],
        )
      }
    },
  )

  // ---- base text + paragraph spacing -----------------------------------------
  set text(font: ("Libertinus Serif", "Georgia", "Times New Roman"),
           size: 11pt, fill: brand_ink, lang: "en", region: "US")
  set par(leading: 0.78em, justify: true, spacing: 1.05em, first-line-indent: 0pt)
  show link: set text(fill: brand_red)

  // ---- heading hierarchy ------------------------------------------------------
  show heading: it => {
    let lvl = it.level
    let size = if lvl == 1 { 17pt } else if lvl == 2 { 13pt } else { 11.5pt }
    let col = if lvl == 1 { brand_red } else { brand_ink }
    set text(font: ("Helvetica Neue", "Arial"), fill: col, size: size, weight: "bold")
    set block(above: if lvl == 1 { 22pt } else { 16pt },
              below: if lvl == 1 { 9pt } else { 7pt })
    if lvl == 1 {
      // breakable:false + sticky avoids duplication / orphaning at page edges
      block(breakable: false, sticky: true)[#it #v(2pt) #redrule(thick: 1pt)]
    } else {
      block(sticky: true, it)
    }
  }

  // ---- tables: lighter, more legible -----------------------------------------
  set table(stroke: (x, y) => (
    top: if y == 0 { 0.8pt + brand_ink } else { 0pt },
    bottom: 0.5pt + brand_rule,
  ), inset: 6pt)
  show table.cell.where(y: 0): set text(weight: "bold", size: 9.5pt, fill: brand_ink)

  // ================= TITLE PAGE =================
  v(40pt)
  block(text(font: ("Helvetica Neue", "Arial"), size: 13pt, fill: brand_red,
             weight: "bold", tracking: 2pt)[LIVE SHOPPING SEARCH INSIGHTS])
  v(6pt)
  block(text(font: ("Helvetica Neue", "Arial"), size: 30pt, fill: brand_ink,
             weight: "bold")[#title])
  if subtitle != none {
    v(8pt)
    block(width: 92%, text(font: ("Helvetica Neue", "Arial"), size: 14pt,
                           fill: brand_red, weight: "medium")[#subtitle])
  }
  v(14pt)
  redrule()
  v(8pt)
  grid(
    columns: (1fr, 1fr),
    align(left)[#text(size: 10.5pt, fill: brand_gray)[#author]],
    align(right)[#text(size: 10.5pt, fill: brand_gray)[#date]],
  )
  v(26pt)

  if abstract != none {
    block(
      width: 100%, fill: brand_light, inset: 16pt, radius: 3pt,
      [
        #text(font: ("Helvetica Neue", "Arial"), size: 9.5pt, weight: "bold",
              fill: brand_red, tracking: 1pt)[EXECUTIVE OVERVIEW]
        #v(5pt)
        #set text(size: 10.5pt, fill: brand_ink)
        #set par(justify: true, leading: 0.7em)
        #abstract
      ],
    )
  }

  v(20pt)
  // table of contents
  show outline.entry.where(level: 1): it => {
    v(4pt, weak: true)
    text(font: ("Helvetica Neue", "Arial"), weight: "bold", fill: brand_ink, it)
  }
  block(text(font: ("Helvetica Neue", "Arial"), size: 13pt, fill: brand_red,
             weight: "bold")[Contents])
  v(4pt)
  outline(title: none, depth: 2, indent: 1.2em)

  pagebreak()

  // ================= BODY =================
  doc
}
