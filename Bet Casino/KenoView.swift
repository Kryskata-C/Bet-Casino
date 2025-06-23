// Bet Casino/KenoView.swift

import SwiftUI
import AVFoundation

// MARK: - Sound Manager
class KenoSoundManager {
    static let shared = KenoSoundManager()
    private var audioPlayer: AVAudioPlayer?

    enum SoundOption: String {
        case start = "Mines Start.wav"
        case cashout = "Mines Cashout.wav"
        case miss = "Keno Miss.wav"
        case hit = "Keno Diamond 2.wav"
    }

    func playSound(sound: SoundOption) {
        guard let url = Bundle.main.url(forResource: sound.rawValue, withExtension: nil) else { return }
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.play()
        } catch {
            print("Error playing sound: \(error.localizedDescription)")
        }
    }
}

// MARK: - Reusable Components
struct KenoStatusPill: View {
    let title: String
    var value: String
    var color: Color = .purple
    
    var body: some View {
        VStack(spacing: 2) {
            Text(title.uppercased()).font(.system(size: 10, weight: .bold)).foregroundColor(.gray)
            Text(value).font(.system(size: 26, weight: .heavy, design: .rounded)).foregroundColor(color)
                .contentTransition(.numericText()).animation(.spring(), value: value) // --- MODIFIED: Removed the .shadow() modifier from this line
        }
        .padding(.horizontal).frame(minWidth: 120, minHeight: 60).background(.black.opacity(0.25))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(.white.opacity(0.1), lineWidth: 1))
    }
}

// --- ADDED: Floating Bonus Text View (inspired by Towers) ---
struct KenoBonusTextView: View {
    let item: KenoBonusTextItem
    @State private var yOffset: CGFloat = 0
    @State private var opacity: Double = 1
    
    var body: some View {
        Text(item.text)
            .font(.headline).bold()
            .foregroundColor(item.color)
            .shadow(color: item.color.opacity(0.8), radius: 5)
            .offset(y: yOffset)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeOut(duration: 2.0)) {
                    yOffset = -60
                    opacity = 0
                }
            }
    }
}


// MARK: - Static Background
struct StaticKenoBackground: View {
    var body: some View {
        LinearGradient(
            gradient: Gradient(colors: [Color(red: 20/255, green: 0, blue: 40/255), .black]),
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

// MARK: - Main Keno View
struct KenoView: View {
    @StateObject private var viewModel: KenoViewModel
    @FocusState private var isBetAmountFocused: Bool
    @State private var bonusTexts: [KenoBonusTextItem] = []
    @State private var showBoostsSheet = false // --- NEW ---
    
    init(session: SessionManager) {
        _viewModel = StateObject(wrappedValue: KenoViewModel(session: session))
    }

    var body: some View {
        ZStack {
            StaticKenoBackground()
            VStack(spacing: 15) {
                HStack {
                    KenoStatusPill(title: "Multiplier", value: String(format: "%.2fx", viewModel.currentMultiplier), color: .cyan)
                    KenoStatusPill(
                        title: "Profit",
                        value: (viewModel.profit >= 0 ? "+" : "") + formatNumber(Int(viewModel.profit)),
                        color: viewModel.profit > 0 ? .green : (viewModel.profit < 0 ? .red : .white)
                    )
                    if viewModel.winStreak > 0 {
                        KenoStatusPill(title: "Streak", value: "🔥 \(viewModel.winStreak)", color: .orange)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.top)
                .animation(.spring(), value: viewModel.winStreak)
                
                // --- NEW: Mercy Mode Banner ---
                if viewModel.isMercyModeActive {
                    Text("Mercy Mode Active: +1 Extra Draw")
                        .font(.caption).bold().foregroundColor(.cyan)
                        .padding(8).background(Color.cyan.opacity(0.2)).cornerRadius(10)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                KenoPayoutBarView(viewModel: viewModel)
                
                ScrollView {
                    KenoBoardView(viewModel: viewModel).padding()
                }
                
                KenoControlsView(viewModel: viewModel, isBetAmountFocused: $isBetAmountFocused, showBoosts: $showBoostsSheet)
            }
            .padding(.top, 40)
            
            ZStack {
                ForEach(bonusTexts) { item in
                    KenoBonusTextView(item: item)
                }
            }
        }
        .foregroundColor(.white)
        .toolbar {
             ToolbarItemGroup(placement: .keyboard) {
                 Spacer()
                 Button("Done") { isBetAmountFocused = false }.fontWeight(.bold)
             }
         }
        .onChange(of: viewModel.bonusText) { newValue in
             if let newBonus = newValue {
                 bonusTexts.append(newBonus)
                 viewModel.bonusText = nil
                 DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                     bonusTexts.removeAll { $0.id == newBonus.id }
                 }
             }
         }
        // --- NEW: Boosts Sheet ---
        .sheet(isPresented: $showBoostsSheet) {
            BoostsSheetView(viewModel: viewModel)
        }
    }
}



// MARK: - Payout Bar
private struct KenoPayoutBarView: View {
    @ObservedObject var viewModel: KenoViewModel
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(spacing: 2) {
                HStack(spacing: 8) {
                    ForEach(0...viewModel.maxSelections, id: \.self) { hitCount in
                        Text(getPayout(for: hitCount))
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .frame(width: 60)
                    }
                }
                HStack(spacing: 8) {
                    ForEach(0...viewModel.maxSelections, id: \.self) { hitCount in
                        HStack(spacing: 4) {
                            Text("\(hitCount)")
                            Image(systemName: "diamond.fill")
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 60)
                        .padding(.vertical, 8)
                        .background(backgroundForHit(hitCount))
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(strokeForHit(hitCount), lineWidth: 2))
                    }
                }
            }.padding(.horizontal)
        }.frame(height: 70)
    }
    
    private func getPayout(for hits: Int) -> String {
        guard let payouts = viewModel.payoutTable[viewModel.selectedNumbers.count] else { return "0.00x" }
        return String(format: "%.2fx", payouts[hits] ?? 0.0)
    }
    
    private func backgroundForHit(_ hitCount: Int) -> Color {
        let isCurrentHit = viewModel.hits.count == hitCount && viewModel.gameState != .betting
        return isCurrentHit ? .green.opacity(0.3) : .black.opacity(0.2)
    }
    
    private func strokeForHit(_ hitCount: Int) -> Color {
        let isCurrentHit = viewModel.hits.count == hitCount && viewModel.gameState != .betting
        return isCurrentHit ? .green : .clear
    }
}


// MARK: - Keno Board and Tile
private struct KenoBoardView: View {
    @ObservedObject var viewModel: KenoViewModel
    
