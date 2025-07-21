// Bet Casino/PlinkoView.swift

import SwiftUI
import Combine

// MARK: - Plinko View
struct PlinkoView: View {
    @StateObject private var viewModel: PlinkoViewModel
    @FocusState private var isBetAmountFocused: Bool

    init(session: SessionManager) {
        _viewModel = StateObject(wrappedValue: PlinkoViewModel(sessionManager: session))
    }

    var body: some View {
        ZStack {
            // Background consistent with other games
            LinearGradient(colors: [.black, Color(red: 20/255, green: 0, blue: 40/255)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top status bar
                HStack {
                    PlinkoStatusPill(title: "Last Win", value: formatNumber(Int(viewModel.lastWin)), color: .green)
                    PlinkoStatusPill(title: "Total Profit", value: formatNumber(Int(viewModel.totalProfit)), color: viewModel.totalProfit >= 0 ? .green : .red)
                }
                .padding(.top, 20)
                .padding(.bottom, 15)
                .padding(.horizontal)

                // The main Plinko board area
                // Using a ZStack to overlay the buckets at the bottom of the board
                ZStack(alignment: .bottom) {
                    PlinkoBoardView(viewModel: viewModel)
                    
                    MultiplierBucketsView(
                        multipliers: viewModel.riskLevel.multipliers(for: viewModel.pegRows),
                        highlightedIndex: $viewModel.lastHitMultiplierIndex
                    )
                    // Pushing the buckets up from the bottom to sit just below the pegs.
                    .padding(.bottom, 5)
                }
                .layoutPriority(1) // Allows the board to take up available space

                // Game controls
                PlinkoControlsView(viewModel: viewModel, isBetAmountFocused: $isBetAmountFocused)
                    
                Text("⚠️ Game is currently overpowered and not balanced for fair play.")
                    .font(.caption.bold())
                    .foregroundColor(.yellow)
                    .padding(8)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(12)
// Ensures controls are lifted above the tab bar
            }
        }
        .foregroundColor(.white)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { isBetAmountFocused = false }.fontWeight(.bold)
            }
        }
    }
}

// MARK: - Plinko Board and Components
struct PlinkoBoardView: View {
    @ObservedObject var viewModel: PlinkoViewModel
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Pegs
                PlinkoPegsView(rows: viewModel.pegRows, size: geo.size)

                // Balls
                ForEach(viewModel.balls) { ball in
                    PlinkoBallView(ball: ball, size: geo.size)
                }
            }
            .onAppear {
                DispatchQueue.main.async {
                    viewModel.boardSize = geo.size
                }
            }
            .onChange(of: geo.size) {
                DispatchQueue.main.async {
                    viewModel.boardSize = geo.size
                }
            }
        }
    }
}

struct PlinkoPegsView: View {
    let rows: Int
    let size: CGSize

    var body: some View {
        let spacing = size.width / CGFloat(rows + 1)
        
        ForEach(0..<rows, id: \.self) { row in
            let pegCount = row + 2
            let yPos = (size.height * 0.9 / CGFloat(rows)) * CGFloat(row) // Position pegs within top 90% of the frame
            
            ForEach(0..<pegCount, id: \.self) { peg in
                let xPos = (size.width - (CGFloat(pegCount - 1) * spacing)) / 2 + (CGFloat(peg) * spacing)
                
                Circle()
                    .fill(Color.white.opacity(0.5))
                    .frame(width: 8, height: 8)
                    .position(x: xPos, y: yPos)
            }
        }
    }
}

struct PlinkoBallView: View {
    let ball: PlinkoBall
    let size: CGSize

    var body: some View {
        Circle()
            .fill(ball.color)
            .frame(width: 15, height: 15)
            .shadow(color: ball.color.opacity(0.8), radius: 8)
            .position(x: ball.position.x * size.width, y: ball.position.y * size.height)
            .animation(.spring(response: 0.1, dampingFraction: 0.8), value: ball.position)
    }
}


