//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Combine
import Foundation
import JellyfinAPI
import OrderedCollections

@MainActor
@Stateful
final class PluginsViewModel: ViewModel {

    @CasePathable
    enum Action {
        case refresh
        case addRepository(repository: RepositoryInfo)
        case removeRepository(repository: RepositoryInfo)

        var transition: Transition {
            switch self {
            case .refresh:
                .to(.refreshing, then: .initial)
            case .addRepository, .removeRepository:
                .background(.updating)
            }
        }
    }

    enum BackgroundState {
        case updating
    }

    struct Environment: Hashable {
        var category: PluginCategory?
        var isInstalled: Bool? = true
    }

    enum State {
        case initial
        case error
        case refreshing
    }

    @Published
    var environment = Environment()
    @Published
    private var allPlugins: OrderedDictionary<String, PluginDetailsViewModel> = [:]
    @Published
    private(set) var repositories: [RepositoryInfo] = []

    var plugins: [PluginDetailsViewModel] {
        allPlugins.values.filter { viewModel in
            (environment.isInstalled == nil || viewModel.plugin.isInstalled == environment.isInstalled) &&
                (environment.category == nil || viewModel.package?.pluginCategory == environment.category)
        }
    }

    var categories: [PluginCategory] {
        let categories = Set(allPlugins.values.compactMap(\.package?.pluginCategory))
        return PluginCategory.allCases.filter(categories.contains)
    }

    @Function(\Action.Cases.refresh)
    private func _refresh() async throws {
        async let installedResponse = send(Paths.getPlugins)
        async let packagesResponse = send(Paths.getPackages)
        async let repositoriesResponse = send(Paths.getRepositories)

        let packages = try await Dictionary(
            packagesResponse.value.compactMap { package in
                package.id.map { ($0, package) }
            },
            uniquingKeysWith: { first, _ in first }
        )

        let installed = try await Dictionary(
            installedResponse.value.compactMap { plugin in
                plugin.id.map { ($0.uppercased(), plugin) }
            },
            uniquingKeysWith: { first, second in
                first.isInstalled ? first : second
            }
        )

        let available = packages
            .filter { installed[$0.key] == nil }
            .map { PluginInfo(package: $0.value) }

        let incomingPlugins = (Array(installed.values) + available).sorted {
            $0.displayTitle.localizedCaseInsensitiveCompare($1.displayTitle) == .orderedAscending
        }

        var updatedPlugins: OrderedDictionary<String, PluginDetailsViewModel> = [:]

        for plugin in incomingPlugins {
            guard let id = plugin.id?.uppercased() else { continue }

            if let existing = allPlugins[id] {
                existing.plugin = plugin
                existing.package = packages[id] ?? existing.package
                updatedPlugins[id] = existing
            } else {
                let viewModel = PluginDetailsViewModel(plugin: plugin, package: packages[id])

                viewModel.objectWillChange
                    .sink { [weak self] _ in
                        self?.objectWillChange.send()
                    }
                    .store(in: &cancellables)

                updatedPlugins[id] = viewModel
            }
        }

        allPlugins = updatedPlugins

        repositories = try await repositoriesResponse.value
    }

    @Function(\Action.Cases.addRepository)
    private func _addRepository(_ repository: RepositoryInfo) async throws {
        let request = Paths.setRepositories(repositories + [repository])
        try await send(request)

        try await _refresh()
    }

    @Function(\Action.Cases.removeRepository)
    private func _removeRepository(_ repository: RepositoryInfo) async throws {
        let request = Paths.setRepositories(repositories.filter { $0 != repository })
        try await send(request)

        try await _refresh()
    }
}
