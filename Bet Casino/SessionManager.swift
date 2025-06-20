import Foundation
import Combine

class SessionManager: ObservableObject {
    @Published var isLoggedIn: Bool = false
    @Published var currentScreen: Screen = .home
    
    // --- Existing User Data ---
    @Published var username: String = "User"
    @Published var money: Int = 0
    @Published var gems: Int = 0
    
    // --- NEW USER STATISTICS ---
    @Published var level: Int = 0
    @Published var betsPlaced: Int = 0
    @Published var totalMoneyWon: Int = 0
    
    private var currentUserIdentifier: String?

    func loadUser(identifier: String) {
        self.currentUserIdentifier = identifier
        
        if let userData = UserDefaults.standard.dictionary(forKey: identifier) {
            // Load existing data
            self.username = userData["username"] as? String ?? "User"
            self.money = userData["money"] as? Int ?? 0
            self.gems = userData["gems"] as? Int ?? 0
            
            // Load new stats, providing a default value of 0 if they don't exist.
            // This ensures older accounts don't crash the app.
            self.level = userData["level"] as? Int ?? 0
            self.betsPlaced = userData["betsPlaced"] as? Int ?? 0
            self.totalMoneyWon = userData["totalMoneyWon"] as? Int ?? 0
        }
        
        // Finalize login
        self.isLoggedIn = true
    }
    
    func saveData() {
        guard let identifier = currentUserIdentifier else { return }
        
        // Fetch existing data to ensure no fields are ever overwritten or lost
        var userData = UserDefaults.standard.dictionary(forKey: identifier) ?? [:]
        
        // Update the dictionary with the latest data from the session
        userData["username"] = self.username
        userData["money"] = self.money
        userData["gems"] = self.gems
        userData["level"] = self.level
        userData["betsPlaced"] = self.betsPlaced
        userData["totalMoneyWon"] = self.totalMoneyWon
        
        // Save the entire updated dictionary back to UserDefaults
        UserDefaults.standard.set(userData, forKey: identifier)
        print("User data saved for identifier: \(identifier)")
    }
    
    func logout() {
        self.isLoggedIn = false
        self.currentScreen = .home // Reset to home screen on logout
        self.currentUserIdentifier = nil
    }
}
