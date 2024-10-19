//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2024 Jellyfin & Jellyfin Contributors
//

import JellyfinAPI
import SwiftUI

// Since the "Failed login tries before user is locked out" logic is kind of weird, these values are used
// through to assist in converting logic into their corresponding numberical value in loginAttemptsBeforeLockout.
// This version is based on the following:
// A value of zero means inheriting the default of three tries for normal users and five for administrators.
// Setting this to -1 will disable the feature.

let failedNoLimit = -1
let failedUserLimit = 3
let failedAdminLimit = 5

extension UserAdminDetailView.UserAdminPermissionsView {
    struct SessionSection: View {
        @Binding
        var tempPolicy: UserPolicy

        @Environment(\.isEnabled)
        var isEnabled

        // MARK: - Temporary State Variables

        @State
        private var useDefaultLimits: Bool = false
        @State
        private var limitFailedLogins: Bool = false
        @State
        private var enableMaxSessions: Bool = false
        @State
        private var customFailedLogins: Int = 1

        // MARK: - State Variables

        // 1- = Unlimited, 0 = Defaults (3/5), X = Actual Value (See Above)
        @State
        private var tempMaxFailedLogins: Int?

        // 0 = Unlimited, X = Actual Value
        @State
        private var tempMaxSessions: Int?

        var isAdmin: Bool

        // MARK: - Initializer

        init(tempPolicy: Binding<UserPolicy>, isAdmin: Bool) {
            self._tempPolicy = tempPolicy
            self.isAdmin = isAdmin

            let initialFailedLogins = tempPolicy.wrappedValue.loginAttemptsBeforeLockout

            self._limitFailedLogins = State(initialValue: initialFailedLogins != failedNoLimit)

            if initialFailedLogins == failedUserLimit && !isAdmin {
                self._useDefaultLimits = State(initialValue: true)
            } else if initialFailedLogins == failedAdminLimit && isAdmin {
                self._useDefaultLimits = State(initialValue: true)
            } else if initialFailedLogins == failedNoLimit {
                self._useDefaultLimits = State(initialValue: true)
            } else {
                self._useDefaultLimits = State(initialValue: false)
            }

            self._tempMaxFailedLogins = State(initialValue: initialFailedLogins)
            self._customFailedLogins = State(initialValue: initialFailedLogins ?? 1)
            self._tempMaxSessions = State(initialValue: tempPolicy.wrappedValue.maxActiveSessions)
            self._enableMaxSessions = State(initialValue: tempPolicy.wrappedValue.maxActiveSessions != 0)
        }

        // MARK: - Body

        @ViewBuilder
        var body: some View {
            Section(L10n.session) {
                LimitFailedLoginsToggle
                if limitFailedLogins {
                    UseDefaultLimitsToggle
                    if !useDefaultLimits {
                        CustomFailedLoginsField
                    }
                }
                MaxSessionsToggle
                if enableMaxSessions {
                    MaxSessionsButton
                }
            }
        }

        // MARK: - LimitFailedLoginsToggle

        @ViewBuilder
        private var LimitFailedLoginsToggle: some View {
            Toggle("Limit failed login attempts", isOn: $limitFailedLogins)
                .onChange(of: limitFailedLogins) { isEnabled in
                    if !isEnabled {
                        tempMaxFailedLogins = failedNoLimit
                    } else if useDefaultLimits {
                        tempMaxFailedLogins = isAdmin ? failedAdminLimit : failedUserLimit
                    } else {
                        tempMaxFailedLogins = customFailedLogins
                    }
                    tempPolicy.loginAttemptsBeforeLockout = tempMaxFailedLogins
                }
        }

        // MARK: - UseDefaultLimitsToggle

        @ViewBuilder
        private var UseDefaultLimitsToggle: some View {
            Toggle("Use default limits", isOn: $useDefaultLimits)
                .onChange(of: useDefaultLimits) { useDefault in
                    if useDefault {
                        tempMaxFailedLogins = isAdmin ? failedAdminLimit : failedUserLimit
                    } else {
                        tempMaxFailedLogins = customFailedLogins
                    }
                    tempPolicy.loginAttemptsBeforeLockout = tempMaxFailedLogins
                }
        }

        // MARK: - CustomFailedLoginsField

        @ViewBuilder
        private var CustomFailedLoginsField: some View {
            let failedLoginsBinding = Binding<Int>(
                get: {
                    customFailedLogins
                },
                set: { newValue in
                    customFailedLogins = min(max(newValue, 1), 50)
                }
            )

            ChevronAlertButton(
                "Maximum failed login attempts",
                subtitle: customFailedLogins.description,
                description: "Custom failed login attempts"
            ) {
                TextField("Max", value: failedLoginsBinding, format: .number)
                    .keyboardType(.numberPad)
                    .onChange(of: failedLoginsBinding.wrappedValue) { newValue in
                        customFailedLogins = min(max(newValue, 1), 50)
                        tempMaxFailedLogins = customFailedLogins
                        tempPolicy.loginAttemptsBeforeLockout = customFailedLogins
                    }
            }
        }

        // MARK: - MaxSessionsToggle

        @ViewBuilder
        private var MaxSessionsToggle: some View {
            Toggle("Limit simultaneous sessions", isOn: $enableMaxSessions)
                .onChange(of: enableMaxSessions) { isEnabled in
                    tempMaxSessions = isEnabled ? 1 : 0
                    tempPolicy.maxActiveSessions = tempMaxSessions
                }
        }

        // MARK: - MaxSessionsButton

        @ViewBuilder
        private var MaxSessionsButton: some View {
            let maxSessionsBinding = Binding<Int>(
                get: {
                    tempMaxSessions ?? 1
                },
                set: { newValue in
                    tempMaxSessions = newValue
                }
            )

            ChevronAlertButton(
                "Simultaneous sessions",
                subtitle: tempMaxSessions == 0 ? "Unlimited" : tempMaxSessions?.description ?? "",
                description: "Maximum Sessions per User"
            ) {
                TextField("Max", value: maxSessionsBinding, format: .number)
                    .keyboardType(.numberPad)
                    .onChange(of: maxSessionsBinding.wrappedValue) { newValue in
                        tempMaxSessions = min(max(newValue, 1), 50)
                    }
            } onSave: {
                if tempMaxSessions != nil && tempMaxSessions != 0 {
                    tempPolicy.maxActiveSessions = tempMaxSessions
                } else {
                    tempPolicy.maxActiveSessions = nil
                }
            } onCancel: {
                tempMaxSessions = tempPolicy.maxActiveSessions
            }
            .disabled(!isEnabled)
        }
    }
}
