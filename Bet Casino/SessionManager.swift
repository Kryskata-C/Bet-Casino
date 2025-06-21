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
    @Published var biggestWin: Int = 0
    @Published var minesBets: Int = 0

    // --- Level Up Animation Properties ---
    @Published var showLevelUpAnimation = false
    @Published var newLevel: Int? = nil
    
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
            self.biggestWin = userData["biggestWin"] as? Int ?? 0
            self.minesBets = userData["minesBets"] as? Int ?? 0
            
            // Recalculate level on load to ensure it's up to date
            updateLevel(isInitialLoad: true)
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
        
        // Update the user's level before saving
        updateLevel()
        
        var userData = UserDefaults.standard.dictionary(forKey: identifier) ?? [:]
        
        userData["username"] = self.username
        userData["money"] = self.money
        userData["gems"] = self.gems
        userData["level"] = self.level
        userData["betsPlaced"] = self.betsPlaced
        userData["totalMoneyWon"] = self.totalMoneyWon
        userData["biggestWin"] = self.biggestWin
        userData["minesBets"] = self.minesBets
        
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
    
    // MARK: - Level Calculation
    
    /// Recalculates and updates the user's level based on their total money won.
    private func updateLevel(isInitialLoad: Bool = false) {
        let oldLevel = self.level
        let calculatedLevel = calculateLevel(totalMoneyWon: Double(self.totalMoneyWon))
        
        // Check if the level has increased
        if calculatedLevel > oldLevel {
            self.level = calculatedLevel
            
            // Do not show animation on the initial app load
            if !isInitialLoad {
                self.newLevel = calculatedLevel
                // Use a short delay to ensure the main UI has processed other data updates
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.showLevelUpAnimation = true
                }
            }
        } else {
            // Ensure level is always accurate even if it hasn't increased
            self.level = calculatedLevel
        }
    }
    
    /// Calculates the player's level based on a logarithmic curve.
    /// This new formula makes leveling up much harder, targeting level 100 at 700M won.
    /// - Parameter totalMoneyWon: The total amount of money the user has won.
    /// - Returns: The calculated level, capped at 100.
    private func calculateLevel(totalMoneyWon: Double) -> Int {
        guard totalMoneyWon > 0 else { return 0 }
        
        // This formula uses a base-10 logarithm for a smoother, more aggressive curve.
        // The divisor is increased significantly to scale the experience towards the 700M target.
        let baseXP = totalMoneyWon / 500_000.0
        let level = log10(baseXP + 1) * 20.0
        
        return min(100, Int(level.rounded()))
    }
}
