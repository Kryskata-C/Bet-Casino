import SwiftUI

// The SplashScreen view is now defined in this file, resolving the scope issue.
struct SplashScreen: View {
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0.0
    @State private var rotation: Double = 0.0
    
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.black, Color.purple.opacity(0.8)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            
            VStack(spacing: 12) {
                Text("BET CASINO")
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .foregroundStyle(LinearGradient(colors: [.white, .purple.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .shadow(color: .purple.opacity(0.7), radius: 15, x: 0, y: 5)
                    .scaleEffect(scale)
                    .opacity(opacity)
                    .rotation3DEffect(.degrees(rotation), axis: (x: 0, y: 1, z: 0))
                
                Text("Powered by FakeCoin™")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .opacity(opacity * 0.8)
            }
            .onAppear {
                withAnimation(.easeOut(duration: 1.5)) {
                    scale = 1.0
                    opacity = 1.0
                }
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    rotation = 10
                }
            }
        }
    }
}


@main
struct BetCasinoApp: App {
    @StateObject private var session = SessionManager()
    
    // This uses UserDefaults to track if the app has been launched before.
    @AppStorage("hasLaunchedBefore") private var hasLaunchedBefore: Bool = false
    
    // State to control the splash screen visibility
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                // Check the session to see if a user is logged in
                if session.isLoggedIn {
                    // If yes, go straight to the main content
                    ContentView()
                        .environmentObject(session)
                } else {
                    // If no user is logged in, decide between splash and login
                    if hasLaunchedBefore {
                        // If it's not the first launch, show LoginView directly
                        LoginView()
                            .environmentObject(session)
                    } else {
                        // This is the very first launch. Show the splash screen.
                        if showSplash {
                            SplashScreen()
                                .onAppear {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                                        withAnimation(.easeOut(duration: 0.6)) {
                                            self.showSplash = false
                                            self.hasLaunchedBefore = true // Mark that the app has launched
                                        }
                                    }
                                }
                        } else {
                            LoginView()
                                .environmentObject(session)
                                .transition(.opacity) // Nice fade-in
                        }
                    }
                }
            }
            .onAppear {
                // If a user was auto-logged in by the SessionManager, immediately mark them as logged in for the UI.
                if session.currentUserIdentifier != nil {
                    session.isLoggedIn = true
                }
            }
        }
    }
}
