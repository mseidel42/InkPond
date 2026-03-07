#set page(
  paper: "a4",
  margin: (x: 18mm, y: 16mm),
)
#set text(size: 10.5pt)
#set par(justify: true, leading: 0.72em)
#set heading(numbering: "1.")

#let card(title, fill, body) = block(
  inset: 10pt,
  radius: 8pt,
  stroke: rgb("#d7deea"),
  fill: fill,
  width: 100%,
)[
  #text(weight: "semibold")[#title]
  #v(6pt)
  #body
]

#align(right)[
  #text(size: 9pt, fill: rgb("#6b7280"))[
    Fictional internal brief · Revision 3 · 2026-03-07
  ]
]

= Typist Product Brief

#text(size: 18pt, weight: "bold")[A focused editor for serious Typst workflows]

Typist is positioned as a native writing environment for people who need more than plain text but less friction than a traditional desktop publishing tool. The product centers on fast iteration: source on the left, layout confidence on the right, and project files that stay understandable.

#grid(
  columns: (1fr, 1fr, 1fr),
  gutter: 10pt,
  card(
    [Core promise],
    rgb("#eef6ff"),
    [Create structured documents with live preview and dependable export.],
  ),
  card(
    [Primary users],
    rgb("#f3f8ef"),
    [Students, researchers, consultants, and documentation-heavy product teams.],
  ),
  card(
    [Market angle],
    rgb("#fff6e8"),
    [Mobile-first document authoring without sacrificing print-quality output.],
  ),
)

= Product Principles

1. The document source remains legible and close to the final result.
2. Projects should be portable enough to zip, export, and archive cleanly.
3. Common layouts must look polished before the user touches fine-grained styling.

= Key Scenarios

#table(
  columns: (22%, 24%, 54%),
  inset: 8pt,
  stroke: rgb("#cfd8e3"),
  table.header[Scenario][Moment][Why it matters],
  [Conference paper], [Last-mile revisions], [The author checks citations, tables, and abstract layout shortly before submission.],
  [Pitch deck], [Live presentation prep], [A presenter updates slides on a tablet right before walking on stage.],
  [Client brief], [On-site review], [A consultant exports a clean PDF from the same source file edited during the meeting.],
  [Poster], [Print preview], [A researcher validates hierarchy and readability from a zoomed-out view.],
)

= Experience Snapshot

#quote(block: true)[
  Good writing tools shorten the distance between intention and layout.
]

The editor should feel responsive enough that users keep refining the document instead of postponing polish until they return to a laptop. That behavior shift is the real product differentiator.

= Roadmap

#grid(
  columns: (1fr, 1fr),
  gutter: 12pt,
)[
  #card(
    [Now],
    rgb("#eef6ff"),
    [
      - Live Typst editing
      - Native preview
      - PDF export
      - Multi-file project structure
    ],
  )
][
  #card(
    [Next],
    rgb("#f8f3ff"),
    [
      - Better sample project gallery
      - Snippet insertion
      - Project duplication
      - Improved screenshot-ready templates
    ],
  )
]

= Launch Message

Typist helps people produce elegant documents without carrying a desktop workflow everywhere. The strongest screenshots should therefore show variety: a paper, a deck, a polished brief, and a poster, all edited inside the same app.
