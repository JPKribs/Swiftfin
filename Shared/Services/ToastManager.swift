//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2025 Jellyfin & Jellyfin Contributors
//

import Combine
import Factory
import Foundation
import SwiftUI

// MARK: Factory registration

extension Container {
    var toastManager: Factory<ToastManager> { self { ToastManager() }.shared }
}

class ToastManager: ObservableObject {

    // MARK: - Logger

    @Injected(\.logService)
    private var logger

    // MARK: - Toast Messages

    @Published
    private(set) var messages: [Toast] = []

    // MARK: - Work Items

    private var cancellables = Set<AnyCancellable>()
    private var toastWorkItems: [UUID: DispatchWorkItem] = [:]

    // MARK: - Storage Key

    private let messageStorageKey = "stored_messages"

    // MARK: - Initialize

    fileprivate init() {
        loadMessages()

        logger.trace("ToastManager initialized")
    }

    // MARK: Send a New Toast

    func send(title: String, body: String, type: ToastType) {
        let toast = Toast(title: title, body: body, type: type, timestamp: Date())

        messages.append(toast)
        saveMessages()
        scheduleToastDismissal(for: toast)

        logger.trace("Toast sent: \(title)")
    }

    // MARK: - Mark Toast as Read

    func markAsRead(_ toastId: UUID) {
        if let index = messages.firstIndex(where: { $0.id == toastId }) {
            messages[index].isRead = true
            saveMessages()
        }
    }

    // MARK: - Delete Toast

    func dismiss(_ toastId: UUID) {
        if let index = messages.firstIndex(where: { $0.id == toastId }) {
            messages.remove(at: index)
            saveMessages()

            logger.trace("Toast removed: \(toastId)")
        }

        cancelToastDismissal(for: toastId)
    }

    // MARK: - Delete All Toasts

    func dismissAll() {
        for (id, _) in toastWorkItems {
            cancelToastDismissal(for: id)
        }

        messages.removeAll()
        saveMessages()

        logger.trace("All toasts removed")
    }

    // MARK: Toast Management

    private func scheduleToastDismissal(for toast: Toast) {
        cancelToastDismissal(for: toast.id)

        let task = DispatchWorkItem { [weak self] in
            DispatchQueue.main.async {
                self?.markAsRead(toast.id)

                if let index = self?.messages.firstIndex(where: { $0.id == toast.id }) {
                    self?.objectWillChange.send()
                    self?.messages[index].isRead = true
                    self?.saveMessages()
                }
            }
        }

        toastWorkItems[toast.id] = task
        DispatchQueue.main.asyncAfter(deadline: .now() + toast.duration, execute: task)
    }

    // MARK: - Cancel Deletion

    private func cancelToastDismissal(for toastId: UUID) {
        if let workItem = toastWorkItems[toastId] {
            workItem.cancel()
            toastWorkItems.removeValue(forKey: toastId)
        }
    }

    // MARK: Save Toast Message

    private func saveMessages() {
        do {
            let data = try JSONEncoder().encode(messages)
            UserDefaults.standard.set(data, forKey: messageStorageKey)
        } catch {
            logger.error("Failed to save toasts: \(error.localizedDescription)")
        }
    }

    // MARK: Load Toast Message

    private func loadMessages() {
        guard let data = UserDefaults.standard.data(forKey: messageStorageKey) else { return }

        do {
            let loadedMessages = try JSONDecoder().decode([Toast].self, from: data)
            messages = loadedMessages
            logger.trace("Loaded \(loadedMessages.count) toasts")
        } catch {
            logger.error("Failed to load toasts: \(error.localizedDescription)")
        }
    }
}
