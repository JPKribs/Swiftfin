//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2025 Jellyfin & Jellyfin Contributors
//

import Factory
import Foundation
import SwiftUI

struct NotificationsView: View {

    // MARK: - Environment

    @EnvironmentObject
    private var router: SettingsCoordinator.Router

    // MARK: - Toast Manager

    @Injected(\.toastManager)
    private var toastManager

    // MARK: - View State

    @State
    private var selectedToasts: Set<UUID> = []
    @State
    private var isEditing: Bool = false
    @State
    private var isPresentingDeleteConfirmation = false
    @State
    private var selectedToastType: ToastType? = nil

    // MARK: - Filtered Toasts

    private var filteredToasts: [Toast] {
        guard let selectedType = selectedToastType else {
            return toastManager.messages
        }

        return toastManager.messages.filter { $0.type == selectedType }
    }

    // MARK: - Body

    var body: some View {
        List {
            InsetGroupedListHeader(
                "Notifications",
                description: "L10n.notificationsDescription"
            )
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .padding(.vertical, 24)

            contentView
        }
        .listStyle(.plain)
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(isEditing)
        .navigationBarMenuButton(
            isHidden: isEditing && toastManager.messages.isNotEmpty
        ) {
            Section(L10n.management) {
                Button(L10n.edit, systemImage: "pencil") {
                    isEditing = true
                }
            }

            toastFilterButton
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                if isEditing {
                    navigationBarSelectView
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                if isEditing {
                    Button(L10n.cancel) {
                        isEditing.toggle()
                        UIDevice.impact(.light)
                        if !isEditing {
                            selectedToasts.removeAll()
                        }
                    }
                    .buttonStyle(.toolbarPill)
                }
            }
            ToolbarItem(placement: .bottomBar) {
                if isEditing {
                    Button(L10n.delete) {
                        isPresentingDeleteConfirmation = true
                    }
                    .buttonStyle(.toolbarPill(.red))
                    .disabled(selectedToasts.isEmpty)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
        .confirmationDialog(
            L10n.deleteSelectedConfirmation,
            isPresented: $isPresentingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            deleteSelectedToastsConfirmationActions
        } message: {
            Text("L10n.deleteSelectionNotificationsWarning")
        }
    }

    // MARK: - Content View

    @ViewBuilder
    private var contentView: some View {
        if filteredToasts.isEmpty {
            Text(L10n.none)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .listRowSeparator(.hidden)
                .listRowInsets(.zero)
        } else {
            ForEach(filteredToasts) { toast in
                NotificationRow(toast: toast) {
                    selectedToasts.insert(toast.id)
                } onDelete: {
                    selectedToasts.insert(toast.id)
                    isPresentingDeleteConfirmation = true
                }
                .environment(\.isEditing, isEditing)
                .environment(\.isSelected, selectedToasts.contains(toast.id))
                .listRowInsets(.edgeInsets)
            }
        }
    }

    // MARK: - Toast Filter Button

    @ViewBuilder
    private var toastFilterButton: some View {
        Menu(
            L10n.type,
            systemImage: selectedToastType?.systemImage ?? "list.bullet"
        ) {
            Picker(L10n.filters, selection: $selectedToastType) {
                Label(
                    L10n.all,
                    systemImage: "list.bullet"
                )
                .tag(nil as ToastType?)

                ForEach(ToastType.allCases, id: \.self) { type in
                    Label(
                        type.displayTitle,
                        systemImage: type.systemImage
                    )
                    .tag(type as ToastType?)
                }
            }
        }
    }

    // MARK: - Navigation Bar Select/Remove All Content

    @ViewBuilder
    private var navigationBarSelectView: some View {
        let isAllSelected: Bool = selectedToasts.count == filteredToasts.count

        Button(isAllSelected ? L10n.removeAll : L10n.selectAll) {
            if isAllSelected {
                selectedToasts = []
            } else {
                selectedToasts = Set(filteredToasts.map(\.id))
            }
        }
        .buttonStyle(.toolbarPill)
        .disabled(!isEditing)
    }

    // MARK: - Delete Selected Toasts Confirmation Actions

    @ViewBuilder
    private var deleteSelectedToastsConfirmationActions: some View {
        Button(L10n.cancel, role: .cancel) {
            selectedToasts.removeAll()
        }

        Button(L10n.confirm, role: .destructive) {
            for id in selectedToasts {
                toastManager.dismiss(id)
            }
            isEditing = false
            selectedToasts.removeAll()
        }
    }
}
