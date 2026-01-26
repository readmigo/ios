import SwiftUI

enum OnboardingStep: Int, CaseIterable {
    case welcome = 0
    case levelAssessment = 1
    case goalSetting = 2
    case interests = 3

    var title: String {
        switch self {
        case .welcome: return "Welcome"
        case .levelAssessment: return "English Level"
        case .goalSetting: return "Daily Goal"
        case .interests: return "Interests"
        }
    }
}

struct OnboardingView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var currentStep: OnboardingStep = .welcome
    @State private var selectedLevel: EnglishLevel = .intermediate
    @State private var dailyGoalMinutes: Int = 15
    @State private var selectedInterests: Set<ReadingInterest> = []
    @State private var isSubmitting = false

    var body: some View {
        ZStack {
            // Background
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress indicator
                ProgressIndicator(
                    currentStep: currentStep.rawValue,
                    totalSteps: OnboardingStep.allCases.count
                )
                .padding(.horizontal)
                .padding(.top, 16)

                // Content
                TabView(selection: $currentStep) {
                    WelcomeStepView(onContinue: { nextStep() })
                        .tag(OnboardingStep.welcome)

                    LevelAssessmentView(
                        selectedLevel: $selectedLevel,
                        onContinue: { nextStep() }
                    )
                    .tag(OnboardingStep.levelAssessment)

                    GoalSettingView(
                        dailyGoalMinutes: $dailyGoalMinutes,
                        onContinue: { nextStep() }
                    )
                    .tag(OnboardingStep.goalSetting)

                    InterestsView(
                        selectedInterests: $selectedInterests,
                        onComplete: { completeOnboarding() }
                    )
                    .tag(OnboardingStep.interests)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentStep)
            }

            // Loading overlay
            if isSubmitting {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                    Text("onboarding.loading".localized)
                        .foregroundColor(.white)
                        .font(.subheadline)
                }
            }
        }
    }

    private func nextStep() {
        guard let nextIndex = OnboardingStep(rawValue: currentStep.rawValue + 1) else {
            return
        }
        withAnimation {
            currentStep = nextIndex
        }
    }

    private func completeOnboarding() {
        isSubmitting = true

        Task {
            do {
                // Update user profile with onboarding selections
                try await authManager.updateProfile(
                    displayName: nil,
                    englishLevel: selectedLevel,
                    dailyGoalMinutes: dailyGoalMinutes
                )

                // Mark onboarding as complete
                authManager.completeOnboarding()
            } catch {
                print("Failed to update profile: \(error)")
                // Still complete onboarding even if profile update fails
                authManager.completeOnboarding()
            }

            isSubmitting = false
        }
    }
}

// MARK: - Progress Indicator

struct ProgressIndicator: View {
    let currentStep: Int
    let totalSteps: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalSteps, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(index <= currentStep ? Color.accentColor : Color.gray.opacity(0.3))
                    .frame(height: 4)
            }
        }
    }
}

// MARK: - Reading Interests

enum ReadingInterest: String, CaseIterable, Identifiable {
    case classics = "classics"
    case fiction = "fiction"
    case philosophy = "philosophy"
    case poetry = "poetry"
    case history = "history"
    case science = "science"
    case business = "business"
    case selfHelp = "self_help"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .classics: return "Classics"
        case .fiction: return "Fiction"
        case .philosophy: return "Philosophy"
        case .poetry: return "Poetry"
        case .history: return "History"
        case .science: return "Science"
        case .business: return "Business"
        case .selfHelp: return "Self-Help"
        }
    }

    var icon: String {
        switch self {
        case .classics: return "books.vertical"
        case .fiction: return "sparkles"
        case .philosophy: return "brain.head.profile"
        case .poetry: return "text.quote"
        case .history: return "clock.arrow.circlepath"
        case .science: return "atom"
        case .business: return "chart.line.uptrend.xyaxis"
        case .selfHelp: return "figure.mind.and.body"
        }
    }

    var localizedName: String {
        switch self {
        case .classics: return "经典文学"
        case .fiction: return "小说"
        case .philosophy: return "哲学"
        case .poetry: return "诗歌"
        case .history: return "历史"
        case .science: return "科学"
        case .business: return "商业"
        case .selfHelp: return "自我提升"
        }
    }
}
