import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @EnvironmentObject var session: SessionManager
    @State private var email = ""
    @State private var password = ""
    @State private var error = ""
    @State private var goToRegister = false
    @State private var isPressed = false

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [Color.black, Color.purple.opacity(0.8)],
                               startPoint: .top,
                               endPoint: .bottom)
                .ignoresSafeArea()

                VStack(spacing: 24) {
                    Text("Login to Bet Casino")
                        .font(.title).bold().foregroundStyle(.white)

                    VStack(spacing: 12) {
                        TextField("Email", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .padding()
                            // LAG FIX: Replaced .ultraThinMaterial with a solid color
                            .background(Color.black.opacity(0.2))
                            .cornerRadius(12)
                            .foregroundColor(.white)

                        SecureField("Password", text: $password)
                            .padding()
                            // LAG FIX: Replaced .ultraThinMaterial with a solid color
                            .background(Color.black.opacity(0.2))
                            .cornerRadius(12)
                            .foregroundColor(.white)
                    }

                    if !error.isEmpty {
                        Text(error).foregroundColor(.red).font(.caption)
                    }

                    Button(action: {
                        vibrate()
                        isPressed = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isPressed = false
                            loginUser()
                        }
                    }) {
                        Text("Login")
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(Color.purple)
                            .cornerRadius(12)
                            .foregroundColor(.white)
                            .scaleEffect(isPressed ? 0.96 : 1.0)
                            .animation(.easeOut(duration: 0.15), value: isPressed)
                    }

                    SignInWithAppleButton(
                        onRequest: { request in
                            request.requestedScopes = [.fullName, .email]
                        },
                        onCompletion: { result in
                            switch result {
                            case .success(let auth):
                                // Use the new, more robust Apple login logic
                                handleAppleLogin(auth: auth)
                            case .failure(let err):
                                error = "Apple login failed: \(err.localizedDescription)"
                            }
                        }
                    )
                    .signInWithAppleButtonStyle(.whiteOutline)
                    .frame(height: 45)
                    .cornerRadius(10)

                    NavigationLink("Don't have an account? Register",
                                   destination: RegisterView().environmentObject(session))
                        .font(.footnote)
                        .padding(.top, 8)
                }
                .padding()
            }
        }
    }

    func loginUser() {
        if let savedData = UserDefaults.standard.dictionary(forKey: email) as? [String: Any],
           let savedPassword = savedData["password"] as? String,
           savedPassword == password {
            session.isLoggedIn = true
        } else {
            error = "Invalid credentials"
        }
    }

    // New, more robust Apple Login and Registration function
    func handleAppleLogin(auth: ASAuthorization) {
        guard let appleIDCredential = auth.credential as? ASAuthorizationAppleIDCredential else {
            error = "Unable to retrieve Apple ID credential."
            return
        }
        
        // The user's unique and stable identifier
        let userIdentifier = appleIDCredential.user
        
        // Check if we have an existing account for this user identifier
        if let userData = UserDefaults.standard.dictionary(forKey: userIdentifier) {
            // User exists, log them in
            print("Existing Apple user logged in: \(userIdentifier)")
            session.isLoggedIn = true
        } else {
            // User does not exist, this is a first-time registration
            print("New Apple user registering: \(userIdentifier)")
            
            // Email and name are only provided on the *first* authorization
            let email = appleIDCredential.email ?? "private-relay-\(UUID().uuidString.prefix(5))@apple.com"
            let firstName = appleIDCredential.fullName?.givenName ?? "Player"
            
            let newUser: [String: Any] = [
                "username": firstName,
                "email": email,
                "password": "N/A (Apple Sign-In)", // Password is not needed
                "money": 50000,
                "gems": 50
            ]
            
            // Save the new user's data using their stable userIdentifier as the key
            UserDefaults.standard.set(newUser, forKey: userIdentifier)
            
            // Also save the data under the email key for consistency with the regular login flow
            UserDefaults.standard.set(newUser, forKey: email)
            
            session.isLoggedIn = true
        }
    }
}
