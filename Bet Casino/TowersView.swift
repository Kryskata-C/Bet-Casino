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

struct BetAmountVisualizer: View {
    @Binding var betAmount: String
    var body: some View {
        HStack {
            Text("Current Bet:")
                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                .foregroundColor(.gray)
            
            Text(betAmount.isEmpty ? "0" : betAmount)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .contentTransition(.identity)
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .frame(height: 40)
        .background(.black.opacity(0.4))
        .clipShape(Capsule())
    }
}

// MARK: - Floating Bonus Text View
struct BonusTextView: View {
    let text: String
    let color: Color
    @State private var yOffset: CGFloat = 0
    @State private var opacity: Double = 1
    
    var body: some View {
        Text(text)
            .font(.headline).bold()
            .foregroundColor(color)
            .shadow(color: color.opacity(0.8), radius: 5)
            .offset(y: yOffset)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeOut(duration: 1.5)) {
                    yOffset = -50
                    opacity = 0
                }
            }
    }
}


// MARK: - MAIN VIEW
struct TowersView: View {
    @StateObject private var viewModel: TowersViewModel
    @State private var showWinFlash = false
    @State private var showLossFlash = false
    
    @State private var bonusTexts: [BonusTextItem] = []

    init(session: SessionManager) { _viewModel = StateObject(wrappedValue: TowersViewModel(sessionManager: session)) }

    var body: some View {
        ZStack {
            TowersAnimatedBackground()
            
            GameAreaView(viewModel: viewModel)
            
            if showWinFlash { Color.green.opacity(0.3).ignoresSafeArea().transition(.opacity) }
            if showLossFlash { Color.red.opacity(0.4).ignoresSafeArea().transition(.opacity) }
            
            ZStack {
                ForEach(bonusTexts) { item in
                    BonusTextView(text: item.text, color: item.color)
                }
            }
        }
        .modifier(ShakeEffect(animatableData: CGFloat(viewModel.triggerLossShake)))
        .onChange(of: viewModel.triggerWinFlash) { flash() }
        .onChange(of: viewModel.triggerLossShake) { flash(isLoss: true) }
        .onChange(of: viewModel.bonusText) { newValue in
            if let newBonus = newValue {
                addBonusText(text: newBonus.text, color: newBonus.color)
                viewModel.bonusText = nil
            }
        }
    }
    