    let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 5)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach($viewModel.gridNumbers) { kenoNumber in
                // --- MODIFIED: Pass the entire viewModel into the tile ---
                KenoTileView(number: kenoNumber, viewModel: viewModel)
                    .onTapGesture {
                        if viewModel.gameState == .results {
                            viewModel.fullReset()
                        }
                        viewModel.toggleSelection(kenoNumber.wrappedValue.number)
                    }
            }
        }
    }
}

struct KenoTileView: View {
    @Binding var number: KenoNumber
    @ObservedObject var viewModel: KenoViewModel

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10).fill(baseColor)
                .overlay(overlayBorder)
            
            if number.isHot {
                Image(systemName: "flame.fill").foregroundColor(.red.opacity(0.5)).font(.caption).offset(x: 15, y: -15)
            }
            if number.isCold {
                Image(systemName: "snowflake").foregroundColor(.blue.opacity(0.5)).font(.caption).offset(x: 15, y: -15)
            }
            
            Text("\(number.number)")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .opacity(number.state == .none || number.state == .selected ? 1 : 0)

            ZStack {
                 if number.state == .hit {
                    if number.isJackpot {
                        Image(systemName: "sparkles").font(.system(size: 40, weight: .bold))
                             .foregroundStyle(LinearGradient(colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom))
                             // --- MODIFIED: Removed the .shadow() modifier ---
                             .transition(.scale.combined(with: .opacity))
                    } else {
                        Image(systemName: "diamond.fill").font(.system(size: 28, weight: .bold))
                            .foregroundStyle(LinearGradient(colors: [.cyan, .white], startPoint: .top, endPoint: .bottom))
                            // --- MODIFIED: Removed the .shadow() modifier ---
                            .transition(.scale.combined(with: .opacity))
                    }
                } else if number.state == .drawn {
                    Image(systemName: "xmark").font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white.opacity(0.4)).transition(.scale.combined(with: .opacity))
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .animation(.easeOut(duration: 0.4), value: number.state)
        .animation(.spring(), value: number.isLucky)
    }
    
    private var stateIsActive: Bool { number.state == .selected || number.state == .hit }
    private var baseColor: Color { stateIsActive ? .purple.opacity(0.4) : .white.opacity(0.05) }
    
    @ViewBuilder private var overlayBorder: some View {
        RoundedRectangle(cornerRadius: 10).stroke(borderColor, lineWidth: stateIsActive ? 3 : 1)
    }
    
    private var borderColor: Color {
        if number.state == .selected && number.isLucky && viewModel.gameState != .betting { return .yellow }
        if number.isJackpot && number.state == .hit { return .yellow }
        if number.state == .hit { return .cyan }
        if number.state == .selected { return .purple }
        return .white.opacity(0.1)
    }
}


