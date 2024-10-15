//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2024 Jellyfin & Jellyfin Contributors
//

import Combine
import Defaults
import JellyfinAPI
import SwiftUI

extension UserAdministrationDetailView {
    struct PolicyView: View {

        @EnvironmentObject
        private var router: AdminDashboardCoordinator.Router

        @ObservedObject
        var observer: UserAdministrationObserver

        @State
        var tempUser: UserDto
        @State
        var tempPolicy: UserPolicy

        @Default(.accentColor)
        private var accentColor

        @State
        private var error: Error? = nil
        @State
        private var isPresentingError: Bool = false
        @State
        private var isPresentingSuccess: Bool = false

        @State
        private var tempMaxSessions: Int?
        @State
        private var tempMaxFailedLogins: Int?
        @State
        private var tempMaxBitrate: Int?

        init(observer: UserAdministrationObserver) {
            self.observer = observer
            self.tempUser = observer.user ?? UserDto()
            self.tempPolicy = observer.user.policy ?? UserPolicy()
            self.tempMaxSessions = tempPolicy.maxActiveSessions
            self.tempMaxFailedLogins = tempPolicy.loginAttemptsBeforeLockout
            self.tempMaxBitrate = tempPolicy.remoteClientBitrateLimit
        }

        var body: some View {
            List {
                UsernameView()
                ManagementPermissionsView()
                FeatureAccessView()
                MediaPlaybackView()
                ExternalAccessView()
                SyncPlayView()
                MediaDeletionSection()
                RemoteControlView()
                PermissionsSectionView()
                SessionConfigurationSectionView()
                SaveButtonSectionView()
            }
            .interactiveDismissDisabled(observer.state == .updating)
            .navigationBarBackButtonHidden(observer.state == .updating)
            .navigationTitle("Profile") // L10n.profile
            .onReceive(observer.events) { event in
                switch event {
                case let .error(eventError):
                    UIDevice.feedback(.error)
                    error = eventError
                    isPresentingError = true
                case .success:
                    UIDevice.feedback(.success)
                    isPresentingSuccess = true
                }
            }
            .topBarTrailing {
                if observer.state == .updating {
                    ProgressView()
                }
            }
            .alert(
                L10n.error.text,
                isPresented: $isPresentingError,
                presenting: error
            ) { _ in
                Button(L10n.dismiss, role: .cancel) {}
            } message: { error in
                Text(error.localizedDescription)
            }
            .alert(
                L10n.success.text,
                isPresented: $isPresentingSuccess
            ) {
                Button(L10n.dismiss, role: .cancel) {}
            } message: {
                Text("User Profile Updated") // L10n.profileUpdated
            }
        }

        @ViewBuilder
        private func UsernameView() -> some View {
            Section(L10n.username) {
                TextField(L10n.name, text: Binding(
                    get: {
                        tempUser.name ?? ""
                    },
                    set: {
                        tempUser.name = $0.isEmpty ? nil : $0
                    }
                ))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.none)
                .disabled(observer.state == .updating)
            }
        }

        @ViewBuilder
        private func MediaDeletionSection() -> some View {
            Section("Allow media deletion") {
                Toggle("Allow media deletion", isOn: Binding(
                    get: { tempPolicy.enableContentDeletion ?? false },
                    set: { tempPolicy.enableContentDeletion = $0 }
                ))
                .disabled(observer.state == .updating)

                // TODO: Add the 'Allow media deletion from' Libaries
            }
        }

        @ViewBuilder
        private func SyncPlayView() -> some View {
            Section("SyncPlay access") {
                Picker(
                    "SyncPlace",
                    selection: Binding(
                        get: { tempPolicy.syncPlayAccess ?? SyncPlayUserAccessType.none },
                        set: { tempPolicy.syncPlayAccess = $0 }
                    )
                ) {
                    ForEach(SyncPlayUserAccessType.allCases, id: \.self) { type in
                        Text(type.displayTitle).tag(type)
                    }
                }
            }
        }

