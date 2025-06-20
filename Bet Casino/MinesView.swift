import SwiftUI
import Combine

struct Tile: Identifiable {
    let id = UUID()
    var isFlipped: Bool = false
    var isBomb: Bool = false
    var hasShine: Bool = false
    var wasLosingBomb: Bool = false
}

class MinesViewModel: ObservableObject {
    @Published var tiles: [Tile] = []
    @Published var mineCount: Double = 3.0
    @Published var betAmount: String = ""
    @Published var gameState: GameState = .idle
    @Published var profit: Double = 0.0
    @Published var currentMultiplier: Double = 1.0

    private var sessionManager: SessionManager
    private var bombIndexes: Set<Int> = []
    private var selectedTiles: Set<Int> = []
    private var resetGameCancellable: AnyCancellable?
    
    let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 5)
    let totalTiles = 25

    enum GameState { case idle, playing, gameOver }

    init(sessionManager: SessionManager) {
        self.sessionManager = sessionManager
        self.resetGame()
    }

    func startGame() {
        guard let bet = Int(betAmount), bet > 0, bet <= sessionManager.money else { return }
        sessionManager.money -= bet
        resetGame()
        gameState = .playing
        bombIndexes = generateBombs(count: Int(mineCount))
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }

    func tileTapped(_ index: Int) {
        guard gameState == .playing, !tiles[index].isFlipped else { return }
        tiles[index].isFlipped = true
        if bombIndexes.contains(index) {
            tiles[index].isBomb = true
            tiles[index].wasLosingBomb = true
            endGame(won: false)
        } else {
            selectedTiles.insert(index)
            tiles[index].hasShine = true
            currentMultiplier = calculateMultiplier()
            profit = (Double(betAmount) ?? 0.0) * (currentMultiplier - 1.0)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            if selectedTiles.count == totalTiles - bombIndexes.count {
                endGame(won: true)
            }
        }
    }
    
    func cashout() {
        guard gameState == .playing else { return }
        endGame(won: true)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func endGame(won: Bool) {
        gameState = .gameOver
        if won {
            let winnings = (Double(betAmount) ?? 0.0) * currentMultiplier
            sessionManager.money += Int(winnings)
        } else {
            profit = -(Double(betAmount) ?? 0.0)
            for i in bombIndexes {
                tiles[i].isFlipped = true
                tiles[i].isBomb = true
            }
        }
        sessionManager.saveData()
        resetGameCancellable = Just(()).delay(for: .seconds(2), scheduler: DispatchQueue.main).sink { [weak self] _ in self?.gameState = .idle }
    }
    
    func resetGame() {
        resetGameCancellable?.cancel()
        tiles = Array(repeating: Tile(), count: totalTiles)
        selectedTiles.removeAll(); bombIndexes.removeAll(); profit = 0.0; currentMultiplier = 1.0; gameState = .idle
    }

    private func generateBombs(count: Int) -> Set<Int> {
        var bombs = Set<Int>(); while bombs.count < count { bombs.insert(Int.random(in: 0..<totalTiles)) }; return bombs
    }
    
    private func calculateMultiplier() -> Double {
        guard !bombIndexes.isEmpty else { return 1.0 }
        let n = Double(totalTiles), m = Double(bombIndexes.count), k = Double(selectedTiles.count)
        var calculatedMult = 1.0
        for i in 0..<Int(k) { calculatedMult *= (n - m - Double(i)) / (n - Double(i)) }
        return (1 / calculatedMult) * 0.98
    }
}


// MARK: - Main View
struct MinesView: View {
    @StateObject private var viewModel: MinesViewModel
    @FocusState private var isBetAmountFocused: Bool

    init(session: SessionManager) {
        _viewModel = StateObject(wrappedValue: MinesViewModel(sessionManager: session))
    }

    var body: some View {
        ZStack {
            // THE FIX: The background has been restored to this view.
            LinearGradient(colors: [.black, Color(red: 35/255, green: 0, blue: 50/255).opacity(0.9)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 15) {
                    ProfitView(profit: viewModel.profit, multiplier: viewModel.currentMultiplier, gameState: viewModel.gameState)
                    GridView(viewModel: viewModel)
                    ControlsView(viewModel: viewModel, isBetAmountFocused: $isBetAmountFocused)
                }
                .padding(.horizontal)
                .padding(.vertical, 20)
            }
        }
        .foregroundColor(.white)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { isBetAmountFocused = false }
            }
        }
    }
}


