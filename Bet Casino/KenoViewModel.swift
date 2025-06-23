// Bet Casino/KenoViewModel.swift

import SwiftUI
import Combine

struct KenoBonusTextItem: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let color: Color
}

// --- NEW: Enum for Gem-Powered Boosts ---
enum KenoBoost {
    case extraDraw, payoutInsurance
    
    var cost: Int {
        switch self {
        case .extraDraw: return 10
        case .payoutInsurance: return 5
        }
    }
    
    var description: String {
        switch self {
        case .extraDraw: return "Draw 10 numbers instead of 9 for one round."
        case .payoutInsurance: return "If you win 0x, get 50% of your bet back."
        }
    }
}


class KenoViewModel: ObservableObject {
    // MARK: - Game State
    @Published var gridNumbers: [KenoNumber] = (1...25).map { KenoNumber(number: $0) }
    @Published var gameState: GameState = .betting
    @Published var betAmount: String = "1000"
    
    // MARK: - Win Summary State
    @Published var showWinSummary = false
    @Published var lastWinnings: Double = 0.0

    // MARK: - Player Selections
    @Published var selectedNumbers: Set<Int> = []
    let maxSelections = 7
    
    // MARK: - Game Outcome
    @Published var drawnNumbers: Set<Int> = []
    @Published var hits: Set<Int> = []
    @Published var profit: Double = 0.0
    @Published var currentMultiplier: Double = 0.0

    // MARK: - Bonus & Streak Properties
    @Published var winStreak: Int = 0
    @Published var luckyNumbers: Set<Int> = []
    @Published var jackpotNumber: Int? = nil
    @Published var bonusText: KenoBonusTextItem? = nil
    
    // --- NEW: Properties for new features ---
    @Published var activeBoost: KenoBoost? = nil
    @Published var isMercyModeActive: Bool = false
    @Published var hotNumbers: Set<Int> = []
    @Published var coldNumbers: Set<Int> = []


    // MARK: - Payout Information
    let payoutTable: [Int: [Int: Double]] = [
        1: [1: 2.5], 2: [1: 0.5, 2: 6.0], 3: [1: 0.1, 2: 1.5, 3: 12.0], 4: [2: 1.0, 3: 3.0, 4: 25.0],
        5: [2: 0.2, 3: 1.5, 4: 5.0, 5: 75.0], 6: [3: 0.5, 4: 2.5, 5: 15.0, 6: 120.0],
        7: [3: 0.5, 4: 2.0, 5: 8.0, 6: 30.0, 7: 300.0]
    ]
    
    public var sessionManager: SessionManager
    private var cancellables = Set<AnyCancellable>()

    enum GameState { case betting, drawing, results }
    
    init(session: SessionManager) {
        self.sessionManager = session
        self.winStreak = session.kenoWinStreak
        
        // --- NEW: Initial setup for new features ---
        self.isMercyModeActive = session.kenoConsecutiveLosses >= 3
        generateLuckyNumbers()
        updateHotColdNumbers()
    }

    // MARK: - Game Actions
    func toggleSelection(_ number: Int) {
        guard gameState == .betting else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        
        if selectedNumbers.contains(number) {
            selectedNumbers.remove(number)
            updateTileState(number, state: .none)
        } else if selectedNumbers.count < maxSelections {
            selectedNumbers.insert(number)
            updateTileState(number, state: .selected)
        }
    }

    func startGame() {
        guard (gameState == .betting || gameState == .results),
              !selectedNumbers.isEmpty,
              let bet = Int(betAmount), bet > 0 else { return }
        
        if gameState == .results { resetForNewRound() }
        
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        KenoSoundManager.shared.playSound(sound: .start)
        sessionManager.money -= bet
        sessionManager.kenoBets += 1
        gameState = .drawing
        
        var numbersToDraw = Array(1...25)
        drawnNumbers.removeAll()
        let potentialJackpotPool = Array(1...25).filter { !selectedNumbers.contains($0) }
        self.jackpotNumber = potentialJackpotPool.randomElement()
        
        // --- NEW: Determine number of draws based on boosts/mercy ---
        var totalDraws = 9
        if isMercyModeActive { totalDraws += 1 }
        if activeBoost == .extraDraw { totalDraws += 1 }

        Timer.publish(every: 0.25, on: .main, in: .common)
            .autoconnect().prefix(totalDraws)
            .sink(receiveCompletion: { [weak self] _ in self?.endGame() },
                  receiveValue: { [weak self] _ in
                guard let self = self else { return }
                if let drawn = numbersToDraw.randomElement().flatMap({ num in numbersToDraw.removeAll(where: { $0 == num }); return num }) {
                    self.drawnNumbers.insert(drawn)
                    let isHit = self.selectedNumbers.contains(drawn)
                    UIImpactFeedbackGenerator(style: isHit ? .heavy : .light).impactOccurred()
                    KenoSoundManager.shared.playSound(sound: isHit ? .hit : .miss)
                    
                    let isJackpot = drawn == self.jackpotNumber
                    if isJackpot { self.updateTileState(drawn, state: .hit, isJackpot: true) }
                    else { self.updateTileState(drawn, state: isHit ? .hit : .drawn) }
                }
            }).store(in: &cancellables)
    }
    
