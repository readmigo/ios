import SwiftUI

struct WelcomeStepView: View {
    let onContinue: () -> Void

    @State private var animateIcon = false
    @State private var animateText = false
    @State private var animateButton = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Welcome icon
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 160, height: 160)

                Image(systemName: "hand.wave.fill")
                    .font(.system(size: 72))
                    .foregroundColor(.accentColor)
                    .rotationEffect(.degrees(animateIcon ? 10 : -10))
            }
            .scaleEffect(animateIcon ? 1.0 : 0.8)
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                    animateIcon = true
                }
                // Wave animation
                withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true).delay(0.6)) {
                    animateIcon = true
                }
            }

            // Welcome text
            VStack(spacing: 16) {
                Text("onboarding.welcome.title".localized)
                    .font(.title.bold())
                    .multilineTextAlignment(.center)

                Text("onboarding.welcome.subtitle".localized)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .opacity(animateText ? 1 : 0)
            .offset(y: animateText ? 0 : 20)
            .onAppear {
                withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
                    animateText = true
                }
            }

            Spacer()

            // Features list
            VStack(alignment: .leading, spacing: 16) {
                FeatureRow(
                    icon: "book.fill",
                    title: "onboarding.feature1.title".localized,
                    description: "onboarding.feature1.description".localized
                )

                FeatureRow(
                    icon: "brain",
                    title: "onboarding.feature2.title".localized,
                    description: "onboarding.feature2.description".localized
                )

                FeatureRow(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "onboarding.feature3.title".localized,
                    description: "onboarding.feature3.description".localized
                )
            }
            .padding(.horizontal, 24)
            .opacity(animateText ? 1 : 0)

            Spacer()

            // Continue button
            Button(action: onContinue) {
                Text("onboarding.getStarted".localized)
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color.accentColor)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
            .opacity(animateButton ? 1 : 0)
            .offset(y: animateButton ? 0 : 20)
            .onAppear {
                withAnimation(.easeOut(duration: 0.5).delay(0.5)) {
                    animateButton = true
                }
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 40, height: 40)
                .background(Color.accentColor.opacity(0.1))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }
}
