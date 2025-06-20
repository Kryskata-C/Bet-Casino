import Foundation
import Combine

// The Screen enum has been removed from this file to prevent redeclaration errors.
// It should be defined in ContentView.swift instead.

class SessionManager: ObservableObject {
    @Published var isLoggedIn: Bool = false
    
    // This property now controls which main view is shown.
    @Published var currentScreen: Screen = .home
    
    // User data is managed by the session
    @Published var username: String = "User"
    @Published var money: Int = 0
    @Published var gems: Int = 0
    
    private var currentUserIdentifier: String?

    func loadUser(identifier: String) {
        self.currentUserIdentifier = identifier
        
        if let userData = UserDefaults.standard.dictionary(forKey: identifier) {
            self.username = userData["username"] as? String ?? "User"
            self.money = userData["money"] as? Int ?? 0
            self.gems = userData["gems"] as? Int ?? 0
        }
        
        self.isLoggedIn = true
    }
    
    func saveData() {
        guard let identifier = currentUserIdentifier else { return }
        
        let userData: [String: Any] = [
            "username": self.username,
            "money": self.money,
            "gems": self.gems
        ]
        
        UserDefaults.standard.set(userData, forKey: identifier)
        print("User data saved for identifier: \(identifier) with money: \(self.money)")
    }
    
    func logout() {
        self.isLoggedIn = false
        self.currentScreen = .home // Reset to home screen on logout
        self.currentUserIdentifier = nil
    }
}
