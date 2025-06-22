import SwiftUI
import Combine

// --- UPDATED: Particle struct to support different styles ---
struct Particle: Identifiable {
    let id = UUID()
    var position: CGPoint
    var scale: CGFloat = 1.0
    var opacity: Double = 1.0
    var isBombParticle: Bool = false
}

class MinesViewModel: ObservableObject {
    // Game State
    @Published var tiles: [Tile] = []
    @Published var gameState: GameState = .idle
    @Published var bettingMode: BettingMode = .manual
    
    // --- NEW: For polished transitions and feedback ---
    @Published var showGrid = true
    @Published var triggerLossShake = 0
    @Published var triggerWinFlash = 0
    @Published var lastBombIndex: Int? = nil

    // Bet Properties
    @Published var mineCount: Double = 3.0
    @Published var betAmount: String = ""
    @Published var profit: Double = 0.0
    @Published var currentMultiplier: Double = 1.0
    @Published var isBetAmountInvalid = false

    // Auto Bet Properties & State
    @Published var isAutoBetting: Bool = false, numberOfBets: String = "10", showAutoBetSummary = false
    @Published var autoBetSelection: Set<Int> = [], autoBetWins = 0, autoBetLosses = 0
    @Published var currentBetCount: Int = 0, autoRunProfit: Double = 0.0

    // Streak Properties
    @Published var winStreak: Int = 0
    @Published var streakBonusMultiplier: Double = 1.0
    
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
    
    deinit { stopAutoBet() }

