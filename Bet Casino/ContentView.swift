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
                    case .keno: // Add this case
                        KenoView(session: session)
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
    @State private var selectedCategory = "Originals"
    
    let categories = ["Originals", "New", "Popular"]
    var allGames: [Game] {
        (originals + trendingGames + biggestWinners).filter {
            searchText.isEmpty ? true : $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var filteredGames: [Game] {
        switch selectedCategory {
        case "New":
            return allGames.filter { $0.isNew }
        case "Popular":
            return allGames.filter { $0.isHot }
        case "Originals":
            // Assuming 'originals' is the source array for this category
            return originals.filter {
                searchText.isEmpty ? true : $0.name.localizedCaseInsensitiveContains(searchText)
            }
        default:
            return allGames
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                // Header remains the same
                VStack(spacing: 18) {
                    

                    SearchBar(text: $searchText)
                }
                .padding(.top, 10)
                .padding(.horizontal)

                EliteBanner()
                
                // Add the category chooser here
                CategoryFilterChips(categories: categories, selection: $selectedCategory)

                // Replace the VStack of GameSections with a single section
                if !filteredGames.isEmpty {
                    GameSection(title: selectedCategory, games: filteredGames)
                } else {
                    Text("No games found for '\(searchText)'")
                        .foregroundColor(.gray)
                        .padding()
                }
            }
            .padding(.bottom, 60)
        }
        .background(
            LinearGradient(colors: [Color.black, Color(red: 30/255, green: 0, blue: 50/255)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
    }
}

struct CategoryFilterChips: View {
    let categories: [String]
    @Binding var selection: String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(categories, id: \.self) { category in
                    Button(action: {
                        withAnimation {
                            selection = category
                        }
                    }) {
                        Text(category)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(selection == category ? Color.purple : Color.black.opacity(0.3))
                            .foregroundColor(.white)
                            .cornerRadius(20)
                    }
                }
            }
            .padding(.horizontal)
        }
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
    
    // --- NEW: A state variable to track the currently visible card ---
    @State private var currentIndex: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text(title)
                .font(.title2)
                .bold()
                .padding(.horizontal)
                .foregroundStyle(LinearGradient(colors: [.white, .purple], startPoint: .leading, endPoint: .trailing))

            // --- EDIT: The TabView is now wrapped in a VStack with the indicator ---
            VStack {
                // The TabView now updates the currentIndex when you swipe
                TabView(selection: $currentIndex) {
                    ForEach(games.indices, id: \.self) { index in
                        let game = games[index]
                        Button {
                            withAnimation {
                                if game.name == "Mines" {
                                    session.currentScreen = .mines
                                } else if game.name == "Towers" {
                                    session.currentScreen = .towers
                                } else if game.name == "Keno" {
                                    session.currentScreen = .keno
                                }
                            }
                        } label: {
                            GameCard(game: game)
                        }
                        .padding(.horizontal)
                        .tag(index) // Tag each view with its index
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .frame(height: 320)
                
                // --- NEW: This is the scroll indicator ---
                HStack(spacing: 8) {
                    ForEach(games.indices, id: \.self) { index in
                        Circle()
                            .fill(currentIndex == index ? Color.purple : Color.gray.opacity(0.5))
                            .frame(width: 8, height: 8)
                            .scaleEffect(currentIndex == index ? 1.2 : 1.0)
                            .animation(.spring(), value: currentIndex)
                    }
                }
                .padding(.top, 8) // Add some space above the dots
            }
        }
    }
}

struct GameCard: View {
    let game: Game
    @State private var hasAppeared = false

    var body: some View {
        // The ZStack now only contains the overlay content.
        ZStack(alignment: .bottomLeading) {
            // Gradient for text readability
            LinearGradient(colors: [.black.opacity(0.0), .black.opacity(0.8)], startPoint: .center, endPoint: .bottom)
                .zIndex(1) // Ensure gradient is on top of the background

            // Text content
            VStack(alignment: .leading, spacing: 6) {
                Spacer()
                Image(systemName: game.icon)
                    .font(.title)
                    .foregroundColor(game.color)
                    .shadow(radius: 5)

                Text(game.name)
                    .font(.title2)
                    .fontWeight(.bold)

                Text(game.subtitle)
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(20)
            .zIndex(2) // Ensure text is on top of the gradient
        }
        // The background is now applied here, outside the main content ZStack.
        // This is the key to fixing the scaling issue.
        .background(
            ZStack {
                if UIImage(named: game.imageName) != nil {
                    Image(game.imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fill) // The image fills the background space
                } else {
                    LinearGradient(colors: [game.color.opacity(0.8), .black], startPoint: .topLeading, endPoint: .bottomTrailing)
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 20)) // Clip the background to the card shape
        .shadow(color: .black.opacity(0.4), radius: 8, y: 5)
        .scaleEffect(hasAppeared ? 1 : 0.95)
        .opacity(hasAppeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
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
    @State private var glow = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(LinearGradient(colors: [Color.purple, Color.blue.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .shadow(color: glow ? .purple.opacity(0.6) : .clear, radius: 20)
                .onAppear {
                    withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                        glow.toggle()
                    }
                }

            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("ELITE PASS")
                        .font(.title2).bold()
                        .foregroundStyle(.white)
                        .scaleEffect(glow ? 1.05 : 1.0)
                        .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: glow)
                    Text("Unlock exclusive bonuses, VIP support, and more.")
                        .font(.caption).foregroundColor(.white.opacity(0.9))
                }
                Spacer()
                Image(systemName: "crown.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.yellow)
                    .rotationEffect(.degrees(glow ? 10 : -10))
                    .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: glow)
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
    let imageName: String
    let icon: String
    // Add these two properties
    var isNew: Bool = false
    var isHot: Bool = false
}

let trendingGames: [Game] = [
    Game(name: "Mines", subtitle: "Uncover the gems", color: .purple, imageName: "mines_card_bg", icon: "hammer.fill", isNew: true, isHot: false),
]
let biggestWinners: [Game] = []

let originals: [Game] = [
    Game(name: "Towers", subtitle: "Climb to the top", color: .red, imageName: "towers_card_bg", icon: "building.columns.fill", isNew: false, isHot: true),
    Game(name: "Keno", subtitle: "Pick your numbers", color: .blue, imageName: "keno_card_bg", icon: "number.square.fill", isNew: false, isHot: false),
    Game(name: "Mines", subtitle: "Uncover the gems", color: .purple, imageName: "mines_card_bg", icon: "hammer.fill", isNew: true, isHot: false),
    
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
