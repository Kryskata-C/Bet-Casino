import SwiftUI
import Combine
import UIKit // Import UIKit for UIImpactFeedbackGenerator

// MARK: - Game Logic & Data Models

struct Tile: Identifiable {
    let id = UUID()
    var isFlipped: Bool = false
    var isBomb: Bool = false
    var hasShine: Bool = false // For visual sparkle on safe tiles
}

class MinesViewModel: ObservableObject {
    @Published var tiles: [Tile] = []
    @Published var mineCount: Double = 3.0
    @Published var betAmount: String = "" // Remains String for TextField binding
    @Published var gameState: GameState = .idle // .idle, .playing, .gameOver
    @Published var profit: Double = 0.0 // Profit can still be fractional
    @Published var currentMultiplier: Double = 1.0
    @Published var userMoney: Int = 0 // User's current money

    private var bombIndexes: Set<Int> = []
    private var selectedTiles: Set<Int> = []
    var currentUserEmail: String? // Changed to var so MinesView can access it for saving user data via its own functions

    let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 5)
    let totalTiles = 25

    enum GameState {
        case idle, playing, gameOver
    }

    init() {
        resetGame()
    }

    // Call this from the view to set the user's email
    func setupUser(email: String, initialMoney: Int) {
        self.currentUserEmail = email
        self.userMoney = initialMoney
        loadUserMoney() // Load the actual money from UserDefaults
    }

    // Loads user money from UserDefaults
    func loadUserMoney() {
        if let email = currentUserEmail,
           let savedData = UserDefaults.standard.dictionary(forKey: email) as? [String: Any],
           let money = savedData["money"] as? Int {
            self.userMoney = money
        } else {
            self.userMoney = 25000 // A default value if user data isn't found
            print("DEBUG: User money not found in UserDefaults for \(currentUserEmail ?? "nil"). Setting to default.")
        }
    }

    // Saves user money to UserDefaults
    private func saveUserMoney() {
        if let email = currentUserEmail {
            var userData = UserDefaults.standard.dictionary(forKey: email) as? [String: Any] ?? [:]
            userData["money"] = userMoney
            UserDefaults.standard.set(userData, forKey: email)
            print("DEBUG: Saved user money (\(userMoney)) for \(email).")
        }
    }

    func startGame() {
        // Ensure bet amount is valid and user has enough money
        guard let bet = Int(betAmount), bet > 0 else { // Parse as Int
            print("DEBUG: Invalid bet amount (must be an integer greater than 0).")
            return
        }
        guard userMoney >= bet else { // Compare Int with Int
            print("DEBUG: Insufficient funds. Current money: \(userMoney), Bet: \(bet).")
            return
        }

        userMoney -= bet // Deduct bet as Int
        saveUserMoney()
        profit = 0.0 // Reset profit for new game
        currentMultiplier = 1.0 // Reset multiplier

        resetGame() // Reset the board
        gameState = .playing
        bombIndexes = generateBombs(count: Int(mineCount))

        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        print("DEBUG: Game started with bet: \(bet), mines: \(Int(mineCount)). Current money: \(userMoney)")
    }

    func tileTapped(_ index: Int) {
        guard gameState == .playing, !tiles[index].isFlipped else { return }

        selectedTiles.insert(index)
        tiles[index].isFlipped = true

        if bombIndexes.contains(index) {
            tiles[index].isBomb = true
            // If bomb hit, profit is just the negative of the bet (loss)
            profit = -Double(Int(betAmount) ?? 0) // Cast Int bet to Double for profit display
            endGame(won: false)
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            print("DEBUG: Bomb hit at index \(index). Game Over (Lost).")
        } else {
            tiles[index].hasShine = true
            currentMultiplier = calculateMultiplier()
            profit = Double(Int(betAmount) ?? 0) * currentMultiplier // Cast Int bet to Double for profit calculation
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            print("DEBUG: Safe tile tapped at index \(index). Current multiplier: \(currentMultiplier), Current return: \(profit).")

            if selectedTiles.filter({ !bombIndexes.contains($0) }).count == (totalTiles - bombIndexes.count) {
                endGame(won: true)
                print("DEBUG: All safe tiles revealed. Game Over (Won).")
            }
        }
    }

    func cashout() {
        guard gameState == .playing else { return }
        endGame(won: true)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        print("DEBUG: Cashed out. Final profit: \(profit).")
    }

    private func endGame(won: Bool) {
        gameState = .gameOver
        if won {
            userMoney += Int(profit) // Add the profit (total return) to user's money as Int
        }
        saveUserMoney()

        for i in bombIndexes {
            tiles[i].isFlipped = true
            tiles[i].isBomb = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if self.gameState == .gameOver {
                self.gameState = .idle
            }
        }
    }

    func resetGame() {
        tiles = Array(repeating: Tile(), count: totalTiles)
        selectedTiles.removeAll()
        bombIndexes.removeAll()
        profit = 0.0
        currentMultiplier = 1.0
        gameState = .idle
        betAmount = ""
    }

    private func generateBombs(count: Int) -> Set<Int> {
        var bombs = Set<Int>()
        while bombs.count < count {
            bombs.insert(Int.random(in: 0..<totalTiles))
        }
        return bombs
    }

    private func calculateMultiplier() -> Double {
        guard !bombIndexes.isEmpty else { return 1.0 }

        let n = Double(totalTiles)
        let m = Double(bombIndexes.count)
        let k = Double(selectedTiles.filter({ !bombIndexes.contains($0) }).count) // Count of *safe* selected tiles

        var calculatedMult = 1.0
        for i in 0..<Int(k) {
            calculatedMult *= (n - Double(i)) / (n - m - Double(i))
        }

        let houseEdge: Double = 0.98
        return calculatedMult * houseEdge
    }
}
