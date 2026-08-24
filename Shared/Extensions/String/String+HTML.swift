//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import SwiftUI

extension String {

    /// `AttributedString` formatted using HTML and/or Markdown tags
    var richText: AttributedString {
        guard let formattedText = try? AttributedString(
            markdown: self,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) else {
            return AttributedString(self)
        }

        return HTMLParser(formattedText).parsed()
    }
}

extension String {

    private final class HTMLParser {

        struct OpenTag {
            let tag: HTMLTag
            let link: URL?
            let color: Color?
        }

        var openTags: [OpenTag] = []

        private var result = AttributedString()

        private var pendingBreak: InlinePresentationIntent = []

        private let source: AttributedString
        private let isHTML: Bool

        init(_ source: AttributedString) {
            self.source = source
            isHTML = source.runs.contains { $0.inlinePresentationIntent?.contains(.inlineHTML) == true }
        }

        func parsed() -> AttributedString {
            for run in source.runs {
                if run.inlinePresentationIntent?.contains(.inlineHTML) == true {
                    resolveElements(in: run.range)
                } else {
                    appendText(for: run)
                }
            }

            while result.characters.last?.isWhitespace == true {
                result.characters.removeLast()
            }

            return result
        }

        /// Records a break. Adjacent requests merge, so the strongest one wins
        func requestBreak(_ intent: InlinePresentationIntent) {
            let breaks = intent.intersection(.breaks)

            guard !breaks.isEmpty else { return }

            pendingBreak.formUnion(openTags.contains(where: { $0.tag == .li }) ? breaks.inListItem : breaks)
        }

        /// `<br>` is explicit, so a second one before any text stacks into a paragraph
        func requestStackedBreak() {
            pendingBreak = pendingBreak.isEmpty ? .softBreak : .lineBreak
        }

        func append(_ text: String) {
            flushBreak()

            result.append(AttributedString(text))
        }

        /// Table cells are separated by a space unless one is already there
        func appendCellSeparator() {
            flushBreak()

            guard result.characters.last?.isWhitespace == false else { return }

            result.append(AttributedString(String.space))
        }

        /// The only place a break becomes characters
        private func flushBreak() {
            defer { pendingBreak = [] }

            guard !pendingBreak.isEmpty, result.characters.isNotEmpty else { return }

            while result.characters.last == Character(.space) || result.characters.last == Character(.tab) {
                result.characters.removeLast()
            }

            var text = AttributedString(pendingBreak.text)
            text.inlinePresentationIntent = pendingBreak

            result.append(text)
        }

        private func resolveElements(in range: Range<AttributedString.Index>) {
            let elements = String(source[range].characters)
                .matches(of: #/<(?<closer>/?)(?<name>[a-zA-Z0-9]+)(?<attributes>[^>]*)/#)

            for element in elements {
                guard let tag = HTMLTag(rawValue: element.output.name.lowercased()) else { continue }

                if element.output.closer.isNotEmpty {
                    tag.close(in: self)
                } else if tag == .br || tag == .hr {
                    tag.lineBreak(in: self)
                } else if !element.output.attributes.hasSuffix("/") {
                    tag.open(in: self, from: String(element.output.attributes))
                }
            }
        }

        private func appendText(for run: AttributedString.Runs.Run) {
            var piece = AttributedString(source[run.range])

            // HTML renders any whitespace run as one space, or a paragraph break for blank lines. Preserve Markdown-only and `<pre>` text.
            if isHTML, !openTags.contains(where: { $0.tag == .pre }) {
                let collapsed = String(piece.characters).replacing(#/\s+/#) { match in
                    match.output.filter(\.isNewline).count > 1 ? String.newParagraph : .space
                }

                piece = AttributedString(collapsed, attributes: run.attributes)
            }

            if !pendingBreak.isEmpty || result.characters.isEmpty || result.characters.last == Character(.newLine) {
                piece.characters.trimPrefix(while: \.isWhitespace)
            } else if result.characters.last == Character(.space) {
                piece.characters.trimPrefix { $0 == Character(.space) }
            }

            // Whitespace-only runs between tags must not flush a pending break
            guard piece.characters.isNotEmpty else { return }

            flushBreak()

            let intent = openTags.reduce(run.inlinePresentationIntent ?? []) { $0.union($1.tag.intent) }
            let presentation = intent.subtracting(.custom).subtracting(.breaks)

            piece.inlinePresentationIntent = presentation.isEmpty ? nil : presentation
            piece.underlineStyle = intent.underlineStyle
            piece.baselineOffset = intent.baselineOffset

            // No hyperlinks on tvOS since they can't be opened
            let link = UIDevice.isTV ? nil : openTags.last(where: { $0.link != nil })?.link ?? piece.link
            piece.link = ["http", "https", "mailto"].contains(link?.scheme?.lowercased() ?? "") ? link : nil

            if let color = openTags.last(where: { $0.color != nil })?.color {
                piece.foregroundColor = color
            }

            result.append(piece)
        }
    }

