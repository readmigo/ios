import SwiftUI

/// Import progress overlay view
struct ImportProgressView: View {
    @ObservedObject var viewModel: ImportViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    // Prevent dismissal during active import
                }

            // Progress card
            VStack(spacing: 24) {
                // Icon based on state
                stateIcon
                    .font(.system(size: 48))
                    .foregroundColor(stateColor)

                // Progress ring (for uploading/processing)
                if case .uploading = viewModel.state {
                    progressRing
                } else if case .processing = viewModel.state {
                    progressRing
                }

                // Status text
                Text(viewModel.state.displayMessage)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)

                // Action buttons
                HStack(spacing: 16) {
                    if viewModel.state.isActive {
                        Button("import.action.cancel".localized) {
                            viewModel.cancelImport()
                        }
                        .buttonStyle(.bordered)
                    }

                    if case .completed(let book) = viewModel.state {
                        Button("import.action.viewBook".localized) {
                            dismiss()
                            // Navigate to book detail would happen here
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    if case .failed = viewModel.state {
                        Button("import.action.retry".localized) {
                            viewModel.retry()
                        }
                        .buttonStyle(.borderedProminent)

                        Button("import.action.close".localized) {
                            dismiss()
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemBackground))
                    .shadow(radius: 20)
            )
            .padding(40)
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var stateIcon: some View {
        switch viewModel.state {
        case .idle:
            Image(systemName: "doc.badge.plus")
        case .checkingPermission:
            ProgressView()
                .scaleEffect(1.5)
        case .selectingFile:
            Image(systemName: "folder.badge.plus")
        case .preparing:
            ProgressView()
                .scaleEffect(1.5)
        case .uploading:
            Image(systemName: "arrow.up.circle")
        case .processing:
            Image(systemName: "gearshape.2")
        case .completed:
            Image(systemName: "checkmark.circle.fill")
        case .failed:
            Image(systemName: "xmark.circle.fill")
        }
    }

    private var stateColor: Color {
        switch viewModel.state {
        case .completed:
            return .green
        case .failed:
            return .red
        default:
            return .accentColor
        }
    }

    @ViewBuilder
    private var progressRing: some View {
        ZStack {
            Circle()
                .stroke(Color(.systemGray4), lineWidth: 8)

            Circle()
                .trim(from: 0, to: viewModel.progress)
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.3), value: viewModel.progress)

            Text("\(Int(viewModel.progress * 100))%")
                .font(.title2.bold())
                .foregroundColor(.primary)
        }
        .frame(width: 100, height: 100)
    }
}
