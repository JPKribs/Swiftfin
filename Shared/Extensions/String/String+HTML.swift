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
        var result = AttributedString()

        private let source: AttributedString

        init(_ source: AttributedString) {
            self.source = source
        }

        func parsed() -> AttributedString {
            for run in source.runs {
                if run.inlinePresentationIntent?.contains(.inlineHTML) == true {
                    resolveElements(in: run.range)
                } else {
                    appendText(for: run)
                }
            }

            // Condense instances where there are 3+ line breaks down to just 2
            while let range = result.characters.firstRange(of: String.newParagraph + .newLine) {
                result.characters.replaceSubrange(range, with: String.newParagraph)
            }

            // Remove trailing spaces
            while result.characters.last?.isWhitespace == true {
                result.characters.removeLast()
            }

            return result
        }

        private func resolveElements(in range: Range<AttributedString.Index>) {
            for element in source[range].characters.split(separator: ">").map(String.init) {
                let name = String(element.drop { $0 == "<" || $0 == "/" }.prefix { $0.isLetter || $0.isNumber }).lowercased()

                guard let tag = HTMLTag(rawValue: name) else { continue }

                if element.hasPrefix("</") {
                    tag.close(in: self)
                } else if tag == .br || tag == .hr {
                    tag.lineBreak(in: self)
                } else if !element.hasSuffix("/") {
                    tag.open(in: self, from: element)
                }
            }
        }

        private func appendText(for run: AttributedString.Runs.Run) {
            var piece = AttributedString(source[run.range])

            // Collapse any non-<pre> HTML whitespace. Preserve Markdown-only text.
            if source.runs.contains(where: { $0.inlinePresentationIntent?.contains(.inlineHTML) == true }),
               !openTags.contains(where: { $0.tag == .pre })
            {
                piece = AttributedString(collapseWhitespace(in: String(piece.characters)), attributes: run.attributes)
            }

            trimLeadingWhitespace(of: &piece)
            style(&piece, within: run.inlinePresentationIntent ?? [])

            result.append(piece)
        }

        private func trimLeadingWhitespace(of piece: inout AttributedString) {
            if result.characters.isEmpty || result.characters.last == Character(.newLine) {
                while piece.characters.first?.isWhitespace == true {
                    piece.characters.removeFirst()
                }
            } else if result.characters.last == Character(.space) {
                while piece.characters.first == Character(.space) {
                    piece.characters.removeFirst()
                }
            }
        }

        private func style(_ piece: inout AttributedString, within runIntent: InlinePresentationIntent) {
            let intent = openTags.reduce(runIntent) { $0.union($1.tag.intent) }
            piece.inlinePresentationIntent = intent.isEmpty ? nil : intent

            if openTags.contains(where: { $0.tag == .u || $0.tag == .ins }) {
                piece.underlineStyle = .single
            }

            let baselineOffset = openTags.reduce(0) { $0 + $1.tag.baselineOffset }

            if baselineOffset != 0 {
                piece.baselineOffset = baselineOffset
            }

            piece.link = link(inheriting: piece.link)

            if let color = openTags.last(where: { $0.color != nil })?.color {
                piece.foregroundColor = color
            }
        }

        private func link(inheriting inherited: URL?) -> URL? {
            guard !UIDevice.isTV else { return nil } // No hyperlinks on tvOS since they can't be opened

            let link = openTags.last(where: { $0.link != nil })?.link ?? inherited

            guard let scheme = link?.scheme?.lowercased(), ["http", "https", "mailto"].contains(scheme) else { return nil }

            return link
        }

        private func collapseWhitespace(in element: String) -> String {
            var result: String = .empty
            var newlines: Int?

            for character in element {
                if character == Character(.space) || character == Character(.tab) || character.isNewline {
                    newlines = (newlines ?? 0) + (character.isNewline ? 1 : 0)
                } else {
                    if let newlines {
                        result += newlines > 1 ? .newParagraph : .space
                    }

                    newlines = nil
                    result.append(character)
                }
            }

            if let newlines {
                result += newlines > 1 ? .newParagraph : .space
            }

            return result
        }
    }

    // MARK: HTML Tags & Rules

    /// HTML tags that can be used to denote usable `InlinePresentationIntent`s
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
        case font
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
        case span
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

        func open(in parser: HTMLParser, from element: String) {
            lineBreak(in: parser)

            if self == .li {
                parser.result.append(AttributedString(String.bullet + String.space))
            } else if self == .td || self == .th, parser.result.characters.last?.isWhitespace == false {
                parser.result.append(AttributedString(String.space))
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

            lineBreak(in: parser)
        }

        func lineBreak(in parser: HTMLParser) {
            guard parser.result.characters.isNotEmpty, self == .br || blockBreaks > 0 else { return }

            while parser.result.characters.last == Character(.space) || parser.result.characters.last == Character(.tab) {
                parser.result.characters.removeLast()
            }

            if self == .br {
                if !parser.result.characters.suffix(2).elementsEqual(String.newParagraph) {
                    parser.result.append(AttributedString(String.newLine))
                }

                return
            }

            // List items are single spaced regardless of what the tag would otherwise break
            let count = parser.openTags.contains(where: { $0.tag == .li }) ? Swift.min(blockBreaks, 1) : blockBreaks

            while !parser.result.characters.suffix(count).elementsEqual(repeatElement(Character(.newLine), count: count)) {
                parser.result.append(AttributedString(String.newLine))
            }
        }

        private func attribute(_ name: String, in element: String) -> String? {
            guard let range = element.range(of: " \(name)=", options: .caseInsensitive) else { return nil }

            let rest = element[range.upperBound...]
            let quote = rest.first.flatMap { $0 == "\"" || $0 == "'" ? $0 : nil }
            let value = quote.map { quote in rest.dropFirst().prefix { $0 != quote } } ?? rest.prefix { !$0.isWhitespace }

            return String(value).replacingOccurrences(of: "&amp;", with: "&")
        }

        private func color(in element: String) -> Color? {
            let styleColor = attribute("style", in: element)?
                .split(separator: ";")
                .map { $0.split(separator: ":", maxSplits: 1) }
                .first { $0.first?.trimmingCharacters(in: .whitespaces).lowercased() == "color" }?
                .last

            return (styleColor.map(String.init) ?? attribute("color", in: element))
                .flatMap { Color(html: $0) }
        }

        var intent: InlinePresentationIntent {
            switch self {
            case .b, .strong, .th, .h1, .h2, .h3, .h4, .h5, .h6:
                .stronglyEmphasized
            case .i, .em, .cite, .dfn:
                .emphasized
            case .s, .strike, .del:
                .strikethrough
            case .code, .tt, .kbd, .samp, .pre:
                .code
            default:
                []
            }
        }

        var blockBreaks: Int {
            switch self {
            case .p, .h1, .h2, .h3, .h4, .h5, .h6, .blockquote, .pre, .hr, .ul, .ol, .table:
                2
            case .div, .li, .tr:
                1
            default:
                0
            }
        }

        var baselineOffset: CGFloat {
            switch self {
            case .sup:
                5
            case .sub:
                -3
            default:
                0
            }
        }
    }
}
