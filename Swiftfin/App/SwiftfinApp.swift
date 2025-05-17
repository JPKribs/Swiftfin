//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2025 Jellyfin & Jellyfin Contributors
//

import Combine // Required for AnyCancellable
import CoreStore
import Defaults
import Factory
import Logging
import Nuke
import PreferencesView
import Pulse
import PulseLogHandler
import SwiftUI

// MARK: - ToastManager Expectation

// IMPORTANT: Your existing ToastManager class (which should be an ObservableObject)
// needs a property like this:
//
// @Published var hasVisibleMessages: Bool = false
//
// This property should be updated to `true` when `messages.filter { !$0.isRead }` is not empty,
// and `false` when it is empty. The ToastPresentationController relies on this.
// For example, in your ToastManager:
/*
 class ToastManager: ObservableObject {
     @Published var messages: [ToastMessageDataModel] = [] { // Assuming ToastMessageDataModel is your data struct
         didSet {
             self.hasVisibleMessages = !messages.filter { !$0.isRead }.isEmpty
         }
     }
     @Published var hasVisibleMessages: Bool = false // This will be updated by the messages setter

     // ... your existing methods like addToast, markAsRead, dismiss ...
     // Ensure these methods correctly update the messages array, which in turn updates hasVisibleMessages.
     func addToast(message: String /* , other params */ ) {
         let newToast = ToastMessageDataModel(message: message, /* ... */ )
         messages.append(newToast)
     }

     func markAsRead(_ id: UUID) {
         if let index = messages.firstIndex(where: { $0.id == id && !$0.isRead }) {
             // messages[index].isRead = true // Or however you handle it
             // Potentially remove or update state that affects 'hasVisibleMessages'
             // For simplicity, often dismissed after read.
         }
         // Crucially, update messages or hasVisibleMessages
         self.hasVisibleMessages = !messages.filter { !$0.isRead }.isEmpty
     }

     func dismiss(_ id: UUID) {
         messages.removeAll { $0.id == id }
         // messages didSet will update hasVisibleMessages
     }
 }

 // Assuming ToastMessageDataModel is your actual data structure for a toast
 struct ToastMessageDataModel: Identifiable {
     let id = UUID()
     var message: String
     // var style: ToastStyle
     // var duration: TimeInterval
     var isRead: Bool = false
 }
 */

// MARK: - Toast Presentation Controller

// This controller manages a separate UIWindow for displaying toasts above all other content.
class ToastPresentationController {
    private var toastWindow: UIWindow?
    private let toastManager: ToastManager // Your existing ToastManager
    private var cancellables = Set<AnyCancellable>()

    init(toastManager: ToastManager) {
        self.toastManager = toastManager

        toastManager.$messages
            .receive(on: DispatchQueue.main)
            .sink { [weak self] messages in
                if messages.contains(where: { !$0.isRead }) {
                    self?.showToastWindow()
                } else {
                    self?.hideToastWindow()
                }
            }
            .store(in: &cancellables)
    }

    private func showToastWindow() {
        guard toastWindow == nil else { return } // Show only if not already visible

        // Find an active scene to attach the window to.
        guard let windowScene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }) as? UIWindowScene
        else {
            print("ToastPresentationController: No active window scene found to present toasts.")
            return
        }

        let newWindow = UIWindow(windowScene: windowScene)
        newWindow.windowLevel = .alert // Ensures it's above most other content, including standard alerts and sheets.
        newWindow.backgroundColor = .clear // Important for transparency

        // Use your existing ToastContainerView.
        // The .edgesIgnoringSafeArea(.all) on the HostingController's root view can help
        // if the ToastContainerView needs to manage its own safe area insets fully.
        let toastHostingController = UIHostingController(
            rootView: EmptyView()
                .toastContainer()
        )
        toastHostingController.view.backgroundColor = .clear

        newWindow.rootViewController = toastHostingController
        newWindow.makeKeyAndVisible()
        self.toastWindow = newWindow
    }

    private func hideToastWindow() {
        toastWindow?.isHidden = true
        toastWindow = nil // Release the window so it can be deallocated.
    }
}

// MARK: - Swiftfin Application

