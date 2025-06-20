import SwiftUI
import Combine

// Enum to define the betting mode
enum BettingMode {
    case manual
    case auto
}

// Enum to manage focus state for TextFields
enum MinesFocusField {
    case betAmount
    case numberOfBets
}

struct Tile: Identifiable {
    let id = UUID()
    var isFlipped: Bool = false
    var isBomb: Bool = false
    var hasShine: Bool = false
    var wasLosingBomb: Bool = false
}

class MinesViewModel: ObservableObject {
    // MARK: - Game State Properties
    @Published var tiles: [Tile] = []
    @Published var gameState: GameState = .idle
    
    // MARK: - Manual Bet Properties
    @Published var mineCount: Double = 3.0
    @Published var betAmount: String = ""
    @Published var profit: Double = 0.0
    @Published var currentMultiplier: Double = 1.0

    // MARK: - Auto Bet Properties
    @Published var bettingMode: BettingMode = .manual
    @Published var autoBetSelection: Set<Int> = []
    @Published var numberOfBets: String = "10"
    @Published var isAutoBetting: Bool = false
    @Published var lastRoundProfit: Double? = nil
    @Published var currentBetCount: Int = 0
    @Published var winStreak: Int = 0
    @Published var streakProfit: Double = 0.0
    @Published var streakIntensity: Double = 0.0
    
    // MARK: - Private Properties
    private var sessionManager: SessionManager
    private var bombIndexes: Set<Int> = []
    private var selectedTiles: Set<Int> = []
    private var resetGameCancellable: AnyCancellable?
    private var autoBetTask: Task<Void, Never>?

