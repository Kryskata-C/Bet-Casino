import SwiftUI
import Combine

// MARK: - Data Models
// Define the data structures for the game here.
// By placing Tile here, any other file that imports this view model can use it.
struct Tile: Identifiable {
    let id = UUID()
    var isFlipped: Bool = false
    var isBomb: Bool = false
    var hasShine: Bool = false
    var wasLosingBomb: Bool = false
}

enum BettingMode {
    case manual, auto
}

// MARK: - ViewModel
class MinesViewModel: ObservableObject {
    // Game State
    @Published var tiles: [Tile] = []
    @Published var gameState: GameState = .idle
    @Published var bettingMode: BettingMode = .manual

    // Bet Properties
    @Published var mineCount: Double = 3.0
    @Published var betAmount: String = ""
    @Published var profit: Double = 0.0
    @Published var currentMultiplier: Double = 1.0

    // Auto Bet Properties
    @Published var isAutoBetting: Bool = false
    @Published var numberOfBets: String = "10"
    @Published var autoBetSelection: Set<Int> = []
    @Published var currentBetCount: Int = 0
    @Published var autoRunProfit: Double = 0.0

    // Streak Properties
    @Published var winStreak: Int = 0
    @Published var streakBonusMultiplier: Double = 1.0
    
    // Private Properties
    private var sessionManager: SessionManager
    private var bombIndexes: Set<Int> = []
    public var selectedTiles: Set<Int> = []
    private var resetGameCancellable: AnyCancellable?
    private var autoBetTask: Task<Void, Never>?

