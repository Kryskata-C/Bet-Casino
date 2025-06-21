import SwiftUI

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
