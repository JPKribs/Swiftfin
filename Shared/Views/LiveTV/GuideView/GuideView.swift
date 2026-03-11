//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import JellyfinAPI
import SwiftUI

struct GuideView: View {

    @Environment(\.horizontalSizeClass)
    private var horizontalSizeClass

    @Router
    private var router

    @StateObject
    private var viewModel = ChannelLibraryViewModel()

    @FocusState
    private var isPlayButtonFocused: Bool

    @State
    private var selectedProgram: BaseItemDto?
    @State
    private var selectedDate: Date = .now
    @State
    private var timeRange: ClosedRange<Date> = {
        let start = GuideTimeScale.timeWindowStart()
        let end = GuideTimeScale.timeWindowEnd()
        return start ... end
    }()

    private var isCompact: Bool {
        horizontalSizeClass == .compact
    }

    private var isToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }

    private func refreshTimeRange() {
        let calendar = Calendar.current
        if isToday {
            timeRange = GuideTimeScale.timeWindowStart() ... GuideTimeScale.timeWindowEnd()
        } else {
            let start = calendar.startOfDay(for: selectedDate)
            let nextDay = calendar.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
            let end = calendar.startOfDay(for: nextDay)
            timeRange = start ... end
        }
    }

    private func selectDay(_ date: Date) {
        selectedDate = date
        viewModel.selectedDate = date
        refreshTimeRange()
        viewModel.send(.refresh)
    }

    private func advanceToNextDay() {
        let calendar = Calendar.current
        guard let nextDay = calendar.date(byAdding: .day, value: 1, to: selectedDate) else { return }
        let startOfNext = calendar.startOfDay(for: nextDay)
        let startOfMaxDay = calendar.date(byAdding: .day, value: 7, to: calendar.startOfDay(for: .now)) ?? .now
        guard startOfNext < startOfMaxDay else { return }
        selectDay(startOfNext)
    }

    private func playProgram(_ program: BaseItemDto) {
        let provider = program.getPlaybackItemProvider(userSession: viewModel.userSession)
        router.route(to: .videoPlayer(provider: provider))
    }

    private func selectProgram(_ program: BaseItemDto) {
        if selectedProgram?.id == program.id {
            selectedProgram = nil
        } else {
            selectedProgram = program
        }
    }

    var body: some View {
        ZStack {
            switch viewModel.state {
            case .content:
                if viewModel.elements.isEmpty {
                    Text(L10n.noResults)
                } else {
                    VStack(spacing: 0) {
                        if let program = selectedProgram {
                            ProgramDetails(
                                program: program,
                                playButtonFocused: $isPlayButtonFocused,
                                onPlay: { playProgram(program) }
                            )
                            .id(program.id)
                            .clipped()
                            .transition(.move(edge: .top).combined(with: .opacity))

                            Divider()
                        }

                        DayPicker(selectedDate: $selectedDate) { date in
                            selectDay(date)
                        }
                        .padding(.vertical, isCompact ? 8 : 12)

                        GuideGridView(
                            channels: Array(viewModel.elements),
                            timeRange: timeRange,
                            isToday: isToday,
                            onProgramSelected: { selectProgram($0) },
                            onReachedBottom: { viewModel.send(.getNextPage) },
                            onReachedEnd: advanceToNextDay
                        )
                    }
                    .animation(.easeInOut(duration: 0.3), value: selectedProgram?.id)
                }
            case let .error(error):
                ErrorView(error: error)
            case .initial, .refreshing:
                ProgressView()
            }
        }
        #if os(tvOS)
        .ignoresSafeArea()
        #else
        .navigationTitle(L10n.guide)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .refreshable {
            refreshTimeRange()
            viewModel.send(.refresh)
        }
        #if os(tvOS)
        .onChange(of: selectedProgram?.id) { _, newValue in
            if newValue != nil {
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(350))
                    isPlayButtonFocused = true
                }
            }
        }
        #endif
        .onFirstAppear {
                refreshTimeRange()
                if viewModel.state == .initial {
                    viewModel.send(.refresh)
                }
            }
            .sinceLastDisappear { interval in
                if interval >= 10800 {
                    refreshTimeRange()
                    viewModel.send(.refresh)
                }
            }
    }
}
