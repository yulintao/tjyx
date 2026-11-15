import SwiftUI
import Foundation
import UIKit

// MARK: - 用户协议与隐私说明 (Legal Document Sheet)

/// Data controls remain reachable without a paid entitlement.
struct PersonalProfileDataView: View {
    @ObservedObject private var profile = UserKuaProfileManager.shared
    @ObservedObject private var lang = LocalizationManager.shared
    @State private var showDeleteConfirmation = false

    var body: some View {
        List {
            Section {
                Text(lang.t("profile_data_notice"))
                    .font(.system(size: 13)).foregroundColor(.secondary)
            }
            Section(header: Text(lang.t("profile_data_members"))) {
                if profile.familyMembers.isEmpty { Text(lang.t("profile_data_empty")) }
                ForEach(profile.familyMembers) { member in
                    HStack {
                        Text(member.displayName)
                        Spacer()
                        Button(role: .destructive) { profile.removeFamilyMember(id: member.id) } label: {
                            Image(systemName: "trash")
                                .frame(minWidth: 44, minHeight: 44)
                        }.buttonStyle(.plain)
                            .accessibilityLabel(lang.t("profile_data_delete_member") + " " + member.displayName)
                    }
                }
            }
            Section(footer: Text(lang.t("profile_data_delete_note"))) {
                Button(lang.t("profile_data_delete_all"), role: .destructive) { showDeleteConfirmation = true }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(lang.t("profile_data_title"))
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(lang.t("profile_data_delete_all"), isPresented: $showDeleteConfirmation,
                            titleVisibility: .visible) {
            Button(lang.t("profile_data_delete_all"), role: .destructive) { profile.deleteAllPersonalProfiles() }
            Button(lang.t("cancel"), role: .cancel) {}
        } message: { Text(lang.t("profile_data_delete_note")) }
    }
}