// MARK: - Controls
private struct KenoControlsView: View {
    @ObservedObject var viewModel: KenoViewModel
    @FocusState.Binding var isBetAmountFocused: Bool
    @Binding var showBoosts: Bool // ADD THIS
    
    var body: some View {
        VStack(spacing: 12) {
            // --- NEW: Active Boost Indicator ---
            if let boost = viewModel.activeBoost {
                Text("Active Boost: \(boost == .extraDraw ? "Extra Draw" : "Payout Insurance")")
                    .font(.caption).bold().foregroundColor(.green)
                    .padding(8).background(Color.green.opacity(0.2)).cornerRadius(10)
            }
            
            HStack(spacing: 12) {
                VStack(spacing: 6) {
                    Text("Bet Amount").font(.caption).foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    TextField("Enter bet", text: $viewModel.betAmount)
                        .keyboardType(.numberPad).padding(12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.2)))
                        .focused($isBetAmountFocused)
                }
                
                // --- NEW: Boosts Button ---
                Button { showBoosts = true } label: {
                    VStack {
                        Image(systemName: "star.circle.fill")
                        Text("Boosts")
                    }
                    .font(.caption).bold().padding(10).frame(height: 60)
                    .background(Color.yellow.opacity(0.2)).cornerRadius(12)
                    .foregroundColor(.yellow)
                }
                .disabled(viewModel.gameState != .betting || viewModel.activeBoost != nil)
                .opacity(viewModel.gameState != .betting || viewModel.activeBoost != nil ? 0.5 : 1.0)
            }
            
            Button(action: viewModel.startGame) {
                Text(viewModel.gameState == .results ? "Play Again" : "Place Bet")
                    .font(.headline).bold().padding().frame(maxWidth: .infinity)
                    .background(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .foregroundColor(.white).cornerRadius(15)
            }
            .buttonStyle(PressableButtonStyle())
            .disabled(viewModel.selectedNumbers.isEmpty || viewModel.gameState == .drawing)
        }
        .padding().background(.black.opacity(0.25)).cornerRadius(25)
        .padding(.horizontal).padding(.bottom, 5)
    }
}
struct BoostsSheetView: View {
    @ObservedObject var viewModel: KenoViewModel
    @Environment(\.dismiss) var dismiss
    
    let boosts: [KenoBoost] = [.extraDraw, .payoutInsurance]
    
    var body: some View {
        ZStack {
            StaticKenoBackground()
            VStack(spacing: 20) {
                Text("Gem Boosts")
                    .font(.largeTitle).bold()
                
                Text("Spend gems to get an advantage for one round.")
                    .font(.headline).foregroundColor(.gray)
                
                ForEach(boosts, id: \.self) { boost in
                    Button {
                        viewModel.activateBoost(boost)
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(boost == .extraDraw ? "Extra Draw" : "Payout Insurance")
                                    .font(.title3).bold()
                                Text(boost.description)
                                    .font(.caption).foregroundColor(.white.opacity(0.8))
                            }
                            Spacer()
                            HStack {
                                Text("\(boost.cost)")
                                Image(systemName: "diamond.fill")
                            }
                            .font(.headline).foregroundColor(.cyan)
                        }
                        .padding()
                        .background(.black.opacity(0.3))
                        .cornerRadius(15)
                    }
                    .disabled(viewModel.sessionManager.gems < boost.cost)
                    .opacity(viewModel.sessionManager.gems < boost.cost ? 0.6 : 1.0)
                }
                
                Spacer()
                
                Button("Close") { dismiss() }
                    .font(.headline)
            }
            .padding()
        }
        .foregroundColor(.white)
    }
}

// MARK: - Preview Provider
#Preview {
    let session = SessionManager()
    session.isLoggedIn = true
    session.gems = 50 // Give some gems for preview
    return KenoView(session: session).environmentObject(session)
}
