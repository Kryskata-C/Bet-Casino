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
                            .background(.ultraThinMaterial)
                            .cornerRadius(12)

                        SecureField("Password", text: $password)
                            .padding()
                            .background(.ultraThinMaterial)
                            .cornerRadius(12)
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

    func handleAppleLogin(auth: ASAuthorization) {
        guard let credentials = auth.credential as? ASAuthorizationAppleIDCredential else { return }

        let userEmail = credentials.email ?? "user\(UUID().uuidString.prefix(6))@apple.com"
        let username = credentials.fullName?.givenName ?? "Guest\(Int.random(in: 100...999))"

        let userData: [String: Any] = [
            "username": username,
            "email": userEmail,
            "password": "appleid",
            "money": 50000,
            "gems": 50
        ]
        UserDefaults.standard.set(userData, forKey: userEmail)
        session.isLoggedIn = true
    }
}