    func startGame() {
        guard let bet = Int(betAmount), bet > 0, bet <= sessionManager.money else {
            isBetAmountInvalid = true; DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.isBetAmountInvalid = false }
            return
        }
        SoundManager.shared.playSound(sound: .start)
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        
        sessionManager.money -= bet; sessionManager.betsPlaced += 1; sessionManager.minesBets += 1
        if Int(betAmount) != sessionManager.lastBetAmount {
            resetStreak(); sessionManager.lastBetAmount = Int(betAmount) ?? 0
        }
        resetBoard(); gameState = .playing; bombIndexes = generateBombs(count: Int(mineCount))
    }

    func tileTapped(_ index: Int) {
        if gameState == .playing {
            guard !tiles[index].isFlipped else { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { tiles[index].isFlipped = true }
            
            if bombIndexes.contains(index) {
                SoundManager.shared.playSound(sound: .bomb)
                tiles[index].isBomb = true; tiles[index].wasLosingBomb = true; lastBombIndex = index
                endGame(won: false)
            } else {
                SoundManager.shared.playSound(sound: .flip)
                selectedTiles.insert(index);
                withAnimation(.spring()) { tiles[index].hasShine = true }
                triggerParticleEffect(at: index, isBomb: false)
                currentMultiplier = calculateManualMultiplier() * calculateStreakBonus(tilesUncovered: selectedTiles.count)
                profit = (Double(betAmount) ?? 0.0) * (currentMultiplier - 1.0)
                if Double(selectedTiles.count) == totalTiles - Double(bombIndexes.count) { endGame(won: true) }
            }
        } else if gameState == .autoSetup {
            toggleAutoBetTile(index)
        }
    }
    
    func cashout() {
        guard gameState == .playing, !selectedTiles.isEmpty else { return }
        SoundManager.shared.playSound(sound: .cashout)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        triggerWinFlash += 1
        endGame(won: true)
    }

    private func endGame(won: Bool) {
        guard gameState == .playing else { return }
        gameState = .gameOver
        let bet = Double(betAmount) ?? 0.0

        if won {
            winStreak += 1
            streakBonusMultiplier = calculateStreakBonus(tilesUncovered: selectedTiles.count)
            let finalWinnings = bet * currentMultiplier
            let roundProfit = finalWinnings - bet
            self.profit = roundProfit
            sessionManager.money += Int(finalWinnings.rounded())
            sessionManager.totalMoneyWon += Int(roundProfit.rounded())
            if Int(roundProfit.rounded()) > sessionManager.biggestWin {
                sessionManager.biggestWin = Int(roundProfit.rounded())
            }
        } else {
            self.profit = -bet; resetStreak(); triggerLossShake += 1
            if let bombIndex = lastBombIndex { triggerParticleEffect(at: bombIndex, isBomb: true) }
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            for i in bombIndexes where !tiles[i].isFlipped {
                DispatchQueue.main.asyncAfter(deadline: .now() + .random(in: 0.2...0.6)) {
                    withAnimation(.spring()) { self.tiles[i].isFlipped = true; self.tiles[i].isBomb = true }
                }
            }
        }
        
        sessionManager.saveData()
        resetGameCancellable = Just(()).delay(for: .seconds(1.5), scheduler: DispatchQueue.main)
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
        resetGameCancellable?.cancel(); resetBoard(); lastBombIndex = nil
        if bettingMode == .manual { autoBetSelection.removeAll(); gameState = .idle }
        else { gameState = .autoSetup }
    }
    
    func resetBoard() {
        tiles = Array(repeating: Tile(), count: Int(totalTiles)); selectedTiles.removeAll()
        bombIndexes.removeAll(); profit = 0.0; currentMultiplier = 1.0
    }
    
    private func generateBombs(count: Int) -> Set<Int> {
        var bombs = Set<Int>(); while bombs.count < count { bombs.insert(Int.random(in: 0..<Int(totalTiles))) }
        return bombs
    }
    
    func triggerParticleEffect(at index: Int, isBomb: Bool) {
        let particleCount = isBomb ? 50 : 15
        for _ in 0..<particleCount {
            tiles[index].particles.append(Particle(position: .zero, isBombParticle: isBomb))
        }

        for i in 0..<tiles[index].particles.count {
            let randomX = CGFloat.random(in: -80...80), randomY = CGFloat.random(in: -80...80)
            let duration = isBomb ? 0.8 : 1.2
            withAnimation(.easeOut(duration: duration).delay(.random(in: 0...0.1))) {
                tiles[index].particles[i].position = CGPoint(x: randomX, y: randomY)
                tiles[index].particles[i].opacity = 0
                tiles[index].particles[i].scale = 0.5
            }
        }
    }
    
    func calculateManualMultiplier() -> Double {
        guard !bombIndexes.isEmpty else { return 1.0 }
        let n = totalTiles, m = Double(bombIndexes.count), k = Double(selectedTiles.count)
        if k == 0 { return 1.0 }
        var calculatedMult = 1.0
        for i in 0..<Int(k) { calculatedMult *= (n - m - Double(i)) / (n - Double(i)) }
        let base = (1 / calculatedMult) * 0.98
        let risk = min(1.0, (Double(betAmount) ?? 0) / max(Double(sessionManager.money) + (Double(betAmount) ?? 0), 1))
        let mineBonus = 1.0 + (m / n) * 0.3
        return base * mineBonus * (1 + risk * 0.15)
    }

    func calculateStreakBonus(tilesUncovered: Int) -> Double {
        guard winStreak > 0 else { return 1.0 }
        let uncoveredRatio = Double(tilesUncovered) / (totalTiles - mineCount)
        let mineDensity = mineCount / totalTiles; let streakFactor = log(Double(winStreak) + 1) * 1.25
        let level = Double(sessionManager.level)
        let levelMultiplier = pow(1.1, level > 0 ? level : 1.0)
        let bonus = 1.0 + (uncoveredRatio * mineDensity * streakFactor * levelMultiplier * 0.1)
        return min(25.0, bonus)
    }

    private func resetStreak() { winStreak = 0; streakBonusMultiplier = 1.0 }
    private func toggleAutoBetTile(_ index: Int) {
        if autoBetSelection.contains(index) { autoBetSelection.remove(index) }
        else { autoBetSelection.insert(index) }
    }
    func switchBettingMode(to mode: BettingMode) { stopAutoBet(); bettingMode = mode; resetGame() }
    func startAutoBet() { /* Auto-bet logic here */ }
    func stopAutoBet() { /* Auto-bet logic here */ }
}
