// Bet Casino/HiloView.swift

import SwiftUI

// MARK: - Main View
struct HiloView: View {
    @StateObject private var viewModel: HiloViewModel
    @FocusState private var isBetAmountFocused: Bool

    init(session: SessionManager) {
        _viewModel = StateObject(wrappedValue: HiloViewModel(session: session))
    }

    var body: some View {
        ZStack {
            RadialGradient(colors: [Color(red: 10/255, green: 40/255, blue: 30/255), .black], center: .center, startRadius: 50, endRadius: 600)
                .ignoresSafeArea()

            VStack(spacing: 15) {
                HiloHeaderView(multiplier: viewModel.currentMultiplier, profit: viewModel.profit)
                Spacer()

                HiloCardArea(
                    currentCard: viewModel.currentCard,
                    // ✅ FIX: Pass the new `revealedCard` property to the view
                    revealedCard: viewModel.revealedCard,
                    isFlipped: $viewModel.flipCard
                )
                .overlay(GameOutcomeIndicator(outcome: viewModel.lastOutcome))

                Spacer()
                
                if viewModel.gameState == .playing {
                    HiloGameplayView(viewModel: viewModel)
                        .transition(.asymmetric(insertion: .scale.combined(with: .opacity), removal: .opacity))
                } else {
                    HiloBettingView(viewModel: viewModel, isBetAmountFocused: $isBetAmountFocused)
                        .transition(.asymmetric(insertion: .scale.combined(with: .opacity), removal: .opacity))
                }
            }
            .padding()
            .padding(.bottom, 20)
        }
        .foregroundColor(.white)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.gameState)
    }
}

// MARK: - Subviews
struct HiloHeaderView: View {
    let multiplier: Double
    let profit: Double

    var body: some View {
        HStack {
            TowersStatusPill(title: "Multiplier", value: String(format: "%.2fx", multiplier), color: .cyan)
            Spacer()
            TowersStatusPill(
                title: "Profit",
                value: (profit >= 0 ? "+" : "") + formatNumber(Int(profit)),
                color: profit > 0 ? .green : (profit < 0 ? .red : .white)
            )
        }
        .padding(.top, 40)
    }
}

struct HiloCardArea: View {
    let currentCard: Card?
    // ✅ FIX: Receive the new `revealedCard` property
    let revealedCard: Card?
    @Binding var isFlipped: Bool

    var body: some View {
        HStack(spacing: 20) {
            if let card = currentCard {
                PremiumCardView(card: card).transition(.scale)
            }

            FlippableView(isFlipped: $isFlipped) {
                // ✅ FIX: The front of the card is now based on `revealedCard`
                PremiumCardView(card: revealedCard)
            } back: {
                PremiumCardView(card: nil)
            }
        }
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
            
            HStack(spacing: 15) {
                Button(action: viewModel.skipCard) {
                    Label("Skip", systemImage: "arrow.right.square.fill")
                        .font(.headline.bold())
                        .padding()
                        .frame(maxWidth: .infinity, minHeight: 60)
                        .background(.black.opacity(0.3))
                        .foregroundColor(.yellow)
                        .cornerRadius(15)
                }
                .buttonStyle(PressableButtonStyle())
                
                Button(action: viewModel.cashout) {
                    Text("Cashout")
                        .font(.headline.bold())
                        .padding()
                        .frame(maxWidth: .infinity, minHeight: 60)
                        .background(Color.green)
                        .foregroundColor(.black)
                        .cornerRadius(15)
                }
                .buttonStyle(PressableButtonStyle())
                .disabled(viewModel.profit <= 0)
            }
        }
        .padding()
    }
}

struct HiloBettingView: View {
    @ObservedObject var viewModel: HiloViewModel
    @FocusState.Binding var isBetAmountFocused: Bool
    
    var body: some View {
        VStack(spacing: 15) {
            TextField("Bet Amount", text: $viewModel.betAmount)
                .keyboardType(.numberPad).padding()
                .background(Color.black.opacity(0.3)).cornerRadius(12)
                .focused($isBetAmountFocused)
                .modifier(ShakeEffect(animatableData: CGFloat(viewModel.isBetAmountInvalid ? 1 : 0)))
            
            Button(action: viewModel.placeBet) {
                Text("Place Bet")
                    .font(.headline).bold().padding()
                    .frame(maxWidth: .infinity)
                    .background(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .foregroundColor(.white).cornerRadius(15)
            }
            .buttonStyle(PressableButtonStyle())
            .disabled(viewModel.betAmount.isEmpty || (Int(viewModel.betAmount) ?? 0) <= 0)
        }
        .padding().background(.black.opacity(0.25)).cornerRadius(25)
    }
}

// MARK: - Reusable & Premium Components
struct PremiumCardView: View {
    let card: Card?
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(card != nil ? Color.white.opacity(0.95) : Color.black.opacity(0.5))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(LinearGradient(colors: [.white.opacity(0.3), .clear], startPoint: .topLeading, endPoint: .bottomTrailing))
                .blur(radius: 3)

            if let card = card {
                let cardColor: Color = (card.suit == .hearts || card.suit == .diamonds) ? .red : .black
                VStack(spacing: 10) {
                    Text(card.rank.displayValue).font(.system(size: 50, weight: .heavy, design: .serif))
                    Text(card.suit.rawValue).font(.system(size: 40))
                }.foregroundColor(cardColor).shadow(color: cardColor.opacity(0.3), radius: 5)
            } else {
                ZStack {
                    LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing).clipShape(RoundedRectangle(cornerRadius: 20))
                    Image(systemName: "suit.spade.fill").font(.system(size: 80)).foregroundColor(.white.opacity(0.2))
                }
            }
        }
        .frame(width: 160, height: 240)
        .shadow(color: .black.opacity(0.4), radius: 10, y: 5)
    }
}

struct GuessButton: View {
    let title: String, chance: Double, color: Color, action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(title).font(.headline).bold()
                Text(String(format: "%.2f%%", chance)).font(.title).bold().monospaced()
            }
            .padding().frame(maxWidth: .infinity, minHeight: 100)
            .background(color.opacity(0.3)).background(.ultraThinMaterial).foregroundColor(.white).cornerRadius(15)
            .overlay(RoundedRectangle(cornerRadius: 15).stroke(color, lineWidth: 2).blur(radius: 2))
        }.buttonStyle(PressableButtonStyle())
    }
}

struct GameOutcomeIndicator: View {
    let outcome: HiloViewModel.Outcome?
    @State private var appeared = false
    
    var body: some View {
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

struct FlippableView<Front: View, Back: View>: View {
    @Binding var isFlipped: Bool
    let front: Front, back: Back
    
    init(isFlipped: Binding<Bool>, @ViewBuilder front: () -> Front, @ViewBuilder back: () -> Back = { EmptyView() }) {
        self._isFlipped = isFlipped; self.front = front(); self.back = back()
    }
    
    var body: some View {
        ZStack {
            front.rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0)).opacity(isFlipped ? 0 : 1)
            back.rotation3DEffect(.degrees(isFlipped ? 0 : -180), axis: (x: 0, y: 1, z: 0)).opacity(isFlipped ? 1 : 0)
        }.animation(.spring(response: 0.5, dampingFraction: 0.7), value: isFlipped)
    }
}

// MARK: - Preview
#Preview {
    let session = SessionManager(); session.isLoggedIn = true; session.money = 50000
    return HiloView(session: session).environmentObject(session)
}
