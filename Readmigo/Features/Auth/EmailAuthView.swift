import SwiftUI

enum EmailAuthMode {
    case login
    case register
    case forgotPassword
}

struct EmailAuthView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss

    @State private var mode: EmailAuthMode = .login
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var showPassword = false
    @State private var showResetSentAlert = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [.brandGradientStart, .brandGradientMiddle, .brandGradientEnd]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 8) {
                            Image(systemName: "envelope.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.white)

                            Text(headerTitle)
                                .font(.title.bold())
                                .foregroundColor(.white)

                            Text(headerSubtitle)
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 40)

                        // Form
                        VStack(spacing: 16) {
                            // Display Name (register only)
                            if mode == .register {
                                TextField("auth.email.displayName".localized, text: $displayName)
                                    .textFieldStyle(AuthTextFieldStyle())
                                    .textContentType(.name)
                                    .autocapitalization(.words)
                            }

                            // Email
                            VStack(alignment: .leading, spacing: 4) {
                                TextField("auth.email.email".localized, text: $email)
                                    .textFieldStyle(AuthTextFieldStyle())
                                    .textContentType(.emailAddress)
                                    .keyboardType(.emailAddress)
                                    .autocapitalization(.none)
                                    .autocorrectionDisabled()

                                if !email.isEmpty && !isEmailValid {
                                    Text("auth.email.invalidEmail".localized)
                                        .font(.caption)
                                        .foregroundColor(.red.opacity(0.9))
                                        .padding(.leading, 4)
                                }
                            }

                            // Password (not for forgot password)
                            if mode != .forgotPassword {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        if showPassword {
                                            TextField("auth.email.password".localized, text: $password)
                                                .textContentType(mode == .register ? .newPassword : .password)
                                        } else {
                                            SecureField("auth.email.password".localized, text: $password)
                                                .textContentType(mode == .register ? .newPassword : .password)
                                        }

                                        Button(action: { showPassword.toggle() }) {
                                            Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                                                .foregroundColor(.gray)
                                        }
                                    }
                                    .textFieldStyle(AuthTextFieldStyle())

                                    if !password.isEmpty && password.count < 8 {
                                        Text("auth.email.passwordTooShort".localized)
                                            .font(.caption)
                                            .foregroundColor(.red.opacity(0.9))
                                            .padding(.leading, 4)
                                    }
                                }
                            }

                        }
                        .padding(.horizontal, 24)

                        // Action Button
                        Button(action: performAction) {
                            Group {
                                if authManager.isLoading {
                                    ProgressView()
                                        .tint(.brandGradientStart)
                                } else {
                                    Text(actionButtonTitle)
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.white)
                            .foregroundColor(.brandGradientMiddle)
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 24)
                        .disabled(!isFormValid || authManager.isLoading)
                        .opacity(isFormValid ? 1 : 0.6)

                        // Mode Switch
                        VStack(spacing: 12) {
                            if mode == .login {
                                Button("auth.email.forgotPassword".localized) {
                                    withAnimation { mode = .forgotPassword }
                                }
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.9))

                                HStack(spacing: 4) {
                                    Text("auth.email.noAccount".localized)
                                        .foregroundColor(.white.opacity(0.7))
                                    Button("auth.email.register".localized) {
                                        withAnimation { mode = .register }
                                    }
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                }
                                .font(.subheadline)
                            } else if mode == .register {
                                HStack(spacing: 4) {
                                    Text("auth.email.hasAccount".localized)
                                        .foregroundColor(.white.opacity(0.7))
                                    Button("auth.email.login".localized) {
                                        withAnimation { mode = .login }
                                    }
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                }
                                .font(.subheadline)
                            } else {
                                Button("auth.email.backToLogin".localized) {
                                    withAnimation { mode = .login }
                                }
                                .font(.subheadline)
                                .foregroundColor(.white)
                            }
                        }
                        .padding(.top, 8)

                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                    }
                }
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
        .alert("auth.email.resetSent".localized, isPresented: $showResetSentAlert) {
            Button("common.ok".localized) {
                dismiss()
            }
        } message: {
            Text("auth.email.resetSentMessage".localized)
        }
    }

    // MARK: - Computed Properties

    private var headerTitle: String {
        switch mode {
        case .login:
            return "auth.email.loginTitle".localized
        case .register:
            return "auth.email.registerTitle".localized
        case .forgotPassword:
            return "auth.email.forgotPasswordTitle".localized
        }
    }

    private var headerSubtitle: String {
        switch mode {
        case .login:
            return "auth.email.loginSubtitle".localized
        case .register:
            return "auth.email.registerSubtitle".localized
        case .forgotPassword:
            return "auth.email.forgotPasswordSubtitle".localized
        }
    }

    private var actionButtonTitle: String {
        switch mode {
        case .login:
            return "auth.email.loginButton".localized
        case .register:
            return "auth.email.registerButton".localized
        case .forgotPassword:
            return "auth.email.sendResetButton".localized
        }
    }

    private var isEmailValid: Bool {
        email.contains("@") && email.contains(".")
    }

    private var isFormValid: Bool {
        switch mode {
        case .login, .register:
            return isEmailValid && password.count >= 8
        case .forgotPassword:
            return isEmailValid
        }
    }

    // MARK: - Actions

    private func performAction() {
        Task {
            switch mode {
            case .login:
                await authManager.login(email: email, password: password)
                if authManager.isAuthenticated {
                    dismiss()
                }
            case .register:
                await authManager.register(email: email, password: password, displayName: displayName.isEmpty ? nil : displayName)
                if authManager.isAuthenticated {
                    dismiss()
                }
            case .forgotPassword:
                let success = await authManager.forgotPassword(email: email)
                if success {
                    showResetSentAlert = true
                }
            }
        }
    }
}

// MARK: - Custom TextField Style

struct AuthTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.white)
            .cornerRadius(10)
    }
}

#Preview {
    EmailAuthView()
        .environmentObject(AuthManager.shared)
}
