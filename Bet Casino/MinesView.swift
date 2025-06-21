import SwiftUI
import Combine
import AVFoundation

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
    var particles: [Particle] = []
}

struct Particle: Identifiable {
    let id = UUID()
    var position: CGPoint
    var scale: CGFloat = 1.0
    var opacity: Double = 1.0
}

// Located in MinesView.swift

// MARK: - Sound Manager
class SoundManager {
    static let shared = SoundManager()
    private var audioPlayer: AVAudioPlayer?

    enum SoundOption: String {
        case start = "Mines Start.wav"          // New
        case flip = "Mines Tile Flipped.wav"    // Updated
        case cashout = "Mines Cashout.wav"      // Updated
        case bomb = "Mine Tile.wav"              // Existing
    }

    func playSound(sound: SoundOption) {
        guard let url = Bundle.main.url(forResource: sound.rawValue, withExtension: nil) else {
            print("Could not find sound file: \(sound.rawValue)")
            return
        }

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.play()
        } catch {
            print("Error playing sound: \(error.localizedDescription)")
        }
    }
}


// MARK: - ViewModel
class MinesViewModel: ObservableObject {
    // Game State
    @Published var tiles: [Tile] = []
    @Published var gameState: GameState = .idle
    @Published var bettingMode: BettingMode = .manual
    @Published var debugMode: Bool = true

    // Bet Properties
    @Published var mineCount: Double = 3.0
    @Published var betAmount: String = ""
    @Published var profit: Double = 0.0
    @Published var currentMultiplier: Double = 1.0
    @Published var isBetAmountInvalid = false

    // Auto Bet Properties
    @Published var isAutoBetting: Bool = false
    @Published var numberOfBets: String = "10"
    @Published var autoBetSelection: Set<Int> = []
    @Published var currentBetCount: Int = 0
    @Published var autoRunProfit: Double = 0.0
    @Published var showAutoBetSummary = false
    