    private func addBonusText(text: String, color: Color) {
        let newItem = BonusTextItem(text: text, color: color)
        bonusTexts.append(newItem)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            bonusTexts.removeAll { $0.id == newItem.id }
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

// MARK: - Extracted GameArea View
struct GameAreaView: View {
    @ObservedObject var viewModel: TowersViewModel
    @FocusState private var isBetAmountFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                 VStack(spacing: 4) {
                    TowersStatusPill(title: "Multiplier", value: String(format: "%.2fx", viewModel.currentMultiplier), color: .cyan)
                    if viewModel.winStreak > 1 {
                         Text("🔥 \(viewModel.winStreak) Streak")
                            .font(.caption).bold().foregroundColor(.orange)
                            .transition(.opacity.combined(with: .scale))
                    }
                }
                TowersStatusPill(
                    title: "Profit",
                    value: (viewModel.profit >= 0 ? "+" : "") + formatNumber(Int(viewModel.profit)),
                    color: viewModel.profit >= 0 ? .green : .red
                )
                
                if viewModel.winStreak > 1 {
                    TowersStatusPill(
                        title: "Streak Bonus",
                        value: "x" + String(format: "%.2f", viewModel.streakBonusMultiplier),
                        color: .orange
                    )
                }
            }
            .padding()
            .animation(.spring(), value: viewModel.winStreak)

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
            
            if viewModel.gameState == .idle { TowersControlsView(viewModel: viewModel, isBetAmountFocused: $isBetAmountFocused) }
            else if viewModel.gameState == .playing { AnimatedCashoutButton(viewModel: viewModel) }
            Spacer(minLength: 20)
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: viewModel.gameState)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                if isBetAmountFocused {
                    BetAmountVisualizer(betAmount: $viewModel.betAmount); Spacer()
                    Button("Done") { isBetAmountFocused = false }.fontWeight(.bold)
                }
            }
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
    private var isJackpot: Bool { viewModel.jackpotRow == row && viewModel.jackpotCol == col }
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
                    
                    if viewModel.isDebugMode && !isSafe {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red.opacity(0.6))
                            .font(.largeTitle)
                    }
                    
                    Text(formatNumber(Int(potentialWin))).font(.system(size: 16, weight: .heavy, design: .rounded)).foregroundColor(.white.opacity(0.6))
                        .opacity(viewModel.gameState == .idle && !viewModel.betAmount.isEmpty && !viewModel.isDebugMode ? 1 : 0)
                }.overlay(viewModel.currentRow == row && viewModel.gameState == .playing ? RoundedRectangle(cornerRadius: 12).stroke(Color.yellow, lineWidth: 4).blur(radius: 3) : nil)
            } back: {
                ZStack {
                    RoundedRectangle(cornerRadius: 12).fill(isSafe ? (isJackpot ? Color.yellow.opacity(0.5) : Color.green.opacity(0.4)) : Color.red.opacity(0.5))
                    if isSafe {
                        Image(systemName: isJackpot ? "sparkles" : "star.fill").font(.largeTitle).foregroundColor(.white)
                            .shadow(color: isJackpot ? .yellow.opacity(0.8) : .green.opacity(0.8), radius: 10)
                    } else {
                        Image(systemName: "xmark.octagon.fill").font(.largeTitle).foregroundColor(.white)
                    }
                }
            }
            if showParticles {
                ForEach(0..<15) { _ in
                    Circle().fill(isSafe ? (isJackpot ? .yellow : .green) : .orange).frame(width: .random(in: 3...8), height: .random(in: 3...8))
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

struct ShimmerEffect: View {
    @State private var phase: CGFloat = 0
    var body: some View {
        LinearGradient(
            colors: [.clear, .yellow.opacity(0.5), .clear],
            startPoint: .leading,
            endPoint: .trailing
        )
        .offset(x: phase * 200 - 100)
        .mask(Capsule().frame(width: 100, height: 200).rotationEffect(.degrees(45)))
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                phase = 1
            }
        }
    }
}


struct TowersControlsView: View {
    @ObservedObject var viewModel: TowersViewModel
    @FocusState.Binding var isBetAmountFocused: Bool
    var body: some View {
        VStack(spacing: 15) {
            TextField("Bet Amount", text: $viewModel.betAmount)
                .foregroundColor(.white)
                .keyboardType(.numberPad)
                .padding()
                .background(Color.black.opacity(0.3))
                .cornerRadius(12)
                .focused($isBetAmountFocused)
            
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
    @State private var isGlowing = false

    var body: some View {
        Button(action: viewModel.cashout) {
            Text("Cashout").font(.headline).bold().padding().frame(maxWidth: .infinity)
                .background(LinearGradient(colors: [.green, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                .foregroundColor(.black).cornerRadius(15)
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(Color.yellow, lineWidth: isGlowing ? 4 : 0)
                        .blur(radius: isGlowing ? 5 : 0)
                )
                .shadow(color: isGlowing ? .yellow.opacity(0.8) : .clear, radius: 10)
        }
        .buttonStyle(PressableButtonStyle())
        .padding(.horizontal, 40)
        .padding(.vertical, 10)
        .disabled(viewModel.currentRow == 0)
        .onChange(of: viewModel.shouldSuggestCashout) { newShouldGlow in
            if isGlowing != newShouldGlow {
                withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                    isGlowing = newShouldGlow
                }
                if !newShouldGlow {
                    withAnimation { isGlowing = false }
                }
            }
        }
    }
}

// MARK: - Preview Provider
#Preview {
    let session = SessionManager()
    session.isLoggedIn = true
    session.username = "DevPlayer"
    session.money = 500000
    session.level = 25
    session.currentScreen = .towers

    return TowersView(session: session)
        .environmentObject(session)
}