    let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 5)
    let totalTiles = 25

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
        sessionManager.money -= bet
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
                if selectedTiles.count == totalTiles - bombIndexes.count {
                    endGame(won: true)
                }
            }
        case .autoSetup:
            guard !isAutoBetting else { return }
            toggleAutoBetTile(index)
        default:
            return
        }
    }
    
    func cashout() {
        guard gameState == .playing else { return }
        withAnimation(.easeInOut(duration: 0.4)) {
            endGame(won: true)
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func endGame(won: Bool) {
        gameState = .gameOver
        let bet = Double(betAmount) ?? 0.0

        if won {
            let streakBonus = calculateStreakBonus()
            let finalMultiplier = currentMultiplier * streakBonus
            let finalWinnings = bet * finalMultiplier
            let roundProfit = finalWinnings - bet
            
            self.profit = roundProfit
            
            winStreak += 1
            streakProfit += roundProfit
            
            sessionManager.money += Int(finalWinnings.rounded())
            
        } else {
            self.profit = -bet
            
            winStreak = 0
            streakProfit = 0
            
            for i in bombIndexes where !tiles[i].isFlipped {
                tiles[i].isFlipped = true
                tiles[i].isBomb = true
            }
        }
        
        updateStreakIntensity()
        sessionManager.saveData()
        
        resetGameCancellable = Just(()).delay(for: .seconds(2), scheduler: DispatchQueue.main).sink { [weak self] _ in
            guard let self = self else { return }
            withAnimation(.easeInOut(duration: 0.4)) {
                self.resetGame()
            }
        }
    }
    
    func resetGame() {
        resetGameCancellable?.cancel()
        resetBoard()
        autoBetSelection.removeAll()
        gameState = bettingMode == .auto ? .autoSetup : .idle
    }
    
    func resetBoard() {
        tiles = Array(repeating: Tile(), count: totalTiles)
        selectedTiles.removeAll()
        bombIndexes.removeAll()
        profit = 0.0
        currentMultiplier = 1.0
        lastRoundProfit = nil
    }
    
    func resetBoardForNextRound() {
        bombIndexes.removeAll()
        lastRoundProfit = nil
        for i in 0..<tiles.count {
            tiles[i].isFlipped = false
            tiles[i].isBomb = false
            tiles[i].hasShine = false
            tiles[i].wasLosingBomb = false
        }
    }
    
    // MARK: - Auto Bet Logic
    func switchBettingMode(to mode: BettingMode) {
        stopAutoBet()
        bettingMode = mode
        resetGame()
    }

    private func toggleAutoBetTile(_ index: Int) {
        if autoBetSelection.contains(index) {
            autoBetSelection.remove(index)
        } else {
            autoBetSelection.insert(index)
        }
    }
    
    func startAutoBet() {
        guard let totalBets = Int(numberOfBets), totalBets > 0,
              let bet = Int(betAmount), bet > 0 else { return }

        isAutoBetting = true
        gameState = .autoPlaying
        currentBetCount = 0
        
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
        self.bombIndexes = generateBombs(count: Int(mineCount))
        let multiplier = calculateAutoMultiplier()
        var hitBomb = false
        for tileIndex in autoBetSelection {
            if self.bombIndexes.contains(tileIndex) {
                hitBomb = true
                break
            }
        }
        
        let profitAmount: Double
        if hitBomb {
            profitAmount = -Double(bet)
        } else {
            let winnings = Double(bet) * multiplier
            profitAmount = winnings - Double(bet)
        }

        await MainActor.run {
            withAnimation(.easeInOut(duration: 0.4)) {
                self.sessionManager.money -= bet
                self.sessionManager.money += Int(profitAmount.rounded() + (hitBomb ? 0 : Double(bet)))
                
                self.lastRoundProfit = profitAmount
                for tileIndex in self.autoBetSelection {
                    self.tiles[tileIndex].isFlipped = true
                    if self.bombIndexes.contains(tileIndex) {
                        self.tiles[tileIndex].isBomb = true
                    }
                }
            }
            self.sessionManager.saveData()
        }
        
        try? await Task.sleep(nanoseconds: 800_000_000)
        
        await MainActor.run {
            if self.isAutoBetting {
                withAnimation(.easeInOut(duration: 0.4)) {
                    self.resetBoardForNextRound()
                }
            }
        }
    }

    // MARK: - Helper Functions
    private func generateBombs(count: Int) -> Set<Int> {
        var bombs = Set<Int>()
        while bombs.count < count { bombs.insert(Int.random(in: 0..<totalTiles)) }
        return bombs
    }
    
    private func calculateManualMultiplier() -> Double {
        guard !bombIndexes.isEmpty else { return 1.0 }
        let n = Double(totalTiles), m = Double(bombIndexes.count), k = Double(selectedTiles.count)
        if k == 0 { return 1.0 }
        var calculatedMult = 1.0
        for i in 0..<Int(k) { calculatedMult *= (n - m - Double(i)) / (n - Double(i)) }
        return (1 / calculatedMult) * 0.98
    }
    
    private func calculateAutoMultiplier() -> Double {
        guard !bombIndexes.isEmpty else { return 1.0 }
        let n = Double(totalTiles), m = Double(bombIndexes.count), k = Double(autoBetSelection.count)
        if k == 0 { return 1.0 }
        var calculatedMult = 1.0
        for i in 0..<Int(k) { calculatedMult *= (n - m - Double(i)) / (n - Double(i)) }
        return (1 / calculatedMult) * 0.98
    }
    
    private func calculateStreakBonus() -> Double {
        guard winStreak > 0 else { return 1.0 }
        let streakFactor = pow(Double(winStreak), 1.25) * 0.05
        let riskFactor = 1.0 + (mineCount / Double(totalTiles))
        let bonus = 1.0 + (streakFactor * riskFactor)
        return min(10.0, bonus)
    }

    private func updateStreakIntensity() {
        let bet = Double(betAmount) ?? 1.0
        let targetProfitForMaxFlame = bet * 50.0
        guard targetProfitForMaxFlame > 0 else { streakIntensity = 0; return }
        
        let intensity = streakProfit / targetProfitForMaxFlame
        self.streakIntensity = max(0, intensity)
    }
}


// MARK: - Main View
struct MinesView: View {
    @StateObject private var viewModel: MinesViewModel
    // **THE FIX**: Use an enum for the focus state to handle multiple fields
    @FocusState private var focusedField: MinesFocusField?

    init(session: SessionManager) {
        _viewModel = StateObject(wrappedValue: MinesViewModel(sessionManager: session))
    }

    var body: some View {
        // **THE FIX**: The .ignoresSafeArea modifier is moved to the parent view (MainCasinoView)
        // to prevent the bottom nav bar from moving up.
        ZStack {
            LinearGradient(colors: [.black, Color(red: 35/255, green: 0, blue: 50/255).opacity(0.9)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 15) {
                    if viewModel.bettingMode == .manual {
                        ProfitView(profit: viewModel.profit, multiplier: viewModel.currentMultiplier, winStreak: viewModel.winStreak, streakIntensity: viewModel.streakIntensity)
                    } else if viewModel.isAutoBetting || viewModel.lastRoundProfit != nil {
                        AutoBetStatusView(profit: viewModel.lastRoundProfit ?? 0, currentBet: viewModel.currentBetCount, totalBets: Int(viewModel.numberOfBets) ?? 0)
                    }
                    
                    GridView(viewModel: viewModel)
                    
                    ControlsView(viewModel: viewModel, focusedField: $focusedField)
                }
                .padding(.horizontal)
                .padding(.vertical, 20)
            }
        }
        .foregroundColor(.white)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                // **THE FIX**: This button now dismisses any focused field.
                Button("Done") { focusedField = nil }
            }
        }
        .onDisappear {
            viewModel.stopAutoBet()
        }
    }
}


