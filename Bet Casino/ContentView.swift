import UIKit
import SwiftUI

// This enum defines the main screens of the app for navigation.
// It should only be defined here to avoid errors.
enum Screen {
    case home
    case mines
    // Add other screens like .myBets, .elite, .shop here
}

struct ContentView: View {
    @State private var showMain = false
    @EnvironmentObject var session: SessionManager

    var body: some View {
        ZStack {
            if session.isLoggedIn {
                MainCasinoView()
                    .environmentObject(session)
            } else if showMain {
                 LoginView()
                    .environmentObject(session)
            } else {
                SplashScreen()
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            withAnimation(.easeOut(duration: 0.6)) {
                                self.showMain = true
                            }
                        }
                    }
            }
        }
    }
}

// MARK: - Main App Shell
struct MainCasinoView: View {
    @EnvironmentObject var session: SessionManager

    // The local @State variables for user data have been correctly removed.
    // The view now relies entirely on the SessionManager from the environment.

    var body: some View {
        VStack(spacing: 0) {
            // The TopUserBar is now correctly bound to the session's properties.
            TopUserBar(username: $session.username, money: $session.money, gems: $session.gems)

            ZStack {
                // The main content switches based on the session's currentScreen.
                switch session.currentScreen {
                case .home:
                    HomeView()
                        .transition(.opacity.animation(.easeOut))
                case .mines:
                    MinesView(session: session)
                        .transition(.opacity.animation(.easeOut))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            BottomNavBar(currentScreen: $session.currentScreen)
        }
        .background(
            LinearGradient(colors: [Color.black, Color(red: 35/255, green: 0, blue: 50/255).opacity(0.9)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
        .foregroundColor(.white)
    }
}


// HomeView contains the game selection list.
struct HomeView: View {
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                EliteBanner()
                GameSection(title: "Trending Games", games: trendingGames)
                GameSection(title: "Biggest Winners", games: biggestWinners)
                GameSection(title: "Originals", games: originals)
            }
            .padding(.vertical)
        }
    }
}

struct GameSection: View {
    let title: String
    let games: [Game]
    @EnvironmentObject var session: SessionManager

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text(title).font(.title2).bold().padding(.horizontal)
            
            // This now uses the full-width banner cards.
            VStack(spacing: 15) {
                ForEach(games) { game in
                    Button(action: {
                        withAnimation {
                            if game.name == "Mines" {
                                session.currentScreen = .mines
                            }
                            // Add logic for other games here
                        }
                    }) {
                        GameCard(game: game)
                    }
                }
            }
        }
    }
}


// MARK: - CORRECT GameCard (Full-width banner)
struct GameCard: View {
    let game: Game

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            game.color
                .brightness(-0.2) // Darken the color for better text contrast

            VStack(alignment: .leading, spacing: 4) {
                Text(game.name)
                    .font(.title).bold()
                Text(game.subtitle)
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding()
            .foregroundColor(.white)
        }
        .frame(height: 150)
        .cornerRadius(20)
        .padding(.horizontal)
    }
}

// ... Other subviews (SplashScreen, TopUserBar, etc.) are correct and included for completeness.

struct SplashScreen: View {
    @State private var scale: CGFloat = 0.8; @State private var opacity: Double = 0.0; @State private var rotation: Double = 0.0
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.black, Color.purple.opacity(0.8)],startPoint: .top,endPoint: .bottom).ignoresSafeArea()
            VStack(spacing: 12) {
                Text("BET CASINO").font(.system(size: 40, weight: .heavy, design: .rounded)).foregroundStyle(LinearGradient(colors: [.white, .purple.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)).shadow(color: .purple.opacity(0.7), radius: 15, x: 0, y: 5).scaleEffect(scale).opacity(opacity).rotation3DEffect(.degrees(rotation), axis: (x: 0, y: 1, z: 0))
                Text("Powered by FakeCoin™").font(.caption).foregroundColor(.white.opacity(0.7)).opacity(opacity * 0.8)
            }.onAppear {
                withAnimation(.easeOut(duration: 1.5)) { scale = 1.0; opacity = 1.0 }
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) { rotation = 10 }
            }
        }
    }
}

