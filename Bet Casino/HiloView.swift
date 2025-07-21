// Bet Casino/HiloView.swift

import SwiftUI

// MARK: - Main View - REVAMPED
struct HiloView: View {
    @StateObject private var viewModel: HiloViewModel
    @FocusState private var isBetAmountFocused: Bool

    init(session: SessionManager) {
        _viewModel = StateObject(wrappedValue: HiloViewModel(session: session))
    }

    var body: some View {
        ZStack {
            HiloStarfieldBackground()
                .blur(radius: viewModel.gameState == .betting ? 3 : 0)
                .animation(.easeInOut, value: viewModel.gameState)

            VStack(spacing: 0) {
                GameStageView(viewModel: viewModel)
                ControlPanelView(viewModel: viewModel, isBetAmountFocused: $isBetAmountFocused)
            }
        }
        .foregroundColor(.white)
        .ignoresSafeArea()
    }
}

// MARK: - Background View
struct HiloStarfieldBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [.black, Color(red: 10/255, green: 20/255, blue: 40/255), .black], startPoint: .top, endPoint: .bottom)
            
            TimelineView(.animation) { context in
                let time = context.date.timeIntervalSince1970
                ForEach(0..<50) { _ in
                    let size = Double.random(in: 1...3)
                    let x = Double.random(in: 0...1)
                    let y = Double.random(in: 0...1)
                    Circle().fill(.white.opacity(Double.random(in: 0.3...0.8)))
                        .frame(width: size, height: size)
                        .position(x: UIScreen.main.bounds.width * x, y: UIScreen.main.bounds.height * y)
                }
                ForEach(0..<5) { _ in
                    let size = Double.random(in: 1...2)
                    let x = Double.random(in: 0...1.5)
                    let y = Double.random(in: 0...0.8)
                    let speed = Double.random(in: 150...300)
                    
                    Rectangle().fill(.white.opacity(0.8))
                        .frame(width: size * 20, height: size)
                        .blur(radius: 1)
                        .rotationEffect(.degrees(-15))
                        .position(x: (UIScreen.main.bounds.width * x - time * speed).truncatingRemainder(dividingBy: UIScreen.main.bounds.width * 1.5), y: UIScreen.main.bounds.height * y)
                }
            }
        }
    }
}


// MARK: - Top Panel: Game Stage
struct GameStageView: View {
    @ObservedObject var viewModel: HiloViewModel
    
    var body: some View {
        VStack {
            BetInfoBadgeView(
                betAmount: viewModel.betAmount,
                multiplier: viewModel.currentMultiplier,
                profit: viewModel.profit
            )
            .padding(.top, 50)
            
            Spacer()

            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [.green.opacity(0.15), .clear], center: .center, startRadius: 50, endRadius: 250))
                    .blur(radius: 20)
                    .scaleEffect(viewModel.lastOutcome == .win ? 1.5 : 1.0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.5), value: viewModel.lastOutcome)

                HStack(spacing: 30) {
                    if let card = viewModel.currentCard {
                        PremiumCardView(card: card, outcome: nil).transition(.scale.combined(with: .opacity))
                    }

                    FlippableView(isFlipped: $viewModel.flipCard) {
                        PremiumCardView(card: nil, outcome: nil)
                    } back: {
                        PremiumCardView(card: viewModel.revealedCard, outcome: viewModel.lastOutcome)
                    }
                }
            }
            .overlay(GameOutcomeIndicator(outcome: viewModel.lastOutcome))
            
            VisualHistoryBar(history: viewModel.guessHistory)
                .padding(.top, 20)

            Spacer()
        }
        .frame(maxHeight: .infinity)
    }
}

// MARK: - Bottom Panel: Controls
struct ControlPanelView: View {
    @ObservedObject var viewModel: HiloViewModel
    @FocusState.Binding var isBetAmountFocused: Bool

    var body: some View {
        VStack {
            if viewModel.gameState == .playing || viewModel.gameState == .revealing {
                HiloGameplayView(viewModel: viewModel)
            } else if viewModel.gameState == .betting {
                HiloBettingView(viewModel: viewModel, isBetAmountFocused: $isBetAmountFocused)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 35, style: .continuous))
        .padding(10)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: viewModel.gameState)
    }
}


// MARK: - Revamped & New Components

struct BetInfoBadgeView: View {
    let betAmount: String
    let multiplier: Double
    let profit: Double
    
