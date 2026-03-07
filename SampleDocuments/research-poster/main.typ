#set page(
  width: 297mm,
  height: 210mm,
  margin: 12mm,
)
#set text(size: 11pt)

#let panel(title, fill, body) = block(
  inset: 12pt,
  radius: 10pt,
  stroke: rgb("#cfd6e4"),
  fill: fill,
  width: 100%,
)[
  #text(size: 15pt, weight: "bold")[#title]
  #v(8pt)
  #body
]

#align(center)[
  #text(size: 26pt, weight: "bold")[Readable Posters from Structured Source]
  #v(4pt)
  #text(size: 12pt, fill: rgb("#4b5563"))[
    Fictional Demo for Typist Screenshots · Visual Computing Workshop 2026
  ]
]

#v(10pt)

#grid(
  columns: (1fr, 1fr, 1fr),
  gutter: 12pt,
)[
  #panel(
    [Context],
    rgb("#eef6ff"),
    [
      Posters are often assembled at the last minute, which makes consistency hard to maintain. A structured source format keeps headings, emphasis, and figures aligned across revisions.

      #v(8pt)
      #text(weight: "semibold")[Questions]
      - Can one source adapt to both close reading and wall-scale layout?
      - Can authors revise content without breaking the visual hierarchy?
    ],
  )
][
  #panel(
    [Method],
    rgb("#f3f8ef"),
    [
      #table(
        columns: (46%, 54%),
        inset: 6pt,
        stroke: rgb("#cfd8e3"),
        [Input], [Structured Typst source with sections, tables, and figure captions],
        [Process], [Iterative editing with immediate PDF preview and export checks],
        [Output], [Readable poster layout with stable spacing and strong headings],
      )

      #v(8pt)
      $ C = s + k + p $
    ],
  )
][
  #panel(
    [Takeaways],
    rgb("#fff6e8"),
    [
      1. Strong defaults reduce final-hour design work.
      2. Portable project folders make collaboration simpler.
      3. A poster view is ideal for App Store screenshots because it demonstrates zoomed-out fidelity immediately.
    ],
  )
]

#v(12pt)

#grid(
  columns: (1.2fr, 1.8fr),
  gutter: 12pt,
)[
  #panel(
    [Highlights],
    rgb("#f8f3ff"),
    [
      - One-page landscape composition
      - High information density
      - Clear section contrast
      - Neutral fictional content
    ],
  )
][
  #panel(
    [Visual Summary],
    white,
    [
      #rect(
        width: 100%,
        height: 68mm,
        radius: 10pt,
        fill: rgb("#e9eefb"),
        stroke: rgb("#90a4d4"),
      )

      #v(-56mm)
      #align(center + horizon)[
        #text(size: 20pt, weight: "bold", fill: rgb("#35507a"))[Preview-Friendly Layout]
        #v(8pt)
        #text(fill: rgb("#4b5563"))[
          Dense enough to look impressive from afar,
          clean enough to stay legible when zoomed in.
        ]
      ]
    ],
  )
]
