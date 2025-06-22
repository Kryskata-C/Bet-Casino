import SwiftUI
import Combine

// MARK: - Re-usable & Enhanced Components

struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .shadow(color: .black.opacity(0.3), radius: configuration.isPressed ? 4 : 10, y: configuration.isPressed ? 2 : 5)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct TowersAnimatedBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [.black, Color(red: 20/255, green: 0, blue: 40/255), .black], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            TimelineView(.animation) { context in
                ForEach(0..<20) { _ in
                    let size = Double.random(in: 20...80), x = Double.random(in: 0...1), y = Double.random(in: -0.2...1.2)
                    let speed = Double.random(in: 0.05...0.2), time = context.date.timeIntervalSince1970
                    Circle().fill(Color.purple.opacity(0.15)).frame(width: size, height: size)
                        .position(x: UIScreen.main.bounds.width * x, y: (UIScreen.main.bounds.height * y - time * speed * 100).truncatingRemainder(dividingBy: UIScreen.main.bounds.height * 1.4))
                        .blur(radius: 15)
                }
            }
        }
    }
}

struct TowersStatusPill: View {
    let title: String; var value: String; var color: Color = .purple
    var body: some View {
        VStack(spacing: 2) {
            Text(title.uppercased()).font(.system(size: 10, weight: .bold)).foregroundColor(.gray)
            Text(value).font(.system(size: 26, weight: .heavy, design: .rounded)).foregroundColor(color)
                .contentTransition(.numericText()).animation(.spring(), value: value).shadow(color: color.opacity(0.7), radius: 6)
        }
        .padding(.horizontal).frame(minWidth: 120, minHeight: 60).background(.black.opacity(0.25))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(.white.opacity(0.1), lineWidth: 1))
    }
}

// --- BUG FIXED: Bet Amount Visualizer ---
struct BetAmountVisualizer: View {
    @Binding var betAmount: String
    var body: some View {
        // By adding a fixed height and an identity transition, the "..." bug is resolved.
        HStack {
            Text("Current Bet:")
                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                .foregroundColor(.gray)
            
            Text(betAmount.isEmpty ? "0" : betAmount)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                // This tells SwiftUI to just swap the text, not animate the content, fixing the bug.
                .contentTransition(.identity)
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .frame(height: 40) // A fixed height provides stability
        .background(.black.opacity(0.4))
        .clipShape(Capsule())
    }
}


// MARK: - MAIN VIEW
struct TowersView: View {
    @StateObject private var viewModel: TowersViewModel
    @FocusState private var isBetAmountFocused: Bool
    @State private var showWinFlash = false
    @State private var showLossFlash = false

    init(session: SessionManager) { _viewModel = StateObject(wrappedValue: TowersViewModel(sessionManager: session)) }

    var body: some View {
        ZStack {
            TowersAnimatedBackground()
            VStack(spacing: 0) {
                HStack {
                    TowersStatusPill(title: "Multiplier", value: String(format: "%.2fx", viewModel.currentMultiplier), color: .cyan)
                    TowersStatusPill(title: "Profit", value: String(format: "%@%.0f", viewModel.profit >= 0 ? "+" : "", viewModel.profit), color: viewModel.profit >= 0 ? .green : .red)
                }.padding()
                
                // --- FIXED: Disappearing towers bug ---
                // By wrapping the grid in an `if`, we ensure it's fully removed and re-added
                // during state changes, which is more reliable than just animating opacity.
                if viewModel.showGrid {
                    ScrollViewReader { proxy in
                        ScrollView(.vertical, showsIndicators: false) {
                            LazyVStack(spacing: 12) {
                                ForEach((0..<viewModel.grid.count).reversed(), id: \.self) { row in
                                    HStack(spacing: 12) {
                                        ForEach(Array(viewModel.grid[row].enumerated()), id: \.offset) { col, _ in
                                            TowerTileView(viewModel: viewModel, row: row, col: col)
                                        }
                                    }.id(row)
                                }
                            }.padding()
                        }
                        .onChange(of: viewModel.currentRow) {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                                proxy.scrollTo(viewModel.currentRow, anchor: .center)
                            }
                        }
                    }
                    .transition(.opacity.animation(.easeInOut(duration: 0.4)))
                }
                
                if viewModel.gameState == .idle { TowersControlsView(viewModel: viewModel, isBetAmountFocused: $isBetAmountFocused) }
                else if viewModel.gameState == .playing { AnimatedCashoutButton(viewModel: viewModel) }
                Spacer(minLength: 20)
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: viewModel.gameState)
            if showWinFlash { Color.green.opacity(0.3).ignoresSafeArea().transition(.opacity) }
            if showLossFlash { Color.red.opacity(0.4).ignoresSafeArea().transition(.opacity) }
        }
        .modifier(ShakeEffect(animatableData: CGFloat(viewModel.triggerLossShake)))
        .onChange(of: viewModel.triggerWinFlash) { flash() }
        .onChange(of: viewModel.triggerLossShake) { flash(isLoss: true) }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                if isBetAmountFocused {
                    BetAmountVisualizer(betAmount: $viewModel.betAmount); Spacer()
                    Button("Done") { isBetAmountFocused = false }.fontWeight(.bold)
                }
            }
        }
    }
    
    private func flash(isLoss: Bool = false) {
        let duration = 0.4
        withAnimation(.easeOut(duration: duration * 0.25)) { if isLoss { showLossFlash = true } else { showWinFlash = true } }
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            withAnimation(.easeIn(duration: duration * 0.75)) { if isLoss { showLossFlash = false } else { showWinFlash = false } }
        }
    }
}

