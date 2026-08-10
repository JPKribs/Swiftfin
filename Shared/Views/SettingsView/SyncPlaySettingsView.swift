//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Defaults
import SwiftUI

struct SyncPlaySettingsView: View {

    @Default(.SyncPlay.enableSyncCorrection)
    private var enableSyncCorrection
    @Default(.SyncPlay.enableSpeedToSync)
    private var enableSpeedToSync
    @Default(.SyncPlay.speedToSyncMinimumDelay)
    private var speedToSyncMinimumDelay
    @Default(.SyncPlay.speedToSyncMaximumDelay)
    private var speedToSyncMaximumDelay
    @Default(.SyncPlay.speedToSyncDuration)
    private var speedToSyncDuration
    @Default(.SyncPlay.enableSkipToSync)
    private var enableSkipToSync
    @Default(.SyncPlay.skipToSyncMinimumDelay)
    private var skipToSyncMinimumDelay
    @Default(.SyncPlay.extraTimeOffset)
    private var extraTimeOffset

    var body: some View {
        Form(systemImage: "person.2") {
            Section(L10n.playback, footer: L10n.syncCorrectionDescription) {
                Toggle(L10n.syncCorrection, isOn: $enableSyncCorrection)
            }

            if enableSyncCorrection {
                Section(L10n.speedToSync) {
                    Toggle(L10n.enabled, isOn: $enableSpeedToSync)

                    if enableSpeedToSync {
                        Stepper(L10n.minimumDelay, value: $speedToSyncMinimumDelay, in: 0 ... 1000, step: 10) {
                            LabeledContent(L10n.minimumDelay) {
                                Text(speedToSyncMinimumDelay, format: MillisecondFormatter())
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Stepper(L10n.maximumDelay, value: $speedToSyncMaximumDelay, in: 1000 ... 10000, step: 100) {
                            LabeledContent(L10n.maximumDelay) {
                                Text(speedToSyncMaximumDelay, format: MillisecondFormatter())
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Stepper(L10n.duration, value: $speedToSyncDuration, in: 100 ... 5000, step: 100) {
                            LabeledContent(L10n.duration) {
                                Text(speedToSyncDuration, format: MillisecondFormatter())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } footer: {
                    Text(L10n.enableSpeedToSyncDescription)
                } learnMore: {
                    LabeledContent(
                        L10n.minimumDelay,
                        value: L10n.speedToSyncMinimumDelayDescription
                    )
                    LabeledContent(
                        L10n.maximumDelay,
                        value: L10n.speedToSyncMaximumDelayDescription
                    )
                    LabeledContent(
                        L10n.duration,
                        value: L10n.speedToSyncDurationDescription
                    )
                }

                Section(L10n.skipToSync) {
                    Toggle(L10n.enabled, isOn: $enableSkipToSync)

                    if enableSkipToSync {
                        Stepper(L10n.minimumDelay, value: $skipToSyncMinimumDelay, in: 100 ... 5000, step: 50) {
                            LabeledContent(L10n.minimumDelay) {
                                Text(skipToSyncMinimumDelay, format: MillisecondFormatter())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } footer: {
                    Text(L10n.enableSkipToSyncDescription)
                } learnMore: {
                    LabeledContent(
                        L10n.minimumDelay,
                        value: L10n.skipToSyncMinimumDelayDescription
                    )
                }
            }

            Section(L10n.timeSync, footer: L10n.extraTimeOffsetDescription) {
                Stepper(L10n.extraTimeOffset, value: $extraTimeOffset, in: -5000 ... 5000, step: 10) {
                    LabeledContent(L10n.extraTimeOffset) {
                        Text(extraTimeOffset, format: MillisecondFormatter())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .animation(.linear, value: enableSyncCorrection)
        .animation(.linear, value: enableSpeedToSync)
        .animation(.linear, value: enableSkipToSync)
        .navigationTitle(L10n.syncPlay)
    }
}
