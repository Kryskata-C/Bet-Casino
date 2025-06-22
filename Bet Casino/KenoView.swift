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

    init(session: SessionManager) {
        _viewModel = StateObject(wrappedValue: KenoViewModel(session: session))
    }

    var body: some View {
        ZStack {
            StaticKenoBackground()
            VStack(spacing: 0) {
                KenoPayoutBarView(viewModel: viewModel).padding(.top)
                ScrollView {
                    KenoBoardView(viewModel: viewModel).padding()
                }
                KenoControlsView(viewModel: viewModel, isBetAmountFocused: $isBetAmountFocused)
            }
            .padding(.top, 40)
            .blur(radius: viewModel.showWinSummary ? 10 : 0)

            if viewModel.showWinSummary {
                KenoWinSummaryView(
                    multiplier: viewModel.currentMultiplier,
                    winnings: viewModel.lastWinnings
                )
                .onTapGesture {
                    viewModel.showWinSummary = false
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(), value: viewModel.showWinSummary)
        .foregroundColor(.white)
        .toolbar {
             ToolbarItemGroup(placement: .keyboard) {
                 Spacer()
                 Button("Done") { isBetAmountFocused = false }.fontWeight(.bold)
             }
         }
    }
}

// MARK: - Win Summary Pop-up
struct KenoWinSummaryView: View {
    let multiplier: Double
    let winnings: Double

    var body: some View {
        VStack(spacing: 8) {
            Text(String(format: "%.2fx", multiplier))
                .font(.system(size: 48, weight: .heavy, design: .rounded))
                .foregroundColor(.white)

            Rectangle()
                .frame(height: 1)
                .foregroundColor(.white.opacity(0.3))
                .padding(.horizontal, 20)

            HStack {
                Text(formatNumber(Int(winnings)))
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundColor(.green)
                Image(systemName: "bitcoinsign.circle.fill")
                    .foregroundColor(.orange)
                    .font(.title2)
            }
        }
        .padding(.vertical, 20)
        .padding(.horizontal)
        .frame(minWidth: 240)
        .background(Color(red: 40/255, green: 45/255, blue: 60/255))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.green, lineWidth: 4)
        )
        .shadow(color: .green.opacity(0.5), radius: 20)
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
                KenoTileView(number: kenoNumber)
                    .onTapGesture {
                        if viewModel.gameState == .results {
                            viewModel.fullReset()
                        }
                        // FIX: Access the 'wrappedValue' of the binding to get the integer.
                        viewModel.toggleSelection(kenoNumber.wrappedValue.number)
                    }
            }
        }
    }
}

struct KenoTileView: View {
    @Binding var number: KenoNumber
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10).fill(baseColor)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(borderColor, lineWidth: stateIsActive ? 3 : 1))

            ZStack {
                if number.state == .hit {
                    Image(systemName: "diamond.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(LinearGradient(colors: [.cyan, .white], startPoint: .top, endPoint: .bottom))
                        .shadow(color: .cyan.opacity(0.8), radius: 10)
                        .transition(.scale.combined(with: .opacity))
                } else if number.state == .drawn {
                    Image(systemName: "xmark")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white.opacity(0.4))
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .animation(.spring(response: 0.4, dampingFraction: 0.5), value: number.state)
    }
    
    private var stateIsActive: Bool { number.state == .selected || number.state == .hit }
    private var baseColor: Color { stateIsActive ? .purple.opacity(0.4) : .white.opacity(0.05) }
    private var borderColor: Color {
        if number.state == .hit { return .yellow }
        if number.state == .selected { return .purple }
        return .white.opacity(0.1)
    }
}

// MARK: - Controls
private struct KenoControlsView: View {
    @ObservedObject var viewModel: KenoViewModel
    @FocusState.Binding var isBetAmountFocused: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: 6) {
                 Text("Bet Amount").font(.caption).foregroundColor(.gray)
                     .frame(maxWidth: .infinity, alignment: .leading)
                 TextField("Enter bet", text: $viewModel.betAmount)
                     .keyboardType(.numberPad).padding(12)
                     .background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.2)))
                     .focused($isBetAmountFocused)
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
        .padding()
        .background(.black.opacity(0.25))
        .cornerRadius(25)
        .padding(.horizontal)
        .padding(.bottom, 5)
    }
}

// MARK: - Preview Provider
#Preview {
    let session = SessionManager()
    session.isLoggedIn = true
    return KenoView(session: session).environmentObject(session)
}