    let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 5)
    let totalTiles = 25.0

    enum GameState { case idle, playing, autoSetup, autoPlaying, gameOver }

    init(sessionManager: SessionManager) {
        self.sessionManager = sessionManager
        self.resetGame()
    }
    
    deinit {
        stopAutoBet()
    }

    // MARK: - Game Logic
    func startGame() {
        guard let bet = Int(betAmount), bet > 0, bet <= sessionManager.money else { return }
        resetGameCancellable?.cancel()
        
        sessionManager.money -= bet
        sessionManager.betsPlaced += 1
        
        resetBoard()
        gameState = .playing
        bombIndexes = generateBombs(count: Int(mineCount))
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }

    func tileTapped(_ index: Int) {
        switch gameState {
        case .playing:
            guard !tiles[index].isFlipped else { return }
            
            tiles[index].isFlipped = true
            if bombIndexes.contains(index) {
                tiles[index].isBomb = true
                tiles[index].wasLosingBomb = true
                endGame(won: false)
            } else {
                selectedTiles.insert(index)
                tiles[index].hasShine = true
                currentMultiplier = calculateManualMultiplier()
                profit = (Double(betAmount) ?? 0.0) * (currentMultiplier - 1.0)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                if Double(selectedTiles.count) == totalTiles - Double(bombIndexes.count) {
                    endGame(won: true)
                }
            }
        case .autoSetup:
             toggleAutoBetTile(index)
        default:
            return
        }
    }
    
    func cashout() {
        guard gameState == .playing, !selectedTiles.isEmpty else { return }
        endGame(won: true)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func endGame(won: Bool) {
        guard gameState == .playing else { return }
        gameState = .gameOver
        let bet = Double(betAmount) ?? 0.0

        if won {
            winStreak += 1
            let streakBonus = calculateStreakBonus(tilesUncovered: selectedTiles.count)
            streakBonusMultiplier = streakBonus
            
            let finalMultiplier = currentMultiplier * streakBonus
            let finalWinnings = bet * finalMultiplier
            let roundProfit = finalWinnings - bet
            
            self.profit = roundProfit
            
            let winningsInt = Int(finalWinnings.rounded())
            sessionManager.money += winningsInt
            sessionManager.totalMoneyWon += winningsInt
        } else {
            self.profit = -bet
            resetStreak()
            for i in bombIndexes where !tiles[i].isFlipped {
                tiles[i].isFlipped = true
                tiles[i].isBomb = true
            }
        }
        
        sessionManager.saveData()
        
        resetGameCancellable = Just(()).delay(for: .seconds(2), scheduler: DispatchQueue.main).sink { [weak self] _ in
            self?.resetGame()
        }
    }
    
    func resetGame() {
        resetGameCancellable?.cancel()
        resetBoard()
        if bettingMode == .manual {
             autoBetSelection.removeAll()
             gameState = .idle
        } else {
             gameState = .autoSetup
        }
    }
    
    func resetBoard() {
        tiles = Array(repeating: Tile(), count: Int(totalTiles))
        selectedTiles.removeAll()
        bombIndexes.removeAll()
        profit = 0.0
        currentMultiplier = 1.0
    }
    
    // MARK: - Auto Bet Logic
    func switchBettingMode(to mode: BettingMode) {
        stopAutoBet()
        bettingMode = mode
        resetGame()
    }

    func startAutoBet() {
        guard let totalBets = Int(numberOfBets), totalBets > 0,
              let bet = Int(betAmount), bet > 0 else { return }

        isAutoBetting = true
        gameState = .autoPlaying
        currentBetCount = 0
        autoRunProfit = 0
        resetStreak()

        autoBetTask = Task {
            for i in 1...totalBets {
                if Task.isCancelled { break }
                
                await MainActor.run { self.currentBetCount = i }
                
                guard sessionManager.money >= bet else {
                    print("Insufficient funds, stopping auto-bet.")
                    break
                }
                
                await runAutoBetRound(bet: bet)
                if Task.isCancelled { break }
                try? await Task.sleep(nanoseconds: 1_200_000_000)
            }
            
            await MainActor.run {
                self.isAutoBetting = false
                self.gameState = .autoSetup
            }
        }
    }
    
    func stopAutoBet() {
        autoBetTask?.cancel()
        autoBetTask = nil
        if gameState == .autoPlaying {
            isAutoBetting = false
            gameState = .autoSetup
        }
    }
    
    private func runAutoBetRound(bet: Int) async {
        await MainActor.run {
            self.resetBoard()
            self.sessionManager.money -= bet
            self.sessionManager.betsPlaced += 1
            self.bombIndexes = generateBombs(count: Int(mineCount))
        }

        let multiplier = calculateAutoMultiplier()
        let hitBomb = autoBetSelection.contains { bombIndexes.contains($0) }
        var lastRoundProfit: Double

        if hitBomb {
            lastRoundProfit = -Double(bet)
            await MainActor.run { resetStreak() }
        } else {
            let streakBonus = calculateStreakBonus(tilesUncovered: autoBetSelection.count)
            let finalWinnings = (Double(bet) * multiplier) * streakBonus
            lastRoundProfit = finalWinnings - Double(bet)
                
            await MainActor.run {
                self.winStreak += 1
                self.streakBonusMultiplier = streakBonus
                let winningsInt = Int(finalWinnings.rounded())
                self.sessionManager.money += winningsInt
                self.sessionManager.totalMoneyWon += winningsInt
            }
        }

        await MainActor.run {
            withAnimation(.easeInOut) {
                self.autoRunProfit += lastRoundProfit
                for tileIndex in self.autoBetSelection {
                    self.tiles[tileIndex].isFlipped = true
                    if self.bombIndexes.contains(tileIndex) {
                        self.tiles[tileIndex].isBomb = true
                    }
                }
            }
            self.sessionManager.saveData()
        }
    }

    // MARK: - Helper & Calculation Functions
    private func resetStreak() {
        winStreak = 0
        streakBonusMultiplier = 1.0
    }
    
    private func toggleAutoBetTile(_ index: Int) {
        if autoBetSelection.contains(index) {
            autoBetSelection.remove(index)
        } else {
            autoBetSelection.insert(index)
        }
    }

    private func generateBombs(count: Int) -> Set<Int> {
        var bombs = Set<Int>()
        while bombs.count < count { bombs.insert(Int.random(in: 0..<Int(totalTiles))) }
        return bombs
    }
    
    func calculateManualMultiplier() -> Double {
        guard !bombIndexes.isEmpty else { return 1.0 }
        let n = totalTiles, m = Double(bombIndexes.count), k = Double(selectedTiles.count)
        if k == 0 { return 1.0 }
        var calculatedMult = 1.0
        for i in 0..<Int(k) { calculatedMult *= (n - m - Double(i)) / (n - Double(i)) }
        return (1 / calculatedMult) * 0.98
    }
    
    private func calculateAutoMultiplier() -> Double {
        guard !bombIndexes.isEmpty else { return 1.0 }
        let n = totalTiles, m = Double(bombIndexes.count), k = Double(autoBetSelection.count)
        if k == 0 { return 1.0 }
        var calculatedMult = 1.0
        for i in 0..<Int(k) { calculatedMult *= (n - m - Double(i)) / (n - Double(i)) }
        return (1 / calculatedMult) * 0.98
    }
    
    func calculateStreakBonus(tilesUncovered: Int) -> Double {
        guard winStreak > 0 else { return 1.0 }
        guard mineCount < totalTiles else { return 1.0 }

        let uncoveredRatio = Double(tilesUncovered) / (totalTiles - mineCount)
        let mineDensity = mineCount / totalTiles
        let baseRisk = uncoveredRatio * mineDensity
        let streakPower = log(Double(winStreak) + 1) * 1.25
        let rarityBonus = pow((1.0 + baseRisk), streakPower)
        let dynamicCap = 1.0 + (mineDensity * 12.0)
        return min(dynamicCap, max(1.0, rarityBonus))
    }
}
