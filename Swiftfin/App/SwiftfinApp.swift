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

// MARK: - Passthrough Toast Support

final class PassthroughWindow: UIWindow {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hitView = super.hitTest(point, with: event)
        return hitView is ToastContainerHostingView ? hitView : nil
    }
}

final class ToastContainerHostingView: UIView {}

// MARK: - Toast Presentation Controller

class ToastPresentationController {
    private var toastWindow: UIWindow?
    private let toastManager: ToastManager
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
        guard toastWindow == nil else { return }

        guard let windowScene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }) as? UIWindowScene
        else {
            print("ToastPresentationController: No active window scene found to present toasts.")
            return
        }

        let passthroughWindow = PassthroughWindow(windowScene: windowScene)
        passthroughWindow.windowLevel = .alert
        passthroughWindow.backgroundColor = .clear

        let toastController = UIHostingController(
            rootView: EmptyView().toastContainer()
        )
        toastController.view.backgroundColor = .clear

        let containerView = ToastContainerHostingView()
        containerView.backgroundColor = .clear
        containerView.frame = passthroughWindow.bounds
        containerView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        toastController.view.frame = containerView.bounds
        toastController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        containerView.addSubview(toastController.view)

        let rootViewController = UIViewController()
        rootViewController.view = containerView
        rootViewController.view.backgroundColor = .clear

        passthroughWindow.rootViewController = rootViewController
        passthroughWindow.makeKeyAndVisible()

        self.toastWindow = passthroughWindow
    }

    private func hideToastWindow() {
        toastWindow?.isHidden = true
        toastWindow = nil
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
