//
//  OnboardingView.swift
//  InkPond
//

import SwiftUI

struct OnboardingView: View {
    @State private var currentPage = 0
    @State private var appeared = false
    @Environment(\.horizontalSizeClass) private var sizeClass
    var onComplete: () -> Void

    private let pageCount = 4
    private var isRegular: Bool { sizeClass == .regular }

    // Purple → Blue gradient across 4 pages
    private var interpolatedGradient: [Color] {
        let t = Double(currentPage) / Double(pageCount - 1)
        let topR = 0.15 + (0.08 - 0.15) * t
        let topG = 0.10 + (0.16 - 0.10) * t
        let topB = 0.28 + (0.30 - 0.28) * t
        let botR = 0.08 + (0.06 - 0.08) * t
        let botG = 0.06 + (0.10 - 0.06) * t
        let botB = 0.18 + (0.22 - 0.18) * t
        return [
            Color(red: topR, green: topG, blue: topB),
            Color(red: botR, green: botG, blue: botB),
        ]
    }

    var body: some View {
        ZStack {
            backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    welcomePage.tag(0)
                    editorPage.tag(1)
                    previewPage.tag(2)
                    projectsPage.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.spring(duration: 0.5), value: currentPage)

                bottomBar
                    .padding(.horizontal, isRegular ? 80 : 32)
                    .padding(.bottom, isRegular ? 40 : 24)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                appeared = true
            }
        }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        ZStack {
            LinearGradient(
                colors: interpolatedGradient,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .animation(.easeInOut(duration: 0.6), value: currentPage)

            RadialGradient(
                colors: [Color.white.opacity(0.04), Color.clear],
                center: .top,
                startRadius: 100,
                endRadius: 500
            )
        }
    }

    // MARK: - Pages

    private var welcomePage: some View {
        OnboardingPageView(appeared: appeared) {
            VStack(spacing: isRegular ? 40 : 28) {
                Image("AppIconDisplay")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: isRegular ? 180 : 128, height: isRegular ? 180 : 128)
                    .clipShape(RoundedRectangle(cornerRadius: isRegular ? 42 : 30, style: .continuous))
                    .shadow(color: .black.opacity(0.3), radius: 20, y: 8)
                    .shadow(color: .white.opacity(0.08), radius: 1, y: -1)

                pageText(
                    title: L10n.tr("onboarding.welcome.title"),
                    subtitle: L10n.tr("onboarding.welcome.subtitle")
                )
            }
        }
    }

    private var editorPage: some View {
        OnboardingPageView(appeared: appeared) {
            VStack(spacing: isRegular ? 40 : 32) {
                OnboardingEditorIllustration(isRegular: isRegular)
                    .frame(
                        width: isRegular ? 480 : 280,
                        height: isRegular ? 340 : 200
                    )

                pageText(
                    title: L10n.tr("onboarding.editor.title"),
                    subtitle: L10n.tr("onboarding.editor.subtitle")
                )
            }
        }
    }

    private var previewPage: some View {
        OnboardingPageView(appeared: appeared) {
            VStack(spacing: isRegular ? 40 : 32) {
                OnboardingPreviewIllustration(isRegular: isRegular)
                    .frame(
                        width: isRegular ? 480 : 280,
                        height: isRegular ? 340 : 200
                    )

                pageText(
                    title: L10n.tr("onboarding.preview.title"),
                    subtitle: L10n.tr("onboarding.preview.subtitle")
                )
            }
        }
    }

    private var projectsPage: some View {
        OnboardingPageView(appeared: appeared) {
            VStack(spacing: isRegular ? 40 : 32) {
                OnboardingProjectsIllustration(isRegular: isRegular)
                    .frame(
                        width: isRegular ? 480 : 280,
                        height: isRegular ? 340 : 200
                    )

                pageText(
                    title: L10n.tr("onboarding.projects.title"),
                    subtitle: L10n.tr("onboarding.projects.subtitle")
                )
            }
        }
    }

    private func pageText(title: String, subtitle: String) -> some View {
        VStack(spacing: isRegular ? 16 : 12) {
            Text(title)
                .font(.system(size: isRegular ? 36 : 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text(subtitle)
                .font(.system(size: isRegular ? 20 : 17, weight: .regular))
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .lineSpacing(5)
        }
        .padding(.horizontal, isRegular ? 60 : 24)
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        VStack(spacing: isRegular ? 28 : 24) {
            pageIndicator

            Button {
                InteractionFeedback.impact(.medium)
                if currentPage == pageCount - 1 {
                    onComplete()
                } else {
                    withAnimation(.spring(duration: 0.4)) { currentPage += 1 }
                }
            } label: {
                Text(currentPage == pageCount - 1
                     ? L10n.tr("onboarding.action.get_started")
                     : L10n.tr("Continue"))
                    .font(.system(size: isRegular ? 19 : 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: isRegular ? 400 : .infinity)
                    .padding(.vertical, isRegular ? 18 : 16)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.40, green: 0.45, blue: 1.0),
                                        Color(red: 0.55, green: 0.35, blue: 0.95),
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                    .shadow(color: Color(red: 0.45, green: 0.40, blue: 1.0).opacity(0.4), radius: 12, y: 4)
            }
            .contentShape(Capsule())

            if currentPage < pageCount - 1 {
                Button {
                    InteractionFeedback.selection()
                    onComplete()
                } label: {
                    Text(L10n.tr("Skip"))
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.45))
                }
            } else {
                Color.clear.frame(height: 20)
            }
        }
    }

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<pageCount, id: \.self) { index in
                Capsule()
                    .fill(index == currentPage
                          ? Color.white
                          : Color.white.opacity(0.25))
                    .frame(width: index == currentPage ? 24 : 8, height: 8)
                    .animation(.spring(duration: 0.35), value: currentPage)
            }
        }
    }
}