// MARK: - Subviews
struct GlassView: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(.black.opacity(0.25))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(.white.opacity(0.3), lineWidth: 1)
            )
    }
}

struct ProfitView: View {
    let profit: Double
    let multiplier: Double
    
    var winStreak: Int? = nil
    var streakIntensity: Double? = nil
    
    var body: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading) {
                Text("Multiplier").font(.caption).foregroundColor(.gray)
                Text("\(multiplier, specifier: "%.2f")x").font(.system(size: 20, weight: .bold, design: .monospaced))
            }
            VStack(alignment: .leading) {
                Text("Profit").font(.caption).foregroundColor(.gray)
                Text(String(format: "%@%.2f", profit >= 0 ? "+" : "", profit))
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundColor(profit > 0 ? .green : (profit < 0 ? .red : .white))
                    .lineLimit(1).minimumScaleFactor(0.5)
            }
            Spacer()
            
            if let streak = winStreak, streak > 0 {
                ZStack {
                    VStack(alignment: .trailing) {
                        Text("Streak").font(.caption).foregroundColor(.gray)
                        Text("🔥 \(streak)x")
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                            .foregroundColor(.orange)
                    }
                }
            }
        }
        .padding()
        .background(GlassView())
        .animation(.easeOut, value: profit)
        .animation(.easeOut, value: multiplier)
        .animation(.spring(), value: winStreak)
    }
}

struct AutoBetStatusView: View {
    let profit: Double
    let currentBet: Int
    let totalBets: Int

    var body: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading) {
                Text("Last Round Profit").font(.caption).foregroundColor(.gray)
                Text(String(format: "%@%.2f", profit >= 0 ? "+" : "", profit))
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundColor(profit >= 0 ? .green : .red)
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text("Bet Number").font(.caption).foregroundColor(.gray)
                Text("\(currentBet) / \(totalBets)")
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
            }
        }.padding().background(GlassView())
    }
}

