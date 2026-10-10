//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Foundation
import JellyfinAPI

@MainActor
@Stateful
final class PluginDetailsViewModel: ViewModel, @preconcurrency Identifiable {

    @CasePathable
    enum Action {
        case refresh
        case setEnabled(isEnabled: Bool)
        case install
        case uninstall

        var transition: Transition {
            switch self {
            case .refresh:
                .background(.refreshing)
            case .setEnabled, .install, .uninstall:
                .background(.updating)
            }
        }
    }

    enum BackgroundState {
        case refreshing
        case updating
    }

    enum State {
        case error
        case initial
    }

    @Published
    var plugin: PluginInfo
    @Published
    private(set) var configurationPage: ConfigurationPageInfo?
    @Published
    var package: PackageInfo?

    var id: String? {
        plugin.id?.uppercased()
    }

    init(plugin: PluginInfo, package: PackageInfo?) {
        self.plugin = plugin
        self.package = package
    }

    @Function(\Action.Cases.refresh)
    private func _refresh() async throws {
        guard let id = plugin.id, let name = plugin.name else { return }

        async let installedResponse = send(Paths.getPlugins)
        async let packageResponse = send(Paths.getPackageInfo(name: name, assemblyGuid: id))
        async let configurationPagesResponse = send(Paths.getConfigurationPages())

        let installed = try await installedResponse.value.filter { $0.id?.caseInsensitiveCompare(id) == .orderedSame }

        if let current = installed.first(where: \.isInstalled) ?? installed.first {
            plugin = current
        }

        // Plugins bundled with the server are not in any repository
        if let package = try? await packageResponse.value {
            self.package = package
        }

        let configurationPages = try await configurationPagesResponse.value.filter {
            $0.pluginID?.caseInsensitiveCompare(id) == .orderedSame
        }

        configurationPage = configurationPages.first { $0.enableInMainMenu == true } ?? configurationPages.first
    }

    @Function(\Action.Cases.setEnabled)
    private func _setEnabled(_ isEnabled: Bool) async throws {
        guard let id = plugin.id, let version = plugin.version else {
            logger.error("Plugin ID or version is nil")
            throw ErrorMessage(L10n.unknownError)
        }

        let request = isEnabled
            ? Paths.enablePlugin(pluginID: id, version: version)
            : Paths.disablePlugin(pluginID: id, version: version)
        try await send(request)

        try await _refresh()
    }

    @Function(\Action.Cases.install)
    private func _install() async throws {
        guard let name = plugin.name else {
            logger.error("Plugin name is nil")
            throw ErrorMessage(L10n.unknownError)
        }

        let request = Paths.installPackage(
            name: name,
            parameters: .init(assemblyGuid: plugin.id)
        )
        try await send(request)

        try await _refresh()
    }

    @Function(\Action.Cases.uninstall)
    private func _uninstall() async throws {
        guard let id = plugin.id, let version = plugin.version else {
            logger.error("Plugin ID or version is nil")
            throw ErrorMessage(L10n.unknownError)
        }

        let request = Paths.uninstallPluginByVersion(pluginID: id, version: version)
        try await send(request)

        try await _refresh()
    }
}
