import SwiftUI
import Combine

// The Tile struct can stay the same, but let's put it here for organization.
struct Tile: Identifiable {
    let id = UUID()
    var isFlipped: Bool = false
    var isBomb: Bool = false
    var hasShine: Bool = false
}

// THIS is our new game engine! 🚀
class MinesViewModel: ObservableObject {
    @Published var tiles: [Tile] = []
    @Published var mineCount: Double = 3.0
    @Published var betAmount: String = ""
    @Published var gameState: GameState = .idle
    @Published var profit: Double = 0.0
    @Published var currentMultiplier: Double = 1.0

    private var bombIndexes: Set<Int> = []
    private var selectedTiles: Set<Int> = []
    
    let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 5)
    let totalTiles = 25

    enum GameState {
        case idle, playing, gameOver
    }

    init() {
        resetGame()
    }

    func startGame() {
        guard gameState == .idle || gameState == .gameOver else { return }
        
        resetGame()
        gameState = .playing
        bombIndexes = generateBombs(count: Int(mineCount))
        
        // Let's get that haptic feedback! W 😎
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }

    func tileTapped(_ index: Int) {
        guard gameState == .playing, !tiles[index].isFlipped else { return }

        selectedTiles.insert(index)
        tiles[index].isFlipped = true

        if bombIndexes.contains(index) {
            // BOOM! 💥 Game over.
            tiles[index].isBomb = true
            endGame(won: false)
        } else {
            // GEM FOUND! 💎 Let's go!
            tiles[index].hasShine = true
            profit = calculateProfit()
            currentMultiplier = calculateMultiplier()
            
            // Nice little vibration for finding a gem.
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            
            // Check for a win!
            if selectedTiles.count == totalTiles - bombIndexes.count {
                endGame(won: true)
            }
        }
    }
    
    func cashout() {
        guard gameState == .playing else { return }
        // TODO: Add actual cashout logic (e.g., add profit to user's balance)
        endGame(won: true)
    }

    private func endGame(won: Bool) {
        gameState = .gameOver
        
        if !won {
            // Reveal all bombs if the player lost
            for i in bombIndexes {
                tiles[i].isFlipped = true
                tiles[i].isBomb = true
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
    }

    private func generateBombs(count: Int) -> Set<Int> {
        var bombs = Set<Int>()
        while bombs.count < count {
            bombs.insert(Int.random(in: 0..<totalTiles))
        }
        return bombs
    }
    
    // ✨ ACTUAL PROFIT LOGIC! ✨
    private func calculateMultiplier() -> Double {
        guard !bombIndexes.isEmpty else { return 1.0 }
        let safeTiles = Double(totalTiles - bombIndexes.count)
        let selectedSafeTiles = Double(selectedTiles.count - (selectedTiles.intersection(bombIndexes)).count)
        
        guard selectedSafeTiles > 0 else { return 1.0 }
        
        // This is a common multiplier formula for this type of game.
        // You can tweak it to make it more or less rewarding!
        let multiplier = (pow(1.0 - (Double(bombIndexes.count) / Double(totalTiles)), -selectedSafeTiles)) * 0.98
        return multiplier
    }

    private func calculateProfit() -> Double {
        guard let bet = Double(betAmount), bet > 0 else { return 0.0 }
        return bet * (calculateMultiplier() - 1)
    }
}
