import SwiftUI
import Combine
import UIKit

class TowersViewModel: ObservableObject {
    // Game State
    @Published var grid: [[Bool]] = []
    @Published var gameState: GameState = .idle
    @Published var currentRow: Int = 0
    @Published var revealedTiles: [[Int]] = []
    @Published var gridID = UUID()
    
    // For polished transitions and feedback
    @Published var showGrid = true
    @Published var triggerLossShake = 0
    @Published var triggerWinFlash = 0

    // Bet Properties
    @Published var riskLevel: RiskLevel = .medium {
        didSet { if oldValue != riskLevel && gameState == .idle { resetGame() } }
    }
    @Published var betAmount: String = ""
    @Published var profit: Double = 0.0
    @Published var currentMultiplier: Double = 1.0
    @Published var multipliers: [Double] = []

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
        resetGame()
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
        if grid[row][col] {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            currentRow += 1
            currentMultiplier = multipliers[row]
            profit = (Double(betAmount) ?? 0.0) * (currentMultiplier - 1.0)
            if currentRow >= grid.count { endGame(won: true) }
        } else {
            endGame(won: false)
        }
    }

    func cashout() {
        guard gameState == .playing, currentRow > 0 else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        triggerWinFlash += 1
        endGame(won: true)
    }

    private func endGame(won: Bool) {
        gameState = .gameOver
        if won {
            let bet = Double(betAmount) ?? 0.0
            let finalWinnings = bet * currentMultiplier
            let roundProfit = finalWinnings - bet
            sessionManager.money += Int(finalWinnings.rounded())
            sessionManager.totalMoneyWon += Int(roundProfit.rounded())
            if Int(roundProfit.rounded()) > sessionManager.biggestWin {
                sessionManager.biggestWin = Int(roundProfit.rounded())
            }
        } else {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            triggerLossShake += 1
            self.profit = -(Double(betAmount) ?? 0)
            for r in 0..<grid.count {
                for c in 0..<grid[r].count where !grid[r][c] && !revealedTiles[r].contains(c) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + .random(in: 0.2...0.6)) {
                        self.revealedTiles[r].append(c)
                    }
                }
            }
        }
        sessionManager.saveData()
        
        // --- FIXED: Reduced delay to make the transition feel immediate ---
        resetGameCancellable = Just(()).delay(for: .seconds(1.2), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in self?.prepareForNewGame() }
    }
    
    func prepareForNewGame() {
        withAnimation(.easeInOut(duration: 0.4)) { self.showGrid = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            self.resetGame()
            withAnimation(.easeInOut(duration: 0.4)) { self.showGrid = true }
        }
    }
    
    func resetGame() {
        gameState = .idle; currentRow = 0; profit = 0.0; currentMultiplier = 1.0
        revealedTiles = Array(repeating: [], count: 8); generateGrid()
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
    }
}
