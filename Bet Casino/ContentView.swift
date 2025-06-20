import SwiftUI
import UIKit

struct ContentView: View {
    @State private var showMain = false
    @EnvironmentObject var session: SessionManager // Inject SessionManager

    var body: some View {
        ZStack {
            if showMain {
                // Wrap MainCasinoView in NavigationStack
                NavigationStack {
                    MainCasinoView()
                        .environmentObject(session) // Pass session to MainCasinoView
                }
                .transition(.opacity)
            } else {
                SplashScreen()
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            withAnimation(.easeOut(duration: 0.6)) {
                                showMain = true
                            }
                        }
                    }
            }
        }
    }
}

struct SplashScreen: View {
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0.0
    @State private var rotation: Double = 0.0

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black, Color.purple.opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            ).ignoresSafeArea()

            VStack(spacing: 12) {
                Text("BET CASINO")
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(colors: [.white, .purple.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .shadow(color: .purple.opacity(0.7), radius: 15, x: 0, y: 5)
                    .scaleEffect(scale)
                    .opacity(opacity)
                    .rotation3DEffect(.degrees(rotation), axis: (x: 0, y: 1, z: 0))

                Text("Powered by FakeCoin™")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .opacity(opacity * 0.8)
            }
            .onAppear {
                withAnimation(.easeOut(duration: 1.5)) {
                    scale = 1.0
                    opacity = 1.0
                }
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    rotation = 10
                }
            }
        }
    }
}

struct MainCasinoView: View {
    @EnvironmentObject var session: SessionManager // Receive SessionManager
    @State private var username: String = "User"
    @State private var money: Int = 0
    @State private var gems: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            TopUserBar(username: $username, money: $money, gems: $gems)
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    EliteBanner()
                    GameSection(title: "Trending Games", games: trendingGames)
                    GameSection(title: "Biggest Winners", games: biggestWinners)
                    GameSection(title: "Originals", games: originals)
                }
                .padding(.horizontal)
                .padding(.bottom, 40)
            }
            BottomNavBar()
        }
        .onAppear {
            loadUserData()
        }
        .background(
            LinearGradient(
                colors: [Color.black, Color(red: 35/255, green: 0, blue: 50/255).opacity(0.9)],
                startPoint: .top,
                endPoint: .bottom
            ).ignoresSafeArea()
        )
        .foregroundColor(.white)
    }

    func loadUserData() {
        let defaults = UserDefaults.standard
        let allKeys = defaults.dictionaryRepresentation().keys
        if let lastKey = allKeys.first(where: { $0.contains("@") }), // crude email match
           let data = defaults.dictionary(forKey: lastKey) as? [String: Any] {
            username = data["username"] as? String ?? "User"
            money = data["money"] as? Int ?? 0
            gems = data["gems"] as? Int ?? 0
        }
    }
}


struct TopUserBar: View {
    @Binding var username: String
    @Binding var money: Int
    @Binding var gems: Int

    var body: some View {
        HStack(alignment: .center) {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.purple.opacity(0.6))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Text(username.isEmpty ? "?" : String(username.prefix(1)).uppercased())
                            .font(.title2).bold().foregroundColor(.white)
                    )
                    .shadow(color: .purple.opacity(0.7), radius: 8, x: 0, y: 4)

                VStack(alignment: .leading, spacing: 6) {
                    Text(username).font(.headline).bold()
                    Text("Level 7").font(.footnote).bold().foregroundColor(.gray)
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.gray.opacity(0.3)).frame(height: 8)
                        Capsule().fill(Color.green).frame(width: 80, height: 8)
                            .shadow(color: .green.opacity(0.5), radius: 5)
                    }
                    .frame(width: 100)
                }
            }

            Spacer()

            HStack(spacing: 20) {
                CurrencyDisplay(value: money, icon: "bitcoinsign.circle.fill", color: .yellow)
                CurrencyDisplay(value: gems, icon: "diamond.fill", color: .cyan)

                Button {
                    vibrate()
                } label: {
                    Image(systemName: "bell.fill")
                        .font(.title3)
                        .padding(8)
                        .background(Circle().fill(.ultraThinMaterial))
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 3)
                }
            }
            .font(.subheadline)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.4))
        .shadow(color: .black.opacity(0.6), radius: 10, y: 5)
    }
}

