//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2024 Jellyfin & Jellyfin Contributors
//

import JellyfinAPI
import SwiftUI

let defaultBitrate = 10_000_000

extension UserAdminDetailView.UserAdminPermissionsView {
    struct ExternalSection: View {
        @Binding
        var tempPolicy: UserPolicy

        @Environment(\.isEnabled)
        var isEnabled

        // MARK: - Temporary State Variables

        @State
        private var limitBitrate: Bool = false

        // MARK: - State Variables

        @State
        private var tempMaxBitrate: Int?

        // MARK: - Initializer

        init(tempPolicy: Binding<UserPolicy>) {
            self._tempPolicy = tempPolicy
            let initialBitrate = tempPolicy.wrappedValue.remoteClientBitrateLimit
            self._tempMaxBitrate = State(initialValue: initialBitrate != 0 ? initialBitrate : defaultBitrate)
            self._limitBitrate = State(initialValue: initialBitrate != 0)
        }

        // MARK: - Body

        @ViewBuilder
        var body: some View {
            Section("Remote Connections") {
                Toggle("Remote Connections", isOn: Binding(
                    get: { tempPolicy.enableRemoteAccess ?? false },
                    set: { tempPolicy.enableRemoteAccess = $0 }
                ))
                .disabled(!isEnabled)

                LimitBitrateToggle

                if limitBitrate {
                    MaxBitrateButton
                }
            }
        }

        // MARK: - LimitBitrateToggle

        @ViewBuilder
        private var LimitBitrateToggle: some View {
            Toggle("Limit max bitrate", isOn: $limitBitrate)
                .onChange(of: limitBitrate) { isEnabled in
                    if !isEnabled {
                        tempMaxBitrate = 0
                        tempPolicy.remoteClientBitrateLimit = tempMaxBitrate
                    } else {
                        tempMaxBitrate = defaultBitrate
                        tempPolicy.remoteClientBitrateLimit = tempMaxBitrate
                    }
                }
        }

        // MARK: - MaxBitrateButton

        @ViewBuilder
        private var MaxBitrateButton: some View {
            let bitrateBinding = Binding<Double>(
                get: {
                    guard let bitrate = tempMaxBitrate else { return 0 }
                    return Double(bitrate) / 1_000_000
                },
                set: { newValue in
                    tempMaxBitrate = Int(newValue * 1_000_000)
                }
            )

            ChevronAlertButton(
                L10n.maximumBitrate,
                subtitle: tempPolicy.remoteClientBitrateLimit?.formatted(.bitRate),
                description: L10n.maximumBitrate
            ) {
                TextField("mbps", value: bitrateBinding, format: .number)
                    .keyboardType(.numbersAndPunctuation)
            } onSave: {
                if tempMaxBitrate != nil && tempMaxBitrate != 0 {
                    tempPolicy.remoteClientBitrateLimit = tempMaxBitrate
                } else {
                    tempPolicy.remoteClientBitrateLimit = nil
                }
            } onCancel: {
                tempMaxBitrate = tempPolicy.remoteClientBitrateLimit
            }
            .disabled(!isEnabled)
        }
    }
}