    // Auto-Bet Summary Stats
    @Published var autoBetWins = 0
    @Published var autoBetLosses = 0

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
        guard let bet = Int(betAmount), bet > 0, bet <= sessionManager.money else {
            isBetAmountInvalid = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.isBetAmountInvalid = false
            }
            return
        }
        SoundManager.shared.playSound(sound: .start)
        resetGameCancellable?.cancel()
        
        sessionManager.money -= bet
        sessionManager.betsPlaced += 1
        sessionManager.minesBets += 1
        if Int(betAmount) != sessionManager.lastBetAmount {
            resetStreak()
            sessionManager.lastBetAmount = Int(betAmount) ?? 0
        }
        resetBoard()
        gameState = .playing
        bombIndexes = generateBombs(count: Int(mineCount))
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        if debugMode {
            for bombIndex in bombIndexes {
                let row = bombIndex / 5
                let col = bombIndex % 5
                print("💣 Bomb at row \(row), col \(col)")
            }
        }

    }

    func tileTapped(_ index: Int) {
        switch gameState {
        case .playing:
            guard !tiles[index].isFlipped else { return }
            
            tiles[index].isFlipped = true
            if bombIndexes.contains(index) {
                SoundManager.shared.playSound(sound: .bomb)
                tiles[index].isBomb = true
                tiles[index].wasLosingBomb = true
                endGame(won: false)
            } else {
                SoundManager.shared.playSound(sound: .flip)
                selectedTiles.insert(index)
                tiles[index].hasShine = true
                triggerParticleEffect(at: index)
                let baseMult = calculateManualMultiplier()
                let streakBonus = calculateStreakBonus(tilesUncovered: selectedTiles.count)
                currentMultiplier = baseMult * streakBonus
                profit = (Double(betAmount) ?? 0.0) * (currentMultiplier - 1.0)
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
        SoundManager.shared.playSound(sound: .cashout)
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
            
            let profitInt = Int(roundProfit.rounded())
            sessionManager.totalMoneyWon += profitInt
            if profitInt > sessionManager.biggestWin {
                sessionManager.biggestWin = profitInt
            }
            
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
              let bet = Int(betAmount), bet > 0, bet <= sessionManager.money else {
            isBetAmountInvalid = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.isBetAmountInvalid = false
            }
            return
        }

        isAutoBetting = true
        gameState = .autoPlaying
        currentBetCount = 0
        autoRunProfit = 0
        autoBetWins = 0
        autoBetLosses = 0
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
                // Add a delay between auto-bet rounds to allow animations to be seen
                try? await Task.sleep(nanoseconds: 1_500_000_000)
            }
            
            await MainActor.run {
                self.isAutoBetting = false
                self.gameState = .autoSetup
                self.showAutoBetSummary = true
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
            sessionManager.minesBets += 1
            self.bombIndexes = generateBombs(count: Int(mineCount))
        }

        let multiplier = calculateAutoMultiplier()
        let hitBomb = autoBetSelection.contains { bombIndexes.contains($0) }
        var lastRoundProfit: Double

        if hitBomb {
            lastRoundProfit = -Double(bet)
            autoBetLosses += 1
            await MainActor.run { resetStreak() }
        } else {
            autoBetWins += 1
            let streakBonus = calculateStreakBonus(tilesUncovered: autoBetSelection.count)
            let finalWinnings = (Double(bet) * multiplier) * streakBonus
            lastRoundProfit = finalWinnings - Double(bet)
                
            await MainActor.run {
                self.winStreak += 1
                self.streakBonusMultiplier = streakBonus
                
                let winningsInt = Int(finalWinnings.rounded())
                self.sessionManager.money += winningsInt

                let profitInt = Int(lastRoundProfit.rounded())
                self.sessionManager.totalMoneyWon += profitInt
                if profitInt > self.sessionManager.biggestWin {
                    self.sessionManager.biggestWin = profitInt
                }
            }
        }

        // Trigger the tile flip animation for the auto-bet selection
        for tileIndex in self.autoBetSelection {
             await MainActor.run {
                 self.tiles[tileIndex].isFlipped = true
                 if self.bombIndexes.contains(tileIndex) {
                     self.tiles[tileIndex].isBomb = true
                 }
             }
        }
        
        await MainActor.run {
            self.autoRunProfit += lastRoundProfit
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
    
    private func triggerParticleEffect(at index: Int) {
        let particleCount = 10
        for _ in 0..<particleCount {
            let particle = Particle(position: .zero)
            tiles[index].particles.append(particle)
        }

        for i in 0..<tiles[index].particles.count {
            let randomX = CGFloat.random(in: -25...25)
            let randomY = CGFloat.random(in: -25...25)
            
            withAnimation(.easeOut(duration: 0.8)) {
                tiles[index].particles[i].position = CGPoint(x: randomX, y: randomY)
                tiles[index].particles[i].opacity = 0
                tiles[index].particles[i].scale = 0.5
            }
        }
    }
    
    func calculateManualMultiplier() -> Double {
        guard !bombIndexes.isEmpty else { return 1.0 }
        let n = totalTiles
        let m = Double(bombIndexes.count)
        let k = Double(selectedTiles.count)
        if k == 0 { return 1.0 }
        var calculatedMult = 1.0
        for i in 0..<Int(k) {
            calculatedMult *= (n - m - Double(i)) / (n - Double(i))
        }
        let base = (1 / calculatedMult) * 0.98
        let risk = min(1.0, (Double(betAmount) ?? 0) / max(Double(sessionManager.money) + (Double(betAmount) ?? 0), 1))
        let mineBonus = 1.0 + (m / n) * 0.3
        return base * mineBonus * (1 + risk * 0.15)
    }

    private func calculateAutoMultiplier() -> Double {
        guard !bombIndexes.isEmpty else { return 1.0 }
        let n = totalTiles
        let m = Double(bombIndexes.count)
        let k = Double(autoBetSelection.count)
        if k == 0 { return 1.0 }
        var calculatedMult = 1.0
        for i in 0..<Int(k) {
            calculatedMult *= (n - m - Double(i)) / (n - Double(i))
        }
        let base = (1 / calculatedMult) * 0.98
        let risk = min(1.0, (Double(betAmount) ?? 0) / max(Double(sessionManager.money) + (Double(betAmount) ?? 0), 1))
        let mineBonus = 1.0 + (m / n) * 0.3
        return base * mineBonus * (1 + risk * 0.15)
    }


    
    func calculateStreakBonus(tilesUncovered: Int) -> Double {
        let level = 10.0
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
        ZStack(alignment: .bottom) {
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

                    if viewModel.gameState != .playing {
                        ControlsView(viewModel: viewModel, focusedField: $focusedField)
                    }

                    Spacer()
                }
                .padding(.horizontal)
            }

            // Show floating cashout button only during an active game
            if viewModel.gameState == .playing {
                FloatingCashoutButton(viewModel: viewModel)
            }
        }
        .foregroundColor(.white)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focusedField = nil }
            }
        }
        .sheet(isPresented: $viewModel.showAutoBetSummary) {
            AutoBetSummaryView(viewModel: viewModel)
        }
        .onDisappear(perform: viewModel.stopAutoBet)
        .onChange(of: viewModel.winStreak) {
            if viewModel.winStreak > 0 {
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
        VStack(spacing: 8) {
            if viewModel.bettingMode == .auto && viewModel.isAutoBetting {
                AutoStatusView(profit: viewModel.autoRunProfit, streak: viewModel.winStreak)
            } else {
                ManualStatusView(profit: viewModel.profit, multiplier: viewModel.currentMultiplier, streak: viewModel.winStreak)
            }
            
            if viewModel.gameState == .playing || viewModel.gameState == .gameOver {
                let safeTiles = Int(viewModel.totalTiles - viewModel.mineCount)
                ProgressView(value: Double(viewModel.selectedTiles.count), total: Double(safeTiles)) {
                    HStack {
                        Text("Safe Tiles Found")
                        Spacer()
                        Text("\(viewModel.selectedTiles.count) / \(safeTiles)")
                    }
                    .font(.caption)
                }
                .tint(.purple)
            }
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
        .background(SolidPanelView())
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
                TileView(tile: $viewModel.tiles[index], isAutoSelected: viewModel.autoBetSelection.contains(index), onTap: {
                    viewModel.tileTapped(index)
                }, viewModel: viewModel)

            }
        }
    }
}