// MARK: - Page Container

private struct OnboardingPageView<Content: View>: View {
    let appeared: Bool
    @ViewBuilder let content: Content

    var body: some View {
        VStack {
            Spacer()
            content
                .scaleEffect(appeared ? 1.0 : 0.88)
                .opacity(appeared ? 1.0 : 0.0)
            Spacer()
            Spacer()
        }
    }
}

// MARK: - Editor Illustration

private struct OnboardingEditorIllustration: View {
    let isRegular: Bool
    private let tint = Color(red: 0.45, green: 0.65, blue: 1.0)

    private var s: CGFloat { isRegular ? 1.7 : 1.0 }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14 * s, style: .continuous)
                .stroke(tint.opacity(0.3), lineWidth: 1.5)
                .background(
                    RoundedRectangle(cornerRadius: 14 * s, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                )

            VStack(alignment: .leading, spacing: 0) {
                // Title bar
                HStack(spacing: 6 * s) {
                    Circle().fill(Color.red.opacity(0.7)).frame(width: 8 * s, height: 8 * s)
                    Circle().fill(Color.yellow.opacity(0.7)).frame(width: 8 * s, height: 8 * s)
                    Circle().fill(Color.green.opacity(0.7)).frame(width: 8 * s, height: 8 * s)
                    Spacer()
                }
                .padding(.horizontal, 12 * s)
                .padding(.vertical, 10 * s)

                Rectangle().fill(tint.opacity(0.15)).frame(height: 0.5)

                // Code lines with gutter
                VStack(alignment: .leading, spacing: 8 * s) {
                    codeLine(number: 1, segments: [(.hash, 30), (.keyword, 18), (.plain, 50)])
                    codeLine(number: 2, segments: [(.hash, 18), (.keyword, 24), (.string, 60)])
                    codeLine(number: 3, segments: [])
                    codeLine(number: 4, segments: [(.heading, 90)])
                    codeLine(number: 5, segments: [])
                    codeLine(number: 6, segments: [(.plain, 120)])
                    codeLine(number: 7, segments: [(.plain, 80)])
                    codeLine(number: 8, segments: [(.math, 50)])
                    codeLine(number: 9, segments: [(.plain, 65), (.label, 30)])
                }
                .padding(.horizontal, 8 * s)
                .padding(.vertical, 10 * s)

                Spacer(minLength: 0)

                // Keyboard bar hint
                HStack(spacing: 4 * s) {
                    ForEach(["#", "$", "=", "*", "[", "]"], id: \.self) { sym in
                        Text(sym)
                            .font(.system(size: 9 * s, weight: .medium, design: .monospaced))
                            .foregroundStyle(tint.opacity(0.5))
                            .frame(width: 18 * s, height: 16 * s)
                            .background(
                                RoundedRectangle(cornerRadius: 3 * s, style: .continuous)
                                    .stroke(tint.opacity(0.2), lineWidth: 0.8)
                            )
                    }
                    Spacer()
                    Image(systemName: "text.badge.plus")
                        .font(.system(size: 8 * s))
                        .foregroundStyle(tint.opacity(0.45))
                    Image(systemName: "photo")
                        .font(.system(size: 8 * s))
                        .foregroundStyle(tint.opacity(0.45))
                }
                .padding(.horizontal, 12 * s)
                .padding(.bottom, 8 * s)
            }
        }
    }

    private enum SegmentKind {
        case hash, keyword, string, heading, plain, math, label
    }

    private func codeLine(number: Int, segments: [(SegmentKind, CGFloat)]) -> some View {
        HStack(spacing: 6 * s) {
            Text("\(number)")
                .font(.system(size: 8 * s, weight: .regular, design: .monospaced))
                .foregroundStyle(tint.opacity(0.25))
                .frame(width: 14 * s, alignment: .trailing)

            if segments.isEmpty {
                Spacer(minLength: 0)
            } else {
                HStack(spacing: 3 * s) {
                    ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                        RoundedRectangle(cornerRadius: 2 * s)
                            .fill(segmentColor(segment.0))
                            .frame(width: segment.1 * s, height: 6 * s)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .frame(height: 10 * s)
    }

    private func segmentColor(_ kind: SegmentKind) -> Color {
        switch kind {
        case .hash:    Color(red: 0.55, green: 0.75, blue: 1.0).opacity(0.7)
        case .keyword: Color(red: 0.75, green: 0.55, blue: 1.0).opacity(0.7)
        case .string:  Color(red: 0.55, green: 0.85, blue: 0.60).opacity(0.7)
        case .heading: Color(red: 1.0, green: 0.75, blue: 0.40).opacity(0.7)
        case .plain:   Color.white.opacity(0.25)
        case .math:    Color(red: 0.95, green: 0.55, blue: 0.65).opacity(0.7)
        case .label:   Color(red: 0.45, green: 0.80, blue: 0.85).opacity(0.7)
        }
    }
}

// MARK: - Preview Illustration

private struct OnboardingPreviewIllustration: View {
    let isRegular: Bool
    private let tint = Color(red: 0.75, green: 0.50, blue: 1.0)

    private var s: CGFloat { isRegular ? 1.7 : 1.0 }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14 * s, style: .continuous)
                .stroke(tint.opacity(0.3), lineWidth: 1.5)
                .background(
                    RoundedRectangle(cornerRadius: 14 * s, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                )

            VStack(spacing: 0) {
                // Title bar
                HStack(spacing: 6 * s) {
                    Circle().fill(Color.red.opacity(0.7)).frame(width: 8 * s, height: 8 * s)
                    Circle().fill(Color.yellow.opacity(0.7)).frame(width: 8 * s, height: 8 * s)
                    Circle().fill(Color.green.opacity(0.7)).frame(width: 8 * s, height: 8 * s)
                    Spacer()
                }
                .padding(.horizontal, 12 * s)
                .padding(.vertical, 10 * s)

                Rectangle().fill(tint.opacity(0.15)).frame(height: 0.5)

                HStack(spacing: 0) {
                    // Left: code side
                    VStack(alignment: .leading, spacing: 6 * s) {
                        miniCodeLine(widths: [20, 40])
                        miniCodeLine(widths: [14, 28, 50])
                        miniCodeLine(widths: [])
                        miniCodeLine(widths: [70])
                        miniCodeLine(widths: [90])
                        miniCodeLine(widths: [50])
                        miniCodeLine(widths: [80])
                        if isRegular {
                            miniCodeLine(widths: [])
                            miniCodeLine(widths: [60, 30])
                            miniCodeLine(widths: [45])
                        }
                    }
                    .padding(10 * s)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Divider
                    Rectangle()
                        .fill(tint.opacity(0.2))
                        .frame(width: 1)

                    // Right: rendered preview (page mockup)
                    VStack(spacing: 0) {
                        RoundedRectangle(cornerRadius: 4 * s, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                            .overlay(
                                VStack(alignment: .leading, spacing: 5 * s) {
                                    // Title
                                    RoundedRectangle(cornerRadius: 1.5 * s)
                                        .fill(Color.white.opacity(0.35))
                                        .frame(width: 60 * s, height: 7 * s)
                                        .frame(maxWidth: .infinity, alignment: .center)

                                    Spacer().frame(height: 2 * s)

                                    // Body text lines
                                    let lineWidths: [CGFloat] = isRegular
                                        ? [80, 85, 70, 82, 60, 45, 75, 68]
                                        : [80, 85, 70, 82, 60, 45]
                                    ForEach(Array(lineWidths.enumerated()), id: \.offset) { _, w in
                                        RoundedRectangle(cornerRadius: 1 * s)
                                            .fill(Color.white.opacity(0.15))
                                            .frame(width: w * s, height: 4 * s)
                                    }

                                    Spacer().frame(height: 4 * s)

                                    // Math block
                                    RoundedRectangle(cornerRadius: 1 * s)
                                        .fill(tint.opacity(0.25))
                                        .frame(width: 50 * s, height: 5 * s)
                                        .frame(maxWidth: .infinity, alignment: .center)
                                }
                                .padding(8 * s)
                            )
                            .padding(10 * s)
                    }
                    .frame(maxWidth: .infinity)
                }
                .frame(maxHeight: .infinity)
            }
        }
    }

    private func miniCodeLine(widths: [CGFloat]) -> some View {
        HStack(spacing: 3 * s) {
            if widths.isEmpty {
                Spacer(minLength: 0).frame(height: 5 * s)
            } else {
                ForEach(Array(widths.enumerated()), id: \.offset) { index, w in
                    RoundedRectangle(cornerRadius: 1.5 * s)
                        .fill(index == 0
                              ? tint.opacity(0.5)
                              : Color.white.opacity(0.2))
                        .frame(width: w * s, height: 5 * s)
                }
                Spacer(minLength: 0)
            }
        }
        .frame(height: 5 * s)
    }
}

// MARK: - Projects Illustration

private struct OnboardingProjectsIllustration: View {
    let isRegular: Bool
    private let tint = Color(red: 0.40, green: 0.80, blue: 0.70)

    private var s: CGFloat { isRegular ? 1.7 : 1.0 }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14 * s, style: .continuous)
                .stroke(tint.opacity(0.3), lineWidth: 1.5)
                .background(
                    RoundedRectangle(cornerRadius: 14 * s, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                )

            VStack(spacing: 0) {
                // Title bar
                HStack(spacing: 6 * s) {
                    Circle().fill(Color.red.opacity(0.7)).frame(width: 8 * s, height: 8 * s)
                    Circle().fill(Color.yellow.opacity(0.7)).frame(width: 8 * s, height: 8 * s)
                    Circle().fill(Color.green.opacity(0.7)).frame(width: 8 * s, height: 8 * s)
                    Spacer()
                    Text("my-thesis")
                        .font(.system(size: 9 * s, weight: .medium, design: .monospaced))
                        .foregroundStyle(tint.opacity(0.5))
                    Spacer()
                }
                .padding(.horizontal, 12 * s)
                .padding(.vertical, 10 * s)

                Rectangle().fill(tint.opacity(0.15)).frame(height: 0.5)

                VStack(alignment: .leading, spacing: 0) {
                    fileRow(icon: "doc.text.fill", color: tint, name: "main.typ", badge: "entry", indent: 0)
                    fileRow(icon: "doc.text", color: tint.opacity(0.6), name: "chapter1.typ", indent: 0)
                    fileRow(icon: "doc.text", color: tint.opacity(0.6), name: "chapter2.typ", indent: 0)
                    fileRow(icon: "folder.fill", color: Color(red: 0.95, green: 0.75, blue: 0.35), name: "images/", indent: 0)
                    fileRow(icon: "photo", color: Color.white.opacity(0.35), name: "diagram.png", indent: 1)
                    fileRow(icon: "photo", color: Color.white.opacity(0.35), name: "photo.jpg", indent: 1)
                    fileRow(icon: "folder.fill", color: Color(red: 0.95, green: 0.75, blue: 0.35), name: "fonts/", indent: 0)
                    fileRow(icon: "textformat", color: Color.white.opacity(0.35), name: "CustomFont.otf", indent: 1)
                    fileRow(icon: "book.closed", color: Color(red: 0.75, green: 0.55, blue: 1.0).opacity(0.7), name: "refs.bib", indent: 0)
                }
                .padding(.horizontal, 12 * s)
                .padding(.vertical, 8 * s)

                Spacer(minLength: 0)
            }
        }
    }

    private func fileRow(icon: String, color: Color, name: String, badge: String? = nil, indent: Int) -> some View {
        HStack(spacing: 6 * s) {
            if indent > 0 {
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(tint.opacity(0.15))
                        .frame(width: 1, height: 16 * s)
                        .padding(.leading, 6 * s)
                    Rectangle()
                        .fill(tint.opacity(0.15))
                        .frame(width: 8 * s, height: 1)
                }
                .frame(width: CGFloat(indent) * 16 * s)
            }

            Image(systemName: icon)
                .font(.system(size: 10 * s, weight: .medium))
                .foregroundStyle(color)
                .frame(width: 14 * s)

            Text(name)
                .font(.system(size: 10 * s, weight: .regular, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.7))

            if let badge {
                Text(badge)
                    .font(.system(size: 7 * s, weight: .semibold))
                    .foregroundStyle(tint)
                    .padding(.horizontal, 5 * s)
                    .padding(.vertical, 2 * s)
                    .background(
                        Capsule().fill(tint.opacity(0.15))
                    )
            }

            Spacer()
        }
        .frame(height: 18 * s)
    }
}

#Preview {
    OnboardingView(onComplete: {})
}