struct TopUserBar: View {
    @Binding var username: String; @Binding var money: Int; @Binding var gems: Int
    var body: some View {
        HStack(alignment: .center) {
            HStack(spacing: 12) {
                Circle().fill(Color.purple.opacity(0.6)).frame(width: 50, height: 50).overlay(Text(username.isEmpty ? "?" : String(username.prefix(1)).uppercased()).font(.title2).bold().foregroundColor(.white))
                VStack(alignment: .leading, spacing: 6) {
                    Text(username).font(.headline).bold(); Text("Level 7").font(.footnote).bold().foregroundColor(.gray)
                    ZStack(alignment: .leading) { Capsule().fill(Color.gray.opacity(0.3)).frame(height: 8); Capsule().fill(Color.green).frame(width: 80, height: 8) }.frame(width: 100)
                }
            }
            Spacer()
            HStack(spacing: 16) {
                CurrencyDisplay(value: money, icon: "bitcoinsign.circle.fill", color: .yellow)
                CurrencyDisplay(value: gems, icon: "diamond.fill", color: .cyan)
                Button { vibrate() } label: { Image(systemName: "bell.fill").font(.title3).padding(8).background(Circle().fill(Color.black.opacity(0.2))) }
            }
        }.padding().background(Color.black)
    }
}

struct CurrencyDisplay: View {
    let value: Int; let icon: String; let color: Color
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon).foregroundColor(color)
            Text(formatNumber(value)).fontWeight(.semibold).lineLimit(1).minimumScaleFactor(0.7)
        }.padding(.vertical, 8).padding(.horizontal, 12).background(Color.black.opacity(0.3)).cornerRadius(20)
    }
}

struct EliteBanner: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 20).fill(LinearGradient(colors: [Color.purple.opacity(0.7), Color.black.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)).overlay(HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text("ELITE SUBSCRIPTION").font(.title2).bold()
                Text("Unlock exclusive bonuses and VIP support.").font(.caption).opacity(0.9)
            }
            Spacer()
            Image(systemName: "crown.fill").font(.system(size: 60)).foregroundColor(.yellow.opacity(0.8))
        }.padding(20)).frame(height: 120).padding(.horizontal)
    }
}

struct BottomNavBar: View {
    @Binding var currentScreen: Screen
    var body: some View {
        HStack {
            Button(action: { withAnimation { currentScreen = .home } }) {
                NavItem(title: "Home", icon: "house.fill", isSelected: currentScreen == .home)
            }
            Button(action: { /* Set state for My Bets */ }) {
                 NavItem(title: "My Bets", icon: "clock.arrow.circlepath", isSelected: false)
            }
            Button(action: { /* Set state for Elite */ }) {
                 NavItem(title: "Elite", icon: "crown.fill", isSelected: false)
            }
             Button(action: { /* Set state for Shop */ }) {
                NavItem(title: "Shop", icon: "bag.fill", isSelected: false)
            }
        }.padding([.top, .horizontal]).padding(.bottom, 25).background(Color.black)
    }
}

struct NavItem: View {
    let title: String; let icon: String; var isSelected: Bool = false
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.title2).foregroundColor(isSelected ? .purple : .white.opacity(0.7))
            Text(title).font(.caption).foregroundColor(isSelected ? .purple : .white.opacity(0.7))
        }.frame(maxWidth: .infinity).padding(.vertical, 4)
    }
}

// Updated Game struct to include a subtitle
struct Game: Identifiable {
    let id = UUID()
    let name: String
    let subtitle: String // New property
    let color: Color
}

let trendingGames: [Game] = [ Game(name: "Mines", subtitle: "Uncover the gems", color: .purple), Game(name: "Plinko", subtitle: "Drop and win", color: .pink) ]
let biggestWinners: [Game] = [ Game(name: "Crash", subtitle: "Ride the multiplier", color: .yellow) ]
let originals: [Game] = [ Game(name: "Blackjack", subtitle: "Classic card game", color: .cyan), Game(name: "Slots", subtitle: "Spin the reels", color: .orange) ]

func vibrate() { let impact = UIImpactFeedbackGenerator(style: .light); impact.impactOccurred() }

func formatNumber(_ num: Int) -> String {
    let number = Double(num); let formatter = NumberFormatter(); formatter.numberStyle = .decimal; formatter.maximumFractionDigits = 1
    if number >= 1_000_000_000 { return (formatter.string(from: NSNumber(value: number / 1_000_000_000)) ?? "") + "B" }
    if number >= 1_000_000 { return (formatter.string(from: NSNumber(value: number / 1_000_000)) ?? "") + "M" }
    if number >= 1_000 { return (formatter.string(from: NSNumber(value: number / 1_000)) ?? "") + "K" }
    return "\(num)"
}

#Preview { ContentView().environmentObject(SessionManager()) }