// MARK: - Component Views

struct TowerTileView: View {
    @ObservedObject var viewModel: TowersViewModel
    let row: Int, col: Int
    @State private var showParticles = false
    private var isRevealed: Bool { viewModel.revealedTiles[row].contains(col) }
    private var isSafe: Bool { viewModel.grid[row][col] }
    private var potentialWin: Double { (Double(viewModel.betAmount) ?? 0) * viewModel.multipliers[row] }
    private var borderColor: Color {
        let multiplier = viewModel.multipliers[row]
        if multiplier > 50 { return .yellow } else if multiplier > 10 { return .green }
        else if multiplier > 5 { return .cyan } else { return .purple }
    }

    var body: some View {
        ZStack {
            FlipView(isFlipped: .constant(isRevealed)) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12).fill(.black.opacity(0.3))
                    RoundedRectangle(cornerRadius: 12).stroke(borderColor, lineWidth: 2).blur(radius: 3)
                    Text(formatNumber(Int(potentialWin))).font(.system(size: 16, weight: .heavy, design: .rounded)).foregroundColor(.white.opacity(0.6))
                        .opacity(viewModel.gameState == .idle && !viewModel.betAmount.isEmpty ? 1 : 0)
                }.overlay(viewModel.currentRow == row && viewModel.gameState == .playing ? RoundedRectangle(cornerRadius: 12).stroke(Color.yellow, lineWidth: 4).blur(radius: 3) : nil)
            } back: {
                ZStack {
                    RoundedRectangle(cornerRadius: 12).fill(isSafe ? Color.green.opacity(0.4) : Color.red.opacity(0.5))
                    if isSafe { Image(systemName: "star.fill").font(.largeTitle).foregroundColor(.white).shadow(color: .green.opacity(0.8), radius: 10) }
                    else { Image(systemName: "xmark.octagon.fill").font(.largeTitle).foregroundColor(.white) }
                }
            }
            if showParticles {
                ForEach(0..<15) { _ in
                    Circle().fill(isSafe ? .green : .orange).frame(width: .random(in: 3...8), height: .random(in: 3...8))
                        .offset(x: .random(in: -40...40), y: .random(in: -40...40))
                        .opacity(0).animation(.easeOut(duration: 0.6).delay(.random(in: 0...0.1)), value: showParticles)
                }
            }
        }
        .frame(height: 65).onTapGesture { viewModel.tileTapped(row: row, col: col) }
        .onChange(of: isRevealed) { if isRevealed { showParticles = true } }
        .animation(.spring(response: 0.5, dampingFraction: 0.6), value: isRevealed)
    }
}

struct TowersControlsView: View {
    @ObservedObject var viewModel: TowersViewModel
    @FocusState.Binding var isBetAmountFocused: Bool
    var body: some View {
        VStack(spacing: 15) {
            TextField("Bet Amount", text: $viewModel.betAmount).keyboardType(.numberPad).padding().background(Color.black.opacity(0.3)).cornerRadius(12).focused($isBetAmountFocused)
            Picker("Risk Level", selection: $viewModel.riskLevel.animation()) {
                ForEach(TowersViewModel.RiskLevel.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }.pickerStyle(SegmentedPickerStyle())
            Button(action: viewModel.startGame) {
                Text("Start Game").font(.headline).bold().padding().frame(maxWidth: .infinity)
                    .background(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .foregroundColor(.white).cornerRadius(15)
            }.buttonStyle(PressableButtonStyle())
        }.padding().background(.black.opacity(0.25)).cornerRadius(25).padding(.horizontal)
    }
}

struct AnimatedCashoutButton: View {
    @ObservedObject var viewModel: TowersViewModel
    var body: some View {
        Button(action: viewModel.cashout) {
            Text("Cashout").font(.headline).bold().padding().frame(maxWidth: .infinity)
                .background(LinearGradient(colors: [.green, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                .foregroundColor(.black).cornerRadius(15)
        }.buttonStyle(PressableButtonStyle()).padding(.horizontal, 40).padding(.vertical, 10).disabled(viewModel.currentRow == 0)
    }
}