struct GridView: View {
    @ObservedObject var viewModel: MinesViewModel
    var body: some View {
        LazyVGrid(columns: viewModel.columns, spacing: 10) {
            ForEach(0..<viewModel.tiles.count, id: \.self) { index in
                TileView(tile: $viewModel.tiles[index], isAutoSelected: viewModel.autoBetSelection.contains(index)) {
                    viewModel.tileTapped(index)
                }
            }
        }
        .padding()
        .background(GlassView())
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

// MARK: - Control Views
struct ControlsView: View {
    @ObservedObject var viewModel: MinesViewModel
    // **THE FIX**: Pass the FocusState binding down.
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
    // **THE FIX**: Pass the FocusState binding down.
    @FocusState.Binding var focusedField: MinesFocusField?
    
    var body: some View {
        let isPlaying = viewModel.gameState == .playing
        let isBetValid = (Int(viewModel.betAmount) ?? 0) > 0

        VStack(spacing: 15) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Bet Amount").font(.caption).foregroundColor(.gray)
                    TextField("Enter bet", text: $viewModel.betAmount)
                        .keyboardType(.decimalPad)
                        .padding(10)
                        .background(Color.black.opacity(0.2))
                        .cornerRadius(10)
                        // **THE FIX**: Bind the focus state.
                        .focused($focusedField, equals: .betAmount)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Mines: \(Int(viewModel.mineCount))").font(.caption).foregroundColor(.gray)
                    Slider(value: $viewModel.mineCount, in: 1...24, step: 1).accentColor(.purple)
                }
            }
            .disabled(isPlaying).opacity(isPlaying ? 0.6 : 1.0)
            
            Button(action: {
                vibrate()
                if isPlaying { viewModel.cashout() } else { viewModel.startGame() }
            }) {
                Text(isPlaying ? "Cashout (\(String(format: "%.2f", (Double(viewModel.betAmount) ?? 0) * viewModel.currentMultiplier)))" : "Place Bet")
                    .font(.headline).fontWeight(.bold).frame(maxWidth: .infinity).padding()
                    .background(isPlaying ? Color.green : Color.purple)
                    .foregroundColor(isPlaying ? .black : .white).cornerRadius(15)
                    .shadow(color: (isPlaying ? Color.green : Color.purple).opacity(0.5), radius: 10, y: 5)
            }
            .disabled(!isPlaying && !isBetValid).opacity(!isPlaying && !isBetValid ? 0.6 : 1.0)
        }
    }
}

struct AutoControlsView: View {
    @ObservedObject var viewModel: MinesViewModel
    // **THE FIX**: Pass the FocusState binding down.
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
                        .keyboardType(.decimalPad)
                        .padding(10)
                        .background(Color.black.opacity(0.2))
                        .cornerRadius(10)
                        // **THE FIX**: Bind the focus state.
                        .focused($focusedField, equals: .betAmount)
                }
                VStack(alignment: .leading, spacing:0.4) {
                    Text("Mines: \(Int(viewModel.mineCount))").font(.caption).foregroundColor(.gray)
                    Slider(value: $viewModel.mineCount, in: 1...24, step: 1).accentColor(.purple)
                }
            }.disabled(isBetting).opacity(isBetting ? 0.6 : 1.0)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Number of Bets").font(.caption).foregroundColor(.gray)
                TextField("Number of bets", text: $viewModel.numberOfBets)
                    .keyboardType(.numberPad)
                    .padding(10)
                    .background(Color.black.opacity(0.2))
                    .cornerRadius(10)
                    // **THE FIX**: Bind the focus state.
                    .focused($focusedField, equals: .numberOfBets)
            }.disabled(isBetting).opacity(isBetting ? 0.6 : 1.0)
            
            if isSetup {
                Text("Select tiles on the grid to include in the auto-bet.")
                    .font(.caption).foregroundColor(.gray).multilineTextAlignment(.center)
            }

            Button(action: {
                vibrate()
                if isBetting { viewModel.stopAutoBet() } else { viewModel.startAutoBet() }
            }) {
                Text(isBetting ? "Stop Autobet" : "Start Autobet")
                    .font(.headline).fontWeight(.bold).frame(maxWidth: .infinity).padding()
                    .background(isBetting ? Color.red : (canStart ? Color.green : Color.gray))
                    .foregroundColor(isBetting ? .white : (canStart ? .black : .white)).cornerRadius(15)
                    .shadow(color: (isBetting ? Color.red : (canStart ? Color.green : Color.gray)).opacity(0.5), radius: 10, y: 5)
            }
            .disabled(!isBetting && !canStart)
        }
    }
}

#Preview {
    MinesView(session: SessionManager())
}
