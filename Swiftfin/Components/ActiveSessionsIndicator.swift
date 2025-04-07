//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2025 Jellyfin & Jellyfin Contributors
//

import JellyfinAPI
import SwiftUI

struct ActiveSessionBadgeModifier: ViewModifier {

    // MARK: - Objserved Object

    @ObservedObject
    var viewModel = ActiveSessionsViewModel()

    // MARK: - View Model Update Timer

    private let timer = Timer.publish(every: 60, on: .main, in: .common)
        .autoconnect()

    // MARK: - Session States

    private var isEnabled: Bool

    private var activeSessions: [SessionInfo] {
        viewModel.sessions.compactMap(\.value.value).filter {
            $0.nowPlayingItem != nil
        }
    }

    // MARK: - Initializer

    init(_ isEnabled: Bool = false) {
        self.isEnabled = isEnabled
        self.viewModel.send(.getSessions)
    }

    // MARK: - Body

    func body(content: Content) -> some View {
        content
            .if(isEnabled && activeSessions.isNotEmpty) { view in
                view
                    .overlay(alignment: .topTrailing) {
                        ActivityBadge(value: activeSessions.count)
                    }
                    .onReceive(timer) { _ in
                        viewModel.send(.getSessions)
                    }
            }
    }
}

// MARK: - View Extension

extension View {
    func activeSessionBadge(_ isEnabled: Bool = false) -> some View {
        modifier(ActiveSessionBadgeModifier(isEnabled))
    }
}
