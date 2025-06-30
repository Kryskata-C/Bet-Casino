import SwiftUI

// MARK: - Profile View Refactor

// A more premium, modern font for the profile section.
let premiumFont = Font.system(.body, design: .rounded)

struct ProfileView: View {
    @EnvironmentObject var session: SessionManager
    @State private var selectedTab: ProfileTab = .overview
    
    var body: some View {
        ZStack {
            // Darker, more subtle background gradient.
            LinearGradient(colors: [Color(red: 25/255, green: 20/255, blue: 40/255), .black], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                ProfileHeaderView(
                    username: session.username,
                    level: session.level,
                    xpProgress: session.xpProgress,isVip: true // Now uses the dynamic calculation                    isVip: true // Example VIP status
                )
                .padding(.bottom, 20)

                TabSwitcherView(selectedTab: $selectedTab)

                // Animated transition between tabs.
                TabView(selection: $selectedTab) {
                    OverviewTabView().tag(ProfileTab.overview)
                    StatsTabView().tag(ProfileTab.stats)
                    HistoryTabView().tag(ProfileTab.history)
                    SettingsTabView().tag(ProfileTab.settings)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .animation(.spring(), value: selectedTab)
            }
        }
        .font(premiumFont)
        .foregroundColor(.white)
        .navigationBarHidden(true)
    }
}

// MARK: - Profile Subviews

struct ProfileHeaderView: View {
    let username: String
    let level: Int
    let xpProgress: Double
    let isVip: Bool

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                // Circular level progress bar.
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: xpProgress)
                    .stroke(LinearGradient(colors: [.cyan, .purple], startPoint: .topLeading, endPoint: .bottomTrailing), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: .cyan.opacity(0.5), radius: 5)
                
                Image(systemName: "person.fill")
                    .font(.system(size: 60))
                    .padding(20)
                    .background(.thinMaterial, in: Circle())
            }
            .frame(width: 120, height: 120)

            HStack(spacing: 8) {
                Text(username)
                    .font(.largeTitle)
                    .fontWeight(.heavy)
                
                // VIP Tag.
                if isVip {
                    Image(systemName: "star.seal.fill")
                        .foregroundColor(.yellow)
                        .font(.title2)
                }
            }
            
            Text("Level \(level)")
                .font(.headline)
                .foregroundColor(.gray)
        }
        .padding(.top, 20)
    }
}


// MARK: - Tab Implementation

enum ProfileTab: String, CaseIterable {
    case overview = "Overview"
    case stats = "Stats"
    case history = "History"
    case settings = "Settings" // Add this line
}

struct TabSwitcherView: View {
    @Binding var selectedTab: ProfileTab

