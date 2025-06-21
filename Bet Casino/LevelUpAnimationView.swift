//
//  LevelUpAnimationView.swift
//  Bet Casino
//
//  Created by Christian Angelov on 21.06.25.
//

import SwiftUI

struct LevelUpAnimationView: View {
    @EnvironmentObject var session: SessionManager
    
    // Animation state
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var rotation: Double = -90
    
    var body: some View {
        ZStack {
            // Background blur
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .transition(.opacity)

            VStack(spacing: 20) {
                // "LEVEL UP" Text
                Text("LEVEL UP!")
                    .font(.system(size: 50, weight: .heavy, design: .rounded))
                    .foregroundStyle(LinearGradient(colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom))
                    .shadow(color: .yellow.opacity(0.8), radius: 10)
                    .scaleEffect(scale)
                    .opacity(textOpacity)

                // New Level Display
                if let newLevel = session.newLevel {
                    Text("\(newLevel)")
                        .font(.system(size: 120, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: .cyan.opacity(0.8), radius: 15)
                        .rotation3DEffect(
                            .degrees(rotation),
                            axis: (x: 0.0, y: 1.0, z: 0.0)
                        )
                        .opacity(opacity)
                }
            }
        }
        .onAppear(perform: startAnimation)
    }
    
    private func startAnimation() {
        // Phase 1: Animate the "LEVEL UP" text
        withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
            scale = 1.0
            textOpacity = 1.0
        }
        
        // Phase 2: Animate the level number after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.interpolatingSpring(mass: 1, stiffness: 100, damping: 12)) {
                rotation = 0
                opacity = 1
            }
        }
        
        // Phase 3: Hide the view after it has been displayed
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation(.easeOut(duration: 0.5)) {
                textOpacity = 0
                opacity = 0
            }
            // Dismiss the view from the session manager
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                session.showLevelUpAnimation = false
                session.newLevel = nil
            }
        }
    }
}

#Preview {
    let session = SessionManager()
    session.showLevelUpAnimation = true
    session.newLevel = 10
    return LevelUpAnimationView()
        .environmentObject(session)
}
