import SwiftUI

/// Message type picker component
struct MessageTypePickerView: View {
    @Binding var selectedType: MessageType

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(MessageType.allCases, id: \.self) { type in
                Button {
                    selectedType = type
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: type.icon)
                            .font(.title3)
                            .foregroundColor(colorForType(type))
                            .frame(width: 28)

                        Text(type.localizedNameKey.localized)
                            .font(.body)
                            .foregroundColor(.primary)

                        Spacer()

                        if selectedType == type {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.accentColor)
                        } else {
                            Image(systemName: "circle")
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if type != MessageType.allCases.last {
                    Divider()
                        .padding(.leading, 56)
                }
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    private func colorForType(_ type: MessageType) -> Color {
        switch type.iconColor {
        case "orange": return .orange
        case "yellow": return .yellow
        case "blue": return .blue
        case "red": return .red
        case "purple": return .purple
        case "green": return .green
        default: return .accentColor
        }
    }
}
