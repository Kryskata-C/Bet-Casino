import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @EnvironmentObject var session: SessionManager
    
    // State for the form fields
    @State private var email = ""
    @State private var password = ""
    @State private var error: String?
    
    // State for UI logic
    @State private var isLoggingIn = false
    @State private var showRegisterView = false
    
    // State to control developer tools visibility
    @State private var showDevTools = true

    var body: some View {
        NavigationStack {
            ZStack {
                // Background Gradient
                LinearGradient(colors: [Color.black, Color.purple.opacity(0.6), Color.black], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()

                VStack {
                    // Header
                    VStack(spacing: 8) {
                        Text("Welcome Back")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Text("Login to your Bet Casino account")
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.bottom, 40)
                    .onLongPressGesture {
                        withAnimation {
                            showDevTools.toggle()
                        }
                    }
                    
                    // Login Form Card
                    VStack(spacing: 20) {
                        AuthTextField(icon: "envelope.fill", placeholder: "Email", text: $email)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                        
                        AuthTextField(icon: "lock.fill", placeholder: "Password", text: $password, isSecure: true)
                        
                        if let errorText = error {
                            Text(errorText)
                                .foregroundColor(.red)
                                .font(.caption)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        AuthButton(title: "Login", isLoading: isLoggingIn, action: loginUser)
                        
                        Text("or")
                            .font(.footnote)
                            .foregroundColor(.gray)
                        
                        SignInWithAppleButton(
                            onRequest: { request in
                                request.requestedScopes = [.fullName, .email]
                            },
                            onCompletion: handleAppleLogin
                        )
                        .signInWithAppleButtonStyle(.white)
                        .frame(height: 50)
                        .cornerRadius(12)
                        
                        if showDevTools {
                            DevToolsView()
                        }
                        
                    }
                    .padding(30)
                    .background(.ultraThinMaterial)
                    .cornerRadius(25)
                    .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
                    .padding(.horizontal)
                    
                    Spacer()
                    
                    // Footer to navigate to Register
                    HStack {
                        Text("Don't have an account?")
                        Button("Register Now") {
                            showRegisterView = true
                        }
                        .fontWeight(.bold)
                        .foregroundColor(.purple)
                    }
                }
                .padding(.vertical)
            }
            .foregroundColor(.white)
            .navigationDestination(isPresented: $showRegisterView) {
                RegisterView().environmentObject(session)
            }
        }
    }
    
    // --- FUNCTIONS ---
    
    func loginUser() {
        guard !email.isEmpty, !password.isEmpty else {
            error = "Please fill in all fields."
            return
        }
        
        isLoggingIn = true
        error = nil
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let loginEmailKey = email.lowercased()
            
            if let savedData = UserDefaults.standard.dictionary(forKey: loginEmailKey),
               let savedPassword = savedData["password"] as? String,
               savedPassword == password {
                
                session.loadUser(identifier: loginEmailKey)
                
            } else {
                error = "Invalid email or password."
                vibrate(style: .error)
            }
            isLoggingIn = false
        }
    }
    
    func handleAppleLogin(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard let appleIDCredential = auth.credential as? ASAuthorizationAppleIDCredential else {
                error = "Apple Sign-In failed. Please try again."
                vibrate(style: .error)
                return
            }
            
            let userIdentifier = appleIDCredential.user
            
            if let _ = UserDefaults.standard.dictionary(forKey: userIdentifier) {
                session.loadUser(identifier: userIdentifier)
            } else {
                let email = appleIDCredential.email ?? "\(userIdentifier.prefix(5))@privaterelay.appleid.com"
                let firstName = appleIDCredential.fullName?.givenName ?? "Player"
                
                let newUser: [String: Any] = [
                    "username": firstName,
                    "email": email.lowercased(),
                    "password": "N/A (Apple Sign-In)",
                    "money": 50000,
                    "gems": 50,
                    "level": 0,
                    "betsPlaced": 0,
                    "totalMoneyWon": 0,
                    "biggestWin": 0,
                    "minesBets": 0
                ]
                
                UserDefaults.standard.set(newUser, forKey: userIdentifier)
                UserDefaults.standard.set(newUser, forKey: email.lowercased())

                session.loadUser(identifier: userIdentifier)
            }
            
        case .failure(let err):
            error = "Apple Sign-In failed: \(err.localizedDescription)"
            vibrate(style: .error)
        }
    }
}


// MARK: - Extracted DevTools View
struct DevToolsView: View {
    @EnvironmentObject var session: SessionManager
    
    var body: some View {
        VStack {
            Divider()
                .padding(.vertical, 8)
            
            Button(action: {
                session.currentScreen = .profile
                session.isLoggedIn = true
            }) {
                Text("Go to Profile (Dev)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(10)
                    .frame(maxWidth: .infinity)
                    .background(Color.blue.opacity(0.8))
                    .cornerRadius(8)
            }
            
            Button(action: {
                print("Attempting to clear all user data...")
                if let bundleID = Bundle.main.bundleIdentifier {
                    UserDefaults.standard.removePersistentDomain(forName: bundleID)
                    print("All user data has been cleared.")
                    vibrate(style: .success)
                    session.logout()
                } else {
                    print("Could not find bundle identifier.")
                    vibrate(style: .error)
                }
            }) {
                Text("⚠️ Clear Database (Dev Only)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(10)
                    .frame(maxWidth: .infinity)
                    .background(Color.red.opacity(0.8))
                    .cornerRadius(8)
            }
        }
        .transition(.opacity)
    }
}

// MARK: - Preview
#Preview {
    LoginView()
        .environmentObject(SessionManager())
}