    private func endGame() {
        let bet = Double(betAmount) ?? 0.0
        hits = selectedNumbers.intersection(drawnNumbers)
        
        let spotsPicked = selectedNumbers.count
        let spotsHit = hits.count
        let baseMultiplier = payoutTable[spotsPicked]?[spotsHit] ?? 0.0

        let riskBonus = calculateRiskFactorBonus()
        let streakBonus = calculateStreakBonus()
        let luckyBonus = calculateLuckyNumberBonus()
        
        currentMultiplier = baseMultiplier * riskBonus * streakBonus * luckyBonus
        let winnings = bet * currentMultiplier
        self.lastWinnings = winnings
        self.profit = winnings - bet

        if self.profit > 0 {
            winStreak += 1
            sessionManager.kenoConsecutiveLosses = 0 // Reset losses on win
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            KenoSoundManager.shared.playSound(sound: .cashout)
            sessionManager.money += Int(winnings.rounded())
            showWinSummary = true
        } else {
            winStreak = 0
            sessionManager.kenoConsecutiveLosses += 1 // Increment losses
            
            // --- NEW: Handle Payout Insurance ---
            if activeBoost == .payoutInsurance {
                let refund = Int(bet * 0.5)
                sessionManager.money += refund
                self.profit += Double(refund)
                bonusText = KenoBonusTextItem(text: "Insurance! +\(refund)", color: .green)
            }
        }
        
        if hits.contains(jackpotNumber ?? -1) {
            let gemBonus = Int.random(in: 10...25)
            sessionManager.gems += gemBonus
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.bonusText = KenoBonusTextItem(text: "+\(gemBonus) GEMS! 💎", color: .cyan)
            }
        }
        
        // --- NEW: Update History & Reset Boosts ---
        sessionManager.kenoDrawHistory.append(contentsOf: drawnNumbers)
        if sessionManager.kenoDrawHistory.count > 50 { // Keep history to last 50 draws
            sessionManager.kenoDrawHistory.removeFirst(sessionManager.kenoDrawHistory.count - 50)
        }
        activeBoost = nil
        
        sessionManager.kenoWinStreak = self.winStreak
        sessionManager.saveData()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.gameState = .results
        }
    }

    private func resetForNewRound() {
        drawnNumbers.removeAll(); hits.removeAll(); profit = 0; currentMultiplier = 0
        cancellables.forEach { $0.cancel() }
        
        // --- NEW: Update for new features ---
        isMercyModeActive = sessionManager.kenoConsecutiveLosses >= 3
        generateLuckyNumbers()
        updateHotColdNumbers()
        
        for i in gridNumbers.indices {
            let num = gridNumbers[i].number
            gridNumbers[i].state = selectedNumbers.contains(num) ? .selected : .none
            gridNumbers[i].isJackpot = false
        }
    }
    
    func fullReset() {
        gameState = .betting; showWinSummary = false; selectedNumbers.removeAll()
        resetForNewRound()
    }
    
    private func updateTileState(_ number: Int, state: KenoNumber.State, isJackpot: Bool = false) {
        if let index = gridNumbers.firstIndex(where: { $0.number == number }) {
            gridNumbers[index].state = state
            gridNumbers[index].isJackpot = isJackpot
        }
    }
    
    // --- NEW: Functions for new features ---
    func activateBoost(_ boost: KenoBoost) {
        guard sessionManager.gems >= boost.cost else { return }
        sessionManager.gems -= boost.cost
        activeBoost = boost
    }
    
    private func updateHotColdNumbers() {
        let history = sessionManager.kenoDrawHistory
        guard !history.isEmpty else { return }
        
        let counts = history.reduce(into: [:]) { $0[$1, default: 0] += 1 }
        let sortedCounts = counts.sorted { $0.value > $1.value }
        
        self.hotNumbers = Set(sortedCounts.prefix(3).map { $0.key })
        
        var allNumbers = Set(1...25)
        let drawnNumbers = Set(history)
        allNumbers.subtract(drawnNumbers)
        self.coldNumbers = allNumbers.count > 3 ? Set(allNumbers.shuffled().prefix(3)) : allNumbers

        for i in gridNumbers.indices {
            let num = gridNumbers[i].number
            gridNumbers[i].isHot = self.hotNumbers.contains(num)
            gridNumbers[i].isCold = self.coldNumbers.contains(num)
        }
    }

    private func generateLuckyNumbers() {
        luckyNumbers.removeAll()
        while luckyNumbers.count < 2 { luckyNumbers.insert(Int.random(in: 1...25)) }
        for i in gridNumbers.indices {
            gridNumbers[i].isLucky = luckyNumbers.contains(gridNumbers[i].number)
        }
    }

    private func calculateRiskFactorBonus() -> Double {
        let bet = Double(betAmount) ?? 0.0; let totalMoney = Double(sessionManager.money) + bet
        guard totalMoney > 0 else { return 1.0 }
        let riskRatio = min(1.0, bet / totalMoney)
        return 1.0 + (riskRatio * 0.20)
    }

    private func calculateStreakBonus() -> Double {
        guard winStreak > 0 else { return 1.0 }
        let bonus = 1.0 + (log(Double(winStreak) + 1) * 0.15)
        return min(bonus, 2.5)
    }
    
    private func calculateLuckyNumberBonus() -> Double {
        let luckyHits = hits.intersection(luckyNumbers)
        if !luckyHits.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.bonusText = KenoBonusTextItem(text: "Lucky Hit! ✨", color: .yellow)
            }
            return 1.2
        }
        return 1.0
    }
}

struct KenoNumber: Identifiable, Equatable {
    let id = UUID()
    let number: Int
    var state: State = .none
    var isLucky: Bool = false
    var isJackpot: Bool = false
    var isHot: Bool = false   // ADD THIS
    var isCold: Bool = false  // ADD THIS
    enum State { case none, selected, drawn, hit }
}
