//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2024 Jellyfin & Jellyfin Contributors
//

import Combine
import Factory
import Foundation
import JellyfinAPI
import UIKit

extension Container {
    var notificationCenter: Factory<NotificationCenter> {
        self { NotificationCenter.default }.singleton
    }
}

enum Notifications {

    typealias Keys = _AnyKey

    class _AnyKey {
        typealias Key = Notifications.Key
    }

    final class Key<Payload>: _AnyKey {

        @Injected(\.notificationCenter)
        private var notificationCenter

        let name: Notification.Name

        var rawValue: String {
            name.rawValue
        }

        init(_ string: String) {
            self.name = Notification.Name(string)
        }

        init(_ name: Notification.Name) {
            self.name = name
        }

        func post(_ payload: Payload) {
            notificationCenter
                .post(
                    name: name,
                    object: nil,
                    userInfo: ["payload": payload]
                )
        }

        func post() where Payload == Void {
            notificationCenter
                .post(
                    name: name,
                    object: nil,
                    userInfo: nil
                )
        }

        var publisher: AnyPublisher<Payload, Never> {
            notificationCenter
                .publisher(for: name)
                .compactMap { notification in
                    notification.userInfo?["payload"] as? Payload
                }
                .eraseToAnyPublisher()
        }

        func subscribe(_ object: Any, selector: Selector) {
            notificationCenter.addObserver(object, selector: selector, name: name, object: nil)
        }
    }

    static subscript<Payload>(key: Key<Payload>) -> Key<Payload> {
        key
    }
}

// MARK: - Keys

extension Notifications.Key {

    // MARK: - Authentication

    static var didSignIn: Key<Void> {
        Key("didSignIn")
    }

    static var didSignOut: Key<Void> {
        Key("didSignOut")
    }

    // MARK: - App Flow

    static var processDeepLink: Key<Void> {
        Key("processDeepLink")
    }

    static var didPurge: Key<Void> {
        Key("didPurge")
    }

    static var didChangeCurrentServerURL: Key<ServerState> {
        Key("didChangeCurrentServerURL")
    }

    static var didSendStopReport: Key<Void> {
        Key("didSendStopReport")
    }

    static var didRequestGlobalRefresh: Key<Void> {
        Key("didRequestGlobalRefresh")
    }

    static var didFailMigration: Key<Void> {
        Key("didFailMigration")
    }

    // MARK: - Media Items

    /// - Payload: The new item with updated metadata.
    static var itemMetadataDidChange: Key<BaseItemDto> {
        Key("itemMetadataDidChange")
    }

    static var itemShouldRefresh: Key<(itemID: String, parentID: String?)> {
        Key("itemShouldRefresh")
    }

    /// - Payload: The ID of the deleted item.
    static var didDeleteItem: Key<String> {
        Key("didDeleteItem")
    }

    // MARK: - Server

    static var didConnectToServer: Key<ServerState> {
        Key("didConnectToServer")
    }

    static var didDeleteServer: Key<ServerState> {
        Key("didDeleteServer")
    }

    // MARK: - User

    static var didChangeUserProfileImage: Key<Void> {
        Key("didChangeUserProfileImage")
    }

    static var didAddServerUser: Key<UserDto> {
        Key("didAddServerUser")
    }

    // MARK: - Playback

    static var didStartPlayback: Key<Void> {
        Key("didStartPlayback")
    }

    // MARK: - UIApplication

    static var applicationDidEnterBackground: Key<Void> {
        Key(UIApplication.didEnterBackgroundNotification)
    }

    static var applicationWillEnterForeground: Key<Void> {
        Key(UIApplication.willEnterForegroundNotification)
    }

    static var applicationWillResignActive: Key<Void> {
        Key(UIApplication.willResignActiveNotification)
    }

    static var applicationWillTerminate: Key<Void> {
        Key(UIApplication.willTerminateNotification)
    }
}