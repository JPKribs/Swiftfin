//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import JellyfinAPI
import SwiftUI

struct GuideView: PlatformView {

    @Router
    private var router

    @FocusedValue(\.focusedPoster)
    private var focusedPoster

    @FocusState
    private var isPlayButtonFocused: Bool

    @StateObject
    private var viewModel = ChannelLibraryViewModel()

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

    /// The program to display in the detail panel.
    /// Prefers focus-driven selection (tvOS), falls back to tap-driven (iOS).
    private var displayedProgram: BaseItemDto? {
        if let focusedPoster, let program = focusedPoster._poster as? BaseItemDto {
            return program
        }
        return selectedProgram
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

    // MARK: - Play Action

    private func playProgram(_ program: BaseItemDto) {
        let provider = program.getPlaybackItemProvider(userSession: viewModel.userSession)
        router.route(to: .videoPlayer(provider: provider))
    }

    // MARK: - Detail Panel

    @ViewBuilder
    private var detailPanel: some View {
        if let program = displayedProgram {
            ProgramDetails(
                program: program,
                onPlay: { playProgram(program) },
                playButtonFocused: $isPlayButtonFocused
            )
            .id(program.id)
            .transition(.opacity)
        } else {
            VStack {
                Spacer()

                Text(L10n.guide)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Program Selection

    private func selectProgram(_ program: BaseItemDto) {
        #if os(iOS)
        if selectedProgram?.id == program.id {
            selectedProgram = nil
        } else {
            selectedProgram = program
        }
        #else
        selectedProgram = program
        isPlayButtonFocused = true
        #endif
    }

    // MARK: - Guide Grid

    @ViewBuilder
    private var guideGrid: some View {
        GuideGridView(
            channels: Array(viewModel.elements),
            timeRange: timeRange,
            isToday: isToday,
            onProgramSelected: { program in
                selectProgram(program)
            },
            onReachedBottom: {
                viewModel.send(.getNextPage)
            }
        )
    }

    // MARK: - Day Picker

    // MARK: - tvOS Content Layout (Detail 33% + Grid 67%)

    @ViewBuilder
    private func tvOSGuideContent(detailFraction: CGFloat = 1.0 / 3.0) -> some View {
        GeometryReader { geometry in
            let detailHeight = geometry.size.height * detailFraction
            let gridHeight = geometry.size.height * (1.0 - detailFraction)

            VStack(spacing: 0) {
                detailPanel
                    .frame(height: detailHeight)
                    .clipped()
                    .animation(.easeInOut(duration: 0.2), value: displayedProgram?.id)

                Divider()

                DayPicker(selectedDate: $selectedDate) { date in
                    selectDay(date)
                }
                .padding(.vertical, 12)

                guideGrid
                    .frame(height: gridHeight)
            }
        }
    }

    // MARK: - iOS Content Layout (Detail slides in/out)

    @ViewBuilder
    private func iOSGuideContent() -> some View {
        VStack(spacing: 0) {
            if selectedProgram != nil {
                detailPanel
                    .clipped()
                    .transition(.move(edge: .top).combined(with: .opacity))

                Divider()
            }

            DayPicker(selectedDate: $selectedDate) { date in
                selectDay(date)
            }
            .frame(height: 40)
            .padding(.vertical, 8)

            guideGrid
        }
        .animation(.easeInOut(duration: 0.3), value: selectedProgram?.id)
    }

    // MARK: - iOS

    var iOSView: some View {
        ZStack {
            Color.clear

            switch viewModel.state {
            case .content:
                if viewModel.elements.isEmpty {
                    Text(L10n.noResults)
                } else {
                    iOSGuideContent()
                }
            case let .error(error):
                ErrorView(error: error)
            case .initial, .refreshing:
                ProgressView()
            }
        }
        .navigationTitle(L10n.guide)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            refreshTimeRange()
            viewModel.send(.refresh)
        }
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

    // MARK: - tvOS

    var tvOSView: some View {
        ZStack {
            switch viewModel.state {
            case .content:
                if viewModel.elements.isEmpty {
                    Text(L10n.noResults)
                } else {
                    tvOSGuideContent()
                }
            case let .error(error):
                ErrorView(error: error)
            case .initial, .refreshing:
                ProgressView()
            }
        }
        .animation(.linear(duration: 0.1), value: viewModel.state)
        .ignoresSafeArea()
        .refreshable {
            refreshTimeRange()
            viewModel.send(.refresh)
        }
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