struct TileView: View {
    @Binding var tile: Tile
    var isAutoSelected: Bool
    var onTap: () -> Void
    var viewModel: MinesViewModel
    @State private var scale: CGFloat = 1.0
    
    var body: some View {
        let isSetupMode = !tile.isFlipped && isAutoSelected
        
        FlipView(isFlipped: $tile.isFlipped) {
            // Front of the tile
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                            isSetupMode ? RoundedRectangle(cornerRadius: 10).stroke(Color.purple, lineWidth: 4) :
                                (viewModel.debugMode && viewModel.gameState != .gameOver && tile.isBomb ? RoundedRectangle(cornerRadius: 10).stroke(Color.red, lineWidth: 4) : nil)
                        )
            }
        } back: {
            // Back of the tile
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(tile.isBomb ? Color.red.opacity(0.6) : Color.purple.opacity(0.4))
                    .overlay(tile.wasLosingBomb ? RoundedRectangle(cornerRadius: 10).stroke(Color.yellow, lineWidth: 4) : nil)
                    
                if tile.isBomb {
                    Image(systemName: "xmark.octagon.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                } else {
                    Image(systemName: "diamond.fill")
                        .font(.title2)
                        .foregroundStyle(LinearGradient(colors: [.cyan, .white], startPoint: .top, endPoint: .bottom))
                        .shadow(color: .cyan, radius: tile.hasShine ? 8 : 0)
                }
                
                // Particle effect
                ZStack {
                    ForEach(tile.particles) { particle in
                        Circle()
                            .fill(Color.yellow)
                            .frame(width: 5, height: 5)
                            .scaleEffect(particle.scale)
                            .offset(x: particle.position.x, y: particle.position.y)
                            .opacity(particle.opacity)
                    }
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .scaleEffect(scale)
        .onTapGesture {
            onTap()
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                scale = 1.1
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.spring()) {
                    scale = 1.0
                }
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
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
            .disabled(viewModel.isAutoBetting || viewModel.gameState == .playing)
            
            if viewModel.bettingMode == .manual {
                ManualControlsView(viewModel: viewModel, focusedField: $focusedField)
            } else {
                AutoControlsView(viewModel: viewModel, focusedField: $focusedField)
            }
        }
        .padding()
        .background(SolidPanelView())
    }
}

struct ManualControlsView: View {
    @ObservedObject var viewModel: MinesViewModel
    @FocusState.Binding var focusedField: MinesFocusField?

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                VStack(spacing: 6) {
                    Text("Bet")
                        .font(.caption).foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    TextField("1000", text: $viewModel.betAmount)
                        .keyboardType(.numberPad)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.2)))
                        .focused($focusedField, equals: .betAmount)
                        .modifier(ShakeEffect(animatableData: CGFloat(viewModel.isBetAmountInvalid ? 1 : 0)))
                }

                VStack(spacing: 6) {
                    Text("Mines: \(Int(viewModel.mineCount))")
                        .font(.caption).foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Slider(value: $viewModel.mineCount, in: 1...24, step: 1)
                        .accentColor(.purple)
                }
            }

            Button(action: viewModel.startGame) {
                Text("Place Bet")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.purple)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .shadow(color: .purple.opacity(0.5), radius: 8, y: 4)
            }
            .disabled(viewModel.gameState == .playing)
            .opacity(viewModel.gameState == .playing ? 0.6 : 1.0)
        }
        .padding()
        .background(Color.black.opacity(0.15)).cornerRadius(20)
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
                        .keyboardType(.numberPad).padding(10)
                        .background(Color.black.opacity(0.2)).cornerRadius(10)
                        .focused($focusedField, equals: .betAmount)
                        .modifier(ShakeEffect(animatableData: CGFloat(viewModel.isBetAmountInvalid ? 1 : 0)))
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

