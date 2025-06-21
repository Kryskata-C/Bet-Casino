import SwiftUI

// MARK: - Win Tier Model
// Defines the different tiers of wins for the BiggestWinView
enum WinTier {
    case none
    case gold
    case diamond
    case legendary
    case mythic
    
    // The gradient for the tier's background
    var gradient: LinearGradient {
        switch self {
        case .none:
            return LinearGradient(colors: [.gray], startPoint: .top, endPoint: .bottom)
        case .gold:
            return LinearGradient(colors: [Color(red: 1.0, green: 0.85, blue: 0.4), Color(red: 0.8, green: 0.6, blue: 0.2)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .diamond:
            return LinearGradient(colors: [.cyan, .blue.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .legendary:
            return LinearGradient(colors: [.purple, .pink.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .mythic:
            return LinearGradient(colors: [.red, .orange, .yellow, .red], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
    
    // The icon representing the tier
    var icon: String {
        switch self {
        case .none: return "questionmark.diamond.fill"
        case .gold: return "trophy.fill"
        case .diamond: return "diamond.fill"
        case .legendary: return "crown.fill"
        case .mythic: return "flame.fill"
        }
    }
    
    // The title of the tier
    var title: String {
        switch self {
        case .none: return "No Wins Yet"
        case .gold: return "Big Win"
        case .diamond: return "Diamond Win"
        case .legendary: return "Legendary Win"
        case .mythic: return "Mythic Win"
        }
    }
    
    // The color of the animated shadow/glow
    var shadowColor: Color {
        switch self {
        case .none: return .clear
        case .gold: return .yellow
        case .diamond: return .cyan
        case .legendary: return .purple
        case .mythic: return .red
        }
    }
}

struct ProfileView: View {
    @EnvironmentObject var session: SessionManager
    
    // Define the grid layout for stat cards
    let columns = [
        GridItem(.flexible(), spacing: 15),
        GridItem(.flexible(), spacing: 15)
    ]

    var body: some View {
        ZStack {
            // Background Gradient
            LinearGradient(colors: [.black, Color(red: 35/255, green: 0, blue: 50/255).opacity(0.9)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 25) {
                    // MARK: - Header
                    ProfileHeaderView(username: session.username, level: session.level)
                        .padding(.top, 20)

                    // MARK: - Biggest Win Trophy (Dynamic & Animated)
                    // This view will now only appear if the user has a biggest win recorded.
                    if session.biggestWin > 0 {
                        BiggestWinView(amount: session.biggestWin)
                            .padding(.horizontal)
                    }

                    // MARK: - Statistics Grid
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Player Statistics")
                            .font(.title2).bold()
                            .padding(.horizontal)
                        
                        LazyVGrid(columns: columns, spacing: 15) {
                            StatCardView(icon: "dollarsign.circle.fill", title: "Total Won", value: formatNumber(session.totalMoneyWon), color: .green)
                            StatCardView(icon: "dice.fill", title: "Total Bets", value: "\(session.betsPlaced)", color: .cyan)
                            StatCardView(icon: "hammer.fill", title: "Mines Bets", value: "\(session.minesBets)", color: .orange)
                            StatCardView(icon: "star.fill", title: "Gems", value: "\(session.gems)", color: .purple)
                        }
                        .padding(.horizontal)
                    }

                    // MARK: - Logout Button
                    Button(action: {
                        session.logout()
                    }) {
                        Label("Logout", systemImage: "arrow.right.to.line.square.fill")
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red.opacity(0.8))
                            .cornerRadius(15)
                            .shadow(color: .red.opacity(0.5), radius: 8, y: 4)
                    }
                    .padding(.horizontal)
                    .padding(.top, 15)

                }
                .padding(.vertical)
            }
        }
        .foregroundColor(.white)
        .navigationBarHidden(true) // Hiding default navigation bar for a custom look
    }
}

// MARK: - Subviews for Profile

struct ProfileHeaderView: View {
    let username: String
    let level: Int

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(
                    LinearGradient(colors: [.purple, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .shadow(color: .purple.opacity(0.6), radius: 10)

            Text(username)
                .font(.largeTitle)
                .fontWeight(.heavy)

            HStack {
                LevelView(level: level)
                
            }
        }
    }
}

struct LevelView: View {
    let level: Int
    @State private var isGlowing = false
    
    private var levelColor: Color {
        switch level {
            case 0..<10: return .gray
            case 10..<20: return .cyan
            case 20..<30: return .green
            case 30..<40: return .blue
            case 40..<50: return .indigo
            case 50..<60: return .pink
            case 60..<70: return .purple
            case 70..<80: return .orange
            case 80..<90: return .red
            case 90...: return .yellow
            default: return .white
        }
    }
    
    var body: some View {
        Text("Level \(level)")
            .font(.footnote)
            .fontWeight(.bold)
            .foregroundColor(levelColor)
            .shadow(
                color: isGlowing ? levelColor.opacity(0.8) : .clear,
                radius: isGlowing ? 8 : 0
            )
            .onAppear {
                if level >= 80 {
                    withAnimation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                        isGlowing = true
                    }
                }
            }
            .onChange(of: level) {
                if level >= 80 && !isGlowing {
                    withAnimation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                        isGlowing = true
                    }
                } else if level < 80 && isGlowing {
                    isGlowing = false
                }
            }
    }
}

struct BiggestWinView: View {
    let amount: Int
    @State private var isAnimating = false

    // Determine the tier based on the win amount
    private var tier: WinTier {
        switch amount {
        case 0:
            return .none
        case 1..<1_000_000:
            return .gold
        case 1_000_000..<10_000_000:
            return .diamond
        case 10_000_000..<100_000_000:
            return .legendary
        default:
            return .mythic
        }
    }
    
    var body: some View {
        ZStack {
            // Use the tier's gradient for the background
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(tier.gradient)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(tier.shadowColor.opacity(0.8), lineWidth: 2)
                )
                .shadow(color: isAnimating ? tier.shadowColor.opacity(0.8) : .clear, radius: 15, y: 5)

            // Content
            HStack(spacing: 20) {
                Image(systemName: tier.icon)
                    .font(.system(size: 50))
                    .foregroundColor(.white.opacity(0.9))
                    .shadow(color: .black.opacity(0.2), radius: 5)
                
                VStack(alignment: .leading) {
                    Text(tier.title)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white.opacity(0.8))
                    
                    Text(formatNumber(amount))
                        .font(.system(size: 36, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
                Spacer()
            }
            .padding(20)
        }
        .scaleEffect(isAnimating ? 1.02 : 1.0)
        .onAppear {
            withAnimation(Animation.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}


struct StatCardView: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .shadow(color: color.opacity(0.5), radius: 5)

            VStack(alignment: .leading) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }
}


// MARK: - Preview
struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a prefilled session manager for the preview
        let session = SessionManager()
        session.isLoggedIn = true
        session.username = "Kryska"
        session.money = 1_500_000
        session.level = 85 // Set a high level to preview the glow effect
        session.gems = 150
        session.betsPlaced = 1243
        session.minesBets = 812
        session.totalMoneyWon = 1_250_000
        session.biggestWin = 1_000000_000 // Set a high win to see the Legendary tier
        session.currentScreen = .profile
        
        // This is how it would look inside the main app view
        return ContentView()
            .environmentObject(session)
    }
}
