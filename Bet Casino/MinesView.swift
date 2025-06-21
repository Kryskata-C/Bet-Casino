import SwiftUI
import Combine

// MARK: - Enums & Models
enum BettingMode {
    case manual, auto
}

enum MinesFocusField {
    case betAmount, numberOfBets
}

struct Tile: Identifiable {
    let id = UUID()
    var isFlipped: Bool = false
    var isBomb: Bool = false
    var hasShine: Bool = false
    var wasLosingBomb: Bool = false
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
        let level = 1.0 
        guard winStreak > 0 else { return 1.0 }
        let uncoveredRatio = Double(tilesUncovered) / (totalTiles - mineCount)
        let mineDensity = mineCount / totalTiles
        let streakFactor = log(Double(winStreak) + 1) * 1.25
        let levelMultiplier = pow(1.15, level)
        let bonus = 1.0 + (uncoveredRatio * mineDensity * streakFactor * levelMultiplier)
        return min(25.0, bonus)
    }

}


// MARK: - Main View
struct MinesView: View {
    @StateObject private var viewModel: MinesViewModel
    @FocusState private var focusedField: MinesFocusField?
    
    @State private var showStreakBonus = false
    @State private var streakAnimationId = UUID()

    init(session: SessionManager) {
        _viewModel = StateObject(wrappedValue: MinesViewModel(sessionManager: session))
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [.black, Color(red: 35/255, green: 0, blue: 50/255).opacity(0.9)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 15) {
                    StatusHeaderView(viewModel: viewModel)
                    
                    ZStack {
                        GridView(viewModel: viewModel)
                        
                        if showStreakBonus {
                            StreakBonusView(bonus: viewModel.streakBonusMultiplier)
                                .id(streakAnimationId)
                        }
                    }
                    
                    ControlsView(viewModel: viewModel, focusedField: $focusedField)
                }
                .padding()
            }
            // The scaleEffect is now removed from here so it's not applied twice.
        }
        .foregroundColor(.white)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focusedField = nil }
            }
        }
        .onDisappear(perform: viewModel.stopAutoBet)
        .onChange(of: viewModel.winStreak) { oldValue, newValue in
            if newValue > oldValue && newValue > 0 {
                streakAnimationId = UUID()
                withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
                    showStreakBonus = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    withAnimation(.easeOut) {
                        showStreakBonus = false
                    }
                }
            }
        }
    }
}


// MARK: - Subviews
struct StatusHeaderView: View {
    @ObservedObject var viewModel: MinesViewModel
    
    var body: some View {
        if viewModel.bettingMode == .auto {
            AutoStatusView(profit: viewModel.autoRunProfit, streak: viewModel.winStreak)
        } else {
            ManualStatusView(profit: viewModel.profit, multiplier: viewModel.currentMultiplier, streak: viewModel.winStreak)
        }
    }
}

struct ManualStatusView: View {
    let profit: Double
    let multiplier: Double
    let streak: Int
    
    var body: some View {
        HStack(spacing: 10) {
            InfoPill(title: "Multiplier", value: String(format: "%.2fx", multiplier))
            InfoPill(title: "Profit", value: String(format: "%@%.2f", profit >= 0 ? "+" : "", profit),
                     color: profit > 0 ? .green : (profit < 0 ? .red : .white))
            Spacer()
            if streak > 0 {
                InfoPill(title: "Streak", value: "🔥 \(streak)", color: .orange)
            }
        }
        .animation(.easeOut, value: profit)
        .animation(.easeOut, value: multiplier)
        .animation(.spring(), value: streak)
    }
}

struct AutoStatusView: View {
    let profit: Double
    let streak: Int

    var body: some View {
        HStack(spacing: 10) {
            InfoPill(title: "Profit on Run", value: String(format: "%@%.2f", profit >= 0 ? "+" : "", profit),
                     color: profit > 0 ? .green : (profit < 0 ? .red : .white))
            Spacer()
            if streak > 0 {
                InfoPill(title: "Streak", value: "🔥 \(streak)", color: .orange)
            }
        }
        .animation(.easeOut, value: profit)
        .animation(.spring(), value: streak)
    }
}