// Replaced GlassView with a solid, non-transparent panel
struct SolidPanelView: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 15, style: .continuous)
            .fill(Color(white: 0.1, opacity: 0.9))
            .overlay(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(.white.opacity(0.1), lineWidth: 1)
            )
    }
}

struct FloatingCashoutButton: View {
    @ObservedObject var viewModel: MinesViewModel
    @State private var isPulsing = false
    
    var body: some View {
        VStack {
            Spacer()
            Button(action: viewModel.cashout) {
                VStack {
                    let cashoutValue = (Double(viewModel.betAmount) ?? 0.0) * viewModel.currentMultiplier * viewModel.streakBonusMultiplier
                    Text("Cashout")
                        .font(.headline).bold()
                    Text(String(format: "%.2f", cashoutValue))
                        .font(.caption)
                }
                .padding()
                .frame(minWidth: 150)
                .background(Color.green)
                .foregroundColor(.black)
                .cornerRadius(20)
                .shadow(color: .green.opacity(0.7), radius: isPulsing ? 15 : 10)
                .scaleEffect(isPulsing ? 1.1 : 1.0)
            }
            .disabled(viewModel.selectedTiles.isEmpty)
            .opacity(viewModel.selectedTiles.isEmpty ? 0.6 : 1.0)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    isPulsing.toggle()
                }
            }
        }
        .padding(.bottom, 20)
    }
}

// Custom Flip Animation View
struct FlipView<Front: View, Back: View>: View {
    @Binding var isFlipped: Bool
    let front: Front
    let back: Back
    
    init(isFlipped: Binding<Bool>, @ViewBuilder front: () -> Front, @ViewBuilder back: () -> Back) {
        self._isFlipped = isFlipped
        self.front = front()
        self.back = back()
    }
    
    var body: some View {
        ZStack {
            front
                .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
                .opacity(isFlipped ? 0 : 1)
            
            back
                .rotation3DEffect(.degrees(isFlipped ? 0 : -180), axis: (x: 0, y: 1, z: 0))
                .opacity(isFlipped ? 1 : 0)
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: isFlipped)
    }
}

// Shake animation for invalid bet
struct ShakeEffect: GeometryEffect {
    var amount: CGFloat = 10
    var shakesPerUnit = 3
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: amount * sin(animatableData * .pi * CGFloat(shakesPerUnit)), y: 0))
    }
}

// Auto-Bet Summary Modal
struct AutoBetSummaryView: View {
    @ObservedObject var viewModel: MinesViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Autobet Complete")
                .font(.largeTitle).bold()
            
            VStack(alignment: .leading, spacing: 15) {
                SummaryRow(title: "Total Profit:", value: String(format: "%.2f", viewModel.autoRunProfit), color: viewModel.autoRunProfit >= 0 ? .green : .red)
                SummaryRow(title: "Bets Won:", value: "\(viewModel.autoBetWins)", color: .green)
                SummaryRow(title: "Bets Lost:", value: "\(viewModel.autoBetLosses)", color: .red)
                
                let winRate = (Double(viewModel.autoBetWins) / Double(viewModel.autoBetWins + viewModel.autoBetLosses) * 100)
                SummaryRow(title: "Win Rate:", value: String(format: "%.1f%%", winRate.isNaN ? 0 : winRate), color: .cyan)
            }
            .padding()
            .background(SolidPanelView())
            
            Button("Done") {
                dismiss()
            }
            .font(.headline).bold()
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.purple)
            .foregroundColor(.white)
            .cornerRadius(15)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 25/255, green: 25/255, blue: 35/255))
        .foregroundColor(.white)
    }
}

struct SummaryRow: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
            Spacer()
            Text(value)
                .font(.headline).bold()
                .foregroundColor(color)
        }
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
        manager.level = 100
        manager.currentScreen = .mines
        return manager
    }
}