    /// Named HTML entities that can appear in attribute values
    private enum SpecialCharacter: String {
        case amp
        case apos
        case gt
        case lt
        case nbsp
        case quot

        var character: Character {
            switch self {
            case .amp:
                "&"
            case .apos:
                "'"
            case .gt:
                ">"
            case .lt:
                "<"
            case .nbsp:
                "\u{00A0}"
            case .quot:
                "\""
            }
        }
    }

    // MARK: HTML Tags & Rules

    private enum HTMLTag: String {
        case a
        case b
        case blockquote
        case br
        case cite
        case code
        case del
        case dfn
        case div
        case em
        case h1
        case h2
        case h3
        case h4
        case h5
        case h6
        case hr
        case i
        case ins
        case kbd
        case li
        case ol
        case p
        case pre
        case s
        case samp
        case strike
        case strong
        case sub
        case sup
        case table
        case td
        case th
        case tr
        case tt
        case u
        case ul

        /// Unused but required to capture colors from
        /// `<font color=...>` and `<span style="color:...">`
        case font
        case span

        var intent: InlinePresentationIntent {
            switch self {
            case .h1, .h2, .h3, .h4, .h5, .h6:
                [.stronglyEmphasized, .lineBreak]
            case .b, .strong, .th:
                .stronglyEmphasized
            case .i, .em, .cite, .dfn:
                .emphasized
            case .s, .strike, .del:
                .strikethrough
            case .pre:
                [.code, .lineBreak]
            case .code, .tt, .kbd, .samp:
                .code
            case .u, .ins:
                .underlined
            case .sup:
                .superscripted
            case .sub:
                .subscripted
            case .p, .blockquote, .hr, .ul, .ol, .table:
                .lineBreak
            case .div, .li, .tr:
                .softBreak
            default:
                []
            }
        }

        func open(in parser: HTMLParser, from element: String) {
            parser.requestBreak(intent)

            if self == .li {
                parser.append(String.bullet + String.space)
            } else if self == .td || self == .th {
                parser.appendCellSeparator()
            }

            parser.openTags.append(
                HTMLParser.OpenTag(
                    tag: self,
                    link: self == .a ? attribute("href", in: element).flatMap { URL(string: $0) } : nil,
                    color: color(in: element)
                )
            )
        }

        func close(in parser: HTMLParser) {
            if let index = parser.openTags.lastIndex(where: { $0.tag == self }) {
                parser.openTags.remove(at: index)
            }

            parser.requestBreak(intent)
        }

        func lineBreak(in parser: HTMLParser) {
            if self == .br {
                parser.requestStackedBreak()
            } else {
                parser.requestBreak(intent)
            }
        }

        private func attribute(_ name: String, in element: String) -> String? {
            guard let regex = try? Regex("(?i) \(name)=(?:\"([^\"]*)\"|'([^']*)'|(\\S+))"),
                  let match = element.firstMatch(of: regex)
            else { return nil }

            let value = match.output.dropFirst().compactMap(\.substring).first ?? ""

            // Foundation decodes entities in text runs but leaves raw HTML untouched
            return String(value).replacing(#/&(?:#(?<code>[xX]?[0-9a-fA-F]+)|(?<name>[a-zA-Z]+));/#) { entity in
                if let name = entity.output.name {
                    SpecialCharacter(rawValue: String(name)).map { String($0.character) } ?? String(entity.output.0)
                } else if let code = entity.output.code {
                    (code.hasPrefix("x") || code.hasPrefix("X") ? UInt32(code.dropFirst(), radix: 16) : UInt32(code))
                        .flatMap(Unicode.Scalar.init)
                        .map { String(Character($0)) } ?? String(entity.output.0)
                } else {
                    String(entity.output.0)
                }
            }
        }

        private func color(in element: String) -> Color? {
            let styleColor = attribute("style", in: element)?
                .firstMatch(of: #/(?:^|[;\s])color\s*:\s*(?<value>[^;]+)/#.ignoresCase())?
                .output.value

            return (styleColor.map(String.init) ?? attribute("color", in: element))
                .flatMap { Color(html: $0) }
        }
    }
}
