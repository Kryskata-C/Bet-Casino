import SwiftUI
import Combine
import UIKit

struct BonusTextItem: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let color: Color
}


class TowersViewModel: ObservableObject {
    // MARK: - Game State
    @Published var grid: [[Bool]] = []
    @Published var gameState: GameState = .idle
    @Published var currentRow: Int = 0
    @Published var revealedTiles: [[Int]] = []
    @Published var gridID = UUID()
    
    // For polished transitions and feedback
    @Published var triggerLossShake = 0
    @Published var triggerWinFlash = 0
    
    // Debug property, now only modifiable in code.
    @Published var isDebugMode: Bool = true

    // MARK: - Bet Properties
    @Published var riskLevel: RiskLevel = .medium {
        didSet { if oldValue != riskLevel && gameState == .idle { resetGame(isNewGame: true) } }
    }
    @Published var betAmount: String = "" {
        didSet { if gameState == .idle { resetGame(isNewGame: true) } }
    }
    @Published var profit: Double = 0.0
    @Published var currentMultiplier: Double = 1.0
    @Published var multipliers: [Double] = []

    // MARK: - New Feature Properties
    @Published var winStreak: Int = 0
    @Published var combo: Int = 0
    @Published var shouldSuggestCashout: Bool = false
    @Published var bonusText: BonusTextItem? = nil
    @Published var jackpotRow: Int? = nil
    @Published var jackpotCol: Int? = nil
    @Published var streakBonusMultiplier: Double = 1.0


    private var sessionManager: SessionManager
    private var resetGameCancellable: AnyCancellable?

    enum GameState { case idle, playing, gameOver }
    enum RiskLevel: String, CaseIterable {
        case easy = "Easy", medium = "Medium", hard = "Hard"
        var columnCount: Int { switch self { case .easy, .hard: return 3; case .medium: return 2 } }
        var bombCount: Int { switch self { case .easy, .medium: return 1; case .hard: return 2 } }
    }

    init(sessionManager: SessionManager) {
        self.sessionManager = sessionManager
        self.winStreak = sessionManager.towersWinStreak
        resetGame(isNewGame: false)
    }

    func startGame() {
        guard let bet = Int(betAmount), bet > 0, bet <= sessionManager.money else { return }
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        resetGameCancellable?.cancel()
        
        sessionManager.money -= bet
        sessionManager.betsPlaced += 1
        sessionManager.towersBets += 1
        
        generateGrid()
        gameState = .playing
    }

    func tileTapped(row: Int, col: Int) {
        guard gameState == .playing, row == currentRow, !revealedTiles[row].contains(col) else { return }
        revealedTiles[row].append(col)
        
        if grid[row][col] { // Safe tile
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            combo += 1
            
            if row == jackpotRow && col == jackpotCol {
                let jackpotBonus = Int.random(in: 5...20)
                sessionManager.gems += jackpotBonus
                bonusText = BonusTextItem(text: "+\(jackpotBonus) GEMS! 💎", color: .yellow)
                jackpotRow = nil
            }
            
            currentRow += 1
            updateMultiplier()
            checkCashoutSuggestion()

            if currentRow >= grid.count { endGame(won: true) }
        } else { // Bomb
            endGame(won: false)
        }
    }

    func cashout() {
        guard gameState == .playing, currentRow > 0 else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        triggerWinFlash += 1
        
        if currentRow <= 2 {
            let bet = Double(betAmount) ?? 0.0
            let earlyBonus = Int(bet * 0.1)
            sessionManager.money += earlyBonus
            bonusText = BonusTextItem(text: "+\(earlyBonus) Early Bonus!", color: .cyan)
        }
        
        endGame(won: true)
    }

