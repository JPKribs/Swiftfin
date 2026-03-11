//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Defaults
import JellyfinAPI
import SwiftUI

extension GuideView {

    struct ProgramCell: View {

        @Default(.accentColor)
        private var accentColor

        private let program: BaseItemDto
        private let width: CGFloat
        private let rowHeight: CGFloat
        private let action: () -> Void

        init(program: BaseItemDto, width: CGFloat, rowHeight: CGFloat, action: @escaping () -> Void) {
            self.program = program
            self.width = width
            self.rowHeight = rowHeight
            self.action = action
        }

        private var titleFont: Font {
            UIDevice.isTV ? .callout : .caption
        }

        private var timeFont: Font {
            UIDevice.isTV ? .footnote : .caption2
        }

        private var cornerRadius: CGFloat {
            UIDevice.isTV ? 10 : 8
        }

        private var showText: Bool {
            width >= GuideTimeScale.pointsPerHour / 4
        }

        private var contentPadding: CGFloat {
            UIDevice.isTV ? 12 : 8
        }

        var body: some View {
            Button(action: action) {
                ZStack {
                    if program.isAiring {
                        accentColor.opacity(0.5)
                    } else {
                        Color.gray.opacity(0.3)
                    }

                    if showText {
                        VStack(alignment: .leading, spacing: UIDevice.isTV ? 4 : 2) {
                            Text(program.displayTitle)
                                .font(titleFont)
                                .fontWeight(program.isAiring ? .bold : .regular)
                                .lineLimit(1)

                            HStack(spacing: 2) {
                                if let startDate = program.startDate {
                                    Text(startDate, style: .time)
                                }
                                Text("-")
                                if let endDate = program.endDate {
                                    Text(endDate, style: .time)
                                }
                            }
                            .font(timeFont)
                            .foregroundStyle(Color.secondary)
                            .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, contentPadding)
                    }
                }
                .frame(width: width, height: rowHeight, alignment: .leading)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            }
            .buttonStyle(.card)
        }
    }

    struct GroupedProgramCell: View {

        @Default(.accentColor)
        private var accentColor

        let programs: [BaseItemDto]
        let width: CGFloat
        let rowHeight: CGFloat
        let onProgramSelected: (BaseItemDto) -> Void

        private var cornerRadius: CGFloat {
            UIDevice.isTV ? 10 : 8
        }

        private var titleFont: Font {
            UIDevice.isTV ? .callout : .caption
        }

        private var timeFont: Font {
            UIDevice.isTV ? .footnote : .caption2
        }

        private var sortedPrograms: [BaseItemDto] {
            programs.sorted { a, b in
                if a.isAiring != b.isAiring {
                    return a.isAiring
                }
                return (a.startDate ?? .distantPast) < (b.startDate ?? .distantPast)
            }
        }

        private var hasAiringProgram: Bool {
            programs.contains { $0.isAiring }
        }

        private let maxVisibleNames = 3

        private var contentPadding: CGFloat {
            UIDevice.isTV ? 12 : 8
        }

        var body: some View {
            Menu {
                ForEach(sortedPrograms, id: \.id) { program in
                    Button {
                        onProgramSelected(program)
                    } label: {
                        Text(program.displayTitle)

                        if let startDate = program.startDate,
                           let endDate = program.endDate
                        {
                            Text("\(startDate, style: .time) – \(endDate, style: .time)")
                        }
                    }
                }
            } label: {
                ZStack {
                    if hasAiringProgram {
                        accentColor.opacity(0.5)
                    } else {
                        Color.gray.opacity(0.3)
                    }

                    VStack(alignment: .leading, spacing: UIDevice.isTV ? 3 : 1) {
                        ForEach(Array(sortedPrograms.prefix(maxVisibleNames).enumerated()), id: \.offset) { _, program in
                            Text(program.displayTitle)
                                .font(titleFont)
                                .fontWeight(program.isAiring ? .bold : .regular)
                                .lineLimit(1)
                        }

                        if programs.count > maxVisibleNames {
                            Text("…")
                                .font(titleFont)
                                .foregroundStyle(Color.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, contentPadding)
                }
                .frame(width: width, height: rowHeight)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            }
            .buttonStyle(.card)
        }
    }
}
