import SwiftUI

struct SwipeToDismissModifier: ViewModifier {
    @Environment(\.dismiss) private var dismiss
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false

    private let dismissThreshold: CGFloat = 150

    func body(content: Content) -> some View {
        GeometryReader { geometry in
            content
                .frame(width: geometry.size.width, height: geometry.size.height)
                .background(Color(.systemBackground))
                .cornerRadius(dragOffset > 0 ? 20 : 0)
                .offset(y: dragOffset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            // Only allow downward drag
                            if value.translation.height > 0 {
                                isDragging = true
                                // Apply resistance as user drags further
                                let resistance: CGFloat = 0.6
                                dragOffset = value.translation.height * resistance
                            }
                        }
                        .onEnded { value in
                            if dragOffset > dismissThreshold {
                                // Dismiss with animation
                                withAnimation(.easeOut(duration: 0.25)) {
                                    dragOffset = geometry.size.height
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                    dismiss()
                                }
                            } else {
                                // Snap back
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    dragOffset = 0
                                }
                            }
                            isDragging = false
                        }
                )
        }
        .ignoresSafeArea()
    }
}

extension View {
    func swipeToDismiss() -> some View {
        modifier(SwipeToDismissModifier())
    }
}
