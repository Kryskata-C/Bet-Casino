import SwiftUI
import UIKit

struct ContentView: View {
    @State private var showMain = false

    var body: some View {
        ZStack {
            if showMain {
                MainCasinoView()
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

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black, Color.purple.opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            ).ignoresSafeArea()

            VStack(spacing: 12) {
                Text("BET CASINO")
                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(colors: [.white, .purple.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .shadow(color: .purple.opacity(0.7), radius: 12)
                    .scaleEffect(scale)
                    .opacity(opacity)

                Text("Powered by FakeCoin™")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                    .opacity(opacity * 0.8)
            }
            .onAppear {
                withAnimation(.easeOut(duration: 1.5)) {
                    scale = 1.0
                    opacity = 1.0
                }
            }
        }
    }
}

struct MainCasinoView: View {
    @State private var username = "User"
    @State private var money = 0
    @State private var gems = 0

    var body: some View {
        VStack(spacing: 0) {
            TopUserBar(username: username, money: money, gems: gems)
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
                colors: [Color.black, Color(red: 35/255, green: 0, blue: 50/255)],
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
    @AppStorage("username") var username: String = ""
    @AppStorage("money") var money: Int = 0
    @AppStorage("gems") var gems: Int = 0

    var body: some View {
        HStack(alignment: .center) {
            HStack(spacing: 10) {
                Circle()
                    .fill(.gray.opacity(0.5))
                    .frame(width: 48, height: 48)
                    .overlay(Text(username.isEmpty ? "?" : String(username.prefix(1))).font(.title2).bold().foregroundColor(.white))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Level 7").font(.footnote).bold()
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.gray.opacity(0.3)).frame(height: 6)
                        Capsule().fill(Color.green).frame(width: 60, height: 6)
                    }
                }
            }

            Spacer()

            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Image(systemName: "bitcoinsign.circle.fill")
                    Text("\(money)")
                }

                HStack(spacing: 4) {
                    Image(systemName: "diamond.fill")
                    Text("\(gems)")
                }

                Button {
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                } label: {
                    Image(systemName: "bell.fill")
                        .padding(6)
                        .background(Circle().fill(.ultraThinMaterial))
                }
            }
            .font(.footnote)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.black.opacity(0.3))
    }
}

struct EliteBanner: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(LinearGradient(colors: [.purple, .black], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(
                VStack(alignment: .leading, spacing: 6) {
                    Text("Elite Subscription")
                        .font(.headline)
                        .bold()
                    Text("Unlock exclusive bonuses, faster XP, extra gems and VIP support.")
                        .font(.footnote)
                        .opacity(0.85)
                }
                .padding()
            )
            .frame(height: 100)
    }
}

struct GameSection: View {
    let title: String
    let games: [Game]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline).bold()
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(games) { game in
                        Button {
                            launchGame(name: game.name)
                        } label: {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(game.color.opacity(0.15))
                                .frame(width: 120, height: 100)
                                .overlay(
                                    VStack {
                                        Image(systemName: "gamecontroller.fill")
                                            .font(.title2)
                                        Text(game.name)
                                            .font(.subheadline).bold()
                                    }
                                    .foregroundColor(game.color)
                                )
                                .shadow(color: game.color.opacity(0.6), radius: 6, x: 0, y: 3)
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


struct BottomNavBar: View {
    var body: some View {
        HStack {
            NavItem(title: "Home", icon: "house.fill")
            NavItem(title: "My Bets", icon: "clock.arrow.circlepath")
            NavItem(title: "Elite", icon: "crown.fill")
            NavItem(title: "Shop", icon: "bag.fill")
        }
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.6))
        .shadow(color: .black.opacity(0.8), radius: 10, y: -4)
    }
}

struct NavItem: View {
    let title: String
    let icon: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
            Text(title).font(.caption2)
        }
        .frame(maxWidth: .infinity)
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
}
