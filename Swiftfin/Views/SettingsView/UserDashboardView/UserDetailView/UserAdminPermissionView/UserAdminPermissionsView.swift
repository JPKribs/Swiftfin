//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2024 Jellyfin & Jellyfin Contributors
//

import Defaults
import JellyfinAPI
import SwiftUI

extension UserAdminDetailView {
    struct UserAdminPermissionsView: View {
        // MARK: - Environment Objects

        @EnvironmentObject
        private var router: SettingsCoordinator.Router

        // MARK: - Observed Objects

        @ObservedObject
        var observer: UserAdminObserver

        // MARK: - Default Variables

        private var accentColor = Defaults[.accentColor]

        // MARK: - State Variables

        @State
        var tempPolicy: UserPolicy

        @State
        private var isEditing: Bool = false
        @State
        private var error: Error?
        @State
        private var isPresentingError: Bool = false
        @State
        private var isPresentingSuccess: Bool = false

        // MARK: - State Variables

        var isEnabled: Bool {
            observer.state != .updating && isEditing
        }

        // MARK: - Initializer

        init(observer: UserAdminObserver) {
            self.observer = observer
            self.tempPolicy = observer.user.policy ?? UserPolicy()
        }

        // MARK: - Body

        var body: some View {
            ZStack {
                switch observer.state {
                case let .error(error):
                    ErrorView(error: error)
                default:
                    if observer.user.id != nil {
                        contentView
                    } else {
                        Text(L10n.none)
                    }
                }
            }
            .navigationTitle("Permissions") // L10n.profile
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

                Button(isEditing ? L10n.cancel : L10n.edit) {
                    if isEditing {
                        tempPolicy = observer.user.policy ?? UserPolicy()
                    }
                    isEditing.toggle()
                    UIDevice.impact(.light)
                }
                .buttonStyle(.toolbarPill)
                .disabled(observer.state == .updating)
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
                "Success",
                isPresented: $isPresentingSuccess
            ) {
                Button(L10n.dismiss, role: .cancel) {}
            } message: {
                Text("User Profile Updated")
            }
        }

        @ViewBuilder
        var contentView: some View {
            VStack {
                List {
                    StatusSection(tempPolicy: $tempPolicy)
                        .environment(\.isEnabled, isEnabled)

                    ManagementSection(tempPolicy: $tempPolicy)
                        .environment(\.isEnabled, isEnabled)

                    LiveTVSection(tempPolicy: $tempPolicy)
                        .environment(\.isEnabled, isEnabled)

                    MediaPlaybackSection(tempPolicy: $tempPolicy)
                        .environment(\.isEnabled, isEnabled)

                    ExternalSection(tempPolicy: $tempPolicy)
                        .environment(\.isEnabled, isEnabled)

                    SyncPlaySection(tempPolicy: $tempPolicy)
                        .environment(\.isEnabled, isEnabled)

                    MediaManagementSection(tempPolicy: $tempPolicy)
                        .environment(\.isEnabled, isEnabled)

                    RemoteControlSection(tempPolicy: $tempPolicy)
                        .environment(\.isEnabled, isEnabled)

                    SessionSection(
                        tempPolicy: $tempPolicy,
                        isAdmin: observer.user.policy?.isAdministrator ?? false
                    )
                    .environment(\.isEnabled, isEnabled)

                    OtherSection(tempPolicy: $tempPolicy)
                        .environment(\.isEnabled, isEnabled)
                }

                if isEditing {
                    savePermissionsButton
                        .edgePadding([.bottom, .horizontal])
                }
            }
        }

        // MARK: - Save Permissions Button

        @ViewBuilder
        private var savePermissionsButton: some View {
            Button {
                observer.send(.updatePolicy(policy: tempPolicy))
            } label: {
                ZStack {
                    Color.accentColor

                    Text(L10n.save)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(observer.user.policy == tempPolicy ? .secondary : .primary)

                    if observer.user.policy == tempPolicy {
                        Color.black
                            .opacity(0.5)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .frame(height: 50)
                .frame(maxWidth: 400)
            }
            .disabled(observer.user.policy == tempPolicy)
            .buttonStyle(.plain)
        }
    }
}
