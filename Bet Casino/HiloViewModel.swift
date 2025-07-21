// Bet Casino/HiloViewModel.swift

import SwiftUI
import Combine

// MARK: - Card Model
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

// MARK: - ViewModel
class HiloViewModel: ObservableObject {
    // MARK: - Game State
    @Published var gameState: GameState = .betting
    @Published var deck: [Card] = []
    @Published var currentCard: Card?
    @Published var revealedCard: Card?
    @Published var betAmount: String = "1000"

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

    enum GameState { case betting, playing, result }
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
        guard gameState == .playing, let current = currentCard, deck.count > 0 else { return }

        let nextDrawnCard = deck.popLast()
        

        guard let next = nextDrawnCard else { return }
        
        var outcome: Outcome
        if next.rank > current.rank { outcome = (guess == .higher) ? .win : .loss }
        else if next.rank < current.rank { outcome = (guess == .lower) ? .win : .loss }
        else { outcome = .tie }
        
        // Use a short delay to show the outcome indicator after the flip starts
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.lastOutcome = outcome
        }

        if outcome == .win {
            let successChance = (guess == .higher ? higherChance : lowerChance) / 100.0
            let multiplierIncrease = successChance > 0 ? (1.0 / successChance) * 0.97 : 2.0
            currentMultiplier *= multiplierIncrease
            profit = (Double(betAmount) ?? 0) * (currentMultiplier - 1.0)
            
            // Prepare for the next card after a longer delay for the user to see the result
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.prepareForNextCard()
            }
        } else {
            profit = -(Double(betAmount) ?? 0.0)
            gameState = .result
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.startNewGame()
            }
        }
    }
    
    func skipCard() {
        guard gameState == .playing, deck.count > 1 else { return }
        currentCard = deck.popLast()
        calculateChances()
    }
    
    func cashout() {
        guard gameState == .playing, profit > 0 else { return }
        
        let winnings = (Double(betAmount) ?? 0.0) * currentMultiplier
        sessionManager.money += Int(winnings.rounded())
        sessionManager.totalMoneyWon += Int(profit.rounded())
        if Int(profit.rounded()) > sessionManager.biggestWin { sessionManager.biggestWin = Int(profit.rounded()) }
        sessionManager.addGameHistory(gameName: "Hilo", profit: Int(profit.rounded()), betAmount: Int(betAmount) ?? 0)
        sessionManager.saveData()
        
        gameState = .result
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { self.startNewGame() }
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
        calculateChances()
    }
    
    private func prepareForNextCard() {
        lastOutcome = nil
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            self.flipCard = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.currentCard = self.revealedCard
            self.revealedCard = nil
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
        
        let higherCount = deck.filter { $0.rank >= current.rank }.count
        let lowerCount = deck.filter { $0.rank <= current.rank }.count
        
        higherChance = (Double(higherCount) / Double(remainingCount)) * 100
        lowerChance = (Double(lowerCount) / Double(remainingCount)) * 100
    }
}
