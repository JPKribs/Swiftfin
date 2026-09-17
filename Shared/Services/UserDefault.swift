//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Defaults
import FactoryKit
import Foundation

enum UserDefault {

    static let app = suite("swiftfinApp")

    static let id: String = {
        let keychain = Container.shared.keychainService()

        if let userID = keychain.get("userID") {
            return userID
        }

        let newUserID = UUID().uuidString

        keychain.set(newUserID, forKey: "userID")
        migrateLegacySuites(to: newUserID)

        return newUserID
    }()

    static var currentUser: UserDefaults {
        switch Defaults[.lastSignedInUserID] {
        case .signedOut:
            user("default")
        case let .signedIn(userID):
            user(userID)
        }
    }

    static func user(_ id: String) -> UserDefaults {
        suite(id)
    }

    static func suite(_ name: String) -> UserDefaults {
        UserDefaults(suiteName: "\(id).\(name)")!
    }

    // TODO: Remove in 1.8.X
    private static func migrateLegacySuites(to id: String) {
        let legacyAppSuite = UserDefaults(suiteName: "swiftfinApp")!
        let servers = Defaults[Defaults.Key<[ServerState]>("servers", default: [], suite: legacyAppSuite)]
        let users = Defaults[Defaults.Key<[UserState]>("users", default: [], suite: legacyAppSuite)]

        for name in ["swiftfinApp", "default"] + servers.map(\.id) + users.map(\.id) {
            guard let domain = UserDefaults.standard.persistentDomain(forName: name) else { continue }

            UserDefaults.standard.setPersistentDomain(domain, forName: "\(id).\(name)")
            UserDefaults.standard.removePersistentDomain(forName: name)
        }
    }
}
