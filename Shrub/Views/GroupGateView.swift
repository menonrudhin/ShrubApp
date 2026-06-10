import SwiftUI

/// Shown when the user is signed in but has no active group: create a new
/// shared group or join an existing one with an invite code.
struct GroupGateView: View {
    @EnvironmentObject private var app: AppModel

    @State private var newGroupName = ""
    @State private var joinCode = ""

    var body: some View {
        ZStack {
            Theme.primaryBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Expense groups")
                            .font(.title2.weight(.semibold))
                        Text("Create a shared group like “Family expenses,” or join one with an invite code.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if !app.groups.isEmpty {
                        card(title: "Your groups") {
                            ForEach(app.groups) { group in
                                Button {
                                    app.selectGroup(group.id)
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(group.name).foregroundStyle(.primary)
                                            Text("\(group.memberIds.count) member\(group.memberIds.count == 1 ? "" : "s")")
                                                .font(.caption).foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                                    }
                                    .padding(.vertical, 12)
                                }
                            }
                        }
                    }

                    card(title: "Create a group") {
                        TextField("Group name (e.g. Family expenses)", text: $newGroupName)
                            .padding(.vertical, 10)
                        actionButton("Create", enabled: !newGroupName.trimmingCharacters(in: .whitespaces).isEmpty) {
                            Task { await app.createGroup(name: newGroupName); newGroupName = "" }
                        }
                    }

                    card(title: "Join with a code") {
                        TextField("Invite code (e.g. FAM-7QX2K)", text: $joinCode)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .padding(.vertical, 10)
                        actionButton("Join", enabled: !joinCode.trimmingCharacters(in: .whitespaces).isEmpty) {
                            Task { await app.joinGroup(code: joinCode); joinCode = "" }
                        }
                    }

                    if let error = app.errorMessage {
                        Text(error).font(.caption).foregroundStyle(.red)
                    }

                    Button("Sign out", role: .destructive) { app.signOut() }
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                }
                .padding(24)
            }
        }
    }

    private func card<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func actionButton(_ title: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(enabled ? Theme.accent : Color.gray.opacity(0.4),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .foregroundStyle(.white)
        }
        .disabled(!enabled || app.isWorking)
    }
}
