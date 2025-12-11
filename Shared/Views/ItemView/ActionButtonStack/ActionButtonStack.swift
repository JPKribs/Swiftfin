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

    // MARK: - Layout Mode

    enum ActionButtonLayoutMode {
        case vertical
        case horizontal
    }

    // MARK: - Action Button Stack

    struct ActionButtonStack: View {

        // MARK: - Properties

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

        private let layoutMode: ActionButtonLayoutMode
        private let buttonHeight: CGFloat
        private let horizontalSpacing: CGFloat
        private let verticalSpacing: CGFloat
        private let primaryButtonWidth: CGFloat?
        private let buttonOrder: [ActionButtonType]

        private let logger = Logger.swiftfin()

        // MARK: - Initializer

        init(
            viewModel: ItemViewModel,
            layoutMode: ActionButtonLayoutMode = .vertical,
            buttonHeight: CGFloat = UIDevice.isTV ? 100 : 50,
            horizontalSpacing: CGFloat = UIDevice.isTV ? 30 : 10,
            verticalSpacing: CGFloat = UIDevice.isTV ? 25 : 10,
            primaryButtonWidth: CGFloat? = nil,
            buttonOrder: [ActionButtonType] = ActionButtonType.allCases
        ) {
            self.viewModel = viewModel
            self._deleteViewModel = StateObject(wrappedValue: .init(item: viewModel.item))
            self._refreshViewModel = StateObject(wrappedValue: .init(item: viewModel.item))
            self.layoutMode = layoutMode
            self.buttonHeight = buttonHeight
            self.horizontalSpacing = horizontalSpacing
            self.verticalSpacing = verticalSpacing
            self.primaryButtonWidth = primaryButtonWidth
            self.buttonOrder = buttonOrder
        }

        // MARK: - Context

        private var context: ActionButtonContext {
            ActionButtonContext(
                item: viewModel.item,
                mediaSources: viewModel.playButtonItem?.mediaSources ?? [],
                selectedMediaSource: viewModel.selectedMediaSource,
                localTrailers: viewModel.localTrailers,
                externalTrailers: viewModel.item.remoteTrailers ?? [],
                enabledTrailerTypes: enabledTrailers,
                canDelete: viewModel.userSession.user.permissions.items.canDelete(item: viewModel.item),
                canEdit: viewModel.userSession.user.permissions.items.canEditMetadata(item: viewModel.item),
                canRefresh: viewModel.userSession.user.permissions.items.canEditMetadata(item: viewModel.item),
                canManageSubtitles: viewModel.userSession.user.permissions.items.canManageSubtitles(item: viewModel.item),
                isPlayed: viewModel.item.userData?.isPlayed == true,
                isFavorite: viewModel.item.userData?.isFavorite == true
            )
        }

        // MARK: - Visible Buttons

        private var visibleButtons: [ActionButtonType] {
            buttonOrder.filter { $0.isAvailable(in: context) }
        }

        private var hasPlayButton: Bool {
            ActionButtonType.play.isAvailable(in: context)
        }

        private var primaryButton: ActionButtonType? {
            hasPlayButton ? .play : visibleButtons.first
        }

        private var secondaryButtons: [ActionButtonType] {
            visibleButtons.filter { $0 != primaryButton }
        }

        // MARK: - Play Button Title

        private var playButtonTitle: String {
            if let seriesViewModel = viewModel as? SeriesItemViewModel,
               let seasonEpisodeLabel = seriesViewModel.playButtonItem?.seasonEpisodeLabel
            {
                return seasonEpisodeLabel
            }
            return viewModel.playButtonItem?.playButtonLabel ?? L10n.play
        }

        // MARK: - Body

        var body: some View {
            Group {
                switch layoutMode {
                case .vertical:
                    verticalLayout
                case .horizontal:
                    horizontalLayout
                }
            }
            .frame(height: calculateHeight())
            .background {
                GeometryReader { geometry in
                    Color.clear
                        .onAppear { availableWidth = geometry.size.width }
                        .onChange(of: geometry.size.width) { newWidth in
                            availableWidth = newWidth
                        }
                }
            }
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

        private func calculateHeight() -> CGFloat {
            switch layoutMode {
            case .horizontal:
                buttonHeight
            case .vertical:
                hasPlayButton ? buttonHeight * 2 + verticalSpacing : buttonHeight
            }
        }

        // MARK: - Vertical Layout

        @ViewBuilder
        private var verticalLayout: some View {
            if hasPlayButton {
                verticalLayoutWithPlayButton
            } else {
                verticalLayoutWithoutPlayButton
            }
        }

        @ViewBuilder
        private var verticalLayoutWithPlayButton: some View {
            let (visible, overflow) = calculateOverflow(from: secondaryButtons, for: availableWidth)
            let promoted = calculatePromotedButtons(visible: visible, overflow: overflow, for: availableWidth)

            let bottomButtons = visible.filter { !promoted.contains($0) }
            let bottomRowCount = bottomButtons.count + (overflow.isEmpty ? 0 : 1)

            let secondaryButtonWidth: CGFloat = bottomRowCount > 0
                ? (availableWidth - CGFloat(bottomRowCount - 1) * horizontalSpacing) / CGFloat(bottomRowCount)
                : buttonHeight

            VStack(spacing: verticalSpacing) {
                HStack(spacing: horizontalSpacing) {
                    playButtonView
                        .frame(height: buttonHeight)
                        .frame(maxWidth: .infinity)

                    ForEach(promoted) { type in
                        buttonView(for: type)
                            .frame(width: secondaryButtonWidth, height: buttonHeight)
                    }
                }

                if bottomRowCount > 0 {
                    HStack(spacing: horizontalSpacing) {
                        ForEach(bottomButtons) { type in
                            buttonView(for: type)
                                .frame(width: secondaryButtonWidth, height: buttonHeight)
                        }

                        if !overflow.isEmpty {
                            overflowMenu(types: overflow)
                                .frame(width: secondaryButtonWidth, height: buttonHeight)
                        }
                    }
                }
            }
        }

        @ViewBuilder
        private var verticalLayoutWithoutPlayButton: some View {
            let (visible, overflow) = calculateOverflow(from: visibleButtons, for: availableWidth)

            HStack(spacing: horizontalSpacing) {
                ForEach(visible) { type in
                    buttonView(for: type)
                        .frame(minWidth: buttonHeight, maxHeight: buttonHeight)
                        .frame(maxWidth: .infinity)
                }

                if !overflow.isEmpty {
                    overflowMenu(types: overflow)
                        .frame(minWidth: buttonHeight, maxHeight: buttonHeight)
                        .frame(maxWidth: .infinity)
                }
            }
        }

        // MARK: - Horizontal Layout

        @ViewBuilder
        private var horizontalLayout: some View {
            if hasPlayButton {
                horizontalLayoutWithPlayButton
            } else {
                horizontalLayoutWithoutPlayButton
            }
        }

        @ViewBuilder
        private var horizontalLayoutWithPlayButton: some View {
            let (visible, overflow) = calculateOverflow(from: secondaryButtons, for: availableWidth)

            HStack(spacing: horizontalSpacing) {
                playButtonView
                    .frame(width: primaryButtonWidth, height: buttonHeight)

                Spacer()

                ForEach(visible) { type in
                    buttonView(for: type)
                        .frame(width: buttonHeight, height: buttonHeight)
                }

                if !overflow.isEmpty {
                    overflowMenu(types: overflow)
                        .frame(width: buttonHeight, height: buttonHeight)
                }
            }
        }

        @ViewBuilder
        private var horizontalLayoutWithoutPlayButton: some View {
            let remainingButtons = Array(secondaryButtons)
            let (visible, overflow) = calculateOverflow(from: remainingButtons, for: availableWidth)

            HStack(spacing: horizontalSpacing) {
                if let promoted = primaryButton {
                    promotedButtonView(for: promoted)
                        .frame(width: primaryButtonWidth, height: buttonHeight)
                }

                Spacer()

                ForEach(visible) { type in
                    buttonView(for: type)
                        .frame(width: buttonHeight, height: buttonHeight)
                }

                if !overflow.isEmpty {
                    overflowMenu(types: overflow)
                        .frame(width: buttonHeight, height: buttonHeight)
                }
            }
        }

        // MARK: - Overflow Calculation

        private func calculateOverflow(
            from buttons: [ActionButtonType],
            for width: CGFloat
        ) -> (visible: [ActionButtonType], overflow: [ActionButtonType]) {
            guard !buttons.isEmpty else { return ([], []) }

            let availableForSecondary: CGFloat
            switch layoutMode {
            case .vertical:
                availableForSecondary = width
            case .horizontal:
                if hasPlayButton {
                    let playWidth = primaryButtonWidth ?? (width * 0.4)
                    availableForSecondary = width - playWidth - horizontalSpacing
                } else {
                    availableForSecondary = width
                }
            }

            var visibleCount = 0
            for count in (1 ... buttons.count).reversed() {
                let needsOverflow = count < buttons.count
                let overflowWidth = needsOverflow ? (buttonHeight + horizontalSpacing) : 0
                let buttonsWidth = buttonHeight * CGFloat(count) + horizontalSpacing * CGFloat(count - 1)

                if buttonsWidth + overflowWidth <= availableForSecondary {
                    visibleCount = count
                    break
                }
            }

            let visible = Array(buttons.prefix(visibleCount))
            let overflow = Array(buttons.dropFirst(visibleCount))
            return (visible, overflow)
        }

        private func calculatePromotedButtons(
            visible: [ActionButtonType],
            overflow: [ActionButtonType],
            for width: CGFloat
        ) -> [ActionButtonType] {
            guard !overflow.isEmpty else { return [] }

            let minPlayButtonRatio: CGFloat = 2.0 / 3.0
            let availableForPromoted = width * (1 - minPlayButtonRatio) - horizontalSpacing
            let maxPromotedCount = min(2, Int(availableForPromoted / (buttonHeight + horizontalSpacing)))

            guard maxPromotedCount > 0 else { return [] }

            var promoted: [ActionButtonType] = []

            if visible.contains(.versions) && promoted.count < maxPromotedCount {
                promoted.append(.versions)
            }
            if visible.contains(.trailers) && promoted.count < maxPromotedCount {
                promoted.append(.trailers)
            }

            return promoted
        }

        // MARK: - Button Views

        @ViewBuilder
        private var playButtonView: some View {
            let ctx = context
            Button {
                handleAction(.play())
            } label: {
                HStack(spacing: UIDevice.isPhone ? 10 : 20) {
                    Image(systemName: "play.fill")

                    if ctx.hasMultipleVersions, let sourceTitle = viewModel.selectedMediaSource?.displayTitle {
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
                .padding(.horizontal, UIDevice.isPhone ? 10 : 20)
            }
            .buttonStyle(
                .tintedMaterial(
                    tint: UIDevice.isTV ? .white : accentColor,
                    foregroundColor: UIDevice.isTV ? .black : accentColor.overlayColor
                )
            )
            .isSelected(true)
            .enabled(viewModel.selectedMediaSource != nil)
        }

        @ViewBuilder
        private func promotedButtonView(for type: ActionButtonType) -> some View {
            let ctx = context
            let isSelected = type.isSelected(in: ctx)

            if type.isMenu && !(type == .trailers && ctx.trailerCount == 1) {
                if type.showTitle {
                    Menu {
                        type.menuContent(in: ctx, onAction: handleAction)
                    } label: {
                        Label(type.displayTitle, systemImage: type.systemImage(isSelected: isSelected))
                    }
                    .buttonStyle(
                        .tintedMaterial(
                            tint: type.tint,
                            foregroundColor: type.foregroundColor
                        )
                    )
                    .isSelected(isSelected)
                    .labelStyle(.titleAndIcon)
                } else {
                    Menu {
                        type.menuContent(in: ctx, onAction: handleAction)
                    } label: {
                        Label(type.displayTitle, systemImage: type.systemImage(isSelected: isSelected))
                    }
                    .buttonStyle(
                        .tintedMaterial(
                            tint: type.tint,
                            foregroundColor: type.foregroundColor
                        )
                    )
                    .isSelected(isSelected)
                    .labelStyle(.iconOnly)
                }
            } else {
                if type.showTitle {
                    Button {
                        if let action = type.primaryAction(in: ctx) {
                            handleAction(action)
                        }
                    } label: {
                        Label(type.displayTitle, systemImage: type.systemImage(isSelected: isSelected))
                    }
                    .buttonStyle(
                        .tintedMaterial(
                            tint: type.tint,
                            foregroundColor: type.foregroundColor
                        )
                    )
                    .isSelected(isSelected)
                    .labelStyle(.titleAndIcon)
                } else {
                    Button {
                        if let action = type.primaryAction(in: ctx) {
                            handleAction(action)
                        }
                    } label: {
                        Label(type.displayTitle, systemImage: type.systemImage(isSelected: isSelected))
                    }
                    .buttonStyle(
                        .tintedMaterial(
                            tint: type.tint,
                            foregroundColor: type.foregroundColor
                        )
                    )
                    .isSelected(isSelected)
                    .labelStyle(.iconOnly)
                }
            }
        }

        @ViewBuilder
        private func buttonView(for type: ActionButtonType) -> some View {
            let ctx = context
            let isSelected = type.isSelected(in: ctx)

            if type.isMenu {
                menuButtonView(for: type, isSelected: isSelected)
            } else {
                standardButtonView(for: type, isSelected: isSelected)
            }
        }

        @ViewBuilder
        private func standardButtonView(for type: ActionButtonType, isSelected: Bool) -> some View {
            Button {
                if let action = type.primaryAction(in: context) {
                    handleAction(action)
                }
            } label: {
                Label(type.displayTitle, systemImage: type.systemImage(isSelected: isSelected))
            }
            .buttonStyle(
                .tintedMaterial(
                    tint: type.tint,
                    foregroundColor: type.foregroundColor
                )
            )
            .isSelected(isSelected)
            .labelStyle(.iconOnly)
        }

        @ViewBuilder
        private func menuButtonView(for type: ActionButtonType, isSelected: Bool) -> some View {
            let ctx = context

            if type == .trailers && ctx.trailerCount == 1 {
                standardButtonView(for: type, isSelected: isSelected)
            } else {
                Menu {
                    type.menuContent(in: ctx, onAction: handleAction)
                } label: {
                    Label(type.displayTitle, systemImage: type.systemImage(isSelected: isSelected))
                }
                .buttonStyle(.material)
                .labelStyle(.iconOnly)
            }
        }

        // MARK: - Overflow Menu

        @ViewBuilder
        private func overflowMenu(types: [ActionButtonType]) -> some View {
            let ctx = context

            Menu {
                ForEach(types) { type in
                    overflowMenuItem(for: type, in: ctx)
                }
            } label: {
                Label(L10n.options, systemImage: "ellipsis")
            }
            .buttonStyle(.material)
            .labelStyle(.iconOnly)
        }

        @ViewBuilder
        private func overflowMenuItem(for type: ActionButtonType, in ctx: ActionButtonContext) -> some View {
            let isSelected = type.isSelected(in: ctx)

            if type.isMenu && !(type == .trailers && ctx.trailerCount == 1) {
                Menu {
                    type.menuContent(in: ctx, onAction: handleAction)
                } label: {
                    Label(type.displayTitle, systemImage: type.systemImage(isSelected: isSelected))
                }
            } else {
                Button {
                    if let action = type.primaryAction(in: ctx) {
                        handleAction(action)
                    }
                } label: {
                    Label(type.displayTitle, systemImage: type.systemImage(isSelected: isSelected))
                }
            }
        }

        // MARK: - Action Handler

        private func handleAction(_ action: ActionButtonAction) {
            switch action {
            case let .play(fromBeginning):
                play(fromBeginning: fromBeginning)
            case .togglePlayed:
                viewModel.send(.toggleIsPlayed)
            case .toggleFavorite:
                viewModel.send(.toggleIsFavorite)
            case let .selectMediaSource(source):
                viewModel.send(.selectMediaSource(source))
            case let .playLocalTrailer(trailer):
                playLocalTrailer(trailer)
            case let .playExternalTrailer(trailer):
                playExternalTrailer(trailer)
            case .searchSubtitles:
                router.route(to: .searchSubtitle(viewModel: .init(item: viewModel.item)))
            case let .refresh(refreshAction):
                handleRefresh(refreshAction)
            #if os(iOS)
            case .edit:
                router.route(to: .itemEditor(viewModel: viewModel))
            #endif
            case .delete:
                showConfirmationDialog = true
            }
        }

        // MARK: - Play Actions

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

        // MARK: - Refresh Handler

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

// MARK: - ButtonContext

struct ActionButtonContext {
    let item: BaseItemDto
    let mediaSources: [MediaSourceInfo]
    let selectedMediaSource: MediaSourceInfo?
    let localTrailers: [BaseItemDto]
    let externalTrailers: [MediaURL]
    let enabledTrailerTypes: TrailerSelection
    let canDelete: Bool
    let canEdit: Bool
    let canRefresh: Bool
    let canManageSubtitles: Bool
    let isPlayed: Bool
    let isFavorite: Bool

    var hasMultipleVersions: Bool {
        mediaSources.count > 1
    }

    var hasTrailers: Bool {
        let hasLocal = enabledTrailerTypes.contains(.local) && localTrailers.isNotEmpty
        let hasExternal = enabledTrailerTypes.contains(.external) && externalTrailers.isNotEmpty
        return hasLocal || hasExternal
    }

    var trailerCount: Int {
        let localCount = enabledTrailerTypes.contains(.local) ? localTrailers.count : 0
        let externalCount = enabledTrailerTypes.contains(.external) ? externalTrailers.count : 0
        return localCount + externalCount
    }

    var showLocalTrailers: Bool {
        enabledTrailerTypes.contains(.local) && localTrailers.isNotEmpty
    }

    var showExternalTrailers: Bool {
        enabledTrailerTypes.contains(.external) && externalTrailers.isNotEmpty
    }
}
