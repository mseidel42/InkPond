#import "@preview/charged-ieee:0.1.4": ieee

#show: ieee.with(
  title: [Edge-Native Writing Workflows for Mobile Scientific Publishing],
  abstract: [
    Mobile-first authoring tools are often treated as viewers or quick note pads, leaving serious writing to desktop environments. This sample paper explores a different assumption: a scientific workflow in which drafting, revising, previewing, and exporting can happen on a tablet or phone without sacrificing typographic quality. We outline a lightweight document architecture, evaluate latency-sensitive feedback loops, and discuss why fast local compilation changes how people iterate on technical prose.
  ],
  authors: (
    (
      name: "Avery Lin",
      department: [Human-Computer Interaction Lab],
      organization: [North Coast Institute of Technology],
      location: [Singapore],
      email: "avery.lin@example.org",
    ),
    (
      name: "Mina Zhao",
      department: [Interactive Systems Group],
      organization: [North Coast Institute of Technology],
      location: [Singapore],
      email: "mina.zhao@example.org",
    ),
  ),
  index-terms: (
    "Typst",
    "mobile authoring",
    "scientific writing",
    "live preview",
    "document tooling",
  ),
  bibliography: bibliography("refs.bib"),
  figure-supplement: [Fig.],
)

= Introduction
Scientific writing workflows are usually split across multiple devices, cloud services, and export steps. That split increases friction for short revision cycles and makes it harder to review layouts while editing the source. A local-first toolchain reduces that overhead and keeps document structure visible throughout the process @inkflow2024.

In this sample, we focus on three qualities that read well in screenshots and matter in practice: immediate feedback, strong defaults, and portable project structure. We assume the author wants to revise a paper while commuting, presenting, or reviewing comments in a meeting.

= Design Goals
The workflow is guided by three constraints.

#figure(
  placement: top,
  caption: [Three goals for a mobile-first scientific writing workflow.],
  table(
    columns: (7em, auto),
    align: (left, left),
    inset: (x: 8pt, y: 4pt),
    stroke: (x, y) => if y <= 1 { (top: 0.5pt, bottom: 0.5pt) },
    fill: (x, y) => if y > 0 and calc.rem(y, 2) == 1 { rgb("#f5f7fb") },

    table.header[Goal][Practical implication],
    [Low latency], [Preview updates should keep pace with normal editing and preserve reading context.],
    [Project portability], [A document folder should bundle source, images, fonts, and exports without hidden state.],
    [Readable defaults], [Common layouts such as papers, slides, or briefs should start from strong templates.],
  ),
) <tab:goals>

As shown in @tab:goals, layout quality is only useful when it remains accessible during drafting. In mobile contexts, authors cannot afford long compile cycles or opaque project structures.

= Method
We model the writing loop as a sequence of edits, compiles, and visual inspections. Let the perceived iteration cost be

$ C = t_e + t_c + t_r $

where $t_e$ is edit time, $t_c$ is compile latency, and $t_r$ is review overhead after the preview changes. The aim is not merely to minimize $t_c$, but to keep the full loop predictable enough that authors stay in flow.

#figure(
  placement: none,
  caption: [A simplified local writing loop.],
  rect(
    width: 100%,
    height: 90pt,
    radius: 8pt,
    fill: rgb("#eef4ff"),
    stroke: rgb("#7aa2f7"),
  ),
)

We also distinguish between deep work sessions and opportunistic sessions. The latter are brief moments in which a user edits one paragraph, fixes a citation, or exports a PDF for sharing. Those moments benefit most from fast local rendering @pockettypeset2025.

= Results
The prototype workflow performed well in three representative scenarios.

1. Revising an abstract while reviewing comments on a tablet.
2. Checking figure placement immediately before a presentation.
3. Exporting a final PDF from the same project directory used for drafting.

These results are qualitative, but they suggest that mobile scientific writing becomes more practical when source editing and visual validation happen in the same environment. The strongest benefit is not raw speed alone; it is confidence that the document on screen matches the source the author is editing.

= Conclusion
Mobile devices should no longer be treated as secondary endpoints for serious technical writing. With local compilation, template-driven structure, and portable project folders, a scientific workflow can remain compact enough for handheld devices while still producing publication-grade output.
