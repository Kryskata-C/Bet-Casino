// Bet Casino/HiloView.swift

import SwiftUI

// MARK: - Main Hilo View (Rebuilt with Mines/Keno Style)
struct HiloView: View {
    @StateObject private var viewModel: HiloViewModel
    @FocusState private var isBetAmountFocused: Bool

    init(session: SessionManager) {
        _viewModel = StateObject(wrappedValue: HiloViewModel(session: session))
    }

    var body: some View {
        ZStack {
            // Using the same dark, luxurious gradient from your other games
            LinearGradient(colors: [.black, Color(red: 35/255, green: 0, blue: 50/255).opacity(0.9)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Header using the same InfoPill style from Mines
                ManualStatusView(
                    profit: viewModel.profit,
                    multiplier: viewModel.currentMultiplier,
                    streak: viewModel.guessHistory.count
                )
                .padding(.top, 15)

                Spacer()

                // Centered, focused card area
                HiloCardArea(
                    currentCard: viewModel.currentCard,
                    revealedCard: viewModel.revealedCard,
                    isFlipped: $viewModel.flipCard,
                    outcome: viewModel.lastOutcome
                )
                .overlay(GameOutcomeIndicator(outcome: viewModel.lastOutcome))

                // Visual history bar, clean and simple
                VisualHistoryBar(history: viewModel.guessHistory)

                Spacer()

                // Bottom control panel, contained and clean
                Group {
                    if viewModel.gameState == .playing || viewModel.gameState == .revealing {
                        HiloGameplayView(viewModel: viewModel)
                            .transition(.opacity.combined(with: .scale))
                    } else if viewModel.gameState == .betting {
                        HiloBettingView(viewModel: viewModel, isBetAmountFocused: $isBetAmountFocused)
                            .transition(.opacity.combined(with: .scale))
                    }
                }

            }
            .padding(.horizontal)
            .animation(.easeInOut(duration: 0.4), value: viewModel.gameState)
        }
        .foregroundColor(.white)
    }
}

// MARK: - Core Game Components

struct HiloCardArea: View {
    let currentCard: Card?
    let revealedCard: Card?
    @Binding var isFlipped: Bool
    let outcome: HiloViewModel.Outcome?

    var body: some View {
        HStack(spacing: 20) {
            PremiumCardView(card: currentCard, outcome: nil)
                .transition(.scale.combined(with: .opacity))
            
            FlippableView(isFlipped: $isFlipped) {
                PremiumCardView(card: nil, outcome: nil) // Front is the card back
            } back: {
                PremiumCardView(card: revealedCard, outcome: outcome) // Back is the revealed card
            }
        }
    }
}

struct HiloBettingView: View {
    @ObservedObject var viewModel: HiloViewModel
    @FocusState.Binding var isBetAmountFocused: Bool

    var body: some View {
        VStack(spacing: 15) {
            TextField("Bet Amount", text: $viewModel.betAmount)
                .keyboardType(.numberPad)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.2)))
                .focused($isBetAmountFocused)

            Button(action: viewModel.placeBet) {
                Text("Place Bet")
                    .font(.headline).bold()
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.purple)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .shadow(color: .purple.opacity(0.5), radius: 8, y: 4)
            }
            .buttonStyle(PressableButtonStyle())
            .disabled(viewModel.betAmount.isEmpty || (Int(viewModel.betAmount) ?? 0) <= 0)
        }
        .padding()
        .background(SolidPanelView()) // Using the panel style from Mines
    }
}

struct HiloGameplayView: View {
    @ObservedObject var viewModel: HiloViewModel
    
    var body: some View {
        VStack(spacing: 15) {
            HStack(spacing: 15) {
                GuessButton(title: "Higher", chance: viewModel.higherChance, color: .cyan) { viewModel.makeGuess(.higher) }
                GuessButton(title: "Lower", chance: viewModel.lowerChance, color: .purple) { viewModel.makeGuess(.lower) }
            }
            
            ActionButton(title: "Cashout", icon: "dollarsign.arrow.circle.right.fill", color: .green, action: viewModel.cashout)
                .disabled(viewModel.profit <= 0)
                .opacity(viewModel.profit <= 0 ? 0.6 : 1.0)
        }
        .padding()
        .background(SolidPanelView())
    }
}


// MARK: - Reusable UI Components (Inspired by Mines & Keno)

struct VisualHistoryBar: View {
    let history: [HiloHistoryItem]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(history) { item in
                    MiniCardView(item: item)
                        .transition(.asymmetric(insertion: .offset(y: 30).combined(with: .opacity), removal: .opacity))
                }
            }
            .padding(.horizontal)
            .frame(height: 50)
        }
        .animation(.spring(), value: history.count)
    }
}

struct MiniCardView: View {
    let item: HiloHistoryItem
    
    var body: some View {
        HStack(spacing: 4) {
            Text(item.card.rank.displayValue)
                .foregroundColor(.white)
            Image(systemName: item.guess == .higher ? "arrow.up" : "arrow.down")
                .foregroundColor(item.guess == .higher ? .cyan : .purple)
        }
        .font(.system(size: 14, weight: .bold, design: .monospaced))
        .padding(.horizontal, 12)
        .frame(height: 35)
        .background(Color.black.opacity(0.4))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.1)))
    }
}

struct GuessButton: View {
    let title: String, chance: Double, color: Color, action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(title).font(.headline).bold()
                Text(String(format: "%.2f%%", chance)).font(.title2).bold().monospaced()
            }
            .padding()
            .frame(maxWidth: .infinity, minHeight: 100)
            .background(color.opacity(0.2))
            .cornerRadius(15)
            .overlay(RoundedRectangle(cornerRadius: 15).stroke(color, lineWidth: 2))
        }.buttonStyle(PressableButtonStyle())
    }
}


// MARK: - REQUIRED DEPENDENCIES (To fix compiler errors)

// From MinesView / KenoView - for the header

// From TowersView - for the buttons
struct ActionButton: View {
    let title: String, icon: String, color: Color, action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.headline.bold())
                .padding()
                .frame(maxWidth: .infinity, minHeight: 60)
                .background(color.opacity(0.8))
                .foregroundColor(color == .green ? .black : .white) // .green is valid here
                .cornerRadius(15)
        }.buttonStyle(PressableButtonStyle())
    }
}

// From previous HiloView - for the win/loss pop-up
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

// From previous HiloView - for the card flip animation
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

// From MinesView - for the panel backgrounds


struct PremiumCardView: View {
    let card: Card?
    let outcome: HiloViewModel.Outcome?
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(card != nil ? Color.white.opacity(0.95) : Color.black.opacity(0.5))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            
            if let card = card {
                let cardColor: Color = (card.suit == .hearts || card.suit == .diamonds) ? .red : .black
                VStack(spacing: 10) {
                    Text(card.rank.displayValue).font(.system(size: 40, weight: .heavy, design: .serif))
                    Text(card.suit.rawValue).font(.system(size: 30))
                }.foregroundColor(cardColor)
            } else {
                RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(0.05))
            }
        }
        .frame(width: 120, height: 180)
        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
        .overlay(
            ZStack {
                if outcome == .win {
                    RoundedRectangle(cornerRadius: 12).stroke(Color.green, lineWidth: 3).blur(radius: 3)
                } else if outcome == .loss {
                    RoundedRectangle(cornerRadius: 12).stroke(Color.red, lineWidth: 3).blur(radius: 3)
                }
            }
            .animation(.easeInOut, value: outcome)
        )
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
