import SwiftUI

/// Sign in / sign up screen shown when no user is authenticated.
struct AuthView: View {
    @EnvironmentObject private var app: AppModel

    @State private var mode: Mode = .signIn
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""

    enum Mode { case signIn, signUp }

    private var canSubmit: Bool {
        !email.isEmpty && password.count >= 6 && (mode == .signIn || !name.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    var body: some View {
        ZStack {
            Theme.primaryBackground.ignoresSafeArea()

            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(Theme.accent)
                    Text("Shrub")
                        .font(.largeTitle.weight(.semibold))
                    Text(mode == .signIn ? "Welcome back" : "Create your account")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 14) {
                    if mode == .signUp {
                        field("Name", text: $name, systemImage: "person")
                            .textContentType(.name)
                    }
                    field("Email", text: $email, systemImage: "envelope")
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                    field("Password (6+ characters)", text: $password, systemImage: "lock", secure: true)
                        .textContentType(mode == .signUp ? .newPassword : .password)
                }

                if let error = app.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                Button(action: submit) {
                    HStack {
                        if app.isWorking { ProgressView().tint(.white) }
                        Text(mode == .signIn ? "Sign In" : "Sign Up")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(canSubmit ? Theme.accent : Color.gray.opacity(0.4),
                                in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .foregroundStyle(.white)
                }
                .disabled(!canSubmit || app.isWorking)

                Button {
                    mode = (mode == .signIn) ? .signUp : .signIn
                    app.errorMessage = nil
                } label: {
                    Text(mode == .signIn ? "New here? Create an account" : "Already have an account? Sign in")
                        .font(.subheadline)
                        .foregroundStyle(Theme.accent)
                }
            }
            .padding(28)
        }
    }

    private func submit() {
        Task {
            switch mode {
            case .signIn: await app.signIn(email: email, password: password)
            case .signUp: await app.signUp(name: name, email: email, password: password)
            }
        }
    }

    private func field(_ placeholder: String, text: Binding<String>, systemImage: String, secure: Bool = false) -> some View {
        HStack {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 22)
            if secure {
                SecureField(placeholder, text: text)
            } else {
                TextField(placeholder, text: text)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
