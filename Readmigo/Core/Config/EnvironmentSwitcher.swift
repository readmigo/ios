import SwiftUI

/// A debug-only view for switching between environments
struct EnvironmentSwitcher: View {
    @ObservedObject private var environmentManager = EnvironmentManager.shared
    @State private var showConfirmation = false
    @State private var pendingEnvironment: AppEnvironment?

    var body: some View {
        #if DEBUG
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Environment")
                    .font(.headline)

                Spacer()

                if environmentManager.isSwitching {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }

            Text("Switching environments will sign you out and clear all cached data.")
                .font(.caption)
                .foregroundColor(.secondary)

            ForEach(AppEnvironment.allCases) { env in
                EnvironmentRow(
                    environment: env,
                    isSelected: environmentManager.current == env,
                    isDisabled: environmentManager.isSwitching,
                    onSelect: {
                        if env == .production && environmentManager.current != .production {
                            pendingEnvironment = env
                            showConfirmation = true
                        } else {
                            environmentManager.switchEnvironment(to: env)
                        }
                    }
                )
            }

            if environmentManager.isSwitching {
                Text("Switching environment...")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .padding(.top, 4)
            }
        }
        .padding()
        .disabled(environmentManager.isSwitching)
        .alert("Switch to Production?", isPresented: $showConfirmation) {
            Button("Cancel", role: .cancel) {
                pendingEnvironment = nil
            }
            Button("Switch", role: .destructive) {
                if let env = pendingEnvironment {
                    environmentManager.switchEnvironment(to: env)
                }
                pendingEnvironment = nil
            }
        } message: {
            Text("You are about to switch to the production environment. This will affect real data and sign you out.")
        }
        #else
        EmptyView()
        #endif
    }
}

/// A row for displaying an environment option
private struct EnvironmentRow: View {
    let environment: AppEnvironment
    let isSelected: Bool
    let isDisabled: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                Circle()
                    .fill(environment.color)
                    .frame(width: 12, height: 12)

                VStack(alignment: .leading, spacing: 2) {
                    Text(environment.displayName)
                        .font(.body)
                        .foregroundColor(isDisabled ? .secondary : .primary)

                    Text(environment.apiBaseURL)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(environment.color)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? environment.color.opacity(0.1) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? environment.color : Color.gray.opacity(0.3), lineWidth: 1)
            )
            .opacity(isDisabled && !isSelected ? 0.5 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isDisabled)
    }
}

// MARK: - Preview

#if DEBUG
struct EnvironmentSwitcher_Previews: PreviewProvider {
    static var previews: some View {
        EnvironmentSwitcher()
            .previewLayout(.sizeThatFits)
    }
}
#endif
