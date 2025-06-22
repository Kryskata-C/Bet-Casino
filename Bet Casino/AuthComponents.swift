import SwiftUI

// MARK: - Reusable Authentication Components

struct AuthTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.purple)
                .frame(width: 20)
            
            if isSecure {
                SecureField(placeholder, text: $text)
            } else {
                TextField(placeholder, text: $text)
                    .autocapitalization(.none)
            }
        }
        .padding()
        .background(Color.black.opacity(0.2))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
}


struct AuthButton: View {
    let title: String
    var isLoading: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Spacer()
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(title)
                        .fontWeight(.bold)
                }
                Spacer()
            }
            .frame(height: 50)
            .background(Color.purple)
            .foregroundColor(.white)
            .cornerRadius(12)
            .shadow(color: .purple.opacity(0.4), radius: 8, y: 4)
        }
        .disabled(isLoading)
    }
}

// MARK: - Helper Functions & Effects

func vibrate(style: UINotificationFeedbackGenerator.FeedbackType) {
    UINotificationFeedbackGenerator().notificationOccurred(style)
}

// --- ADDED: This is now the single source of truth for ShakeEffect ---
struct ShakeEffect: GeometryEffect {
    var amount: CGFloat = 8
    var shakesPerUnit = 3
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: amount * sin(animatableData * .pi * CGFloat(shakesPerUnit)), y: 0))
    }
}