    var body: some View {
        Picker("Profile Tabs", selection: $selectedTab) {
            ForEach(ProfileTab.allCases, id: \.self) { tab in
                Text(tab.rawValue).tag(tab)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding(.horizontal)
        .background(Color.black.opacity(0.2))
        .cornerRadius(8)
    }
}

// MARK: - Tab Content Views

struct OverviewTabView: View {
    @EnvironmentObject var session: SessionManager

    var body: some View {
        ScrollView {
            VStack(spacing: 25) {
                TopPayoutView(amount: session.biggestWin)
                RecentGamesView(history: session.gameHistory)
                AchievementsView()
            }
            .padding()
        }
    }
}
struct GameHistoryEntry: Identifiable, Codable {
    let id: UUID
    let gameName: String
    let profit: Int
    let betAmount: Int
    let timestamp: Date

    // Helper to get the correct game icon
    var iconName: String {
        switch gameName {
        case "Mines": return "hammer.fill"
        case "Towers": return "building.columns.fill"
        case "Keno": return "number.square.fill"
        default: return "questionmark.diamond.fill"
        }
    }
}
struct GameHistoryRowView: View {
    let entry: GameHistoryEntry

    var body: some View {
        HStack {
            Image(systemName: entry.iconName)
                .font(.title2)
                .frame(width: 40)
                .foregroundColor(entry.profit >= 0 ? .cyan : .red)

            VStack(alignment: .leading) {
                Text(entry.gameName)
                    .fontWeight(.bold)
                Text("Bet: \(formatNumber(entry.betAmount))")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer()

            Text( (entry.profit >= 0 ? "+" : "") + formatNumber(entry.profit) )
                .fontWeight(.bold)
                .foregroundColor(entry.profit >= 0 ? .green : .red)
        }
        .padding()
        .background(.black.opacity(0.2))
        .cornerRadius(15)
    }
}
struct SettingsTabView: View {
    @EnvironmentObject var session: SessionManager
    @State private var soundEffects = true
    @State private var hapticFeedback = true

    var body: some View {
        Form {
            Section(header: Text("In-Game").foregroundColor(.gray)) {
                Toggle("Sound Effects", isOn: $soundEffects)
                Toggle("Haptic Feedback", isOn: $hapticFeedback)
            }
            .listRowBackground(Color.black.opacity(0.3))

            Section(header: Text("Account").foregroundColor(.gray)) {
                Button(action: {
                    session.logout()
                }) {
                    Text("Logout")
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .listRowBackground(Color.black.opacity(0.3))
        }
        .scrollContentBackground(.hidden) // Makes form background transparent
    }
}
struct StatsTabView: View {
    @EnvironmentObject var session: SessionManager
    
    let columns = [GridItem(.flexible(), spacing: 15), GridItem(.flexible(), spacing: 15)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 15) {
                StatCardView(icon: "dollarsign.circle.fill", title: "Total Won", value: session.totalMoneyWon, color: .green)
                StatCardView(icon: "dice.fill", title: "Total Bets", value: session.betsPlaced, color: .cyan)
                StatCardView(icon: "hammer.fill", title: "Mines Bets", value: session.minesBets, color: .orange)
                StatCardView(icon: "building.columns.fill", title: "Towers Bets", value: session.towersBets, color: .red)
                StatCardView(icon: "number.square.fill", title: "Keno Bets", value: session.kenoBets, color: .blue)
                StatCardView(icon: "star.fill", title: "Gems", value: session.gems, color: .purple)
            }
            .padding()
        }
    }
}

struct HistoryTabView: View {
    @EnvironmentObject var session: SessionManager

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if session.gameHistory.isEmpty {
                    VStack {
                        Spacer()
                        Text("Play a game to see your history here.")
                            .font(.title3)
                            .foregroundColor(.gray)
                            .padding(.top, 50)
                        Spacer()
                    }
                } else {
                    ForEach(session.gameHistory) { entry in
                        GameHistoryRowView(entry: entry)
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Refactored Components

struct TopPayoutView: View {
    let amount: Int
    // Using the same tier logic from your original code.
    private var tier: WinTier {
        switch amount {
        case 0: return .none
        case 1..<1_000_000: return .gold
        case 1_000_000..<10_000_000: return .diamond
        case 10_000_000..<100_000_000: return .legendary
        default: return .mythic
        }
    }
    
    var body: some View {
        VStack(spacing: 10) {
            Text("Top Payout")
                .font(.title2).bold()
            
            HStack {
                Image(systemName: tier.icon)
                    .font(.largeTitle)
                    .foregroundColor(tier.shadowColor)
                
                AnimatedNumberView(value: amount)
                    .font(.system(size: 40, weight: .bold))
                
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.3), radius: 10)
    }
}

// Replace the old RecentGamesView with this one
struct RecentGamesView: View {
    let history: [GameHistoryEntry]

    var body: some View {
        VStack(alignment: .leading) {
            Text("Recent Activity")
                .font(.title2).bold()
                .padding(.bottom, 5)

            if history.isEmpty {
                Text("Play a game to see your history here.")
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, minHeight: 100)
                    .background(.black.opacity(0.2))
                    .cornerRadius(15)
            } else {
                // Show the last 3 games
                ForEach(history.prefix(3)) { entry in
                    GameHistoryRowView(entry: entry)
                }
            }
        }
    }
}

struct AchievementsView: View {
    var body: some View {
        VStack(alignment: .leading) {
            Text("Achievements")
                .font(.title2).bold()
                .padding(.bottom, 5)
                
            HStack {
                AchievementBadge(icon: "trophy.fill", color: .yellow, isUnlocked: true)
                AchievementBadge(icon: "flame.fill", color: .red, isUnlocked: true)
                AchievementBadge(icon: "crown.fill", color: .purple, isUnlocked: false)
                AchievementBadge(icon: "shield.lefthalf.filled", color: .blue, isUnlocked: false)
            }
        }
    }
}

struct AchievementBadge: View {
    let icon: String
    let color: Color
    let isUnlocked: Bool

    var body: some View {
        Image(systemName: icon)
            .font(.title)
            .padding()
            .background(isUnlocked ? color.opacity(0.3) : Color.black.opacity(0.3))
            .clipShape(Circle())
            .foregroundColor(isUnlocked ? color : .gray)
            .overlay(
                Circle()
                    .stroke(isUnlocked ? color : .gray, lineWidth: 2)
            )
            .opacity(isUnlocked ? 1.0 : 0.5)
    }
}

struct StatCardView: View {
    let icon: String
    let title: String
    let value: Int
    let color: Color

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundColor(color)
                .shadow(color: color.opacity(0.5), radius: 5)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
            
            AnimatedNumberView(value: value)
                .font(.title2).fontWeight(.bold)
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 150)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.3), radius: 8)
    }
}

// Animated Number Counter View
struct AnimatedNumberView: View {
    var value: Int
    @State private var animatedValue: Double = 0

    var body: some View {
        Text(formatNumber(Int(animatedValue)))
            .onAppear {
                withAnimation(.easeInOut(duration: 1.0)) {
                    animatedValue = Double(value)
                }
            }
            .onChange(of: value) { newValue in
                withAnimation(.easeInOut(duration: 1.0)) {
                    animatedValue = Double(newValue)
                }
            }
    }
}





// MARK: - Helper Functions & Preview

// Re-defining this here to make the file self-contained.
// In a real app, this would be in a shared helper file.


// Original WinTier enum to keep TopPayoutView working.
enum WinTier {
    case none, gold, diamond, legendary, mythic
    
    var icon: String {
        switch self {
        case .none: return "questionmark.diamond.fill"
        case .gold: return "trophy.fill"
        case .diamond: return "diamond.fill"
        case .legendary: return "crown.fill"
        case .mythic: return "flame.fill"
        }
    }
    
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

#Preview {
    let session = SessionManager()
    session.isLoggedIn = true
    session.username = "Kryska"
    session.money = 1_500_000
    session.level = 10
    session.gems = 150
    session.betsPlaced = 1243
    session.minesBets = 812
    session.totalMoneyWon = 1_250_000
    session.biggestWin = 15_000_000
    session.currentScreen = .profile
    
    return ContentView()
        .environmentObject(session)
}