    private func endGame(won: Bool) {
        gameState = .gameOver
        let bet = Double(betAmount) ?? 0.0

        sessionManager.towersGameHistory.append(won)
        if sessionManager.towersGameHistory.count > 10 {
            sessionManager.towersGameHistory.removeFirst()
        }

        if won {
            winStreak += 1
            let finalWinnings = bet * currentMultiplier
            let roundProfit = finalWinnings - bet
            
            sessionManager.money += Int(finalWinnings.rounded())
            sessionManager.totalMoneyWon += Int(roundProfit.rounded())
            if Int(roundProfit.rounded()) > sessionManager.biggestWin {
                sessionManager.biggestWin = Int(roundProfit.rounded())
            }
        } else {
            winStreak = 0
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            triggerLossShake += 1
            self.profit = -bet
            for r in 0..<grid.count {
                for c in 0..<grid[r].count where !grid[r][c] && !revealedTiles[r].contains(c) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + .random(in: 0.2...0.6)) {
                        self.revealedTiles[r].append(c)
                    }
                }
            }
        }
        
        sessionManager.towersWinStreak = self.winStreak
        sessionManager.saveData()
        
        resetGameCancellable = Just(()).delay(for: .seconds(1.5), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in self?.prepareForNewGame() }
    }
    
    func prepareForNewGame() {
        self.resetGame(isNewGame: false)
    }
    
    func resetGame(isNewGame: Bool) {
        if isNewGame {
            winStreak = 0
            sessionManager.towersWinStreak = 0
        }
        gameState = .idle; currentRow = 0; profit = 0.0; combo = 0; shouldSuggestCashout = false
        revealedTiles = Array(repeating: [], count: 8); generateGrid()
        
        // BUG FIX: Recalculate streak bonus on reset to fix display glitch
        self.streakBonusMultiplier = calculateStreakBonus()
    }
    
    private func updateMultiplier() {
        guard currentRow > 0 else { return }
        var newMultiplier = multipliers[currentRow - 1]
        
        let streakBonus = calculateStreakBonus()
        self.streakBonusMultiplier = streakBonus
        newMultiplier *= streakBonus
        
        if combo >= 3 {
            let comboBonus = 1.05
            newMultiplier *= comboBonus
            if combo == 3 {
                 bonusText = BonusTextItem(text: "x1.05 Combo!", color: .green)
            }
        }
        
        currentMultiplier = newMultiplier
        profit = (Double(betAmount) ?? 0.0) * (currentMultiplier - 1.0)
    }

    private func calculateStreakBonus() -> Double {
        guard winStreak > 0 else { return 1.0 }

        let baseStreakFactor = 1.0 + (log(Double(winStreak) + 1) * 0.1)

        let difficultyMultiplier: Double
        switch riskLevel {
        case .easy: difficultyMultiplier = 1.0
        case .medium: difficultyMultiplier = 1.15
        case .hard: difficultyMultiplier = 1.3
        }

        let recentLosses = sessionManager.towersGameHistory.filter { !$0 }.count
        let mercyBonus = 1.0 + (Double(recentLosses) * 0.02)

        let totalBonus = (baseStreakFactor * difficultyMultiplier * mercyBonus)
        return min(totalBonus, 2.5)
    }
    
    private func checkCashoutSuggestion() {
        guard currentRow < grid.count, let bet = Double(betAmount), bet > 0 else {
            shouldSuggestCashout = false
            return
        }
        
        let currentProfit = self.profit
        let nextPotentialMultiplier = self.multipliers[currentRow]
        let nextPotentialProfit = bet * (nextPotentialMultiplier - 1.0)
        
        let potentialGain = nextPotentialProfit - currentProfit
        let risk = bet
        
        shouldSuggestCashout = (potentialGain > 0 && (risk / potentialGain) > 3.0)
    }

    private func generateGrid() {
        let rows = 8; let cols = riskLevel.columnCount; let bombs = riskLevel.bombCount
        var newGrid: [[Bool]] = []; var newMultipliers: [Double] = []; var currentMult: Double = 1.0
        
        for _ in 0..<rows {
            var row = Array(repeating: true, count: cols); var bombIndices: Set<Int> = []
            while bombIndices.count < bombs { bombIndices.insert(Int.random(in: 0..<cols)) }
            for index in bombIndices { row[index] = false }
            newGrid.append(row)
            
            let probability = Double(cols - bombs) / Double(cols)
            currentMult *= (1.0 / probability) * 0.98; newMultipliers.append(currentMult)
        }
        
        self.grid = newGrid; self.multipliers = newMultipliers; self.gridID = UUID()
        
        let safeRows = (0..<rows).filter { r in newGrid[r].contains(true) }
        if let randomRow = safeRows.randomElement() {
            let safeCols = (0..<cols).filter { c in newGrid[randomRow][c] }
            if let randomCol = safeCols.randomElement() {
                self.jackpotRow = randomRow
                self.jackpotCol = randomCol
            }
        } else {
            jackpotRow = nil
            jackpotCol = nil
        }
    }
}
