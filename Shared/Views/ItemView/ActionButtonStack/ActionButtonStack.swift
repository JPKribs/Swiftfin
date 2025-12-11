//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2025 Jellyfin & Jellyfin Contributors
//

import Defaults
import JellyfinAPI
import Logging
import SwiftUI

extension ItemView {

    // MARK: - Refresh Action

    enum RefreshAction {
        case findMissing
        case replaceMetadata
        case replaceImages
        case replaceAll
    }

    // MARK: - Action Button Stack

    struct ActionButtonStack: View {

        @Default(.accentColor)
        private var accentColor

        @StoredValue(.User.enabledTrailers)
        private var enabledTrailers: TrailerSelection

        @Router
        var router

        @ObservedObject
        var viewModel: ItemViewModel

        @StateObject
        private var deleteViewModel: DeleteItemViewModel

        @StateObject
        private var refreshViewModel: RefreshMetadataViewModel

        @State
        private var showConfirmationDialog = false

        @State
        private var error: Error?

        @State
        private var availableWidth: CGFloat = 0

        #if os(tvOS)
        @EnvironmentObject
        private var focusGuide: FocusGuide

        @FocusState
        private var focusedButtonIndex: Int?

        @State
        private var lastFocusedIndex: Int = 0
        #endif

        private let buttonHeight: CGFloat
        private let horizontalSpacing: CGFloat
        private let verticalSpacing: CGFloat
        private let layoutMode: ActionButtonLayoutMode
        private let primaryButtonConstraints: ButtonSizeConstraints
        private let secondaryButtonConstraints: ButtonSizeConstraints
        private let focusTag: String
        private let buttonOrder: [ActionButtonType]

        private var overflowButtonWidth: CGFloat {
            buttonHeight * 0.6
        }

        private let logger = Logger.swiftfin()

        // MARK: - Permissions

        private var canDelete: Bool {
            viewModel.userSession.user.permissions.items.canDelete(item: viewModel.item)
        }

        private var canEdit: Bool {
            viewModel.userSession.user.permissions.items.canEditMetadata(item: viewModel.item)
        }

        private var canRefresh: Bool {
            viewModel.userSession.user.permissions.items.canEditMetadata(item: viewModel.item)
        }

        private var canManageSubtitles: Bool {
            viewModel.userSession.user.permissions.items.canManageSubtitles(item: viewModel.item)
        }

        // MARK: - Computed

        private var mediaSources: [MediaSourceInfo] {
            viewModel.playButtonItem?.mediaSources ?? []
        }

        private var localTrailers: [BaseItemDto] {
            viewModel.localTrailers
        }

        private var externalTrailers: [MediaURL] {
            viewModel.item.remoteTrailers ?? []
        }

        private var hasTrailers: Bool {
            (enabledTrailers.contains(.local) && localTrailers.isNotEmpty) ||
                (enabledTrailers.contains(.external) && externalTrailers.isNotEmpty)
        }

        private var playButtonTitle: String {
            if let seriesViewModel = viewModel as? SeriesItemViewModel,
               let seasonEpisodeLabel = seriesViewModel.playButtonItem?.seasonEpisodeLabel
            {
                return seasonEpisodeLabel
            }
            return viewModel.playButtonItem?.playButtonLabel ?? L10n.play
        }

        // MARK: - Visible Buttons

        private var visibleButtons: [ActionButtonType] {
            buttonOrder
                .filter { ActionButtonType.supportedCases.contains($0) }
                .filter { isAvailable($0) }
        }

        // MARK: - Availability

        private func isAvailable(_ type: ActionButtonType) -> Bool {
            switch type {
            case .play:
                viewModel.item.presentPlayButton
            case .played:
                viewModel.item.canBePlayed
            case .favorite:
                true
            case .versions:
                mediaSources.count > 1
            case .trailers:
                hasTrailers
            case .subtitles:
                canManageSubtitles
            case .refresh:
                canRefresh
            case .edit:
                canEdit
            case .delete:
                canDelete
            }
        }

        // MARK: - Initializer

