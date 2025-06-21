import SwiftUI
import Combine

struct TowersView: View {
    @StateObject private var viewModel: TowersViewModel

    init(session: SessionManager) {
        _viewModel = StateObject(wrappedValue: TowersViewModel(sessionManager: session))
    }

    var body: some View {
        ZStack {
            AnimatedTowersBackground()

            VStack {
                HStack {
                    InfoPill(title: "Multiplier", value: String(format: "%.2fx", viewModel.currentMultiplier))
                    InfoPill(title: "Profit", value: String(format: "%@%.2f", viewModel.profit >= 0 ? "+" : "", viewModel.profit), color: viewModel.profit > 0 ? .green : (viewModel.profit < 0 ? .red : .white))
                }
                .padding()
                
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 10) {
                            // This loop iterates from bottom to top (reversed)
                            ForEach((0..<viewModel.grid.count).reversed(), id: \.self) { row in
                                HStack(spacing: 10) {
                                    // CORRECTED: This loop now safely iterates over the items
                                    // in each row using enumerated(), which prevents the crash.
                                    ForEach(Array(viewModel.grid[row].enumerated()), id: \.offset) { col, _ in
                                        
                                        // We safely access multipliers here because its count is always the same as the grid's row count.
                                        let potentialWin = (Double(viewModel.betAmount) ?? 0) * viewModel.multipliers[row]
                                        
                                        TowerTileView(
                                            viewModel: viewModel,
                                            row: row,
                                            col: col,
                                            potentialWin: potentialWin
                                        )
                                    }
                                }
                                .id(row)
                            }
                        }
                        .padding(.horizontal)
                        .id(viewModel.gridID) // This ID helps ensure the whole view redraws correctly.
                    }
                    .onChange(of: viewModel.currentRow) { newRow in
                        withAnimation {
                            proxy.scrollTo(newRow, anchor: .center)
                        }
                    }
                }
                
                if viewModel.gameState == .idle {
                    TowersControlsView(viewModel: viewModel)
                } else if viewModel.gameState == .playing {
                    AnimatedCashoutButton(viewModel: viewModel)
                }

                Spacer()
            }
        }
        .foregroundColor(.white)
    }
}

struct TowerTileView: View {
    @ObservedObject var viewModel: TowersViewModel
    let row: Int
    let col: Int
    let potentialWin: Double
    
    @State private var hasLostOnThisTile = false

    // These computed properties now safely access the grid.
    private var isRevealed: Bool {
        guard viewModel.revealedTiles.indices.contains(row) else { return false }
        return viewModel.revealedTiles[row].contains(col)
    }
    
    private var isSafe: Bool {
        guard viewModel.grid.indices.contains(row), viewModel.grid[row].indices.contains(col) else { return false }
        return viewModel.grid[row][col]
    }

    var body: some View {
        FlipView(isFlipped: .constant(isRevealed)) {
            // Front View (Un-revealed)
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.1))
                if viewModel.gameState == .idle && !viewModel.betAmount.isEmpty && Int(viewModel.betAmount) ?? 0 > 0 {
                    Text(formatNumber(Int(potentialWin)))
                        .font(.headline).fontWeight(.heavy)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .overlay(viewModel.currentRow == row && viewModel.gameState == .playing ? RoundedRectangle(cornerRadius: 10).stroke(Color.yellow, lineWidth: 3) : nil)
        } back: {
            // Back View (Revealed)
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSafe ? Color.green.opacity(0.5) : Color.red.opacity(0.6))
                    .shadow(color: hasLostOnThisTile ? .red : .clear, radius: 15, x: 0, y: 0)

                if isSafe {
                    Text("+\(formatNumber(Int(potentialWin)))")
                        .font(.headline).fontWeight(.heavy)
                        .foregroundColor(.white)
                } else {
                    Image(systemName: "xmark.octagon.fill")
                        .font(.largeTitle).foregroundColor(.white)
                }
            }
        }
        .frame(height: 60)
        .onTapGesture {
            viewModel.tileTapped(row: row, col: col)
        }
        .onChange(of: viewModel.gameState) {
             if $0 == .gameOver && !isSafe && isRevealed {
                 withAnimation(.easeInOut(duration: 0.5).repeatCount(3, autoreverses: true)) {
                     hasLostOnThisTile = true
                 }
                 DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                     hasLostOnThisTile = false
                 }
             }
        }
    }
}

struct TowersControlsView: View {
    @ObservedObject var viewModel: TowersViewModel

    var body: some View {
        VStack(spacing: 15) {
            TextField("Bet Amount", text: $viewModel.betAmount)
                .keyboardType(.numberPad).padding()
                .background(Color.black.opacity(0.2)).cornerRadius(12)
            
            Picker("Risk Level", selection: $viewModel.riskLevel.animation()) {
                ForEach(TowersViewModel.RiskLevel.allCases, id: \.self) {
                    Text($0.rawValue).tag($0)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            
            Button(action: viewModel.startGame) {
                Text("Start Game")
                    .font(.headline).bold().padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.purple).foregroundColor(.white).cornerRadius(15)
            }
        }
        .padding()
    }
}

struct AnimatedTowersBackground: View {
    @State private var start = UnitPoint(x: 0, y: -2)
    @State private var end = UnitPoint(x: 4, y: 0)
    
    let timer = Timer.publish(every: 1, on: .main, in: .default).autoconnect()

    var body: some View {
        LinearGradient(gradient: Gradient(colors: [.black, Color(red: 50/255, green: 0, blue: 35/255), .black]), startPoint: start, endPoint: end)
            .animation(Animation.easeInOut(duration: 6).repeatForever(), value: start)
            .onReceive(timer) { _ in
                self.start = UnitPoint(x: 4, y: 0)
                self.end = UnitPoint(x: 0, y: 2)
                self.start = UnitPoint(x: -4, y: 20)
                self.start = UnitPoint(x: 4, y: 0)
            }
            .ignoresSafeArea()
    }
}

struct AnimatedCashoutButton: View {
    @ObservedObject var viewModel: TowersViewModel
    @State private var isPulsing = false
    
    var body: some View {
        Button(action: viewModel.cashout) {
            Text("Cashout")
                .font(.headline).bold().padding()
                .frame(maxWidth: .infinity)
                .background(Color.green).foregroundColor(.black).cornerRadius(15)
                .shadow(color: .green.opacity(0.7), radius: isPulsing ? 15 : 10)
                .scaleEffect(isPulsing ? 1.05 : 1.0)
        }
        .padding()
        .disabled(viewModel.currentRow == 0)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever()) {
                isPulsing.toggle()
            }
        }
    }
}

struct TowersView_Previews: PreviewProvider {
    static var previews: some View {
        TowersView(session: SessionManager.prefilled())
    }
}

// NOTE: You must have a `FlipView` struct defined elsewhere in your project for this view to compile.