    var body: some View {
        HStack(spacing: 20) {
            InfoItem(title: "BET", value: formatNumber(Int(betAmount) ?? 0))
            InfoItem(title: "MULTIPLIER", value: String(format: "%.2fx", multiplier))
            InfoItem(title: "PROFIT", value: formatNumber(Int(profit)), color: profit > 0 ? .green : .white)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(.black.opacity(0.3))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.2), lineWidth: 1))
        .animation(.spring(), value: profit)
    }
    
    struct InfoItem: View {
        let title: String
        let value: String
        var color: Color = .white
        
        var body: some View {
            VStack {
                Text(title).font(.system(size: 10, weight: .bold)).foregroundColor(.gray)
                Text(value).font(.system(size: 16, weight: .heavy, design: .monospaced)).foregroundColor(color)
            }
        }
    }
}

struct GlowingOrbButton: View {
    let title: String
    let chance: Double
    let color: Color
    let action: () -> Void
    @State private var isPulsing = false
    
    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            action()
        }) {
            VStack {
                Text(title).font(.headline).bold()
                Text(String(format: "%.1f%%", chance)).font(.title2).bold().monospaced()
            }
            .frame(width: 120, height: 120)
            .background(color.opacity(0.3))
            .clipShape(Circle())
            .overlay(Circle().stroke(color, lineWidth: 3))
            .shadow(color: color, radius: isPulsing ? 15 : 10)
            .shadow(color: color, radius: 5)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever()) {
                isPulsing.toggle()
            }
        }
    }
}

struct VisualHistoryBar: View {
    let history: [HiloHistoryItem]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: -15) {
                ForEach(history) { item in
                    MiniCardView(item: item)
                        .transition(.asymmetric(insertion: .offset(y: 50).combined(with: .opacity), removal: .opacity))
                }
            }
            .padding(.horizontal)
            .frame(height: 70)
        }
        .animation(.spring(), value: history.count)
    }
}

struct MiniCardView: View {
    let item: HiloHistoryItem
    
    var body: some View {
        ZStack(alignment: .bottom) {
            PremiumCardView(card: item.card, outcome: .win)
                .frame(width: 45, height: 65)
                .scaleEffect(0.5)
            
            Image(systemName: item.guess == .higher ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                .foregroundColor(.white)
                .background(Circle().fill(Color.black.opacity(0.5)))
                .offset(y: 8)
        }
    }
}

struct HiloGameplayView: View {
    @ObservedObject var viewModel: HiloViewModel
    
    var body: some View {
        VStack(spacing: 15) {
            HStack(spacing: 30) {
                GlowingOrbButton(title: "Higher", chance: viewModel.higherChance, color: .cyan, action: { viewModel.makeGuess(.higher) })
                GlowingOrbButton(title: "Lower", chance: viewModel.lowerChance, color: .purple, action: { viewModel.makeGuess(.lower) })
            }
            
            HStack(spacing: 15) {
                ActionButton(title: "Skip", icon: "arrow.right.square.fill", color: .yellow, action: viewModel.skipCard)
                ActionButton(title: "Cashout", icon: "dollarsign.arrow.circle.right.fill", color: .green, action: viewModel.cashout)
                    .disabled(viewModel.profit <= 0)
                    .opacity(viewModel.profit <= 0 ? 0.6 : 1.0)
            }
        }
    }
}

struct HiloBettingView: View {
    @ObservedObject var viewModel: HiloViewModel
    @FocusState.Binding var isBetAmountFocused: Bool
    @State private var showTextField = false
    
