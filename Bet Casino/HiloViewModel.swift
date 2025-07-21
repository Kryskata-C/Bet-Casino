// Bet Casino/HiloViewModel.swift

import SwiftUI
import Combine

// MARK: - Models
struct Card: Identifiable, Equatable {
    let id = UUID()
    let suit: Suit
    let rank: Rank

    var description: String {
        return "\(rank.displayValue)\(suit.rawValue)"
    }

    enum Suit: String, CaseIterable {
        case spades = "♠", hearts = "♥", diamonds = "♦", clubs = "♣"
    }

    enum Rank: Int, CaseIterable, Comparable {
        case two = 2, three, four, five, six, seven, eight, nine, ten, jack, queen, king, ace

        static func < (lhs: Card.Rank, rhs: Card.Rank) -> Bool {
            return lhs.rawValue < rhs.rawValue
        }

        var displayValue: String {
            switch self {
            case .jack: return "J"
            case .queen: return "Q"
            case .king: return "K"
            case .ace: return "A"
            default: return "\(rawValue)"
            }
        }
    }
}

// ✅ NEW: Model for the visual guess history bar
struct HiloHistoryItem: Identifiable, Equatable {
    let id = UUID()
    let card: Card
    let guess: HiloViewModel.Guess
}


// MARK: - ViewModel
class HiloViewModel: ObservableObject {
    // MARK: - Game State
    @Published var gameState: GameState = .betting
    @Published var deck: [Card] = []
    @Published var currentCard: Card?
    @Published var revealedCard: Card?
    @Published var betAmount: String = "1000"
    
    // ✅ NEW: Published property for guess history
    @Published var guessHistory: [HiloHistoryItem] = []

    // MARK: - Calculation & Chances
    @Published var higherChance: Double = 0.0
    @Published var lowerChance: Double = 0.0
    @Published var currentMultiplier: Double = 1.0
    @Published var profit: Double = 0.0
    
    // MARK: - UI State
    @Published var lastOutcome: Outcome? = nil
    @Published var flipCard = false
    @Published var isBetAmountInvalid = false


    private var sessionManager: SessionManager
    private var cancellables = Set<AnyCancellable>()

    enum GameState { case betting, playing, revealing }
    enum Guess { case higher, lower }
    enum Outcome { case win, loss, tie }

    init(session: SessionManager) {
        self.sessionManager = session
        startNewGame()
    }

    // MARK: - Game Actions
    func placeBet() {
        guard let bet = Int(betAmount), bet > 0, bet <= sessionManager.money else {
            isBetAmountInvalid = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.isBetAmountInvalid = false }
            return
        }
        
        sessionManager.money -= bet
        gameState = .playing
        isBetAmountInvalid = false
    }

    func makeGuess(_ guess: Guess) {
        guard gameState == .playing, let current = currentCard, let nextDrawnCard = deck.popLast() else { return }

        gameState = .revealing
        
        self.revealedCard = nextDrawnCard
        withAnimation { self.flipCard = true }
        
        var outcome: Outcome
        if nextDrawnCard.rank > current.rank { outcome = (guess == .higher) ? .win : .loss }
        else if nextDrawnCard.rank < current.rank { outcome = (guess == .lower) ? .win : .loss }
        else { outcome = .tie }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            self.lastOutcome = outcome
        }

        if outcome == .win {
            let historyItem = HiloHistoryItem(card: current, guess: guess)
            withAnimation {
                guessHistory.append(historyItem)
                if guessHistory.count > 7 { // Keep the visual history to a max of 7 cards
                    guessHistory.removeFirst()
                }
            }
            
            let successChance = (guess == .higher ? higherChance : lowerChance) / 100.0
            let multiplierIncrease = successChance > 0 ? (1.0 / successChance) * 0.97 : 2.0
            currentMultiplier *= multiplierIncrease
            profit = (Double(betAmount) ?? 0) * (currentMultiplier - 1.0)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                self.prepareForNextCard(with: nextDrawnCard)
            }
        } else {
            profit = -(Double(betAmount) ?? 0.0)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                self.startNewGame()
            }
        }
    }
    
    func skipCard() {
        guard gameState == .playing, deck.count > 1 else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        currentCard = deck.popLast()
        calculateChances()
    }
    
    func cashout() {
        guard gameState == .playing, profit > 0 else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        
        let winnings = (Double(betAmount) ?? 0.0) * currentMultiplier
        sessionManager.money += Int(winnings.rounded())
        sessionManager.totalMoneyWon += Int(profit.rounded())
        if Int(profit.rounded()) > sessionManager.biggestWin { sessionManager.biggestWin = Int(profit.rounded()) }
        sessionManager.addGameHistory(gameName: "Hilo", profit: Int(profit.rounded()), betAmount: Int(betAmount) ?? 0)
        sessionManager.saveData()
        
        startNewGame()
    }

    // MARK: - Game Flow Helpers
    private func startNewGame() {
        deck = createShuffledDeck()
        currentCard = deck.popLast()
        revealedCard = nil
        profit = 0.0
        currentMultiplier = 1.0
        lastOutcome = nil
        flipCard = false
        gameState = .betting
        guessHistory.removeAll()
        calculateChances()
    }
    
    private func prepareForNextCard(with newCard: Card) {
        lastOutcome = nil
        currentCard = newCard
        revealedCard = nil
        
        withAnimation { self.flipCard = false }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            self.gameState = .playing
            self.calculateChances()
        }
    }

    private func createShuffledDeck() -> [Card] {
        return Card.Suit.allCases.flatMap { suit in
            Card.Rank.allCases.map { rank in Card(suit: suit, rank: rank) }
        }.shuffled()
    }
    
    private func calculateChances() {
        guard let current = currentCard else { return }
        
        let remainingCount = deck.count
        guard remainingCount > 0 else { higherChance = 0; lowerChance = 0; return }
        
        let higherCount = deck.filter { $0.rank > current.rank }.count
        let lowerCount = deck.filter { $0.rank < current.rank }.count
        
        higherChance = (Double(higherCount) / Double(remainingCount)) * 100
        lowerChance = (Double(lowerCount) / Double(remainingCount)) * 100
    }
}