        init(
            viewModel: ItemViewModel,
            layoutMode: ActionButtonLayoutMode = .horizontal,
            buttonHeight: CGFloat = UIDevice.isTV ? 100 : 50,
            horizontalSpacing: CGFloat = UIDevice.isTV ? 30 : 10,
            verticalSpacing: CGFloat = UIDevice.isTV ? 25 : 10,
            primaryButtonConstraints: ButtonSizeConstraints = .default,
            secondaryButtonConstraints: ButtonSizeConstraints = .default,
            focusTag: String = "actionButtons",
            buttonOrder: [ActionButtonType] = ActionButtonType.defaultOrder
        ) {
            self.viewModel = viewModel
            self._deleteViewModel = StateObject(wrappedValue: .init(item: viewModel.item))
            self._refreshViewModel = StateObject(wrappedValue: .init(item: viewModel.item))
            self.layoutMode = layoutMode
            self.buttonHeight = buttonHeight
            self.horizontalSpacing = horizontalSpacing
            self.verticalSpacing = verticalSpacing
            self.primaryButtonConstraints = primaryButtonConstraints
            self.secondaryButtonConstraints = secondaryButtonConstraints
            self.focusTag = focusTag
            self.buttonOrder = buttonOrder
        }

        // MARK: - Body

        var body: some View {
            ActionButtonLayout(
                mode: layoutMode,
                buttonHeight: buttonHeight,
                horizontalSpacing: horizontalSpacing,
                verticalSpacing: verticalSpacing,
                primaryButtonConstraints: primaryButtonConstraints,
                secondaryButtonConstraints: secondaryButtonConstraints
            ) {
                ForEach(Array(visibleButtons.enumerated()), id: \.element.id) { index, type in
                    button(for: type, at: index)
                }

                overflowMenu(availableWidth: availableWidth)
                    .isOverflowMenu()
            }
            .background {
                GeometryReader { geometry in
                    Color.clear
                        .onAppear { availableWidth = geometry.size.width }
                        .onChange(of: geometry.size.width) { newWidth in
                            availableWidth = newWidth
                        }
                }
            }
            .font(.title3)
            .fontWeight(.semibold)
            #if os(tvOS)
                .focusGuide(
                    focusGuide,
                    tag: focusTag,
                    onContentFocus: { focusedButtonIndex = lastFocusedIndex }
                )
                .onChange(of: focusedButtonIndex) { _, newIndex in
                    if let index = newIndex {
                        lastFocusedIndex = index
                    }
                }
            #endif
                .confirmationDialog(
                        L10n.deleteItemConfirmationMessage,
                        isPresented: $showConfirmationDialog,
                        titleVisibility: .visible
                    ) {
                        Button(L10n.confirm, role: .destructive) {
                            deleteViewModel.send(.delete)
                        }
                        Button(L10n.cancel, role: .cancel) {}
                    }
                    .onReceive(deleteViewModel.events) { event in
                        switch event {
                        case let .error(eventError):
                            error = eventError
                        case .deleted:
                            router.dismiss()
                        }
                    }
                    .errorMessage($error)
        }

        // MARK: - Button Builder

        @ViewBuilder
        private func button(for type: ActionButtonType, at index: Int) -> some View {
            switch type {
            case .play:
                playButton(at: index)

            case .played:
                playedButton(at: index)

            case .favorite:
                favoriteButton(at: index)

            case .versions:
                versionsMenu(at: index)

            case .trailers:
                trailersButton(at: index)

            case .subtitles:
                subtitlesButton(at: index)

            case .refresh:
                refreshMenu(at: index)

            case .edit:
                editButton(at: index)

            case .delete:
                deleteButton(at: index)
            }
        }

        // MARK: - Play Button