// MARK: - Subviews
struct GlassView: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous).fill(.black.opacity(0.25)).overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(.white.opacity(0.3), lineWidth: 1))
    }
}

struct ProfitView: View {
    let profit: Double; let multiplier: Double; let gameState: MinesViewModel.GameState
    var body: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading) {
                Text("Multiplier").font(.caption).foregroundColor(.gray)
                Text("\(multiplier, specifier: "%.2f")x").font(.system(size: 20, weight: .bold, design: .monospaced))
            }
            VStack(alignment: .leading) {
                Text("Profit").font(.caption).foregroundColor(.gray)
                Text(String(format: "%@%.2f", profit > 0 ? "+" : "", profit)).font(.system(size: 20, weight: .bold, design: .monospaced)).foregroundColor(profit > 0 ? .green : (profit < 0 ? .red : .white)).lineLimit(1).minimumScaleFactor(0.5)
            }
            Spacer()
        }.padding().background(GlassView()).animation(.easeOut, value: profit).animation(.easeOut, value: multiplier)
    }
}

struct GridView: View {
    @ObservedObject var viewModel: MinesViewModel
    var body: some View {
        LazyVGrid(columns: viewModel.columns, spacing: 10) {
            ForEach(0..<viewModel.tiles.count) { index in
                TileView(tile: $viewModel.tiles[index]) { viewModel.tileTapped(index) }
            }
        }.padding().background(GlassView()).disabled(viewModel.gameState != .playing).opacity(viewModel.gameState == .gameOver ? 0.6 : 1.0)
    }
}

struct TileView: View {
    @Binding var tile: Tile; var onTap: () -> Void
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10).fill(tile.isFlipped ? (tile.isBomb ? Color.red.opacity(0.6) : Color.purple.opacity(0.4)) : Color.white.opacity(0.05)).overlay(tile.wasLosingBomb ? RoundedRectangle(cornerRadius: 10).stroke(Color.yellow, lineWidth: 4) : nil).aspectRatio(1, contentMode: .fit)
            if tile.isFlipped {
                Text(tile.isBomb ? "💣" : "💎").font(.title2).shadow(color: tile.hasShine ? .cyan : (tile.isBomb ? .red : .clear), radius: tile.hasShine ? 8 : 5)
            }
        }.rotation3DEffect(.degrees(tile.isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0)).onTapGesture { withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { onTap() } }
    }
}

struct ControlsView: View {
    @ObservedObject var viewModel: MinesViewModel; @FocusState.Binding var isBetAmountFocused: Bool
    var body: some View {
        VStack(spacing: 15) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Bet Amount").font(.caption).foregroundColor(.gray)
                    TextField("Enter bet", text: $viewModel.betAmount).keyboardType(.decimalPad).padding(10).background(Color.black.opacity(0.2)).cornerRadius(10).focused($isBetAmountFocused)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Mines: \(Int(viewModel.mineCount))").font(.caption).foregroundColor(.gray)
                    Slider(value: $viewModel.mineCount, in: 1...24, step: 1).accentColor(.purple)
                }
            }.disabled(viewModel.gameState == .playing).opacity(viewModel.gameState == .playing ? 0.6 : 1.0)
            let isPlaying = viewModel.gameState == .playing
            let isBetValid = (Int(viewModel.betAmount) ?? 0) > 0
            Button(action: {
                vibrate(); if isPlaying { viewModel.cashout() } else { viewModel.startGame() }
            }) {
                Text(isPlaying ? "Cashout (\(String(format: "%.2f", (Double(viewModel.betAmount) ?? 0) * viewModel.currentMultiplier)))" : "Place Bet").font(.headline).fontWeight(.bold).frame(maxWidth: .infinity).padding().background(isPlaying ? Color.green : Color.purple).foregroundColor(isPlaying ? .black : .white).cornerRadius(15).shadow(color: (isPlaying ? Color.green : Color.purple).opacity(0.5), radius: 10, y: 5)
            }.disabled(!isPlaying && !isBetValid).opacity(!isPlaying && !isBetValid ? 0.6 : 1.0)
        }.padding().background(GlassView())
    }
}

#Preview {
    let session = SessionManager()
    return MinesView(session: session).environmentObject(session)
}
