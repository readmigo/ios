import SwiftUI

// MARK: - Page Turn Settings

/// 翻页设置
struct PageTurnSettings: Codable, Equatable {
    /// 翻页模式
    var mode: PageTurnMode = .realistic

    /// 启用声效
    var enableSound: Bool = true

    /// 启用触觉反馈
    var enableHaptic: Bool = true

    /// 声音音量 (0-1)
    var soundVolume: Float = 0.7

    /// 触觉强度 (0-1)
    var hapticIntensity: Float = 1.0

    /// 动画速度倍率 (0.5-2.0)
    var animationSpeed: CGFloat = 1.0

    /// 纸张硬度 (0-1)
    var paperStiffness: CGFloat = 0.8

    /// 启用阴影效果
    var enableShadow: Bool = true

    /// 启用光照效果
    var enableLighting: Bool = true

    /// 自动翻页间隔（秒）
    var autoPageInterval: TimeInterval = 30

    /// 启用自动翻页
    var autoPageEnabled: Bool = false

    // MARK: - Computed Properties

    /// 调整后的动画时长
    var adjustedDuration: TimeInterval {
        mode.defaultDuration / Double(animationSpeed)
    }

    // MARK: - Presets

    /// 默认设置
    static let `default` = PageTurnSettings()

    /// 性能优先设置
    static let performance = PageTurnSettings(
        mode: .slide,
        enableSound: false,
        enableHaptic: true,
        enableShadow: false,
        enableLighting: false
    )

    /// 沉浸体验设置
    static let immersive = PageTurnSettings(
        mode: .realistic,
        enableSound: true,
        enableHaptic: true,
        soundVolume: 0.8,
        hapticIntensity: 1.0,
        animationSpeed: 0.8,
        paperStiffness: 0.7,
        enableShadow: true,
        enableLighting: true
    )

    /// 极简设置
    static let minimal = PageTurnSettings(
        mode: .fade,
        enableSound: false,
        enableHaptic: false,
        animationSpeed: 1.5,
        enableShadow: false,
        enableLighting: false
    )
}

// MARK: - Settings Manager

/// 翻页设置管理器
@MainActor
class PageTurnSettingsManager: ObservableObject {
    static let shared = PageTurnSettingsManager()

    @Published var settings: PageTurnSettings {
        didSet {
            saveSettings()
        }
    }

    private let userDefaultsKey = "pageTurnSettings"

    private init() {
        self.settings = Self.loadSettings()
    }

    private static func loadSettings() -> PageTurnSettings {
        guard let data = UserDefaults.standard.data(forKey: "pageTurnSettings"),
              let settings = try? JSONDecoder().decode(PageTurnSettings.self, from: data) else {
            return .default
        }
        return settings
    }

    private func saveSettings() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        UserDefaults.standard.set(data, forKey: userDefaultsKey)
    }

    func applyPreset(_ preset: PageTurnSettings) {
        settings = preset
    }

    func resetToDefaults() {
        settings = .default
    }
}

// MARK: - Settings View

struct PageTurnSettingsView: View {
    @ObservedObject var settingsManager: PageTurnSettingsManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                // 翻页模式选择
                Section("pageTurn.mode".localized) {
                    PageTurnModePicker(selectedMode: $settingsManager.settings.mode)
                }

                // 预设
                Section("pageTurn.quickSettings".localized) {
                    PresetButtonRow(settingsManager: settingsManager)
                }

                // 音效设置
                Section("pageTurn.soundEffect".localized) {
                    Toggle("pageTurn.enableSound".localized, isOn: $settingsManager.settings.enableSound)

                    if settingsManager.settings.enableSound {
                        VStack(alignment: .leading) {
                            Text("pageTurn.volume".localized(with: Int(settingsManager.settings.soundVolume * 100)))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Slider(value: $settingsManager.settings.soundVolume, in: 0...1)
                        }
                    }
                }

