//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import JellyfinAPI
import SwiftUI

extension GuideView {

    struct GuideGridView: View {

        let channels: [ChannelProgram]
        let timeRange: ClosedRange<Date>
        let isToday: Bool
        let onProgramSelected: (BaseItemDto) -> Void
        let onReachedBottom: () -> Void
        let onReachedEnd: () -> Void

        private var totalWidth: CGFloat {
            GuideTimeScale.totalWidth(for: timeRange)
        }

        private var totalContentHeight: CGFloat {
            let spacingCount = max(CGFloat(channels.count) - 1, 0)
            let rowsHeight = channels.reduce(0) { $0 + rowHeight(for: $1) }
            return GuideTimeScale.timeHeaderHeight + rowsHeight + spacingCount * GuideTimeScale.rowSpacing
        }

        private var channelSpacing: CGFloat {
            UIDevice.isTV ? 16 : 8
        }

        var body: some View {
            ScrollView(.vertical, showsIndicators: false) {
                HStack(alignment: .top, spacing: channelSpacing) {
                    VStack(spacing: 0) {
                        Color.clear
                            .frame(height: GuideTimeScale.timeHeaderHeight)

                        VStack(spacing: GuideTimeScale.rowSpacing) {
                            ForEach(Array(channels.enumerated()), id: \.element.id) { _, channelProgram in
                                ChannelCell(channelProgram: channelProgram)
                                    .frame(height: rowHeight(for: channelProgram))
                            }
                        }
                    }
                    .frame(width: GuideTimeScale.channelColumnWidth)
                    .padding(.leading, channelSpacing)

                    ScrollViewReader { proxy in
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(alignment: .top, spacing: 0) {
                                ZStack(alignment: .topLeading) {
                                    VStack(alignment: .leading, spacing: 0) {
                                        TimeHeaderView(timeRange: timeRange)
                                            .frame(height: GuideTimeScale.timeHeaderHeight)

                                        VStack(spacing: GuideTimeScale.rowSpacing) {
                                            ForEach(Array(channels.enumerated()), id: \.element.id) { index, channelProgram in
                                                programRow(for: channelProgram, index: index)
                                            }

                                            Color.clear
                                                .frame(height: 1)
                                                .onAppear {
                                                    onReachedBottom()
                                                }
                                        }
                                    }

                                    if isToday {
                                        NowIndicatorView(
                                            timeRangeStart: timeRange.lowerBound,
                                            gridHeight: totalContentHeight
                                        )
                                    }
                                }

                                Color.clear
                                    .frame(width: 1, height: 1)
                                    .onAppear {
                                        onReachedEnd()
                                    }
                            }
                        }
                        .onAppear {
                            if isToday {
                                proxy.scrollTo(NowIndicatorView.scrollID, anchor: .leading)
                            }
                        }
                    }
                }
            }
        }

        private func rowHeight(for channelProgram: ChannelProgram) -> CGFloat {
            let posterType = channelProgram.channel.preferredPosterDisplayType
            let ratio: CGFloat = switch posterType {
            case .landscape: 1.77
            case .portrait: 2.0 / 3.0
            case .square: 1.0
            }
            let naturalHeight = GuideTimeScale.channelColumnWidth / ratio
            return min(naturalHeight, GuideTimeScale.channelColumnWidth)
        }

        private enum ProgramRowItem: Identifiable {
            case single(BaseItemDto)
            case grouped([BaseItemDto])

            var id: String {
                switch self {
                case let .single(program):
                    program.id ?? UUID().uuidString
                case let .grouped(programs):
                    programs.compactMap(\.id).joined(separator: "-")
                }
            }

            func xPosition(relativeTo start: Date) -> CGFloat {
                switch self {
                case let .single(program):
                    return GuideTimeScale.xPosition(for: program, relativeTo: start)
                case let .grouped(programs):
                    guard let first = programs.first else { return 0 }
                    return GuideTimeScale.xPosition(for: first, relativeTo: start)
                }
            }

