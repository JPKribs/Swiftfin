//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2025 Jellyfin & Jellyfin Contributors
//

import SwiftUI

// MARK: - ActionButtonType

enum ActionButtonType: String, CaseIterable, Identifiable {

    case play
    case played
    case favorite
    case versions
    case trailers
    case subtitles
    case refresh
    #if os(iOS)
    case edit
    #endif
    case delete

    var id: String { rawValue }

    // MARK: - Display Properties

    var displayTitle: String {
        switch self {
        case .play:
            L10n.play
        case .played:
            L10n.played
        case .favorite:
            L10n.favorite
        case .versions:
            L10n.version
        case .trailers:
            L10n.trailer
        case .subtitles:
            L10n.subtitles
        case .refresh:
            L10n.refreshMetadata
        #if os(iOS)
        case .edit:
            L10n.edit
        #endif
        case .delete:
            L10n.delete
        }
    }

    var systemImage: String {
        switch self {
        case .play:
            "play.fill"
        case .played:
            "checkmark"
        case .favorite:
            "heart"
        case .versions:
            "list.dash"
        case .trailers:
            "movieclapper"
        case .subtitles:
            "captions.bubble"
        case .refresh:
            "arrow.clockwise"
        #if os(iOS)
        case .edit:
            "pencil"
        #endif
        case .delete:
            "trash"
        }
    }

    func systemImage(isSelected: Bool) -> String {
        switch self {
        case .favorite:
            isSelected ? "heart.fill" : "heart"
        default:
            systemImage
        }
    }

    // MARK: - Styling

    var tint: Color {
        switch self {
        case .play:
            UIDevice.isTV ? .white : .accentColor
        case .played:
            .jellyfinPurple
        case .favorite:
            UIDevice.isTV ? .pink : .red
        case .versions, .trailers, .subtitles, .refresh, .delete:
            .secondary
        #if os(iOS)
        case .edit:
            .secondary
        #endif
        }
    }

    var foregroundColor: Color {
        switch self {
        case .play:
            UIDevice.isTV ? .black : .accentColor.overlayColor
        case .played, .favorite:
            UIDevice.isTV ? .primary : .white
        case .versions, .trailers, .subtitles, .refresh, .delete:
            .primary
        #if os(iOS)
        case .edit:
            .primary
        #endif
        }
    }

    var isMenu: Bool {
        switch self {
        case .versions, .refresh:
            true
        case .trailers:
            true
        default:
            false
        }
    }

    var showTitle: Bool {
        switch self {
        case .play:
            true
        default:
            false
        }
    }

    // MARK: - Availability

    func isAvailable(in context: ActionButtonContext) -> Bool {
        switch self {
        case .play:
            context.item.presentPlayButton
        case .played:
            context.item.canBePlayed
        case .favorite:
            true
        case .versions:
            context.hasMultipleVersions
        case .trailers:
            context.hasTrailers
        case .subtitles:
            context.canManageSubtitles
        case .refresh:
            context.canRefresh
        #if os(iOS)
        case .edit:
            context.canEdit
        #endif
        case .delete:
            context.canDelete
        }
    }

    // MARK: - Selection State

    func isSelected(in context: ActionButtonContext) -> Bool {
        switch self {
        case .play:
            true
        case .played:
            context.isPlayed
        case .favorite:
            context.isFavorite
        default:
            false
        }
    }

    // MARK: - Actions

    func primaryAction(in context: ActionButtonContext) -> ActionButtonAction? {
        switch self {
        case .play:
            return ActionButtonAction.play()
        case .played:
            return ActionButtonAction.togglePlayed
        case .favorite:
            return ActionButtonAction.toggleFavorite
        case .subtitles:
            return ActionButtonAction.searchSubtitles
        #if os(iOS)
        case .edit:
            return ActionButtonAction.edit
        #endif
        case .delete:
            return ActionButtonAction.delete
        case .versions, .refresh:
            return nil
        case .trailers:
            if context.trailerCount == 1 {
                if context.showLocalTrailers, let trailer = context.localTrailers.first {
                    return ActionButtonAction.playLocalTrailer(trailer)
                } else if context.showExternalTrailers, let trailer = context.externalTrailers.first {
                    return ActionButtonAction.playExternalTrailer(trailer)
                }
            }
            return nil
        }
    }

    // MARK: - Menu Content

    @ViewBuilder
    func menuContent(
        in context: ActionButtonContext,
        onAction: @escaping (ActionButtonAction) -> Void
    ) -> some View {
        switch self {
        case .versions:
            versionsMenuContent(in: context, onAction: onAction)
        case .trailers:
            trailersMenuContent(in: context, onAction: onAction)
        case .refresh:
            refreshMenuContent(onAction: onAction)
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private func versionsMenuContent(
        in context: ActionButtonContext,
        onAction: @escaping (ActionButtonAction) -> Void
    ) -> some View {
        ForEach(context.mediaSources, id: \.id) { source in
            Button {
                onAction(.selectMediaSource(source))
            } label: {
                if source.id == context.selectedMediaSource?.id {
                    Label(source.displayTitle, systemImage: "checkmark")
                } else {
                    Text(source.displayTitle)
                }
            }
        }
    }

    @ViewBuilder
    private func trailersMenuContent(
        in context: ActionButtonContext,
        onAction: @escaping (ActionButtonAction) -> Void
    ) -> some View {
        if context.showLocalTrailers {
            Section(L10n.local) {
                ForEach(context.localTrailers) { trailer in
                    Button {
                        onAction(.playLocalTrailer(trailer))
                    } label: {
                        Label(trailer.displayTitle, systemImage: "play.fill")
                    }
                }
            }
        }

        if context.showExternalTrailers {
            Section(L10n.external) {
                ForEach(context.externalTrailers, id: \.self) { trailer in
                    Button {
                        onAction(.playExternalTrailer(trailer))
                    } label: {
                        Label(trailer.name ?? L10n.trailer, systemImage: "arrow.up.forward")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func refreshMenuContent(
        onAction: @escaping (ActionButtonAction) -> Void
    ) -> some View {
        Section(L10n.metadata) {
            Button(L10n.findMissing, systemImage: "magnifyingglass") {
                onAction(.refresh(.findMissing))
            }
            Button(L10n.replaceMetadata, systemImage: "arrow.clockwise") {
                onAction(.refresh(.replaceMetadata))
            }
            Button(L10n.replaceImages, systemImage: "photo") {
                onAction(.refresh(.replaceImages))
            }
            Button(L10n.replaceAll, systemImage: "staroflife") {
                onAction(.refresh(.replaceAll))
            }
        }
    }
}
