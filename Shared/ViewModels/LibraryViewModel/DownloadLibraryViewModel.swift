//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2025 Jellyfin & Jellyfin Contributors
//

import Combine
import Defaults
import Factory
import JellyfinAPI
import OrderedCollections
import SwiftUI

final class DownloadLibraryViewModel: PagingLibraryViewModel<DownloadItemDto> {

    @Injected(\.downloadManager)
    private var downloadManager

    // MARK: init

    init() {
        super.init(
            parent: TitledLibraryParent(displayTitle: L10n.downloads, id: "downloads"),
            filters: .init()
        )
    }

    // MARK: get

    override func get(page: Int) async throws -> [DownloadItemDto] {
        let allDownloads = await MainActor.run {
            downloadManager.downloads
        }

        let filteredItems = filterItems(allDownloads)
        let sortedItems = sortItems(filteredItems)

        let startIndex = page * pageSize
        let endIndex = min(startIndex + pageSize, sortedItems.count)

        guard startIndex < sortedItems.count else { return [] }

        return Array(sortedItems[startIndex ..< endIndex])
    }

    // MARK: filterItems

    private func filterItems(_ items: [DownloadItemDto]) -> [DownloadItemDto] {
        guard let filterViewModel else { return items }

        let filters = filterViewModel.currentFilters
        var filtered = items

        // Filter by item types
        if filters.itemTypes.isNotEmpty {
            filtered = filtered.filter { item in
                guard let type = item.baseItem.type else { return false }
                return filters.itemTypes.contains(type)
            }
        }

        return filtered
    }

    // MARK: sortItems

    private func sortItems(_ items: [DownloadItemDto]) -> [DownloadItemDto] {
        guard let filterViewModel else {
            return items.sorted { ($0.name ?? "") < ($1.name ?? "") }
        }

        let filters = filterViewModel.currentFilters
        let sortBy = filters.sortBy.first ?? .dateCreated
        let sortOrder = filters.sortOrder.first ?? .descending

        let sorted: [DownloadItemDto]

        switch sortBy {
        case .name:
            sorted = items.sorted { ($0.name ?? "") < ($1.name ?? "") }
        case .dateCreated:
            sorted = items.sorted { $0.downloadedDate < $1.downloadedDate }
        case .premiereDate:
            sorted = items.sorted {
                ($0.baseItem.premiereDate ?? Date.distantPast) < ($1.baseItem.premiereDate ?? Date.distantPast)
            }
        case .runtime:
            sorted = items.sorted {
                ($0.baseItem.runTimeTicks ?? 0) < ($1.baseItem.runTimeTicks ?? 0)
            }
        default:
            sorted = items.sorted { ($0.name ?? "") < ($1.name ?? "") }
        }

        return sortOrder == .ascending ? sorted : sorted.reversed()
    }

    // MARK: getRandomItem

    override func getRandomItem() async -> DownloadItemDto? {
        await MainActor.run {
            downloadManager.downloads.randomElement()
        }
    }
}
