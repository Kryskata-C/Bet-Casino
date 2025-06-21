import UIKit
import SwiftUI

// The duplicate 'Screen' enum has been REMOVED from this file.
// It should only be defined in SessionManager.swift

struct ContentView: View {
    @EnvironmentObject var session: SessionManager

    var body: some View {
        MainCasinoView()
            .environmentObject(session)
    }
}

// MARK: - Main App Shell
struct MainCasinoView: View {
    @EnvironmentObject var session: SessionManager

    var body: some View {
        ZStack {
            // A more dynamic background
            RadialGradient(gradient: Gradient(colors: [Color(red: 35/255, green: 0, blue: 70/255), .black]), center: .top, startRadius: 5, endRadius: 800)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                TopUserBar(username: $session.username, money: $session.money, gems: $session.gems, level: $session.level)

                ZStack {
                    switch session.currentScreen {
                    case .home:
                        HomeView()
                            .transition(.asymmetric(insertion: .opacity, removal: .opacity))
                    case .mines:
                        MinesView(session: session)
                    case .towers: // This case is for the new Towers game
                        TowersView(session: session)
                    case .profile:
                        ProfileView()
                           .transition(.asymmetric(insertion: .opacity, removal: .opacity))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                BottomNavBar(currentScreen: $session.currentScreen)
            }
            
            // --- UNIVERSAL LEVEL UP ANIMATION OVERLAY ---
            if session.showLevelUpAnimation {
                LevelUpAnimationView()
                    .environmentObject(session)
            }
        }
        .ignoresSafeArea()
        .foregroundColor(.white)
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }
}


// MARK: - Home View Redesign
struct HomeView: View {
    @State private var searchText = ""

