import SwiftUI

struct RegisterView: View {
    @EnvironmentObject var session: SessionManager
    @Environment(\.dismiss) var dismiss
    
    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    
    @State private var error: String?
    @State private var isRegistering = false

    var body: some View {
        ZStack {
            // Background Gradient
            LinearGradient(colors: [Color.black, Color.purple.opacity(0.6), Color.black], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            VStack {
                // Header
                VStack(spacing: 8) {
                    Text("Create Account")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("Join the Bet Casino community")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.bottom, 40)
                
                // Registration Form Card
                VStack(spacing: 20) {
                    AuthTextField(icon: "person.fill", placeholder: "Username", text: $username)
                    AuthTextField(icon: "envelope.fill", placeholder: "Email", text: $email)
                        .keyboardType(.emailAddress)
                    AuthTextField(icon: "lock.fill", placeholder: "Password", text: $password, isSecure: true)
                    AuthTextField(icon: "lock.fill", placeholder: "Confirm Password", text: $confirmPassword, isSecure: true)

                    if let errorText = error {
                        Text(errorText)
                            .foregroundColor(.red)
                            .font(.caption)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    AuthButton(title: "Create Account", isLoading: isRegistering, action: registerUser)
                }
                .padding(30)
                .background(.ultraThinMaterial)
                .cornerRadius(25)
                .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
                .padding(.horizontal)
                
                Spacer()
                
                // Footer to navigate back to Login
                HStack {
                    Text("Already have an account?")
                    Button("Login Here") {
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .foregroundColor(.purple)
                }
            }
            .padding(.vertical)
        }
        .foregroundColor(.white)
        .navigationBarBackButtonHidden(true)
    }
    
    // --- FUNCTIONS ---
    
    func registerUser() {
        // Validation
        guard !username.isEmpty, !email.isEmpty, !password.isEmpty else {
            error = "Please fill in all fields."
            vibrate(style: .error)
            return
        }
        guard password == confirmPassword else {
            error = "Passwords do not match."
            vibrate(style: .error)
            return
        }
        guard password.count >= 6 else {
            error = "Password must be at least 6 characters long."
            vibrate(style: .error)
            return
        }
        if UserDefaults.standard.dictionary(forKey: email.lowercased()) != nil {
            error = "An account with this email already exists."
            vibrate(style: .error)
            return
        }
        
        isRegistering = true
        error = nil
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let userData: [String: Any] = [
                "username": username,
                "email": email.lowercased(),
                "password": password,
                "money": 25000,
                "gems": 10,
                "level": 0,
                "betsPlaced": 0,
                "totalMoneyWon": 0,
                "biggestWin": 0,
                "minesBets": 0
            ]
            
            UserDefaults.standard.set(userData, forKey: email.lowercased())
            
            session.loadUser(identifier: email.lowercased())
            
            isRegistering = false
            vibrate(style: .success)
        }
    }
}


#Preview {
    RegisterView()
        .environmentObject(SessionManager())
}
