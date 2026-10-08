import SwiftUI

struct ReviewReportModifier: ViewModifier {
    let reviewID: UUID
    let reviewType: String
    let repository: SafetyRepository?
    @State private var showsReportConfirmation = false
    @State private var isReporting = false
    @State private var hasReported = false
    @State private var resultTitle = L10n.couldnTReportReview
    @State private var resultMessage: String?

    @ViewBuilder
    func body(content: Content) -> some View {
        if repository != nil {
            content
                .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: PlaceDetailVisualSystem.Metrics.cardCornerRadius))
                .contextMenu {
                    Button(hasReported ? L10n.reportSubmitted : L10n.reportReview, systemImage: "flag", role: .destructive) {
                        showsReportConfirmation = true
                    }
                    .disabled(isReporting || hasReported)
                }
                .accessibilityElement(children: .contain)
                .accessibilityAction(named: Text(L10n.reportReview)) {
                    guard !isReporting, !hasReported else { return }
                    showsReportConfirmation = true
                }
                .confirmationDialog(L10n.reportThisReview, isPresented: $showsReportConfirmation, titleVisibility: .visible) {
                    Button(L10n.reportReview, role: .destructive) {
                        Task { await submitReport() }
                    }
                } message: {
                    Text(L10n.theReviewAndItsPhotosWillBeSentToTrustmapForModeration)
                }
                .alert(resultTitle, isPresented: Binding(
                    get: { resultMessage != nil }, set: { if !$0 { resultMessage = nil } }
                )) {} message: {
                    Text(resultMessage ?? "")
                }
        } else {
            content
        }
    }

    private func submitReport() async {
        guard !isReporting, !hasReported, let repository else { return }
        isReporting = true
        defer { isReporting = false }
        do {
            try await repository.report(reviewID: reviewID, reviewType: reviewType)
            hasReported = true
            resultTitle = L10n.reportSubmitted
            resultMessage = L10n.yourReportHasBeenReceivedForReview
        } catch {
            resultTitle = L10n.couldnTReportReview
            resultMessage = AppError.wrap(error).errorDescription
        }
    }
}
