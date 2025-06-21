import SwiftUI
import Combine

class TowersViewModel: ObservableObject {
    // Game State
    @Published var grid: [[Bool]] = []
    @Published var gameState: GameState = .idle
    @Published var currentRow: Int = 0
    @Published var revealedTiles: [[Int]] = []
    @Published var gridID = UUID()
    
    // Animation State
    @Published var winningsAmount: Int? = nil

    // Bet Properties
    @Published var riskLevel: RiskLevel = .medium {
        didSet {
            if oldValue != riskLevel && gameState == .idle {
                resetGame()
            }
        }
    }
    @Published var betAmount: String = ""
    @Published var profit: Double = 0.0
    @Published var currentMultiplier: Double = 1.0
    @Published var multipliers: [Double] = []

    private var sessionManager: SessionManager
    private var resetGameCancellable: AnyCancellable?

    enum GameState { case idle, playing, gameOver }
    enum RiskLevel: String, CaseIterable {
        case easy = "Easy"
        case medium = "Medium"
        case hard = "Hard"

        var columnCount: Int {
            switch self {
            case .easy, .hard: return 3
            case .medium: return 2
            }
        }
        
        var bombCount: Int {
            switch self {
            case .easy, .medium: return 1
            case .hard: return 2
            }
        }
    }

    init(sessionManager: SessionManager) {
        self.sessionManager = sessionManager
        resetGame()
    }

    func startGame() {
        guard let bet = Int(betAmount), bet > 0, bet <= sessionManager.money else { return }
        resetGameCancellable?.cancel()
        sessionManager.money -= bet
        sessionManager.towersBets += 1
        generateGrid()
        gameState = .playing
    }

    func tileTapped(row: Int, col: Int) {
        guard gameState == .playing, row == currentRow, !revealedTiles[row].contains(col) else { return }

        withAnimation(.spring()) {
            revealedTiles[row].append(col)
        }
        
        if grid[row][col] {
            currentRow += 1
            currentMultiplier = multipliers[row]
            profit = (Double(betAmount) ?? 0.0) * (currentMultiplier - 1.0)
            if currentRow >= grid.count {
                endGame(won: true)
            }
        } else {
            endGame(won: false)
        }
    }

    func cashout() {
        guard gameState == .playing, currentRow > 0 else { return }
        endGame(won: true)
    }

    private func endGame(won: Bool) {
        gameState = .gameOver
        let bet = Double(betAmount) ?? 0.0

        if won {
            let finalWinnings = bet * currentMultiplier
            let roundProfit = finalWinnings - bet
            
            // Trigger the win animation
            self.winningsAmount = Int(roundProfit.rounded())
            
            self.profit = roundProfit
            sessionManager.money += Int(finalWinnings.rounded())
            sessionManager.totalMoneyWon += Int(roundProfit.rounded())
            if Int(roundProfit.rounded()) > sessionManager.biggestWin {
                sessionManager.biggestWin = Int(roundProfit.rounded())
            }
        } else {
            self.profit = -bet
            for r in 0..<grid.count {
                for c in 0..<grid[r].count where !grid[r][c] {
                    if !revealedTiles[r].contains(c) {
                        revealedTiles[r].append(c)
                    }
                }
            }
        }
        
        sessionManager.saveData()
        
        resetGameCancellable = Just(()).delay(for: .seconds(2), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in self?.resetGame() }
    }
    
    func resetGame() {
        gameState = .idle
        currentRow = 0
        profit = 0.0
        currentMultiplier = 1.0
        winningsAmount = nil // Make sure to reset the animation trigger
        revealedTiles = Array(repeating: [], count: 8)
        generateGrid()
    }

    private func generateGrid() {
        let rows = 8
        let cols = riskLevel.columnCount
        let bombs = riskLevel.bombCount
        var newGrid: [[Bool]] = []
        var newMultipliers: [Double] = []
        var currentMult: Double = 1.0
        
        for _ in 0..<rows {
            var row = Array(repeating: true, count: cols)
            var bombIndices: Set<Int> = []
            while bombIndices.count < bombs {
                bombIndices.insert(Int.random(in: 0..<cols))
            }
            for index in bombIndices {
                row[index] = false
            }
            newGrid.append(row)
            
            let probability = Double(cols - bombs) / Double(cols)
            currentMult *= (1.0 / probability) * 0.98
            newMultipliers.append(currentMult)
        }
        
        self.grid = newGrid
        self.multipliers = newMultipliers
        self.gridID = UUID()
    }
}
