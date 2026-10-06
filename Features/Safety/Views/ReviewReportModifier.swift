import SwiftUI

struct ReviewReportModifier: ViewModifier {
    let reviewID: UUID
    let reviewType: String
    let repository: SafetyRepository?
    @State private var showsReportConfirmation = false
    @State private var isReporting = false
    @State private var hasReported = false
    @State private var resultTitle = "Couldn't Report Review"
    @State private var resultMessage: String?

    @ViewBuilder
    func body(content: Content) -> some View {
        if repository != nil {
            content
                .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: PlaceDetailVisualSystem.Metrics.cardCornerRadius))
                .contextMenu {
                    Button(hasReported ? "Report Submitted" : "Report Review", systemImage: "flag", role: .destructive) {
                        showsReportConfirmation = true
                    }
                    .disabled(isReporting || hasReported)
                }
                .accessibilityElement(children: .contain)
                .accessibilityAction(named: Text("Report Review")) {
                    guard !isReporting, !hasReported else { return }
                    showsReportConfirmation = true
                }
                .confirmationDialog("Report this review?", isPresented: $showsReportConfirmation, titleVisibility: .visible) {
                    Button("Report Review", role: .destructive) {
                        Task { await submitReport() }
                    }
                } message: {
                    Text("The review and its photos will be sent to TrustMap for moderation.")
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
            resultTitle = "Report Submitted"
            resultMessage = "Your report has been received for review."
        } catch {
            resultTitle = "Couldn't Report Review"
            resultMessage = AppError.wrap(error).errorDescription
        }
    }
}
