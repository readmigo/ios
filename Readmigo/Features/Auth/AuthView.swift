import SwiftUI
import AuthenticationServices

struct AuthView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var logoScale: CGFloat = 0.8
    @State private var contentOpacity: Double = 0
    @State private var showEmailAuth = false

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [.brandGradientStart, .brandGradientMiddle, .brandGradientEnd]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                // Logo and Title
                VStack(spacing: 16) {
                    Image(systemName: "book.fill")
                        .font(.system(size: 160))
                        .foregroundColor(.white)
                        .scaleEffect(logoScale)
                        .onAppear {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                                logoScale = 1.0
                            }
                        }

                    Text("app.name".localized)
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text("auth.welcome.subtitle".localized)
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                VStack(spacing: 16) {
                    SignInWithAppleButton(
                        onRequest: { request in
                            request.requestedScopes = [.fullName, .email]
                        },
                        onCompletion: { result in
                            switch result {
                            case .success(let authorization):
                                Task {
                                    await authManager.signInWithApple(authorization: authorization)
                                }
                            case .failure(let error):
                                print("Apple Sign In failed: \(error)")
                            }
                        }
                    )
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 50)
                    .cornerRadius(10)

                    // Google Sign In button
                    Button(action: {
                        authManager.initiateGoogleSignIn()
                    }) {
                        HStack(spacing: 8) {
                            // Google logo (using SF Symbol as placeholder)
                            Image(systemName: "g.circle.fill")
                                .font(.title2)
                            Text("auth.button.signInGoogle".localized)
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.white)
                        .foregroundColor(.black)
                        .cornerRadius(10)
                    }
                    .disabled(authManager.isLoading)

                    // Email Sign In button
                    Button(action: {
                        showEmailAuth = true
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "envelope.fill")
                                .font(.title2)
                            Text("auth.button.signInEmail".localized)
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.white.opacity(0.2))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.white.opacity(0.5), lineWidth: 1)
                        )
                    }
                    .disabled(authManager.isLoading)

                    // Skip login - Guest mode
                    Button(action: {
                        authManager.enterGuestMode()
                    }) {
                        Text("auth.button.browseAsGuest".localized)
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.white.opacity(0.9))
                            .underline()
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal, 32)
                .opacity(contentOpacity)
                .onAppear {
                    withAnimation(.easeIn(duration: 0.4).delay(0.3)) {
                        contentOpacity = 1.0
                    }
                }

                // Terms and Privacy
                VStack(spacing: 4) {
                    Text("auth.terms.prefix".localized)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))

                    HStack(spacing: 4) {
                        Button("auth.terms.termsOfService".localized) {
                            openURL("https://readmigo.app/terms")
                        }
                        .font(.caption.weight(.medium))
                        .foregroundColor(.white.opacity(0.9))

                        Text("auth.terms.and".localized)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))

                        Button("auth.terms.privacyPolicy".localized) {
                            openURL("https://readmigo.app/privacy")
                        }
                        .font(.caption.weight(.medium))
                        .foregroundColor(.white.opacity(0.9))
                    }
                }
                .padding(.bottom, 32)
                .opacity(contentOpacity)

                Spacer()
            }

            // Loading overlay
            if authManager.isLoading {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()

                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
            }
        }
        .alert("common.error".localized, isPresented: .constant(authManager.error != nil)) {
            Button("common.ok".localized) {
                authManager.error = nil
            }
        } message: {
            if let error = authManager.error {
                Text(error)
            }
        }
        .sheet(isPresented: $showEmailAuth) {
            EmailAuthView()
                .environmentObject(authManager)
        }
    }

    private func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }
}