        @ViewBuilder
        private func RemoteControlView() -> some View {
            Section("Remote control") {
                Toggle("Control other users", isOn: Binding(
                    get: { tempPolicy.enableRemoteControlOfOtherUsers ?? false },
                    set: { tempPolicy.enableRemoteControlOfOtherUsers = $0 }
                ))
                .disabled(observer.state == .updating)

                Toggle("Control shared devices", isOn: Binding(
                    get: { tempPolicy.enableSharedDeviceControl ?? false },
                    set: { tempPolicy.enableSharedDeviceControl = $0 }
                ))
                .disabled(observer.state == .updating)
            }
        }

        @ViewBuilder
        private func ExternalAccessView() -> some View {
            Section("Remote Connections") {
                Toggle("Remote Connections", isOn: Binding(
                    get: { tempPolicy.enableRemoteAccess ?? false },
                    set: { tempPolicy.enableRemoteAccess = $0 }
                ))
                .disabled(observer.state == .updating)

                MaxBitrateButtonView()
            }
        }

        @ViewBuilder
        private func ManagementPermissionsView() -> some View {
            Section("Management Permissions") {
                Toggle("Adminstrator", isOn: Binding(
                    get: { tempPolicy.isAdministrator ?? false },
                    set: { tempPolicy.isAdministrator = $0 }
                ))
                .disabled(observer.state == .updating)
            }
        }

        @ViewBuilder
        private func FeatureAccessView() -> some View {
            Section("Feature access") {
                Toggle("Live TV access", isOn: Binding(
                    get: { tempPolicy.enableLiveTvAccess ?? false },
                    set: { tempPolicy.enableLiveTvAccess = $0 }
                ))
                .disabled(observer.state == .updating)

                Toggle("Live TV recording management", isOn: Binding(
                    get: { tempPolicy.enableLiveTvManagement ?? false },
                    set: { tempPolicy.enableLiveTvManagement = $0 }
                ))
                .disabled(observer.state == .updating)
            }
        }

        @ViewBuilder
        private func MediaPlaybackView() -> some View {
            Section("Media playback") {
                Toggle("Allow media playback", isOn: Binding(
                    get: { tempPolicy.enableMediaPlayback ?? false },
                    set: { tempPolicy.enableMediaPlayback = $0 }
                ))
                .disabled(observer.state == .updating)

                Toggle("Allow audio transcoding", isOn: Binding(
                    get: { tempPolicy.enableAudioPlaybackTranscoding ?? false },
                    set: { tempPolicy.enableAudioPlaybackTranscoding = $0 }
                ))
                .disabled(observer.state == .updating)

                Toggle("Allow video transcoding", isOn: Binding(
                    get: { tempPolicy.enableVideoPlaybackTranscoding ?? false },
                    set: { tempPolicy.enableVideoPlaybackTranscoding = $0 }
                ))
                .disabled(observer.state == .updating)

                Toggle("Allow video remuxing", isOn: Binding(
                    get: { tempPolicy.enablePlaybackRemuxing ?? false },
                    set: { tempPolicy.enablePlaybackRemuxing = $0 }
                ))
                .disabled(observer.state == .updating)

                Toggle("Force remote media transcoding", isOn: Binding(
                    get: { tempPolicy.isForceRemoteSourceTranscoding ?? false },
                    set: { tempPolicy.isForceRemoteSourceTranscoding = $0 }
                ))
                .disabled(observer.state == .updating)
            }
        }

        @ViewBuilder
        private func PermissionsSectionView() -> some View {
            Section("Permissions") {
                Toggle("Allow media downloads", isOn: Binding(
                    get: { tempPolicy.enableContentDownloading ?? false },
                    set: { tempPolicy.enableContentDownloading = $0 }
                ))
                .disabled(observer.state == .updating)

                Toggle("Hide user from login screen", isOn: Binding(
                    get: { tempPolicy.isHidden ?? false },
                    set: { tempPolicy.isHidden = $0 }
                ))
                .disabled(observer.state == .updating)
            }
        }

        // Assemble session configuration subviews
        @ViewBuilder
        private func SessionConfigurationSectionView() -> some View {
            Section(L10n.session) {
                MaxFailedLoginsButtonView()
                MaxSessionsButtonView()
            }
        }