@main
struct SwiftfinApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) // AppDelegate is now setup for toasts
    var appDelegate

    @StateObject
    private var valueObservation = ValueObservation() // ValueObservation definition assumed to exist

    // This instance is used by your app's views to *trigger* toasts.
    // The actual presentation is handled by ToastPresentationController.
    @StateObject
    private var globalToastManager = Container.shared.toastManager()

    init() {
        // CoreStore
        CoreStoreDefaults.dataStack = SwiftfinStore.dataStack
        CoreStoreDefaults.logger = SwiftfinCorestoreLogger()

        // Logging
        LoggingSystem.bootstrap { label in
            var loggers: [LogHandler] = [PersistentLogHandler(label: label).withLogLevel(.trace)]
            #if DEBUG
            loggers.append(SwiftfinConsoleLogger())
            #endif
            return MultiplexLogHandler(loggers)
        }

        // Nuke
        ImageCache.shared.costLimit = 1024 * 1024 * 200 // 200 MB
        ImageCache.shared.ttl = 300 // 5 min

        ImageDecoderRegistry.shared.register { context in
            guard let mimeType = context.urlResponse?.mimeType else { return nil }
            return mimeType.contains("svg") ? ImageDecoders.Empty() : nil
        }

        ImagePipeline.shared = .Swiftfin.posters

        // UIKit
        UIScrollView.appearance().keyboardDismissMode = .onDrag
        UITabBar.appearance().scrollEdgeAppearance = UITabBarAppearance(idiom: .unspecified)

        // Swiftfin
        if Defaults[.signOutOnClose] {
            Defaults[.lastSignedInUserID] = .signedOut
        }
    }

    @ViewBuilder
    private var versionedView: some View {
        if #available(iOS 16, *) {
            PreferencesView {
                MainCoordinator()
                    .view()
                    .supportedOrientations(UIDevice.isPad ? .allButUpsideDown : .portrait)
            }
        } else {
            PreferencesView {
                PreferencesView {
                    MainCoordinator()
                        .view()
                        .supportedOrientations(UIDevice.isPad ? .allButUpsideDown : .portrait)
                }
                .ignoresSafeArea()
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            versionedView
                .ignoresSafeArea()
                .onNotification(.applicationDidEnterBackground) {
                    Defaults[.backgroundTimeStamp] = Date.now
                }
                .onNotification(.applicationWillEnterForeground) {

                    // TODO: needs to check if any background playback is happening
                    //       - atow, background video playback isn't officially supported
                    let backgroundedInterval = Date.now.timeIntervalSince(Defaults[.backgroundTimeStamp])

                    if Defaults[.signOutOnBackground], backgroundedInterval > Defaults[.backgroundSignOutInterval] {
                        Defaults[.lastSignedInUserID] = .signedOut
                        Container.shared.currentUserSession.reset()
                        Notifications[.didSignOut].post()
                    }
                }
        }
    }
}

extension UINavigationController {
    override open func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        navigationBar.topItem?.backButtonDisplayMode = .minimal
    }
}

// MARK: - Assumed Definitions (Comments for clarity - Your project has these)

// The following types are assumed to be defined in your project:
// - ValueObservation: An ObservableObject.
// - SwiftfinStore.dataStack: Your CoreStore DataStack.
// - SwiftfinCorestoreLogger: Your CoreStoreLogger.
// - PersistentLogHandler, SwiftfinConsoleLogger: Your LogHandlers.
// - ImagePipeline.Swiftfin.posters: Your Nuke ImagePipeline configuration.
// - Defaults[.someKey]: Your Defaults keys and setup.
// - PreferencesView: Your custom PreferencesView.
// - MainCoordinator().view(): Your main view from the coordinator.
// - Notifications.someNotification: Your custom NotificationDescriptors.
// - Container.shared.toastManager(): Factory method returning your ToastManager instance.
//   (Crucially, this ToastManager must be an ObservableObject with a publisher like `$hasVisibleMessages`)
// - Container.shared.currentUserSession: Your user session management.
// - ToastMessage (Data Model): An Identifiable struct/class holding toast info (e.g., id, message, style, isRead).
// - ToastMessage (View): A View struct that displays a single toast item.
