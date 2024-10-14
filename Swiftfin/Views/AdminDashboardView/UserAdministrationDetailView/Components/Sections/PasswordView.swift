//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2024 Jellyfin & Jellyfin Contributors
//

import CollectionVGrid
import Defaults
import JellyfinAPI
import SwiftUI

extension UserAdministrationDetailView {
    struct PasswordView: View {

        @EnvironmentObject
        private var router: AdminDashboardCoordinator.Router

        @ObservedObject
        var observer: UserAdministrationObserver

        @Default(.accentColor)
        private var accentColor

        @FocusState
        private var focusedPassword: Int?

        @State
        private var currentPassword: String = ""
        @State
        private var newPassword: String = ""
        @State
        private var confirmNewPassword: String = ""

        @State
        private var error: Error? = nil
        @State
        private var isPresentingError: Bool = false
        @State
        private var isPresentingSuccess: Bool = false
        @State
        private var isPresentingWarning: Bool = false

        var body: some View {
            List {
                contentView
            }
            .interactiveDismissDisabled(observer.state == .updating)
            .navigationBarBackButtonHidden(observer.state == .updating)
            .navigationTitle(L10n.password)
            .onFirstAppear {
                focusedPassword = 0
            }
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
                Button(L10n.dismiss, role: .cancel) {
                    focusedPassword = 1
                }
            } message: { error in
                Text(error.localizedDescription)
            }
            .alert(
                L10n.success.text,
                isPresented: $isPresentingSuccess
            ) {
                Button(L10n.dismiss, role: .cancel) {
                    router.pop()
                }
            } message: {
                Text(L10n.userPasswordChanged)
            }
        }

        @ViewBuilder
        private var contentView: some View {
            /* Current Password Input Field IF there is a Password to Change */
            if observer.user.hasPassword ?? false {
                Section(L10n.currentPassword) {
                    UnmaskSecureField(L10n.currentPassword, text: $currentPassword) {
                        focusedPassword = 1
                    }
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.none)
                    .focused($focusedPassword, equals: 0)
                    .disabled(observer.state == .updating)
                }
            }

            /* New Password Input Field */
            Section(L10n.newPassword) {
                UnmaskSecureField(L10n.newPassword, text: $newPassword) {
                    focusedPassword = 2
                }
                .autocorrectionDisabled()
                .textInputAutocapitalization(.none)
                .focused($focusedPassword, equals: 1)
                .disabled(observer.state == .updating)
            }

            /* Confirm New Password Input Field */
            Section {
                UnmaskSecureField(L10n.confirmNewPassword, text: $confirmNewPassword) {
                    observer.send(
                        .updatePassword(
                            currentPassword: currentPassword,
                            newPassword: confirmNewPassword
                        )
                    )
                }
                .autocorrectionDisabled()
                .textInputAutocapitalization(.none)
                .focused($focusedPassword, equals: 2)
                .disabled(observer.state == .updating)
            } header: {
                Text(L10n.confirmNewPassword)
            } footer: {
                if newPassword != confirmNewPassword {
                    Label(L10n.passwordMismatch, systemImage: "exclamationmark.circle.fill")
                        .labelStyle(.sectionFooterWithImage(imageStyle: .orange))
                }
            }

            /* Update Password Button */
            Section {
                if observer.state == .updating {
                    ListRowButton(L10n.cancel) {
                        observer.send(.cancel)
                        focusedPassword = 0
                    }
                    .foregroundStyle(.red, .red.opacity(0.2))
                } else {
                    ListRowButton(L10n.updatePassword) {
                        focusedPassword = nil
                        observer.send(.updatePassword(
                            currentPassword: currentPassword,
                            newPassword: confirmNewPassword
                        ))
                    }
                    .disabled(newPassword != confirmNewPassword || observer.state == .updating)
                    .foregroundStyle(accentColor.overlayColor, accentColor)
                    .opacity(newPassword != confirmNewPassword ? 0.5 : 1)
                }
            } footer: {
                Text(L10n.passwordChangeInfo)
            }

            /* Reset Password Button */
            Section {
                if observer.state != .updating {
                    ListRowButton(L10n.resetPassword) {
                        focusedPassword = nil
                        isPresentingWarning = true
                    }
                    .disabled(observer.state == .updating)
                    .foregroundStyle(.red, .red.opacity(0.2))
                    .confirmationDialog(
                        L10n.resetPassword,
                        isPresented: $isPresentingWarning,
                        titleVisibility: .visible
                    ) {
                        Button(L10n.confirm, role: .destructive) {
                            focusedPassword = nil
                            observer.send(.resetPassword)
                            isPresentingWarning = false
                        }
                        Button(L10n.cancel, role: .cancel) {
                            isPresentingWarning = false
                        }
                    } message: {
                        Text(L10n.resetPasswordWarning(observer.user.name ?? L10n.unknown))
                    }
                }
            } footer: {
                Text(L10n.resetPasswordInfo)
            }
        }
    }
}