    var body: some View {
        VStack(spacing: 20) {
            if showTextField {
                TextField("Enter Bet", text: $viewModel.betAmount)
                    .keyboardType(.numberPad)
                    .font(.system(size: 24, weight: .heavy, design: .monospaced))
                    .padding()
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(15)
                    .focused($isBetAmountFocused)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                BetChipView(amount: viewModel.betAmount) {
                    withAnimation { showTextField = true }
                    isBetAmountFocused = true
                }
                .transition(.scale.combined(with: .opacity))
            }
            
            Button(action: viewModel.placeBet) {
                Text("Place Bet")
                    .font(.headline).bold().padding().frame(maxWidth: .infinity)
                    .background(LinearGradient(colors: [.green, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .foregroundColor(.black).cornerRadius(15)
            }
            .buttonStyle(PressableButtonStyle())
            .disabled(viewModel.betAmount.isEmpty || (Int(viewModel.betAmount) ?? 0) <= 0)
        }
    }
}

struct BetChipView: View {
    let amount: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack {
                Text("BET AMOUNT")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.gray)
                Text(formatNumber(Int(amount) ?? 0))
                    .font(.system(size: 32, weight: .heavy, design: .monospaced))
            }
            .frame(width: 150, height: 100)
            .background(.black.opacity(0.3))
            .clipShape(Circle())
            .overlay(Circle().stroke(.white.opacity(0.2), lineWidth: 2))
            .shadow(radius: 10)
        }
    }
}

struct PremiumCardView: View {
    let card: Card?
    let outcome: HiloViewModel.Outcome?
    @State private var tilt = false
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(card != nil ? Color.white.opacity(0.95) : Color.black.opacity(0.5))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                
            if let card = card {
                let cardColor: Color = (card.suit == .hearts || card.suit == .diamonds) ? .red : .black
                VStack(spacing: 10) {
                    Text(card.rank.displayValue).font(.system(size: 50, weight: .heavy, design: .serif))
                    Text(card.suit.rawValue).font(.system(size: 40))
                }.foregroundColor(cardColor).shadow(color: cardColor.opacity(0.3), radius: 5)
            } else {
                ZStack {
                    LinearGradient(colors: [.purple, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
                        .opacity(0.5)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                    Image(systemName: "suit.spade.fill").font(.system(size: 80)).foregroundColor(.white.opacity(0.2))
                }
            }
        }
        .frame(width: 180, height: 260)
        .shadow(color: .black.opacity(0.5), radius: 15, y: 10)
        .rotation3DEffect(.degrees(tilt ? 5 : 0), axis: (x: tilt ? -0.2 : 0, y: tilt ? 0.2 : 0, z: 0))
        .overlay(
            ZStack {
                if outcome == .win {
                    RoundedRectangle(cornerRadius: 20).stroke(Color.green, lineWidth: 4).blur(radius: 4)
                    RoundedRectangle(cornerRadius: 20).fill(Color.green.opacity(0.2))
                } else if outcome == .loss {
                    RoundedRectangle(cornerRadius: 20).stroke(Color.red, lineWidth: 4).blur(radius: 4)
                    RoundedRectangle(cornerRadius: 20).fill(Color.red.opacity(0.2))
                }
            }
            .animation(.easeInOut, value: outcome)
        )
        .onHover { isHovering in
            withAnimation(.spring()) {
                tilt = isHovering
            }
        }
    }
}

struct ActionButton: View {
    let title: String, icon: String, color: Color, action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.headline.bold())
                .padding()
                .frame(maxWidth: .infinity, minHeight: 60)
                .background(color.opacity(0.8))
                .foregroundColor(color == .yellow ? .black : .white)
                .cornerRadius(15)
        }.buttonStyle(PressableButtonStyle())
    }
}

struct GameOutcomeIndicator: View {
    let outcome: HiloViewModel.Outcome?
    @State private var appeared = false
    
    var body: some View {
        Group {
            if let outcome = outcome {
                ZStack {
                    Circle().fill(outcome == .win ? .green : .red).frame(width: 100, height: 100).blur(radius: 30).scaleEffect(appeared ? 1 : 0.5)
                    Image(systemName: outcome == .win ? "checkmark" : "xmark").font(.system(size: 60, weight: .heavy)).foregroundColor(.white).scaleEffect(appeared ? 1 : 0.5)
                }
                .opacity(appeared ? 1 : 0)
                .onAppear { withAnimation(.interpolatingSpring(mass: 0.5, stiffness: 100, damping: 10)) { appeared = true } }
            }
        }
    }
}

struct FlippableView<Front: View, Back: View>: View {
    @Binding var isFlipped: Bool
    let front: Front, back: Back
    
    init(isFlipped: Binding<Bool>, @ViewBuilder front: () -> Front, @ViewBuilder back: () -> Back) {
        self._isFlipped = isFlipped; self.front = front(); self.back = back()
    }
    
    var body: some View {
        ZStack {
            back.rotation3DEffect(.degrees(isFlipped ? 0 : 180), axis: (x: 0, y: 1, z: 0)).opacity(isFlipped ? 1 : 0)
            front.rotation3DEffect(.degrees(isFlipped ? -180 : 0), axis: (x: 0, y: 1, z: 0)).opacity(isFlipped ? 0 : 1)
        }.animation(.spring(response: 0.4, dampingFraction: 0.6), value: isFlipped)
    }
}

#Preview {
    let session = SessionManager()
    session.isLoggedIn = true
    session.money = 50000
    session.currentScreen = .hilo
    
    return MainCasinoView()
        .environmentObject(session)
}
