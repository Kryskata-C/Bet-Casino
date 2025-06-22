import Foundation
import Combine
import SwiftUI

enum Screen {
    case home
    case mines
    case towers
    case profile
}

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
    @Published var towersBets: Int = 0
    @Published var lastBetAmount: Int = 0
    
    // --- Game-Specific Persistent Data ---
    @Published var towersWinStreak: Int = 0
    @Published var towersGameHistory: [Bool] = [] 


    // --- Level Up Animation Properties ---
    @Published var showLevelUpAnimation = false
    @Published var newLevel: Int? = nil
    
    public var currentUserIdentifier: String?
    private let lastUserIdentifierKey = "lastUserIdentifier"

    init() {
        if let lastIdentifier = UserDefaults.standard.string(forKey: lastUserIdentifierKey) {
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
            self.towersBets = userData["towersBets"] as? Int ?? 0
            
            self.towersWinStreak = userData["towersWinStreak"] as? Int ?? 0
            self.towersGameHistory = userData["towersGameHistory"] as? [Bool] ?? []
            
            updateLevel(isInitialLoad: true)
        }
        
        if !isFromAutoLogin {
             self.isLoggedIn = true
        }
       
        UserDefaults.standard.set(identifier, forKey: lastUserIdentifierKey)
    }
    
    func saveData() {
        guard let identifier = currentUserIdentifier else { return }
        
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
        userData["towersBets"] = self.towersBets
        
        userData["towersWinStreak"] = self.towersWinStreak
        userData["towersGameHistory"] = self.towersGameHistory
        
        UserDefaults.standard.set(userData, forKey: identifier)
        print("User data saved for identifier: \(identifier)")
    }
    
    func logout() {
        self.isLoggedIn = false
        self.currentScreen = .home
        self.currentUserIdentifier = nil
        
        UserDefaults.standard.removeObject(forKey: lastUserIdentifierKey)
    }
    
    private func updateLevel(isInitialLoad: Bool = false) {
        let oldLevel = self.level
        let calculatedLevel = calculateLevel(totalMoneyWon: Double(self.totalMoneyWon))
        
        if calculatedLevel > oldLevel {
            self.level = calculatedLevel
            
            if !isInitialLoad {
                self.newLevel = calculatedLevel
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.showLevelUpAnimation = true
                }
            }
        } else {
            self.level = calculatedLevel
        }
    }
    
    private func calculateLevel(totalMoneyWon: Double) -> Int {
        guard totalMoneyWon > 0 else { return 0 }
        
        let baseXP = totalMoneyWon / 500_000.0
        let level = log10(baseXP + 1) * 20.0
        
        return min(100, Int(level.rounded()))
    }
}