struct InfoPill: View {
    let title: String
    let value: String
    var color: Color = .white
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundColor(.gray)
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(color)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(GlassView())
    }
}

struct StreakBonusView: View {
    let bonus: Double
    @State private var hasAppeared = false
    
    var body: some View {
        Text(String(format: "%.2fx Streak Bonus!", bonus))
            .font(.title).fontWeight(.heavy)
            .foregroundStyle(LinearGradient(colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom))
            .shadow(color: .yellow.opacity(0.8), radius: 10)
            .scaleEffect(hasAppeared ? 1.0 : 0.5)
            .opacity(hasAppeared ? 1.0 : 0.0)
            .onAppear {
                withAnimation(.interpolatingSpring(mass: 0.5, stiffness: 100, damping: 10, initialVelocity: 5)) {
                    hasAppeared = true
                }
            }
    }
}

struct GridView: View {
    @ObservedObject var viewModel: MinesViewModel
    var body: some View {
        LazyVGrid(columns: viewModel.columns, spacing: 10) {
            ForEach(0..<Int(viewModel.totalTiles), id: \.self) { index in
                TileView(tile: $viewModel.tiles[index], isAutoSelected: viewModel.autoBetSelection.contains(index)) {
                    viewModel.tileTapped(index)
                }
            }
        }
    }
}

struct TileView: View {
    @Binding var tile: Tile
    var isAutoSelected: Bool
    var onTap: () -> Void
    
    var body: some View {
        let isSetupMode = !tile.isFlipped && isAutoSelected
        
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(tile.isFlipped ? (tile.isBomb ? Color.red.opacity(0.6) : Color.purple.opacity(0.4)) : Color.white.opacity(0.05))
                .overlay(isSetupMode ? RoundedRectangle(cornerRadius: 10).stroke(Color.purple, lineWidth: 4) : nil)
                .overlay(tile.wasLosingBomb ? RoundedRectangle(cornerRadius: 10).stroke(Color.yellow, lineWidth: 4) : nil)
                .aspectRatio(1, contentMode: .fit)

            if tile.isFlipped {
                Text(tile.isBomb ? "💣" : "💎")
                    .font(.title2)
                    .shadow(color: tile.hasShine ? .cyan : (tile.isBomb ? .red : .clear), radius: tile.hasShine ? 8 : 5)
            }
        }
        .rotation3DEffect(.degrees(tile.isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
        .onTapGesture {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { onTap() }
        }
    }
}

struct ControlsView: View {
    @ObservedObject var viewModel: MinesViewModel
    @FocusState.Binding var focusedField: MinesFocusField?
    
    var body: some View {
        VStack(spacing: 15) {
            Picker("Betting Mode", selection: $viewModel.bettingMode.animation()) {
                Text("Manual").tag(BettingMode.manual)
                Text("Auto").tag(BettingMode.auto)
            }
            .pickerStyle(SegmentedPickerStyle())
            .background(Color.black.opacity(0.3)).cornerRadius(8)
            .onChange(of: viewModel.bettingMode) { viewModel.switchBettingMode(to: $0) }
            .disabled(viewModel.isAutoBetting)
            
            if viewModel.bettingMode == .manual {
                ManualControlsView(viewModel: viewModel, focusedField: $focusedField)
            } else {
                AutoControlsView(viewModel: viewModel, focusedField: $focusedField)
            }
        }
        .padding().background(GlassView())
    }
}

struct ManualControlsView: View {
    @ObservedObject var viewModel: MinesViewModel
    @FocusState.Binding var focusedField: MinesFocusField?
    
    var body: some View {
        let isPlaying = viewModel.gameState == .playing
        let isBetValid = (Int(viewModel.betAmount) ?? 0) > 0

        let cashoutValue: Double = {
            let bet = Double(viewModel.betAmount) ?? 0
            let streakBonus = viewModel.calculateStreakBonus(tilesUncovered: viewModel.selectedTiles.count)
            return bet * viewModel.currentMultiplier * streakBonus
        }()

        VStack(spacing: 15) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Bet Amount").font(.caption).foregroundColor(.gray)
                    TextField("Enter bet", text: $viewModel.betAmount)
                        .keyboardType(.decimalPad).padding(10)
                        .background(Color.black.opacity(0.2)).cornerRadius(10)
                        .focused($focusedField, equals: .betAmount)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Mines: \(Int(viewModel.mineCount))").font(.caption).foregroundColor(.gray)
                    Slider(value: $viewModel.mineCount, in: 1...24, step: 1).accentColor(.purple)
                }
            }
            .disabled(isPlaying).opacity(isPlaying ? 0.6 : 1.0)
            
