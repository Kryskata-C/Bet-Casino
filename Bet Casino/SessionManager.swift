import Foundation
import Combine

class SessionManager: ObservableObject {
    @Published var isLoggedIn: Bool = false
    @Published var currentScreen: Screen = .home
    
    // --- User Data ---
    @Published var username: String = "User"
    @Published var money: Int = 0
    @Published var gems: Int = 0
    @Published var level: Int = 0
    @Published var betsPlaced: Int = 0
    @Published var totalMoneyWon: Int = 0
    
    public var currentUserIdentifier: String?
    private let lastUserIdentifierKey = "lastUserIdentifier"

    init() {
        // On app start, check if there was a user logged in previously.
        if let lastIdentifier = UserDefaults.standard.string(forKey: lastUserIdentifierKey) {
            // If so, load their data automatically.
            self.loadUser(identifier: lastIdentifier, isFromAutoLogin: true)
        }
    }

    func loadUser(identifier: String, isFromAutoLogin: Bool = false) {
        self.currentUserIdentifier = identifier
        
        if let userData = UserDefaults.standard.dictionary(forKey: identifier) {
            self.username = userData["username"] as? String ?? "User"
            self.money = userData["money"] as? Int ?? 0
            self.gems = userData["gems"] as? Int ?? 0
            self.level = userData["level"] as? Int ?? 0
            self.betsPlaced = userData["betsPlaced"] as? Int ?? 0
            self.totalMoneyWon = userData["totalMoneyWon"] as? Int ?? 0
        }
        
        // This prevents the login screen from flashing for auto-logins.
        if !isFromAutoLogin {
             self.isLoggedIn = true
        }
       
        // Save this identifier to enable auto-login for the next session.
        UserDefaults.standard.set(identifier, forKey: lastUserIdentifierKey)
    }
    
    func saveData() {
        guard let identifier = currentUserIdentifier else { return }
        
        var userData = UserDefaults.standard.dictionary(forKey: identifier) ?? [:]
        
        userData["username"] = self.username
        userData["money"] = self.money
        userData["gems"] = self.gems
        userData["level"] = self.level
        userData["betsPlaced"] = self.betsPlaced
        userData["totalMoneyWon"] = self.totalMoneyWon
        
        UserDefaults.standard.set(userData, forKey: identifier)
        print("User data saved for identifier: \(identifier)")
    }
    
    func logout() {
        self.isLoggedIn = false
        self.currentScreen = .home
        self.currentUserIdentifier = nil
        
        // Remove the identifier to disable auto-login.
        UserDefaults.standard.removeObject(forKey: lastUserIdentifierKey)
    }
}
