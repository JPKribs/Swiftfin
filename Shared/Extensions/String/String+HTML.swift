//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import SwiftUI

extension String {

    private final class RichTextBox {

        let value: AttributedString

        init(_ value: AttributedString) {
            self.value = value
        }
    }

    private static let richTextCache = NSCache<NSString, RichTextBox>()

    var richText: AttributedString {
        if let cached = Self.richTextCache.object(forKey: self as NSString) {
            return cached.value
        }

        let value: AttributedString

        if let markdown = try? AttributedString(
            markdown: self,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            var parser = HTMLParser(markdown)
            value = parser.parse()
        } else {
            value = AttributedString(self)
        }

        Self.richTextCache.setObject(RichTextBox(value), forKey: self as NSString)

        return value
    }

    var plainText: String {
        String(richText.characters)
    }
}

extension String {

    private enum HTMLBreak: Comparable {
        case line
        case paragraph

        var text: String {
            switch self {
            case .line:
                .newLine
            case .paragraph:
                .newParagraph
            }
        }
    }

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
        case script
        case strike
        case strong
        case style
        case sub
        case sup
        case table
        case td
        case th
        case tr
        case tt
        case u
        case ul

        var intent: InlinePresentationIntent {
            switch self {
            case .b, .strong, .th, .h1, .h2, .h3, .h4, .h5, .h6:
                .stronglyEmphasized
            case .i, .em, .cite, .dfn:
                .emphasized
            case .s, .strike, .del:
                .strikethrough
            case .code, .kbd, .pre, .samp, .tt:
                .code
            default:
                []
            }
        }

        var htmlBreak: HTMLBreak? {
            switch self {
            case .blockquote, .h1, .h2, .h3, .h4, .h5, .h6, .hr, .ol, .p, .pre, .table, .ul:
                .paragraph
            case .div, .li, .tr:
                .line
            default:
                nil
            }
        }
    }

    private struct HTMLParser {

        private struct OpenTag {
            let tag: HTMLTag
            let link: URL?
            var itemCount = 0
        }

        private let source: AttributedString
        private let isHTML: Bool

        private var result = AttributedString()
        private var openTags: [OpenTag] = []
        private var pendingBreak: HTMLBreak?

        init(_ source: AttributedString) {
            self.source = source
            self.isHTML = source.runs.contains { $0.inlinePresentationIntent?.contains(.inlineHTML) == true }
        }

        mutating func parse() -> AttributedString {
            for run in source.runs {
                if run.inlinePresentationIntent?.contains(.inlineHTML) == true {
                    resolveTags(in: run.range)
                } else {
                    append(run)
                }
            }

            while result.characters.last?.isWhitespace == true {
                result.characters.removeLast()
            }

            return result
        }

        private func isOpen(_ tags: HTMLTag...) -> Bool {
            openTags.contains { tags.contains($0.tag) }
        }

        private mutating func resolveTags(in range: Range<AttributedString.Index>) {
            let html = String(source[range].characters)

            for match in html.matches(of: #/<(?<closing>/?)(?<name>[a-zA-Z0-9]+)(?<attributes>[^>]*)/#) {
                guard let tag = HTMLTag(rawValue: match.output.name.lowercased()) else { continue }

                if match.output.closing.isNotEmpty {
                    close(tag)
                } else if tag == .br {
                    requestBreak(pendingBreak == nil ? .line : .paragraph)
                } else if tag == .hr {
                    requestBreak(.paragraph)
                } else if !match.output.attributes.hasSuffix("/") {
                    open(tag, attributes: match.output.attributes)
                }
            }
        }

        private mutating func open(_ tag: HTMLTag, attributes: Substring) {
            requestBreak(tag.htmlBreak)

            if tag == .li {
                if let index = openTags.lastIndex(where: { $0.tag == .ol || $0.tag == .ul }), openTags[index].tag == .ol {
                    openTags[index].itemCount += 1
                    appendText("\(openTags[index].itemCount)." + .space)
                } else {
                    appendText(.bullet + .space)
                }
            } else if tag == .td || tag == .th {
                flushBreak()

                if result.characters.last?.isWhitespace == false {
                    result.append(AttributedString(String.space))
                }
            }

            openTags.append(OpenTag(tag: tag, link: tag == .a ? link(in: attributes) : nil))
        }

        private mutating func close(_ tag: HTMLTag) {
            if let index = openTags.lastIndex(where: { $0.tag == tag }) {
                openTags.remove(at: index)
            }

            requestBreak(tag.htmlBreak)
        }

        private mutating func requestBreak(_ htmlBreak: HTMLBreak?) {
            guard let htmlBreak else { return }

            let newBreak = isOpen(.li) ? .line : htmlBreak
            pendingBreak = Swift.max(pendingBreak ?? newBreak, newBreak)
        }

        private mutating func flushBreak() {
            defer { pendingBreak = nil }

            guard let pendingBreak, result.characters.isNotEmpty else { return }

            while result.characters.last == " " || result.characters.last == "\t" {
                result.characters.removeLast()
            }

            result.append(AttributedString(pendingBreak.text))
        }

        private mutating func appendText(_ text: String) {
            flushBreak()
            result.append(AttributedString(text))
        }

        private mutating func append(_ run: AttributedString.Runs.Run) {
            guard !isOpen(.script, .style) else { return }

            var text = AttributedString(source[run.range])

            if isHTML, !isOpen(.pre) {
                let collapsed = String(text.characters).replacing(#/\s+/#) { match in
                    match.output.filter(\.isNewline).count > 1 ? String.newParagraph : .space
                }

                text = AttributedString(collapsed, attributes: run.attributes)
            }

            if pendingBreak != nil || result.characters.isEmpty || result.characters.last == "\n" {
                text.characters.trimPrefix(while: \.isWhitespace)
            } else if result.characters.last == " " {
                text.characters.trimPrefix { $0 == " " }
            }

            guard text.characters.isNotEmpty else { return }

            flushBreak()

            let intent = openTags.reduce(run.inlinePresentationIntent ?? []) { $0.union($1.tag.intent) }
            text.inlinePresentationIntent = intent.isEmpty ? nil : intent

            if isOpen(.u, .ins) {
                text.underlineStyle = .single
            }

            if isOpen(.sup) {
                text.baselineOffset = 5
            } else if isOpen(.sub) {
                text.baselineOffset = -3
            }

            // tvOS can't open links
            let link = openTags.last { $0.link != nil }?.link ?? text.link
            let isAllowed = link?.scheme.map { ["http", "https", "mailto"].contains($0.lowercased()) } == true
            text.link = !UIDevice.isTV && isAllowed ? link : nil

            result.append(text)
        }

        private func link(in attributes: Substring) -> URL? {
            guard let match = attributes.firstMatch(
                of: #/\shref\s*=\s*(?:"(?<double>[^"]*)"|'(?<single>[^']*)'|(?<bare>[^\s"']+))/#.ignoresCase()
            ) else { return nil }

            let value = match.output.double ?? match.output.single ?? match.output.bare ?? ""

            return URL(string: String(value).replacing("&amp;", with: "&"))
        }
    }
}
