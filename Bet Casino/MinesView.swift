import SwiftUI
import Combine

// MARK: - Game Logic & Data Models

struct Tile: Identifiable {
    let id = UUID()
    var isFlipped: Bool = false
    var isBomb: Bool = false
}

class MinesViewModel: ObservableObject {
    @Published var tiles: [Tile] = []
    @Published var mineCount: Double = 3.0
    @Published var betAmount: String = ""
    @Published var gameState: GameState = .idle
    @Published var profit: Double = 0.0
    @Published var currentMultiplier: Double = 1.0

    private var bombIndexes: Set<Int> = []
    private var selectedTiles: Set<Int> = []
    
    let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 5)
    let totalTiles = 25

    enum GameState {
        case idle, playing, gameOver
    }

    init() {
        resetGame()
    }

    func startGame() {
        guard gameState == .idle || gameState == .gameOver, let bet = Double(betAmount), bet > 0 else { return }
        resetGame()
        gameState = .playing
        bombIndexes = generateBombs(count: Int(mineCount))
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }

    func tileTapped(_ index: Int) {
        guard gameState == .playing, !tiles[index].isFlipped else { return }

        selectedTiles.insert(index)
        tiles[index].isFlipped = true

        if bombIndexes.contains(index) {
            tiles[index].isBomb = true
            endGame(won: false)
        } else {
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
    }

    private func endGame(won: Bool) {
        gameState = .gameOver
        if !won {
            profit = -(Double(betAmount) ?? 0.0)
            for i in bombIndexes {
                tiles[i].isFlipped = true
                tiles[i].isBomb = true
            }
        }
    }
    
    func resetGame() {
        tiles = Array(repeating: Tile(), count: totalTiles)
        selectedTiles.removeAll()
        bombIndexes.removeAll()
        profit = 0.0
        currentMultiplier = 1.0
        gameState = .idle
    }

    private func generateBombs(count: Int) -> Set<Int> {
        var bombs = Set<Int>()
        while bombs.count < count {
            bombs.insert(Int.random(in: 0..<totalTiles))
        }
        return bombs
    }
    
    private func calculateMultiplier() -> Double {
        guard !bombIndexes.isEmpty else { return 1.0 }
        let n = Double(totalTiles)
        let m = Double(bombIndexes.count)
        let k = Double(selectedTiles.count)
        let multiplier = pow((n / (n - m)), k) * 0.95
        return multiplier
    }
}

// MARK: - Main View

struct MinesView: View {
    @StateObject private var viewModel = MinesViewModel()

    var body: some View {
        ZStack {
            LinearGradient(colors: [.black, Color.purple.opacity(0.8)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 15) {
                ProfitView(profit: viewModel.profit, multiplier: viewModel.currentMultiplier)
                GridView(viewModel: viewModel)
                ControlsView(viewModel: viewModel)
                Spacer()
            }
            .padding(.horizontal)
            
            if viewModel.gameState == .gameOver {
                GameOverView(didWin: viewModel.profit >= 0) {
                    viewModel.resetGame()
                }
            }
        }
        .foregroundColor(.white)
    }
}

// MARK: - Reusable Components & Subviews

// Our NEW "Solid Style" GlassView. No blur, no materials, 100% reliable.
struct GlassView: View {
    var body: some View {
        // A simple, dark, semi-transparent background. Clean and sharp.
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(.black.opacity(0.25))
            .overlay(
                // We keep the crisp border because it looks awesome.
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(.white.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
    }
}

struct ProfitView: View {
    let profit: Double
    let multiplier: Double
    
    var body: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading) {
                Text("Multiplier").font(.caption).foregroundColor(.gray)
                Text("\(multiplier, specifier: "%.2f")x").font(.system(size: 20, weight: .bold, design: .monospaced))
            }
            VStack(alignment: .leading) {
                Text("Profit").font(.caption).foregroundColor(.gray)
                Text(String(format: "%@%.8f", profit >= 0 ? "+" : "", profit))
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundColor(profit >= 0 ? .green : .red)
                    .lineLimit(1).minimumScaleFactor(0.5)
            }
            Spacer()
        }
        .padding().background(GlassView())
    }
}

struct GridView: View {
    @ObservedObject var viewModel: MinesViewModel
    
    var body: some View {
        LazyVGrid(columns: viewModel.columns, spacing: 10) {
            ForEach(0..<viewModel.tiles.count) { index in
                TileView(tile: $viewModel.tiles[index]) {
                    viewModel.tileTapped(index)
                }
            }
        }
        .padding().background(GlassView())
        .disabled(viewModel.gameState != .playing).opacity(viewModel.gameState == .gameOver ? 0.6 : 1.0)
    }
}

struct TileView: View {
    @Binding var tile: Tile
    var onTap: () -> Void

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(tile.isFlipped ? (tile.isBomb ? Color.red.opacity(0.6) : Color.green.opacity(0.4)) : Color.white.opacity(0.05))
                .aspectRatio(1, contentMode: .fit)
            if tile.isFlipped {
                Text(tile.isBomb ? "💣" : "💎").font(.title2)
                    .shadow(color: tile.isBomb ? .red : .cyan, radius: 5)
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
    
    var body: some View {
        VStack(spacing: 15) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Bet Amount").font(.caption).foregroundColor(.gray)
                    TextField("Enter bet", text: $viewModel.betAmount)
                        .keyboardType(.decimalPad).padding(10).background(Color.black.opacity(0.2)).cornerRadius(10)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Mines: \(Int(viewModel.mineCount))").font(.caption).foregroundColor(.gray)
                    Slider(value: $viewModel.mineCount, in: 1...24, step: 1).accentColor(.green)
                }
            }
            .disabled(viewModel.gameState == .playing).opacity(viewModel.gameState == .playing ? 0.6 : 1.0)
            
            Button(action: {
                if viewModel.gameState == .playing { viewModel.cashout() } else { viewModel.startGame() }
            }) {
                Text(viewModel.gameState == .playing ? "Cashout" : "Start Game")
                    .font(.headline).fontWeight(.bold).frame(maxWidth: .infinity).padding()
                    .background(viewModel.gameState == .playing ? Color.green : Color.purple)
                    .foregroundColor(viewModel.gameState == .playing ? .black : .white)
                    .cornerRadius(15).shadow(color: (viewModel.gameState == .playing ? Color.green : Color.purple).opacity(0.5), radius: 10, y: 5)
            }
            .disabled(viewModel.gameState == .idle && (Double(viewModel.betAmount) ?? 0) <= 0)
        }
        .padding().background(GlassView())
    }
}

struct GameOverView: View {
    let didWin: Bool
    var onPlayAgain: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text(didWin ? "YOU WON! 🎉" : "GAME OVER 💥").font(.largeTitle).fontWeight(.black)
                .foregroundColor(didWin ? .green : .red)
            Button("Play Again", action: onPlayAgain)
                .font(.headline).fontWeight(.bold).padding().frame(maxWidth: 200)
                .background(Color.purple).cornerRadius(15)
        }
        .padding(40).background(GlassView())
        .transition(.asymmetric(insertion: .scale.animation(.spring(response: 0.5, dampingFraction: 0.7)), removal: .opacity))
        .zIndex(10)
    }
}


// MARK: - Preview

#Preview {
    MinesView()
}
