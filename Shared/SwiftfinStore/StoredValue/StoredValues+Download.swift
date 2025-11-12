//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2025 Jellyfin & Jellyfin Contributors
//

import Defaults
import Factory
import Foundation
import JellyfinAPI

// MARK: - Keys

extension StoredValues.Keys {

    static func DownloadKey<Value: Codable>(
        _ name: String?,
        ownerID: String,
        domain: String,
        default defaultValue: Value
    ) -> Key<Value> {
        guard let name else {
            return Key(always: defaultValue)
        }

        return Key(
            name,
            ownerID: ownerID,
            domain: domain,
            default: defaultValue
        )
    }

    static func DownloadKey<Value: Codable>(always: Value) -> Key<Value> {
        Key(always: always)
    }
}

// MARK: - Values

extension StoredValues.Keys {

    enum Download {

        static func item(id: String) -> Key<DownloadItemDto?> {
            DownloadKey(
                "item",
                ownerID: id,
                domain: "download",
                default: nil
            )
        }

        static func state(id: String) -> Key<DownloadState> {
            DownloadKey(
                "state",
                ownerID: id,
                domain: "download-state",
                default: .queued
            )
        }

        static func resumeData(id: String) -> Key<Data?> {
            DownloadKey(
                "resumeData",
                ownerID: id,
                domain: "download-resume",
                default: nil
            )
        }

        static var queueIDs: Key<[String]> {
            guard let currentUser = Container.shared.currentUserSession()?.user else {
                return Key(always: [])
            }

            return DownloadKey(
                "queueIDs",
                ownerID: currentUser.id,
                domain: "download-queue",
                default: []
            )
        }

        static var completedIDs: Key<[String]> {
            guard let currentUser = Container.shared.currentUserSession()?.user else {
                return Key(always: [])
            }

            return DownloadKey(
                "completedIDs",
                ownerID: currentUser.id,
                domain: "download-completed",
                default: []
            )
        }
    }
}