        @ViewBuilder
        private func SaveButtonSectionView() -> some View {
            Section {
                if observer.state == .updating {
                    ListRowButton(L10n.cancel) {
                        observer.send(.cancel)
                    }
                    .foregroundStyle(.red, .red.opacity(0.2))
                } else {
                    ListRowButton(L10n.save) {
                        observer.send(.updatePolicy(policy: tempPolicy))
                    }
                    .foregroundStyle(accentColor.overlayColor, accentColor)
                }
            } footer: {
                Text("Bottom Text") // L10n.profileChangeInfo)
            }
        }

        // Subcomponents for each button in the Session Configuration
        @ViewBuilder
        private func MaxBitrateButtonView() -> some View {
            // Create a separate binding for the TextField
            let bitrateBinding = Binding<Double>(
                get: {
                    guard let bitrate = tempMaxBitrate else { return 0 }
                    return Double(bitrate) / 1_000_000
                },
                set: { newValue in
                    tempMaxBitrate = Int(newValue * 1_000_000)
                }
            )

            ChevronInputButton(
                title: L10n.maximumBitrate,
                subtitle: (
                    tempPolicy.remoteClientBitrateLimit == 0 || tempPolicy.remoteClientBitrateLimit == nil ? L10n
                        .disabled : tempPolicy.remoteClientBitrateLimit?.formatted(.bitRate)
                )!,
                description: L10n.maximumBitrate
            ) {
                TextField(L10n.timeLimit, value: bitrateBinding, format: .number)
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
            .disabled(observer.state == .updating)
        }

        @ViewBuilder
        private func MaxFailedLoginsButtonView() -> some View {
            let failedLoginsBinding = Binding<Int>(
                get: {
                    tempMaxFailedLogins ?? -1
                },
                set: { newValue in
                    tempMaxFailedLogins = newValue
                }
            )

            ChevronInputButton(
                title: "Maximum failed login attempts",
                subtitle: (
                    tempPolicy.loginAttemptsBeforeLockout == -1 ? L10n
                        .disabled : (
                            tempPolicy.loginAttemptsBeforeLockout == 0 || tempPolicy
                                .loginAttemptsBeforeLockout == nil ? "Default" : tempPolicy
                                .loginAttemptsBeforeLockout?.description
                        )!
                ),
                description: "Maximum failed login attempts"
            ) {
                TextField(L10n.timeLimit, value: failedLoginsBinding, format: .number)
                    .keyboardType(.numberPad)
            } onSave: {
                if tempMaxFailedLogins != nil && tempMaxFailedLogins != 0 {
                    tempPolicy.loginAttemptsBeforeLockout = tempMaxFailedLogins
                } else {
                    tempPolicy.loginAttemptsBeforeLockout = nil
                }
            } onCancel: {
                tempMaxFailedLogins = tempPolicy.loginAttemptsBeforeLockout
            }
            .disabled(observer.state == .updating)
        }

        @ViewBuilder
        private func MaxSessionsButtonView() -> some View {
            let maxSessionsBinding = Binding<Int>(
                get: {
                    tempMaxSessions ?? 0
                },
                set: { newValue in
                    tempMaxSessions = newValue
                }
            )

            ChevronInputButton(
                title: "Simultaneous sessions",
                subtitle: (
                    tempPolicy.maxActiveSessions == 0 || tempPolicy.maxActiveSessions == nil ? "Unlimited" : tempPolicy.maxActiveSessions?
                        .description
                )!,
                description: "Maximum Sessions per User"
            ) {
                TextField(L10n.timeLimit, value: maxSessionsBinding, format: .number)
                    .keyboardType(.numberPad)
            } onSave: {
                if tempMaxSessions != nil && tempMaxSessions != 0 {
                    tempPolicy.maxActiveSessions = tempMaxSessions
                } else {
                    tempPolicy.maxActiveSessions = nil
                }
            } onCancel: {
                tempMaxSessions = tempPolicy.maxActiveSessions
            }
            .disabled(observer.state == .updating)
        }
    }
}
