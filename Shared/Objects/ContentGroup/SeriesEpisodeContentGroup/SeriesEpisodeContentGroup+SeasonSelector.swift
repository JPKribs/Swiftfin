//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import JellyfinAPI
import SwiftUI

extension SeriesEpisodeContentGroup {

    struct SeasonSelector: PlatformView {

        let seasons: [PagingLibraryViewModel<EpisodeLibrary>]

        @Binding
        var selection: PagingLibraryViewModel<EpisodeLibrary>.ID?

        let preferredSelection: PagingLibraryViewModel<EpisodeLibrary>.ID?

        @FocusState
        private var focusedSeason: PagingLibraryViewModel<EpisodeLibrary>.ID?
        @FocusState
        private var isPickerFocused: Bool

        @Router
        private var router

        private var selectedSeason: PagingLibraryViewModel<EpisodeLibrary>? {
            seasons.first { $0.id == selection }
        }

        var tvOSView: some View {
            if seasons.isEmpty {
                Text(L10n.episodes)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .edgePadding(.horizontal)
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: 20) {
                        ForEach(seasons) { season in
                            let isSelected = selection == season.id

                            Menu(season.library.parent.displayTitle) {
                                Button(L10n.openLibrary, systemImage: "square.grid.2x2.fill") {
                                    router.route(to: .library(library: season.library))
                                }
                            }
                            .menuStyle(.button)
                            .buttonStyle(SeasonButtonStyle(isPickerFocused: isPickerFocused))
                            .isSelected(isSelected)
                            .focused($focusedSeason, equals: season.id)
                            .accessibilityAddTraits(isSelected ? .isSelected : [])
                        }
                    }
                    .edgePadding(.horizontal)
                }
                .scrollIndicators(.hidden)
                .scrollClipDisabled()
                .focusSection()
                .focused($isPickerFocused)
                .defaultFocus(
                    $focusedSeason,
                    preferredSelection,
                    priority: .userInitiated
                )
                .task(id: focusedSeason) {
                    await selectSeasonAfterFocusDebounce(focusedSeason)
                }
            }
        }

        @MainActor
        private func selectSeasonAfterFocusDebounce(
            _ seasonID: PagingLibraryViewModel<EpisodeLibrary>.ID?
        ) async {
            guard let seasonID, seasonID != selection else { return }

            do {
                try await Task.sleep(for: .milliseconds(350))
            } catch {
                return
            }

            guard seasonID == focusedSeason,
                  seasonID != selection,
                  seasons.contains(where: { $0.id == seasonID })
            else { return }

            selection = seasonID
        }

        private struct SeasonButtonStyle: ButtonStyle {

            @Environment(\.isFocused)
            private var isFocused
            @Environment(\.isSelected)
            private var isSelected

            let isPickerFocused: Bool

            private var isHighlighted: Bool {
                isFocused || (!isPickerFocused && isSelected)
            }

            private var glass: BackportGlass {
                isHighlighted ? .regular.selection(
                    tint: .white,
                    foregroundColor: .black
                ) : .identity
            }

            func makeBody(configuration: Configuration) -> some View {
                configuration.label
                    .font(.callout)
                    .fontWeight(.semibold)
                    .padding(CapsuleLabelStyle.defaultInsets)
                    .backport
                    .glassEffect(glass, in: .capsule)
            }
        }

        var iOSView: some View {
            if seasons.count <= 1 {
                if let selectedSeason {
                    LibraryHeaderButton(library: selectedSeason.library)
                } else {
                    Text(L10n.episodes)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .edgePadding(.horizontal)
                }
            } else {
                Menu(
                    selectedSeason?.library.parent.displayTitle ?? L10n.episodes,
                    systemImage: "chevron.down"
                ) {
                    if let selectedSeason {
                        Button(L10n.openLibrary, systemImage: "square.grid.2x2.fill") {
                            router.route(to: .library(library: selectedSeason.library))
                        }

                        Divider()
                    }

                    Picker(L10n.seasons, selection: $selection) {
                        ForEach(seasons) { season in
                            Text(season.library.parent.displayTitle)
                                .tag(season.id)
                        }
                    }
                }
                .labelStyle(
                    CapsuleLabelStyle(
                        isIconTrailing: true
                    )
                )
                .font(.headline)
                .edgePadding(.horizontal)
            }
        }
    }
}