struct CurrencyDisplay: View {
    let value: Int
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(color)
            Text("\(value)").fontWeight(.semibold)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(Capsule().fill(Color.black.opacity(0.3)))
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 2)
    }
}

struct EliteBanner: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(LinearGradient(colors: [Color.purple.opacity(0.7), Color.black.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ELITE SUBSCRIPTION")
                            .font(.title2)
                            .bold()
                            .foregroundStyle(
                                LinearGradient(colors: [.white, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                        Text("Unlock exclusive bonuses, faster XP, extra gems and VIP support.")
                            .font(.caption)
                            .opacity(0.9)
                    }
                    Spacer()
                    Image(systemName: "crown.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.yellow.opacity(0.8))
                        .shadow(color: .black.opacity(0.5), radius: 10)
                }
                .padding(20)
            )
            .frame(height: 120)
            .shadow(color: .purple.opacity(0.6), radius: 15, x: 0, y: 8)
    }
}

struct GameSection: View {
    let title: String
    let games: [Game]

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text(title).font(.title2).bold()
                .padding(.leading, 5)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 18) {
                    ForEach(games) { game in
                        if game.name == "Mines" {
                            NavigationLink(destination: MinesView().environmentObject(SessionManager())) { // Pass environment object
                                GameCard(game: game)
                            }
                            .buttonStyle(GameButtonStyle()) // Apply custom button style for vibration
                        } else {
                            Button {
                                vibrate() // Vibrate for all other game buttons
                                launchGame(name: game.name)
                            } label: {
                                GameCard(game: game)
                            }
                            .buttonStyle(GameButtonStyle()) // Apply custom button style for vibration
                        }
                    }
                }
            }
        }
    }

    func launchGame(name: String) {
        print("🎮 Launching game: \(name)")
    }
}

struct GameCard: View {
    let game: Game

    var body: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(game.color.opacity(0.2))
            .frame(width: 130, height: 110)
            .overlay(
                VStack(spacing: 8) {
                    Image(systemName: "gamecontroller.fill")
                        .font(.system(size: 36))
                    Text(game.name)
                        .font(.headline).bold()
                }
                .foregroundColor(game.color)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(game.color.opacity(0.5), lineWidth: 1)
            )
            .shadow(color: game.color.opacity(0.7), radius: 8, x: 0, y: 4)
    }
}

// Custom ButtonStyle to apply vibration and subtle press effect
struct GameButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label // Corrected from configuration.content
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}


struct BottomNavBar: View {
    var body: some View {
        HStack {
            NavItem(title: "Home", icon: "house.fill", isSelected: true)
            NavItem(title: "My Bets", icon: "clock.arrow.circlepath")
            NavItem(title: "Elite", icon: "crown.fill")
            NavItem(title: "Shop", icon: "bag.fill")
        }
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.7))
        .shadow(color: .black.opacity(0.8), radius: 15, y: -8)
    }
}

struct NavItem: View {
    let title: String
    let icon: String
    var isSelected: Bool = false

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(isSelected ? .purple : .white.opacity(0.7))
            Text(title).font(.caption)
                .foregroundColor(isSelected ? .purple : .white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }
}

struct Game: Identifiable {
    let id = UUID()
    let name: String
    let color: Color
}

let trendingGames: [Game] = [
    Game(name: "Mines", color: .green),
    Game(name: "Plinko", color: .pink),
]

let biggestWinners: [Game] = [
    Game(name: "Crash", color: .yellow),
]

let originals: [Game] = [
    Game(name: "Blackjack", color: .cyan)
]

func vibrate() {
    let impact = UIImpactFeedbackGenerator(style: .light)
    impact.impactOccurred()
}

#Preview {
    ContentView()
        .environmentObject(SessionManager()) // Provide SessionManager for preview
}
    