// MARK: - Controls and UI Elements
struct PlinkoControlsView: View {
    @ObservedObject var viewModel: PlinkoViewModel
    @FocusState.Binding var isBetAmountFocused: Bool

    var body: some View {
        VStack(spacing: 15) {
            // Bet Amount and Risk Level
            HStack(spacing: 12) {
                TextField("Bet Amount", text: $viewModel.betAmount)
                    .keyboardType(.numberPad)
                    .padding()
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(12)
                    .focused($isBetAmountFocused)

                Picker("Risk", selection: $viewModel.riskLevel) {
                    ForEach(PlinkoRiskLevel.allCases, id: \.self) { level in
                        Text(level.rawValue).tag(level)
                    }
                }
                Stepper("Rows: \(viewModel.pegRows)", value: $viewModel.pegRows, in: 7...11, step: 2)
                    .padding(.horizontal)
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(8)
                    .foregroundColor(.white)

                .pickerStyle(SegmentedPickerStyle())
                .background(Color.black.opacity(0.3)).cornerRadius(8)
            }

            // Play Button
            // In PlinkoControlsView.swift

            Button(action: {
                // 1. Get the current list of multipliers
                let multipliers = viewModel.riskLevel.multipliers(for: viewModel.pegRows)
                // 2. Calculate the middle index
                let middleIndex = multipliers.count / 2
                // 3. Drop the ball at the middle index! ✨
                viewModel.dropBall(forBucketIndex: middleIndex)
            }) {
                Text("Drop Ball")
                    .font(.headline).bold()
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .foregroundColor(.white)
                    .cornerRadius(15)
            }

            .buttonStyle(PressableButtonStyle())
        }
        .padding()
        .background(.black.opacity(0.25))
        .cornerRadius(25)
        .padding(.horizontal)
    }
}

// MARK: - NEW Multiplier Buckets View
struct MultiplierBucketsView: View {
    let multipliers: [Double]
    @Binding var highlightedIndex: Int?

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(multipliers.enumerated()), id: \.offset) { index, multiplier in
                Text(String(format: "%.1fx", multiplier))
                    .font(.system(size: max(10, 18 - CGFloat(multipliers.count)), weight: .bold, design: .monospaced))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity) // Each bucket takes equal space
                    .padding(.vertical, 8)
                    .background(multiplierColor(multiplier).opacity(highlightedIndex == index ? 0.8 : 0.4))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(highlightedIndex == index ? .white : .clear, lineWidth: 2)
                            .shadow(color: .white.opacity(highlightedIndex == index ? 0.5 : 0), radius: 3)
                    )
                    .animation(.spring(), value: highlightedIndex)
            }
        }
        .padding(.horizontal)
    }

    func multiplierColor(_ multiplier: Double) -> Color {
        if multiplier >= 10 { return .yellow }
        if multiplier >= 2 { return .green }
        if multiplier >= 1 { return .cyan }
        return .purple
    }
}


struct PlinkoStatusPill: View {
    let title: String
    var value: String
    var color: Color = .purple
    
    var body: some View {
        VStack(spacing: 2) {
            Text(title.uppercased()).font(.system(size: 10, weight: .bold)).foregroundColor(.gray)
            Text(value).font(.system(size: 26, weight: .heavy, design: .rounded)).foregroundColor(color)
                .contentTransition(.numericText()).animation(.spring(), value: value)
        }
        .padding(.horizontal).frame(minWidth: 150, minHeight: 60).background(.black.opacity(0.25))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(.white.opacity(0.1), lineWidth: 1))
    }
}

// MARK: - Preview Provider
#if DEBUG
struct PlinkoView_Previews: PreviewProvider {
    static var previews: some View {
        // Previewing within MainCasinoView to see the full layout with the bottom navigation bar.
        let session = SessionManager()
        session.isLoggedIn = true
        session.money = 100000
        
        return MainCasinoView()
            .environmentObject(session)
            .onAppear {
                session.currentScreen = .plinko
            }
    }
}
#endif