    var filteredTrendingGames: [Game] {
        searchText.isEmpty ? trendingGames : trendingGames.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var filteredOriginals: [Game] {
        searchText.isEmpty ? originals : originals.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var filteredBiggestWinners: [Game] {
        searchText.isEmpty ? biggestWinners : biggestWinners.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 36) {
                VStack(spacing: 18) {
                    Text("Welcome Back")
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundStyle(LinearGradient(colors: [.white, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))

                    SearchBar(text: $searchText)
                }
                .padding(.top, 50)
                .padding(.horizontal)

                CarouselPromo()

                EliteBanner()

                VStack(spacing: 40) {
                    if !filteredTrendingGames.isEmpty {
                        GameSection(title: "Trending Now", games: filteredTrendingGames)
                    }
                    if !filteredOriginals.isEmpty {
                        GameSection(title: "Casino Originals", games: filteredOriginals)
                    }
                    if !filteredBiggestWinners.isEmpty {
                        GameSection(title: "Biggest Winners", games: filteredBiggestWinners)
                    }
                }
                .padding(.bottom, 60)
            }
        }
        .background(
            LinearGradient(colors: [Color.black, Color(red: 30/255, green: 0, blue: 50/255)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
    }
}

struct CarouselPromo: View {
    let promos = ["promo1", "promo2", "promo3"]

    var body: some View {
        TabView {
            ForEach(promos, id: \.self) { promo in
                RoundedRectangle(cornerRadius: 20)
                    .fill(LinearGradient(colors: [.purple, .black], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(Text("Limited Offer").font(.title2).bold().padding(), alignment: .bottomLeading)
                    .padding(.horizontal, 20)
            }
        }
        .frame(height: 160)
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
    }
}

// MARK: - Game Section and Cards Redesign
struct GameSection: View {
    let title: String
    let games: [Game]
    @EnvironmentObject var session: SessionManager

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text(title)
                .font(.title2)
                .bold()
                .padding(.horizontal)
                .foregroundStyle(LinearGradient(colors: [.white, .purple], startPoint: .leading, endPoint: .trailing))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(games) { game in
                        Button {
                            withAnimation {
                                if game.name == "Mines" {
                                    session.currentScreen = .mines
                                } else if game.name == "Towers" { // Navigation to Towers
                                    session.currentScreen = .towers
                                }
                            }
                        } label: {
                            GameCard(game: game)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

struct GameCard: View {
    let game: Game
    @State private var hasAppeared = false

    var body: some View {
        ZStack {
            if UIImage(named: game.imageName) != nil {
                Image(game.imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 170, height: 230)
                    .clipped()
            } else {
                LinearGradient(colors: [game.color.opacity(0.8), .black], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .frame(width: 170, height: 230)
            }

            LinearGradient(colors: [Color.black.opacity(0.0), Color.black.opacity(0.6)], startPoint: .top, endPoint: .bottom)

            VStack(alignment: .leading, spacing: 6) {
                Spacer()
                Image(systemName: game.icon)
                    .font(.title2)
                    .foregroundColor(game.color)

                Text(game.name)
                    .font(.headline)
                    .bold()

                Text(game.subtitle)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.75))
            }
            .padding(12)
            .frame(width: 170, height: 230, alignment: .bottomLeading)
        }
        .background(Color.black.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 4)
        .scaleEffect(hasAppeared ? 1 : 0.95)
        .opacity(hasAppeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                hasAppeared = true
            }
        }
    }
}


// MARK: - Top User Bar Redesign
struct TopUserBar: View {
    @EnvironmentObject var session: SessionManager
    @Binding var username: String
    @Binding var money: Int
    @Binding var gems: Int
    @Binding var level: Int

    var body: some View {
        HStack(alignment: .center) {
            Button(action: {
                withAnimation {
                    session.currentScreen = .profile
                }
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(LinearGradient(colors: [.purple, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(username)
                            .font(.headline).bold()
                        Text("Level \(level)")
                            .font(.footnote).foregroundColor(.gray)
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer()

            HStack(spacing: 12) {
                CurrencyDisplay(value: money, icon: "bitcoinsign.circle.fill", color: .yellow)
                CurrencyDisplay(value: gems, icon: "diamond.fill", color: .cyan)
            }
        }
        .padding(.horizontal)
        .padding(.top, 45)
        .padding(.bottom, 10)
        .background(RadialGradient(gradient: Gradient(colors: [Color(red: 0/255, green: 0, blue: 0/255), .black]), center: .top, startRadius: 1, endRadius: 800))

    }
}

// MARK: - Bottom Nav Bar Redesign
struct BottomNavBar: View {
    @Binding var currentScreen: Screen
    
    var body: some View {
        HStack {
            NavItem(title: "Home", icon: "house.fill", isSelected: currentScreen == .home) {
                withAnimation { currentScreen = .home }
            }
            NavItem(title: "My Bets", icon: "clock.arrow.circlepath", isSelected: false) { /* Action */ }
            NavItem(title: "Shop", icon: "bag.fill", isSelected: false) { /* Action */ }
        }
        .padding()
        .cornerRadius(25)
        .padding(.horizontal)
        .padding(.bottom, 5) // Move it up slightly from the very bottom
    }
}

struct NavItem: View {
    let title: String
    let icon: String
    var isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.caption)
            }
            .foregroundColor(isSelected ? .purple : .white.opacity(0.7))
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - New and Helper Views
struct SplashScreen: View {
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0.0
    @State private var rotation: Double = 0.0
    
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.black, Color.purple.opacity(0.8)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            
            VStack(spacing: 12) {
                Text("BET CASINO")
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .foregroundStyle(LinearGradient(colors: [.white, .purple.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing))
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

struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            TextField("Search for a game...", text: $text)
        }
        .padding(12)
        .background(Color.black.opacity(0.3))
        .cornerRadius(15)
    }
}

struct CurrencyDisplay: View {
    let value: Int; let icon: String; let color: Color
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon).foregroundColor(color)
            Text(formatNumber(value))
                .fontWeight(.semibold)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.black.opacity(0.3))
        .cornerRadius(20)
    }
}

struct EliteBanner: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(LinearGradient(colors: [Color.purple, .blue.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .shadow(color: .purple.opacity(0.5), radius: 10)
            
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("ELITE PASS")
                        .font(.title2).bold()
                    Text("Unlock exclusive bonuses, VIP support, and more.")
                        .font(.caption).opacity(0.9)
                }
                Spacer()
                Image(systemName: "crown.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.yellow.opacity(0.9))
            }
            .padding(25)
        }
        .frame(height: 120)
        .padding(.horizontal)
    }
}

struct Game: Identifiable {
    let id = UUID()
    let name: String
    let subtitle: String
    let color: Color
    let imageName: String // Image for the card background
    let icon: String // Icon to display on the card
}

let trendingGames: [Game] = [
    Game(name: "Mines", subtitle: "Uncover the gems", color: .purple, imageName: "mines_card_bg", icon: "hammer.fill"),
]
let biggestWinners: [Game] = [
    
]
let originals: [Game] = [
    Game(name: "Towers", subtitle: "Climb to the top", color: .red, imageName: "towers_card_bg", icon: "building.columns.fill"),
]


func vibrate() { let impact = UIImpactFeedbackGenerator(style: .light); impact.impactOccurred() }

func formatNumber(_ num: Int) -> String {
    let number = Double(num)
    let billion = 1_000_000_000.0
    let million = 1_000_000.0
    let thousand = 1_000.0

    if number >= billion {
        return String(format: "%.1fB", number / billion).replacingOccurrences(of: ".0", with: "")
    }
    if number >= million {
        return String(format: "%.1fM", number / million).replacingOccurrences(of: ".0", with: "")
    }
    if number >= thousand {
        return String(format: "%.1fK", number / thousand).replacingOccurrences(of: ".0", with: "")
    }
    
    return "\(num)"
}

#Preview {
    let session = SessionManager()
    session.isLoggedIn = true
    return ContentView().environmentObject(session)
}
