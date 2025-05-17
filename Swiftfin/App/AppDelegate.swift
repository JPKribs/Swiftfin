//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2025 Jellyfin & Jellyfin Contributors
//

import AVFAudio
import CoreStore
import Defaults
import Factory
import Logging
import Pulse
import PulseLogHandler
import SwiftUI
import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {

    private var toastPresentationController: ToastPresentationController?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {

        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playback)
        } catch {
            print("setting category AVAudioSessionCategoryPlayback failed")
        }

        let toastManager = Container.shared.toastManager()
        self.toastPresentationController = ToastPresentationController(toastManager: toastManager)

        return true
    }
}
