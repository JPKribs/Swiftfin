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

    struct FavoriteButton: View {

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

        // MARK: - Generic Favorite Button

        @ViewBuilder
        private var itemButton: some View {
            let isSelected: Bool = viewModel.item.userData?.isFavorite == true

            Button(L10n.favorite, systemImage: isSelected ? "heart.fill" : "heart") {
                viewModel.send(.toggleIsFavorite)
            }
            .isSelected(isSelected)
        }

        @ViewBuilder
        private func itemMenu(seriesViewModel: SeriesItemViewModel) -> some View {

            let isSelected: Bool = viewModel.playButtonItem?.userData?.isFavorite == true

            Menu(L10n.favorite, systemImage: isSelected ? "heart.fill" : "heart") {

                // MARK: - Toggle Episode

                Button(
                    L10n.episode,
                    systemImage: isSelected ? "heart.fill" : "heart"
                ) {
                    Task {
                        try await viewModel.playButtonItem?.toggleIsFavorite()
                    }
                }

                // MARK: - Toggle Full Season

                Button(
                    L10n.season,
                    systemImage: seriesViewModel.seasons.first(where: { $0.id == seriesViewModel.playButtonItem?.seasonID })?.season
                        .userData?
                        .isFavorite == true ? "heart.fill" : "heart"
                ) {
                    Task {
                        try await seriesViewModel.seasons.first(
                            where: {
                                $0.id == seriesViewModel.playButtonItem?.seasonID
                            }
                        )?.season.toggleIsFavorite()
                    }
                }

                // MARK: - Toggle Full Series

                Button(
                    L10n.series,
                    systemImage: viewModel.item.userData?
                        .isFavorite == true ? "heart.fill" : "heart"
                ) {
                    Task {
                        try await viewModel.item.toggleIsFavorite()
                    }
                }
            }
            .isSelected(isSelected)
        }
    }
}
