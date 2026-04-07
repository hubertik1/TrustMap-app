import SwiftUI

struct ProfileView: View {
    @ObservedObject private var container: AppContainer
    @ObservedObject private var refreshCenter: AppRefreshCenter
    @StateObject private var viewModel: ProfileViewModel
    @State private var isPresentingEditProfile = false

    init(container: AppContainer) {
        self.container = container
        self.refreshCenter = container.refreshCenter
        _viewModel = StateObject(
            wrappedValue: ProfileViewModel(
                refreshCenter: container.refreshCenter,
                sessionStore: container.sessionStore,
                userRepository: container.userRepository,
                placeReviewRepository: container.placeReviewRepository,
                dishReviewRepository: container.dishReviewRepository
            )
        )
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                LoadingStateView(title: "Loading profile")
            } else if let errorMessage = viewModel.errorMessage {
                ErrorStateView(message: errorMessage) {
                    Task { await viewModel.load() }
                }
            } else if let user = viewModel.user ?? container.sessionStore.currentUser {
                List {
                    Section {
                        HStack(spacing: 16) {
                            AvatarView(name: user.displayName, size: 72)

                            VStack(alignment: .leading, spacing: 6) {
                                Text(user.displayName)
                                    .font(.title3.weight(.semibold))

                                Text("@\(user.handle)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                if let bio = user.bio?.trimmingCharacters(in: .whitespacesAndNewlines),
                                   !bio.isEmpty {
                                    Text(bio)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }

                                Button("Edit Profile") {
                                    viewModel.prepareProfileEditor()
                                    isPresentingEditProfile = true
                                }
                                .buttonStyle(.bordered)
                                .padding(.top, 6)
                            }
                        }
                    }

                    Section {
                        NavigationLink {
                            MyPlaceReviewsView(
                                reviews: viewModel.placeReviews,
                                placeNames: viewModel.placeNames,
                                onDelete: { review in
                                    try await viewModel.deletePlaceReview(review)
                                }
                            )
                        } label: {
                            LabeledContent("Rated Places", value: "\(viewModel.stats.ratedPlacesCount)")
                        }

                        NavigationLink {
                            MyDishReviewsView(
                                reviews: viewModel.dishReviews,
                                placeNames: viewModel.placeNames,
                                onDelete: { review in
                                    try await viewModel.deleteDishReview(review)
                                }
                            )
                        } label: {
                            LabeledContent("Reviewed Dishes", value: "\(viewModel.stats.reviewedDishesCount)")
                        }
                    }

                    Section {
                        NavigationLink("Settings") {
                            SettingsView(container: container)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            } else {
                EmptyStateView(
                    title: "Profile Unavailable",
                    message: "TrustMap could not load your account data yet. Pull to retry or reopen the app.",
                    systemImage: "person.crop.circle.badge.exclamationmark"
                )
            }
        }
        .navigationTitle("Profile")
        .task(id: refreshCenter.globalRevision) {
            await viewModel.load()
        }
        .sheet(isPresented: $isPresentingEditProfile) {
            NavigationStack {
                ProfileEditorSheet(viewModel: viewModel)
            }
        }
    }
}

private struct ProfileEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ProfileViewModel

    var body: some View {
        Form {
            Section("Profile") {
                VStack(alignment: .leading, spacing: 10) {
                    TextField(
                        text: $viewModel.editedDisplayName,
                        prompt: Text("Display name").foregroundStyle(.secondary)
                    ) {
                        EmptyView()
                    }
                    .textFieldStyle(.plain)
                    .font(.body)
                    .textInputAutocapitalization(.words)

                    Divider()

                    HStack(spacing: 12) {
                        TextField(
                            text: $viewModel.editedHandle,
                            prompt: Text("Handle").foregroundStyle(.secondary)
                        ) {
                            EmptyView()
                        }
                        .textFieldStyle(.plain)
                        .font(.body)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                        if !viewModel.editedHandleSuffix.isEmpty {
                            Text(viewModel.editedHandleSuffix)
                                .font(.body.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }

                    Divider()
                }
                .listRowSeparator(.hidden)

                TextField("Bio", text: $viewModel.editedBio, axis: .vertical)
                    .lineLimit(3...5)
            }
        }
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                if viewModel.isSavingProfile {
                    ProgressView()
                } else {
                    Button("Save") {
                        Task {
                            let didSave = await viewModel.saveProfileChanges()
                            if didSave {
                                dismiss()
                            }
                        }
                    }
                }
            }
        }
        .alert(
            "Unable to Save Profile",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}

#Preview {
    NavigationStack {
        ProfileView(container: PreviewAppFactory.makeContainer())
    }
}