        @ViewBuilder
        private func playButton(at index: Int) -> some View {
            Button {
                play()
            } label: {
                HStack(spacing: 20) {
                    Image(systemName: "play.fill")

                    if mediaSources.count >= 1, let sourceTitle = viewModel.selectedMediaSource?.displayTitle {
                        VStack(alignment: .leading) {
                            Text(playButtonTitle)
                                .font(.caption)
                                .fontWeight(.semibold)

                            Marquee(
                                sourceTitle,
                                speed: 40,
                                delay: 3,
                                fade: 5,
                                animateWhenFocused: UIDevice.isTV
                            )
                            .font(.caption)
                            .fontWeight(.semibold)
                        }
                    } else {
                        Text(playButtonTitle)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
            }
            .buttonStyle(
                .tintedMaterial(
                    tint: UIDevice.isTV ? .white : accentColor,
                    foregroundColor: UIDevice.isTV ? .black : accentColor.overlayColor
                )
            )
            .isSelected(true)
            .enabled(viewModel.selectedMediaSource != nil)
            .labelStyle(.titleAndIcon)
            #if os(tvOS)
                .focused($focusedButtonIndex, equals: index)
            #endif
        }

        // MARK: - Played Button

        @ViewBuilder
        private func playedButton(at index: Int) -> some View {
            let isPlayed = viewModel.item.userData?.isPlayed == true

            Button {
                viewModel.send(.toggleIsPlayed)
            } label: {
                Label(L10n.played, systemImage: "checkmark")
            }
            .buttonStyle(
                .tintedMaterial(
                    tint: .jellyfinPurple,
                    foregroundColor: UIDevice.isTV ? .primary : .white
                )
            )
            .isSelected(isPlayed)
            .labelStyle(.iconOnly)
            #if os(tvOS)
                .focused($focusedButtonIndex, equals: index)
            #endif
        }

        // MARK: - Favorite Button

        @ViewBuilder
        private func favoriteButton(at index: Int) -> some View {
            let isFavorite = viewModel.item.userData?.isFavorite == true

            Button {
                viewModel.send(.toggleIsFavorite)
            } label: {
                Label(L10n.favorite, systemImage: isFavorite ? "heart.fill" : "heart")
            }
            .buttonStyle(
                .tintedMaterial(
                    tint: UIDevice.isTV ? .pink : .red,
                    foregroundColor: UIDevice.isTV ? .primary : .white
                )
            )
            .isSelected(isFavorite)
            .labelStyle(.iconOnly)
            #if os(tvOS)
                .focused($focusedButtonIndex, equals: index)
            #endif
        }

        // MARK: - Versions Menu

        @ViewBuilder
        private func versionsMenu(at index: Int) -> some View {
            let selected = viewModel.selectedMediaSource

            Menu {
                ForEach(mediaSources, id: \.id) { source in
                    Button {
                        viewModel.send(.selectMediaSource(source))
                    } label: {
                        if source.id == selected?.id {
                            Label(source.displayTitle, systemImage: "checkmark")
                        } else {
                            Text(source.displayTitle)
                        }
                    }
                }
            } label: {
                Label(L10n.version, systemImage: "list.dash")
            }
            .buttonStyle(.material)
            .labelStyle(.iconOnly)
            #if os(tvOS)
                .focused($focusedButtonIndex, equals: index)
            #endif
        }

        // MARK: - Trailers Button

        @ViewBuilder
        private func trailersButton(at index: Int) -> some View {
            let showLocal = enabledTrailers.contains(.local) && localTrailers.isNotEmpty
            let showExternal = enabledTrailers.contains(.external) && externalTrailers.isNotEmpty
            let totalCount = (showLocal ? localTrailers.count : 0) + (showExternal ? externalTrailers.count : 0)

            if totalCount == 1 {
                Button {
                    if showLocal, let trailer = localTrailers.first {
                        playLocalTrailer(trailer)
                    } else if showExternal, let trailer = externalTrailers.first {
                        playExternalTrailer(trailer)
                    }
                } label: {
                    Label(L10n.trailer, systemImage: "movieclapper")
                }
                .buttonStyle(.material)
                .labelStyle(.iconOnly)
                #if os(tvOS)
                    .focused($focusedButtonIndex, equals: index)
                #endif
            } else {
                Menu {
                    if showLocal {
                        Section(L10n.local) {
                            ForEach(localTrailers) { trailer in
                                Button {
                                    playLocalTrailer(trailer)
                                } label: {
                                    Label(trailer.displayTitle, systemImage: "play.fill")
                                }
                            }
                        }
                    }

                    if showExternal {
                        Section(L10n.external) {
                            ForEach(externalTrailers, id: \.self) { trailer in
                                Button {
                                    playExternalTrailer(trailer)
                                } label: {
                                    Label(trailer.name ?? L10n.trailer, systemImage: "arrow.up.forward")
                                }
                            }
                        }
                    }
                } label: {
                    Label(L10n.trailer, systemImage: "movieclapper")
                }
                .buttonStyle(.material)
                .labelStyle(.iconOnly)
                #if os(tvOS)
                    .focused($focusedButtonIndex, equals: index)
                #endif
            }
        }

        // MARK: - Subtitles Button

        @ViewBuilder
        private func subtitlesButton(at index: Int) -> some View {
            Button {
                router.route(to: .searchSubtitle(viewModel: .init(item: viewModel.item)))
            } label: {
                Label(L10n.subtitles, systemImage: "captions.bubble")
            }
            .buttonStyle(.material)
            .labelStyle(.iconOnly)
            #if os(tvOS)
                .focused($focusedButtonIndex, equals: index)
            #endif
        }

        // MARK: - Refresh Menu

        @ViewBuilder
        private func refreshMenu(at index: Int) -> some View {
            Menu {
                Section(L10n.metadata) {
                    Button(L10n.findMissing, systemImage: "magnifyingglass") {
                        handleRefresh(.findMissing)
                    }
                    Button(L10n.replaceMetadata, systemImage: "arrow.clockwise") {
                        handleRefresh(.replaceMetadata)
                    }
                    Button(L10n.replaceImages, systemImage: "photo") {
                        handleRefresh(.replaceImages)
                    }
                    Button(L10n.replaceAll, systemImage: "staroflife") {
                        handleRefresh(.replaceAll)
                    }
                }
            } label: {
                Label(L10n.refreshMetadata, systemImage: "arrow.clockwise")
            }
            .buttonStyle(.material)
            .labelStyle(.iconOnly)
            #if os(tvOS)
                .focused($focusedButtonIndex, equals: index)
            #endif
        }

        // MARK: - Edit Button

        @ViewBuilder
        private func editButton(at index: Int) -> some View {
            Button {
                router.route(to: .itemEditor(viewModel: viewModel))
            } label: {
                Label(L10n.edit, systemImage: "pencil")
            }
            .buttonStyle(.material)
            .labelStyle(.iconOnly)
            #if os(tvOS)
                .focused($focusedButtonIndex, equals: index)
            #endif
        }

        // MARK: - Delete Button

        @ViewBuilder
        private func deleteButton(at index: Int) -> some View {
            Button(role: .destructive) {
                showConfirmationDialog = true
            } label: {
                Label(L10n.delete, systemImage: "trash")
            }
            .buttonStyle(.material)
            .labelStyle(.iconOnly)
            #if os(tvOS)
                .focused($focusedButtonIndex, equals: index)
            #endif
        }

        // MARK: - Overflow Menu

        @ViewBuilder
        private func overflowMenu(availableWidth: CGFloat) -> some View {
            let overflow = overflowIndices(availableWidth: availableWidth)
            let overflowTypes = overflow.compactMap { index -> ActionButtonType? in
                guard index > 0 && index < visibleButtons.count else { return nil }
                return visibleButtons[index]
            }

            if overflowTypes.isEmpty {
                EmptyView()
            } else {
                Menu {
                    ForEach(overflowTypes) { type in
                        overflowMenuItem(for: type)
                    }
                } label: {
                    Label(L10n.options, systemImage: "ellipsis")
                        .rotationEffect(.degrees(90))
                }
                .buttonStyle(.material)
                .labelStyle(.iconOnly)
                #if os(tvOS)
                    .focused($focusedButtonIndex, equals: visibleButtons.count)
                #endif
            }
        }

        // MARK: - Overflow Menu Item

        @ViewBuilder
        private func overflowMenuItem(for type: ActionButtonType) -> some View {
            switch type {
            case .play:
                Button {
                    play()
                } label: {
                    Label(playButtonTitle, systemImage: "play.fill")
                }

            case .played:
                Button {
                    viewModel.send(.toggleIsPlayed)
                } label: {
                    Label(L10n.played, systemImage: "checkmark")
                }

            case .favorite:
                let isFavorite = viewModel.item.userData?.isFavorite == true
                Button {
                    viewModel.send(.toggleIsFavorite)
                } label: {
                    Label(L10n.favorite, systemImage: isFavorite ? "heart.fill" : "heart")
                }

            case .versions:
                let selected = viewModel.selectedMediaSource
                Menu {
                    ForEach(mediaSources, id: \.id) { source in
                        Button {
                            viewModel.send(.selectMediaSource(source))
                        } label: {
                            if source.id == selected?.id {
                                Label(source.displayTitle, systemImage: "checkmark")
                            } else {
                                Text(source.displayTitle)
                            }
                        }
                    }
                } label: {
                    Label(L10n.version, systemImage: "list.dash")
                }

            case .trailers:
                let showLocal = enabledTrailers.contains(.local) && localTrailers.isNotEmpty
                let showExternal = enabledTrailers.contains(.external) && externalTrailers.isNotEmpty
                let totalCount = (showLocal ? localTrailers.count : 0) + (showExternal ? externalTrailers.count : 0)

                if totalCount == 1 {
                    Button {
                        if showLocal, let trailer = localTrailers.first {
                            playLocalTrailer(trailer)
                        } else if showExternal, let trailer = externalTrailers.first {
                            playExternalTrailer(trailer)
                        }
                    } label: {
                        Label(L10n.trailer, systemImage: "movieclapper")
                    }
                } else {
                    Menu {
                        if showLocal {
                            Section(L10n.local) {
                                ForEach(localTrailers) { trailer in
                                    Button {
                                        playLocalTrailer(trailer)
                                    } label: {
                                        Label(trailer.displayTitle, systemImage: "play.fill")
                                    }
                                }
                            }
                        }

                        if showExternal {
                            Section(L10n.external) {
                                ForEach(externalTrailers, id: \.self) { trailer in
                                    Button {
                                        playExternalTrailer(trailer)
                                    } label: {
                                        Label(trailer.name ?? L10n.trailer, systemImage: "arrow.up.forward")
                                    }
                                }
                            }
                        }
                    } label: {
                        Label(L10n.trailer, systemImage: "movieclapper")
                    }
                }

            case .subtitles:
                Button {
                    router.route(to: .searchSubtitle(viewModel: .init(item: viewModel.item)))
                } label: {
                    Label(L10n.subtitles, systemImage: "captions.bubble")
                }

            case .refresh:
                Menu {
                    Section(L10n.metadata) {
                        Button(L10n.findMissing, systemImage: "magnifyingglass") {
                            handleRefresh(.findMissing)
                        }
                        Button(L10n.replaceMetadata, systemImage: "arrow.clockwise") {
                            handleRefresh(.replaceMetadata)
                        }
                        Button(L10n.replaceImages, systemImage: "photo") {
                            handleRefresh(.replaceImages)
                        }
                        Button(L10n.replaceAll, systemImage: "staroflife") {
                            handleRefresh(.replaceAll)
                        }
                    }
                } label: {
                    Label(L10n.refreshMetadata, systemImage: "arrow.clockwise")
                }

            case .edit:
                Button {
                    router.route(to: .itemEditor(viewModel: viewModel))
                } label: {
                    Label(L10n.edit, systemImage: "pencil")
                }

            case .delete:
                Button(role: .destructive) {
                    showConfirmationDialog = true
                } label: {
                    Label(L10n.delete, systemImage: "trash")
                }
            }
        }

        // MARK: - Overflow Calculation

        private func overflowIndices(availableWidth: CGFloat) -> [Int] {
            let secondaryCount = visibleButtons.count - 1
            guard secondaryCount > 0 else { return [] }

            switch layoutMode {
            case .horizontal:
                return calculateHorizontalOverflow(
                    availableWidth: availableWidth,
                    secondaryCount: secondaryCount
                )
            case .vertical:
                return []
            case .inline:
                return calculateInlineOverflow(
                    availableWidth: availableWidth,
                    secondaryCount: secondaryCount
                )
            }
        }

        private func calculateHorizontalOverflow(
            availableWidth: CGFloat,
            secondaryCount: Int
        ) -> [Int] {
            let minButtonWidth = secondaryButtonConstraints.minWidth ?? buttonHeight

            let row2FitsAll = canFitButtons(
                count: secondaryCount,
                availableWidth: availableWidth,
                minButtonWidth: minButtonWidth,
                reserveOverflow: false
            )

            if row2FitsAll {
                return []
            }

            let row2Fitting = calculateRow2Fitting(
                availableWidth: availableWidth,
                minButtonWidth: minButtonWidth,
                count: secondaryCount,
                reserveOverflow: true
            )

            if row2Fitting < secondaryCount {
                return Array((row2Fitting + 1) ... secondaryCount)
            }

            return []
        }

        private func canFitButtons(
            count: Int,
            availableWidth: CGFloat,
            minButtonWidth: CGFloat,
            reserveOverflow: Bool
        ) -> Bool {
            guard count > 0 else { return true }

            let overflowReserved = reserveOverflow ? (overflowButtonWidth + horizontalSpacing) : 0
            let availableForButtons = availableWidth - overflowReserved
            let neededWidth = minButtonWidth * CGFloat(count) +
                horizontalSpacing * CGFloat(max(0, count - 1))

            return neededWidth <= availableForButtons
        }

        private func calculateRow2Fitting(
            availableWidth: CGFloat,
            minButtonWidth: CGFloat,
            count: Int,
            reserveOverflow: Bool
        ) -> Int {
            guard count > 0 else { return 0 }

            let overflowReserved = reserveOverflow ? (overflowButtonWidth + horizontalSpacing) : 0
            let availableForButtons = availableWidth - overflowReserved

            for tryCount in (1 ... count).reversed() {
                let neededWidth = minButtonWidth * CGFloat(tryCount) +
                    horizontalSpacing * CGFloat(max(0, tryCount - 1))

                if neededWidth <= availableForButtons {
                    return tryCount
                }
            }

            return 0
        }

        private func calculateInlineOverflow(
            availableWidth: CGFloat,
            secondaryCount: Int
        ) -> [Int] {
            let primaryMinWidth = primaryButtonConstraints.minWidth ?? 0
            let secondaryTargetWidth = secondaryButtonConstraints.resolve(
                availableWidth: availableWidth,
                fallback: buttonHeight
            )

            let availableForSecondary = availableWidth - primaryMinWidth - horizontalSpacing
            var fittingCount = 0

            for count in (0 ... secondaryCount).reversed() {
                let needsOverflow = count < secondaryCount
                let overflowReserved = needsOverflow ? (overflowButtonWidth + horizontalSpacing) : 0
                let availableForButtons = availableForSecondary - overflowReserved

                if count == 0 {
                    break
                }

                let neededWidth = secondaryTargetWidth * CGFloat(count) +
                    CGFloat(count - 1) * horizontalSpacing

                if neededWidth <= availableForButtons {
                    fittingCount = count
                    break
                }
            }

            if fittingCount < secondaryCount {
                return Array((fittingCount + 1) ... secondaryCount)
            }
            return []
        }

        // MARK: - Play Action

        private func play(fromBeginning: Bool = false) {
            guard let playButtonItem = viewModel.playButtonItem,
                  let selectedMediaSource = viewModel.selectedMediaSource
            else {
                logger.error("Play selected with no item or media source")
                return
            }

            #if os(tvOS)
            let queue: (any MediaPlayerQueue)? = playButtonItem.type == .episode
                ? EpisodeMediaPlayerQueue(episode: playButtonItem)
                : nil

            let provider = MediaPlayerItemProvider(item: playButtonItem) { item in
                try await MediaPlayerItem.build(
                    for: item,
                    mediaSource: selectedMediaSource
                ) {
                    if fromBeginning {
                        $0.userData?.playbackPositionTicks = 0
                    }
                }
            }

            router.route(to: .videoPlayer(provider: provider, queue: queue))
            #else
            router.route(to: .videoPlayer(item: playButtonItem, mediaSource: selectedMediaSource))
            #endif
        }

        // MARK: - Play Local Trailer

        private func playLocalTrailer(_ trailer: BaseItemDto) {
            if let mediaSource = trailer.mediaSources?.first {
                #if os(tvOS)
                let provider = MediaPlayerItemProvider(item: trailer) { item in
                    try await MediaPlayerItem.build(for: item, mediaSource: mediaSource)
                }
                router.route(to: .videoPlayer(provider: provider, queue: nil))
                #else
                router.route(to: .videoPlayer(item: trailer, mediaSource: mediaSource))
                #endif
            } else {
                logger.error("No media sources found for trailer")
                error = ErrorMessage(L10n.unknownError)
            }
        }

        // MARK: - Play External Trailer

        private func playExternalTrailer(_ trailer: MediaURL) {
            guard let urlString = trailer.url,
                  let url = URL(string: urlString),
                  UIApplication.shared.canOpenURL(url)
            else {
                error = ErrorMessage(L10n.unableToOpenTrailer)
                return
            }

            UIApplication.shared.open(url) { success in
                if !success {
                    error = ErrorMessage(L10n.unableToOpenTrailer)
                }
            }
        }

        // MARK: - Handle Refresh

        private func handleRefresh(_ action: RefreshAction) {
            switch action {
            case .findMissing:
                refreshViewModel.refreshMetadata(
                    metadataRefreshMode: .fullRefresh,
                    imageRefreshMode: .fullRefresh,
                    replaceMetadata: false,
                    replaceImages: false
                )
            case .replaceMetadata:
                refreshViewModel.refreshMetadata(
                    metadataRefreshMode: .fullRefresh,
                    imageRefreshMode: .none,
                    replaceMetadata: true,
                    replaceImages: false
                )
            case .replaceImages:
                refreshViewModel.refreshMetadata(
                    metadataRefreshMode: .none,
                    imageRefreshMode: .fullRefresh,
                    replaceMetadata: false,
                    replaceImages: true
                )
            case .replaceAll:
                refreshViewModel.refreshMetadata(
                    metadataRefreshMode: .fullRefresh,
                    imageRefreshMode: .fullRefresh,
                    replaceMetadata: true,
                    replaceImages: true
                )
            }
        }
    }
}
