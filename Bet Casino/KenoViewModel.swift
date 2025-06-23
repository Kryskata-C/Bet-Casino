// Bet Casino/KenoViewModel.swift

import SwiftUI
import Combine

struct KenoBonusTextItem: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let color: Color
}

// --- MODIFIED: A completely new set of creative and meaningful boosts ---
enum KenoBoost: CaseIterable {
    case highRoller, secondChance, gemJackpot
    
    var cost: Int {
        switch self {
        case .highRoller: return 10
        case .secondChance: return 15
        case .gemJackpot: return 12
        }
    }
    
    var name: String {
        switch self {
        case .highRoller: return "High Roller"
        case .secondChance: return "Second Chance"
        case .gemJackpot: return "Gem Jackpot"
        }
    }
    
    var description: String {
        switch self {
        case .highRoller: return "Dramatically increases payouts for 5+ hits, but you win nothing for less than 3 hits."
        case .secondChance: return "If you win 0x on your bet, your original bet amount is instantly returned."
        case .gemJackpot: return "For this round, every number you hit will also award you with 1 Gem."
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
    
    // --- Properties for new features ---
    @Published var activeBoosts: Set<KenoBoost> = []
    @Published var isMercyModeActive: Bool = false
    @Published var hotNumbers: Set<Int> = []
    @Published var coldNumbers: Set<Int> = []


    // MARK: - Payout Information
    let payoutTable: [Int: [Int: Double]] = [
        1: [1: 2.5],
        2: [1: 0.5, 2: 6.0],
        3: [1: 0.1, 2: 1.8, 3: 15.0],
        4: [2: 1.0, 3: 3.5, 4: 28.0],
        5: [2: 0.2, 3: 1.6, 4: 5.5, 5: 80.0],
        6: [3: 0.5, 4: 2.5, 5: 15.0, 6: 120.0],
        7: [3: 0.5, 4: 2.2, 5: 9.0, 6: 35.0, 7: 325.0]
    ]

    
    public var sessionManager: SessionManager
    private var cancellables = Set<AnyCancellable>()

    enum GameState { case betting, drawing, results }
    
    init(session: SessionManager) {
        self.sessionManager = session
        self.winStreak = session.kenoWinStreak
        
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
        
        var totalDraws = 9
        if isMercyModeActive { totalDraws += 1 }
        
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
        
        var baseMultiplier = payoutTable[spotsPicked]?[spotsHit] ?? 0.0

        // --- NEW: Apply "High Roller" boost effect ---
        if activeBoosts.contains(.highRoller) {
            if spotsHit < 3 {
                baseMultiplier = 0 // No win for small hits
            } else if spotsHit >= 5 {
                baseMultiplier *= 1.5 // Big bonus for large hits
                bonusText = KenoBonusTextItem(text: "High Roller Bonus!", color: .yellow)
            }
        }

        let riskBonus = calculateRiskFactorBonus()
        let streakBonus = calculateStreakBonus()
        let luckyBonus = calculateLuckyNumberBonus()
        
        currentMultiplier = baseMultiplier * riskBonus * streakBonus * luckyBonus
        
        // --- NEW: Apply "Second Chance" boost BEFORE calculating profit ---
        if activeBoosts.contains(.secondChance) && currentMultiplier == 0 {
            currentMultiplier = 1.0 // Return the bet
            bonusText = KenoBonusTextItem(text: "Second Chance!", color: .green)
        }

        let winnings = bet * currentMultiplier
        self.lastWinnings = winnings
        self.profit = winnings - bet

        if self.profit > 0 {
            winStreak += 1
            sessionManager.kenoConsecutiveLosses = 0
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            KenoSoundManager.shared.playSound(sound: .cashout)
            sessionManager.money += Int(winnings.rounded())
            showWinSummary = true
        } else {
            winStreak = 0
            if !(activeBoosts.contains(.secondChance) && winnings == bet) {
                 sessionManager.kenoConsecutiveLosses += 1
            }
        }
        
        // --- NEW: Apply "Gem Jackpot" boost ---
        if activeBoosts.contains(.gemJackpot) && !hits.isEmpty {
            let gemsWon = hits.count
            sessionManager.gems += gemsWon
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.bonusText = KenoBonusTextItem(text: "+\(gemsWon) GEMS! 💎", color: .cyan)
            }
        }
        
        if hits.contains(jackpotNumber ?? -1) {
            let gemBonus = Int.random(in: 10...25)
            sessionManager.gems += gemBonus
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.bonusText = KenoBonusTextItem(text: "+\(gemBonus) GEMS! 💎", color: .cyan)
            }
        }
        
        sessionManager.kenoDrawHistory.append(contentsOf: drawnNumbers)
        if sessionManager.kenoDrawHistory.count > 50 {
            sessionManager.kenoDrawHistory.removeFirst(sessionManager.kenoDrawHistory.count - 50)
        }
        activeBoosts.removeAll()
        
        sessionManager.kenoWinStreak = self.winStreak
        sessionManager.saveData()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.gameState = .results
        }
    }

    private func resetForNewRound() {
        drawnNumbers.removeAll(); hits.removeAll(); profit = 0; currentMultiplier = 0
        cancellables.forEach { $0.cancel() }
        
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
    
    func toggleBoost(_ boost: KenoBoost) {
        if activeBoosts.contains(boost) {
            activeBoosts.remove(boost)
            sessionManager.gems += boost.cost
        } else {
            guard sessionManager.gems >= boost.cost else { return }
            sessionManager.gems -= boost.cost
            activeBoosts.insert(boost)
        }
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
        let luckyNumberCount = 2 // Keeping the base at 2
        while luckyNumbers.count < luckyNumberCount { luckyNumbers.insert(Int.random(in: 1...25)) }
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
    var isHot: Bool = false
    var isCold: Bool = false
    enum State { case none, selected, drawn, hit }
}
