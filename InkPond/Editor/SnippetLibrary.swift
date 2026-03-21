//
//  SnippetLibrary.swift
//  InkPond
//

import Foundation

enum SnippetLibrary {
    static let builtIn: [Snippet] = [
        // MARK: - Document Setup
        Snippet(
            title: "Basic Document",
            category: "Document Setup",
            body: """
            #set page(paper: "a4")
            #set text(font: "New Computer Modern", size: 11pt)

            $0
            """,
            keywords: ["page", "setup", "document", "template"],
            isBuiltIn: true
        ),
        Snippet(
            title: "Article Template",
            category: "Document Setup",
            body: """
            #set page(paper: "a4", margin: 2.5cm)
            #set text(font: "New Computer Modern", size: 11pt)
            #set par(justify: true)
            #set heading(numbering: "1.1")

            #align(center)[
              #text(size: 18pt, weight: "bold")[$0]
              #v(0.5em)
              #text(size: 12pt)[Author Name]
              #v(0.5em)
              #text(size: 10pt, fill: gray)[#datetime.today().display()]
            ]

            #v(1em)

            *Abstract.* #lorem(50)

            = Introduction

            """,
            keywords: ["article", "paper", "academic", "template"],
            isBuiltIn: true
        ),
        Snippet(
            title: "Letter Template",
            category: "Document Setup",
            body: """
            #set page(paper: "a4", margin: 2.5cm)
            #set text(size: 11pt)

            #align(right)[
              Your Name \\
              Your Address \\
              #datetime.today().display()
            ]

            #v(2em)

            Recipient Name \\
            Recipient Address

            #v(1em)

            Dear $0,

            #lorem(30)

            Sincerely,

            Your Name
            """,
            keywords: ["letter", "mail", "correspondence"],
            isBuiltIn: true
        ),
        Snippet(
            title: "Presentation Slide",
            category: "Document Setup",
            body: """
            #set page(width: 25.4cm, height: 14.29cm, margin: 2cm)
            #set text(size: 20pt)

            #align(center + horizon)[
              #text(size: 36pt, weight: "bold")[$0]
            ]
            """,
            keywords: ["slide", "presentation", "16:9", "deck"],
            isBuiltIn: true
        ),

        // MARK: - Layout
        Snippet(
            title: "Two Columns",
            category: "Layout",
            body: "#columns(2)[$0]",
            keywords: ["columns", "layout", "two"],
            isBuiltIn: true
        ),
        Snippet(
            title: "Centered Block",
            category: "Layout",
            body: "#align(center)[$0]",
            keywords: ["center", "align", "middle"],
            isBuiltIn: true
        ),
        Snippet(
            title: "Page Break",
            category: "Layout",
            body: "#pagebreak()\n$0",
            keywords: ["page", "break", "newpage"],
            isBuiltIn: true
        ),

        // MARK: - Figure & Table
        Snippet(
            title: "Figure with Caption",
            category: "Figure & Table",
            body: """
            #figure(
              image("$0"),
              caption: [Caption text],
            ) <fig:label>
            """,
            keywords: ["figure", "image", "caption", "label"],
            isBuiltIn: true
        ),
        Snippet(
            title: "Table (2 Columns)",
            category: "Figure & Table",
            body: """
            #figure(
              table(
                columns: 2,
                [*Header 1*], [*Header 2*],
                [$0], [],
              ),
              caption: [Caption text],
            )
            """,
            keywords: ["table", "grid", "two", "columns"],
            isBuiltIn: true
        ),
        Snippet(
            title: "Table (3 Columns)",
            category: "Figure & Table",
            body: """
            #figure(
              table(
                columns: 3,
                [*Header 1*], [*Header 2*], [*Header 3*],
                [$0], [], [],
              ),
              caption: [Caption text],
            )
            """,
            keywords: ["table", "grid", "three", "columns"],
            isBuiltIn: true
        ),
        Snippet(
            title: "Code Block with Caption",
            category: "Figure & Table",
            body: """
            #figure(
              ```$0
              code here
              ```,
              caption: [Caption text],
            )
            """,
            keywords: ["code", "figure", "caption", "listing"],
            isBuiltIn: true
        ),

        // MARK: - Math
        Snippet(
            title: "Inline Math",
            category: "Math",
            body: "$$$0$",
            keywords: ["math", "inline", "equation"],
            isBuiltIn: true
        ),
        Snippet(
            title: "Display Math",
            category: "Math",
            body: "$ $0 $",
            keywords: ["math", "display", "equation", "block"],
            isBuiltIn: true
        ),
        Snippet(
            title: "Aligned Equations",
            category: "Math",
            body: """
            $ $0 &= a \\\\ &= b $
            """,
            keywords: ["math", "align", "equations", "multiline"],
            isBuiltIn: true
        ),
        Snippet(
            title: "Matrix",
            category: "Math",
            body: """
            $ mat(
              $0, 0;
              0, 1;
            ) $
            """,
            keywords: ["math", "matrix", "linear algebra"],
            isBuiltIn: true
        ),

        // MARK: - Bibliography
        Snippet(
            title: "Bibliography Setup",
            category: "Bibliography",
            body: "#bibliography(\"$0.bib\")",
            keywords: ["bibliography", "references", "bib"],
            isBuiltIn: true
        ),
        Snippet(
            title: "Citation",
            category: "Bibliography",
            body: "@$0",
            keywords: ["cite", "citation", "reference"],
            isBuiltIn: true
        ),

        // MARK: - Code
        Snippet(
            title: "Code Block",
            category: "Code",
            body: "```$0\ncode\n```",
            keywords: ["code", "block", "listing", "raw"],
            isBuiltIn: true
        ),
        Snippet(
            title: "Inline Code",
            category: "Code",
            body: "`$0`",
            keywords: ["code", "inline", "raw", "monospace"],
            isBuiltIn: true
        ),
    ]

    static var categoryOrder: [String] {
        ["Document Setup", "Layout", "Figure & Table", "Math", "Bibliography", "Code"]
    }
}
