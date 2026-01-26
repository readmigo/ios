import SwiftUI

/// Feedback rating component for rating support responses
struct FeedbackRatingView: View {
    let onRate: (FeedbackRating.Rating) -> Void

    @State private var hasRated = false
    @State private var selectedRating: FeedbackRating.Rating?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if hasRated {
                // Thank you message
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)

                    Text("messaging.thanksFeedback".localized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            } else {
                // Rating prompt
                Text("messaging.helpful".localized)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                HStack(spacing: 16) {
                    // Helpful button
                    Button {
                        selectedRating = .helpful
                        hasRated = true
                        onRate(.helpful)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "hand.thumbsup.fill")
                            Text("messaging.yes".localized)
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(20)
                    }

                    // Not helpful button
                    Button {
                        selectedRating = .notHelpful
                        hasRated = true
                        onRate(.notHelpful)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "hand.thumbsdown.fill")
                            Text("messaging.no".localized)
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.red)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(20)
                    }
                }
            }
        }
    }
}
