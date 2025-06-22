import SwiftUI
import Combine

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

    // MARK: - Payout Information
    let payoutTable: [Int: [Int: Double]] = [
        1: [1: 2.0], 2: [1: 0.5, 2: 5.0], 3: [2: 1.5, 3: 10.0], 4: [2: 1.0, 3: 2.5, 4: 20.0],
        5: [3: 1.0, 4: 4.0, 5: 60.0], 6: [3: 0.5, 4: 2.0, 5: 12.0, 6: 100.0],
        7: [3: 0.5, 4: 1.5, 5: 6.0, 6: 25.0, 7: 250.0]
    ]
    
    private var sessionManager: SessionManager
    private var cancellables = Set<AnyCancellable>()

    enum GameState { case betting, drawing, results }
    
    init(session: SessionManager) {
        self.sessionManager = session
    }

    // MARK: - Game Actions
    func toggleSelection(_ number: Int) {
        guard gameState == .betting else { return }
        
        // --- Haptic Feedback for tile selection ---
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
        
        // --- Haptic Feedback for starting game ---
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        
        KenoSoundManager.shared.playSound(sound: .start)
        sessionManager.money -= bet
        gameState = .drawing
        
        var numbersToDraw = Array(1...25)
        drawnNumbers.removeAll()
        
        Timer.publish(every: 0.2, on: .main, in: .common)
            .autoconnect().prefix(9)
            .sink(receiveCompletion: { [weak self] _ in self?.endGame() },
                  receiveValue: { [weak self] _ in
                guard let self = self else { return }
                if let drawn = numbersToDraw.randomElement().flatMap({ num in numbersToDraw.removeAll(where: { $0 == num }); return num }) {
                    self.drawnNumbers.insert(drawn)
                    let isHit = self.selectedNumbers.contains(drawn)
                    
                    // --- Haptic Feedback for hit/miss ---
                    UIImpactFeedbackGenerator(style: isHit ? .heavy : .light).impactOccurred()
                    
                    KenoSoundManager.shared.playSound(sound: isHit ? .hit : .miss)
                    self.updateTileState(drawn, state: isHit ? .hit : .drawn)
                }
            }).store(in: &cancellables)
    }
    
    private func endGame() {
        hits = selectedNumbers.intersection(drawnNumbers)
        let spotsPicked = selectedNumbers.count
        let spotsHit = hits.count
        currentMultiplier = payoutTable[spotsPicked]?[spotsHit] ?? 0.0
        let winnings = (Double(betAmount) ?? 0.0) * currentMultiplier
        self.lastWinnings = winnings
        self.profit = winnings - (Double(betAmount) ?? 0.0)
        
        if self.profit > 0 {
            // --- Haptic Feedback for win ---
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            
            KenoSoundManager.shared.playSound(sound: .cashout)
            sessionManager.money += Int(winnings.rounded())
            showWinSummary = true
        }
        sessionManager.saveData()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.gameState = .results
        }
    }

    private func resetForNewRound() {
        drawnNumbers.removeAll()
        hits.removeAll()
        profit = 0
        currentMultiplier = 0
        cancellables.forEach { $0.cancel() }
        for i in gridNumbers.indices {
            let num = gridNumbers[i].number
            gridNumbers[i].state = selectedNumbers.contains(num) ? .selected : .none
        }
    }
    
    func fullReset() {
        gameState = .betting
        showWinSummary = false
        selectedNumbers.removeAll()
        resetForNewRound()
    }
    
    private func updateTileState(_ number: Int, state: KenoNumber.State) {
        if let index = gridNumbers.firstIndex(where: { $0.number == number }) {
            gridNumbers[index].state = state
        }
    }
}

struct KenoNumber: Identifiable, Equatable {
    let id = UUID()
    let number: Int
    var state: State = .none
    enum State { case none, selected, drawn, hit }
}