                // 触觉反馈设置
                Section("pageTurn.hapticFeedback".localized) {
                    Toggle("pageTurn.enableHaptic".localized, isOn: $settingsManager.settings.enableHaptic)

                    if settingsManager.settings.enableHaptic {
                        VStack(alignment: .leading) {
                            Text("pageTurn.intensity".localized(with: Int(settingsManager.settings.hapticIntensity * 100)))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Slider(value: $settingsManager.settings.hapticIntensity, in: 0...1)
                        }
                    }
                }

                // 动画设置
                if settingsManager.settings.mode.hasPhysics {
                    Section("pageTurn.physicsEffect".localized) {
                        VStack(alignment: .leading) {
                            Text("pageTurn.animationSpeed".localized(with: String(format: "%.1f", settingsManager.settings.animationSpeed)))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Slider(value: $settingsManager.settings.animationSpeed, in: 0.5...2.0, step: 0.1)
                        }

                        VStack(alignment: .leading) {
                            Text("pageTurn.paperStiffness".localized(with: Int(settingsManager.settings.paperStiffness * 100)))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Slider(value: $settingsManager.settings.paperStiffness, in: 0...1)
                        }
                    }
                }

                // 视觉效果
                if settingsManager.settings.mode.requires3D {
                    Section("pageTurn.visualEffect".localized) {
                        Toggle("pageTurn.enableShadow".localized, isOn: $settingsManager.settings.enableShadow)
                        Toggle("pageTurn.enableLighting".localized, isOn: $settingsManager.settings.enableLighting)
                    }
                }

                // 自动翻页
                Section("pageTurn.autoPage".localized) {
                    Toggle("pageTurn.enableAutoPage".localized, isOn: $settingsManager.settings.autoPageEnabled)

                    if settingsManager.settings.autoPageEnabled {
                        Picker("pageTurn.interval".localized, selection: $settingsManager.settings.autoPageInterval) {
                            Text("pageTurn.15seconds".localized).tag(15.0)
                            Text("pageTurn.30seconds".localized).tag(30.0)
                            Text("pageTurn.60seconds".localized).tag(60.0)
                        }
                        .pickerStyle(.segmented)
                    }
                }
            }
            .navigationTitle("pageTurn.settings".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("common.done".localized) {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Page Turn Mode Picker

struct PageTurnModePicker: View {
    @Binding var selectedMode: PageTurnMode

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("pageTurn.basicModes".localized)
                .font(.caption)
                .foregroundColor(.secondary)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(PageTurnMode.basicModes, id: \.self) { mode in
                    ModeButton(mode: mode, isSelected: selectedMode == mode) {
                        selectedMode = mode
                    }
                }
            }

            Text("pageTurn.advancedModes".localized)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 8)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(PageTurnMode.advancedModes, id: \.self) { mode in
                    ModeButton(mode: mode, isSelected: selectedMode == mode) {
                        selectedMode = mode
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
}

private struct ModeButton: View {
    let mode: PageTurnMode
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: mode.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .accentColor : .secondary)

                Text(mode.displayName)
                    .font(.caption2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundColor(isSelected ? .accentColor : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preset Button Row

private struct PresetButtonRow: View {
    @ObservedObject var settingsManager: PageTurnSettingsManager

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                PresetButton(title: "pageTurn.preset.default".localized, icon: "gear") {
                    settingsManager.applyPreset(.default)
                }

                PresetButton(title: "pageTurn.preset.immersive".localized, icon: "sparkles") {
                    settingsManager.applyPreset(.immersive)
                }

                PresetButton(title: "pageTurn.preset.performance".localized, icon: "bolt") {
                    settingsManager.applyPreset(.performance)
                }

                PresetButton(title: "pageTurn.preset.minimal".localized, icon: "minus.circle") {
                    settingsManager.applyPreset(.minimal)
                }
            }
            .padding(.vertical, 4)
        }
    }
}

private struct PresetButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                Text(title)
                    .font(.caption)
            }
            .foregroundColor(.accentColor)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.accentColor.opacity(0.1))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
