//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2025 Jellyfin & Jellyfin Contributors
//

import JellyfinAPI
import SwiftUI

extension ItemView {

    struct PlayedButton: View {

        @ObservedObject
        var viewModel: ItemViewModel

        // MARK: - Body

        var body: some View {
            if let seriesViewModel = viewModel as? SeriesItemViewModel {
                itemMenu(seriesViewModel: seriesViewModel)
            } else {
                itemButton
            }
        }

        // MARK: - Generic Played Button

        @ViewBuilder
        private var itemButton: some View {
            Button(L10n.played, systemImage: "checkmark") {
                viewModel.send(.toggleIsPlayed)
            }
            .isSelected(viewModel.item.userData?.isPlayed == true)
        }

        @ViewBuilder
        private func itemMenu(seriesViewModel: SeriesItemViewModel) -> some View {

            let isSelected: Bool = viewModel.playButtonItem?.userData?.isPlayed == true

            Menu(L10n.played, systemImage: "checkmark") {

                // MARK: - Toggle Episode

                Button(
                    L10n.episode,
                    systemImage: isSelected ? "checkmark.circle.fill" : "checkmark.circle"
                ) {
                    Task {
                        try await viewModel.playButtonItem?.toggleIsPlayed()
                    }
                }

                // MARK: - Toggle Full Season

                Button(
                    L10n.season,
                    systemImage: seriesViewModel.seasons.first(where: { $0.id == seriesViewModel.playButtonItem?.seasonID })?.season
                        .userData?
                        .isPlayed == true ? "checkmark.circle.fill" : "checkmark.circle"
                ) {
                    Task {
                        try await seriesViewModel.seasons.first(
                            where: {
                                $0.id == seriesViewModel.playButtonItem?.seasonID
                            }
                        )?.season.toggleIsPlayed()
                    }
                }

                // MARK: - Toggle Full Series

                Button(
                    L10n.series,
                    systemImage: viewModel.item.userData?
                        .isPlayed == true ? "checkmark.circle.fill" : "checkmark.circle"
                ) {
                    Task {
                        try await viewModel.item.toggleIsPlayed()
                    }
                }
            }
            .isSelected(isSelected)
        }
    }
}
