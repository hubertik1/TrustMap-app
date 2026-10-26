import SwiftUI

struct DemoAccessView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: WelcomeViewModel
    @State private var username = ""
    @State private var password = ""
    @FocusState private var focusedField: Field?

    private enum Field {
        case username, password
    }

    private var canSignIn: Bool {
        !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !password.isEmpty && !viewModel.isSigningIn
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(L10n.demoUsername, text: $username)
                        .textContentType(.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .username)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .password }
                        .accessibilityIdentifier("demoUsername")

                    SecureField(L10n.demoPassword, text: $password)
                        .textContentType(.password)
                        .focused($focusedField, equals: .password)
                        .submitLabel(.go)
                        .onSubmit { signIn() }
                        .accessibilityIdentifier("demoPassword")
                } footer: {
                    Text(L10n.demoAccessDescription)
                }
                .disabled(viewModel.isSigningIn)

                if let error = viewModel.demoErrorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .accessibilityLabel(error)
                    }
                }

                Section {
                    Button(action: signIn) {
                        HStack {
                            Text(L10n.demoSignIn)
                            Spacer()
                            if viewModel.isSigningIn {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(!canSignIn)
                    .accessibilityIdentifier("demoSignIn")
                }

                if let termsOfServiceURL = AppConfiguration.termsOfServiceURL {
                    Section {
                        Link(L10n.termsOfService, destination: termsOfServiceURL)
                    }
                }
            }
            .navigationTitle(L10n.demoAccess)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) { dismiss() }
                        .disabled(viewModel.isSigningIn)
                }
            }
        }
        .interactiveDismissDisabled(viewModel.isSigningIn)
        .onAppear { viewModel.clearDemoError() }
    }

    private func signIn() {
        guard canSignIn else { return }
        focusedField = nil
        Task {
            if await viewModel.signInToDemo(
                username: username.trimmingCharacters(in: .whitespacesAndNewlines), password: password
            ) {
                password = ""
                dismiss()
            }
        }
    }
}