            func width(in timeRange: ClosedRange<Date>) -> CGFloat {
                switch self {
                case let .single(program):
                    return GuideTimeScale.width(for: program, in: timeRange)
                case let .grouped(programs):
                    guard let first = programs.first,
                          let last = programs.last,
                          let start = first.startDate,
                          let end = last.endDate
                    else { return GuideTimeScale.minimumCellWidth }
                    let clampedStart = max(start, timeRange.lowerBound)
                    let clampedEnd = min(end, timeRange.upperBound)
                    let seconds = clampedEnd.timeIntervalSince(clampedStart)
                    return max(CGFloat(seconds / 3600.0) * GuideTimeScale.pointsPerHour, GuideTimeScale.minimumCellWidth)
                }
            }
        }

        private let maxSegmentDuration: TimeInterval = 30 * 60

        private func groupedItems(for programs: [BaseItemDto]) -> [ProgramRowItem] {
            var result: [ProgramRowItem] = []
            var currentGroup: [BaseItemDto] = []
            var currentGroupDuration: TimeInterval = 0

            func flushGroup() {
                guard !currentGroup.isEmpty else { return }
                if currentGroup.count == 1 {
                    result.append(.single(currentGroup[0]))
                } else {
                    result.append(.grouped(currentGroup))
                }
                currentGroup = []
                currentGroupDuration = 0
            }

            for program in programs {
                let duration = programDuration(program)
                if duration < GuideTimeScale.groupingThreshold {
                    if currentGroupDuration + duration > maxSegmentDuration, !currentGroup.isEmpty {
                        flushGroup()
                    }
                    currentGroup.append(program)
                    currentGroupDuration += duration
                } else {
                    flushGroup()
                    result.append(.single(program))
                }
            }
            flushGroup()
            return result
        }

        private func programDuration(_ program: BaseItemDto) -> TimeInterval {
            guard let start = program.startDate, let end = program.endDate else { return 0 }
            return end.timeIntervalSince(start)
        }

        @ViewBuilder
        private func programRow(for channelProgram: ChannelProgram, index: Int) -> some View {
            let height = rowHeight(for: channelProgram)
            let items = groupedItems(for: channelProgram.programs)

            ZStack(alignment: .topLeading) {
                ForEach(items) { item in
                    let cellWidth = item.width(in: timeRange) - GuideTimeScale.cellGap
                    let xPos = item.xPosition(relativeTo: timeRange.lowerBound)

                    switch item {
                    case let .single(program):
                        ProgramCell(
                            program: program,
                            width: cellWidth,
                            rowHeight: height,
                            action: { onProgramSelected(program) }
                        )
                        .offset(x: xPos)

                    case let .grouped(programs):
                        GroupedProgramCell(
                            programs: programs,
                            width: cellWidth,
                            rowHeight: height,
                            onProgramSelected: onProgramSelected
                        )
                        .offset(x: xPos)
                    }
                }
            }
            .frame(width: totalWidth, height: height, alignment: .topLeading)
        }

        struct ChannelCell: View {

            let channelProgram: ChannelProgram

            @State
            private var isInfoPresented = false

            var body: some View {
                #if os(tvOS)
                PosterButton(
                    item: channelProgram.channel,
                    type: channelProgram.channel.preferredPosterDisplayType
                ) {
                    isInfoPresented = true
                } label: {
                    EmptyView()
                }
                .alert(channelProgram.displayTitle, isPresented: $isInfoPresented) {
                    Button(L10n.dismiss, role: .cancel) {}
                } message: {
                    LabeledContent(
                        L10n.channel,
                        value: channelProgram.channel.number?.description ?? .emptyDash
                    )
                }
                #else
                PosterButton(
                    item: channelProgram.channel,
                    type: channelProgram.channel.preferredPosterDisplayType
                ) { _ in
                    isInfoPresented = true
                } label: {
                    EmptyView()
                }
                .popover(isPresented: $isInfoPresented) {
                    VStack(spacing: 4) {
                        Text(channelProgram.displayTitle)
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        if let number = channelProgram.channel.number {
                            Text(number)
                                .font(.caption)
                                .foregroundStyle(Color.secondary)
                        }
                    }
                    .padding()
                    .presentationCompactAdaptation(.popover)
                }
                #endif
            }
        }
    }
}