            Button(action: {
                if isPlaying { viewModel.cashout() } else { viewModel.startGame() }
            }) {
                Text(isPlaying ? "Cashout (\(String(format: "%.2f", cashoutValue)))" : "Place Bet")
                    .font(.headline).fontWeight(.bold).frame(maxWidth: .infinity).padding()
                    .background(isPlaying ? Color.green : Color.purple)
                    .foregroundColor(isPlaying ? .black : .white).cornerRadius(15)
                    .shadow(color: (isPlaying ? Color.green : Color.purple).opacity(0.5), radius: 10, y: 5)
            }
            .disabled((!isPlaying && !isBetValid) || (isPlaying && viewModel.selectedTiles.isEmpty))
            .opacity((!isPlaying && !isBetValid) || (isPlaying && viewModel.selectedTiles.isEmpty) ? 0.6 : 1.0)
        }
    }
}

struct AutoControlsView: View {
    @ObservedObject var viewModel: MinesViewModel
    @FocusState.Binding var focusedField: MinesFocusField?

    var body: some View {
        let isSetup = viewModel.gameState == .autoSetup
        let canStart = isSetup && !viewModel.autoBetSelection.isEmpty && (Int(viewModel.betAmount) ?? 0) > 0
        let isBetting = viewModel.isAutoBetting
        
        VStack(spacing: 15) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Bet Amount").font(.caption).foregroundColor(.gray)
                    TextField("Enter bet", text: $viewModel.betAmount)
                        .keyboardType(.decimalPad).padding(10)
                        .background(Color.black.opacity(0.2)).cornerRadius(10)
                        .focused($focusedField, equals: .betAmount)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Mines: \(Int(viewModel.mineCount))").font(.caption).foregroundColor(.gray)
                    Slider(value: $viewModel.mineCount, in: 1...24, step: 1).accentColor(.purple)
                }
            }.disabled(isBetting).opacity(isBetting ? 0.6 : 1.0)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Number of Bets").font(.caption).foregroundColor(.gray)
                TextField("Number of bets", text: $viewModel.numberOfBets)
                    .keyboardType(.numberPad).padding(10)
                    .background(Color.black.opacity(0.2)).cornerRadius(10)
                    .focused($focusedField, equals: .numberOfBets)
            }.disabled(isBetting).opacity(isBetting ? 0.6 : 1.0)
            
            if isSetup {
                Text("Select tiles on the grid to include in the auto-bet.")
                    .font(.caption).foregroundColor(.gray).multilineTextAlignment(.center)
            }

            Button(action: {
                if isBetting { viewModel.stopAutoBet() } else { viewModel.startAutoBet() }
            }) {
                Text(isBetting ? "Stop Autobet (\(viewModel.currentBetCount)/\(viewModel.numberOfBets))" : "Start Autobet")
                    .font(.headline).fontWeight(.bold).frame(maxWidth: .infinity).padding()
                    .background(isBetting ? Color.red : (canStart ? Color.green : Color.gray))
                    .foregroundColor(isBetting ? .white : (canStart ? .black : .white)).cornerRadius(15)
                    .shadow(color: (isBetting ? Color.red : (canStart ? Color.green : Color.gray)).opacity(0.5), radius: 10, y: 5)
            }
            .disabled(!isBetting && !canStart)
        }
    }
}

struct GlassView: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 15, style: .continuous)
            .fill(.black.opacity(0.25))
            .overlay(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(.white.opacity(0.3), lineWidth: 1)
            )
    }
}

#Preview {
    ContentView()
        .environmentObject(SessionManager.prefilled())
}

extension SessionManager {
    static func prefilled() -> SessionManager {
        let manager = SessionManager()
        manager.isLoggedIn = true
        manager.username = "Kryska"
        manager.money = 250000
        manager.currentScreen = .mines
        return manager
    }
}
