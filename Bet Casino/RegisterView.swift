import SwiftUI

struct RegisterView: View {
    @EnvironmentObject var session: SessionManager
    @Environment(\.dismiss) var dismiss

    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var error = ""
    @State private var isPressed = false

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [Color.black, Color.purple.opacity(0.8)],
                               startPoint: .top,
                               endPoint: .bottom)
                .ignoresSafeArea()

                VStack(spacing: 24) {
                    Text("Register for Bet Casino")
                        .font(.title).bold().foregroundColor(.white)

                    VStack(spacing: 12) {
                        TextField("Username", text: $username)
                            .padding()
                            .background(.ultraThinMaterial)
                            .cornerRadius(12)

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

                        SecureField("Confirm Password", text: $confirmPassword)
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
                            registerUser()
                        }
                    }) {
                        Text("Create Account")
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(Color.purple)
                            .cornerRadius(12)
                            .foregroundColor(.white)
                            .scaleEffect(isPressed ? 0.96 : 1.0)
                            .animation(.easeOut(duration: 0.15), value: isPressed)
                    }

                    Button("Already have an account? Login") {
                        vibrate()
                        dismiss()
                    }
                    .font(.footnote)
                }
                .padding()
            }
        }
    }

    func registerUser() {
        guard !username.isEmpty, !email.isEmpty, !password.isEmpty else {
            error = "Fill all fields"
            return
        }

        guard password == confirmPassword else {
            error = "Passwords don't match"
            return
        }

        let userData: [String: Any] = [
            "username": username,
            "email": email,
            "password": password,
            "money": 250000,
            "gems": 0
        ]
        UserDefaults.standard.set(userData, forKey: email)
        session.isLoggedIn = true
    }
}
