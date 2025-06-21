import UIKit
import SwiftUI

enum Screen {
    case home
    case mines
}

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
            // Background Layer
            LinearGradient(colors: [Color.black, Color(red: 35/255, green: 0, blue: 50/255).opacity(0.9)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            // This VStack holds all UI elements.
            VStack(spacing: 0) {
                TopUserBar(username: $session.username, money: $session.money, gems: $session.gems)

                ZStack {
                    switch session.currentScreen {
                    case .home:
                        HomeView()
                    case .mines:
                        MinesView(session: session)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                BottomNavBar(currentScreen: $session.currentScreen)
            }
        }
        // This pushes the VStack to the edges of the screen.
        .ignoresSafeArea()
        .foregroundColor(.white)
        .ignoresSafeArea(.keyboard, edges: .bottom)
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
            
            VStack(spacing: 15) {
                ForEach(games) { game in
                    Button(action: {
                        withAnimation {
                            if game.name == "Mines" {
                                session.currentScreen = .mines
                            }
                        }
                    }) {
                        GameCard(game: game)
                    }
                }
            }
        }
    }
}

struct GameCard: View {
    let game: Game

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if game.name == "Mines" {
                Image("mines_card_bg")
                    .resizable()
                    .scaledToFill()
                    .frame(height: 150)
                    .clipped()

            } else {
                game.color.frame(height: 150)
            }

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

// MARK: - Final TopUserBar
struct TopUserBar: View {
    @Binding var username: String; @Binding var money: Int; @Binding var gems: Int
    var body: some View {
        HStack(alignment: .center) {
            HStack(spacing: 12) {
                Circle().fill(Color.purple.opacity(0.6)).frame(width: 50, height: 50).overlay(Text(username.isEmpty ? "?" : String(username.prefix(1)).uppercased()).font(.title2).bold().foregroundColor(.white))
                VStack(alignment: .leading, spacing: 6) {
                    // THE FIX for the wrapping name is here:
                    Text(username)
                        .font(.headline).bold()
                        .lineLimit(1) // Ensure it stays on one line
                        .minimumScaleFactor(0.8) // Allow font to shrink to 80% if needed
                    
                    Text("Level 7").font(.footnote).bold().foregroundColor(.gray)
                }
            }
            Spacer()
            HStack(spacing: 16) {
                CurrencyDisplay(value: money, icon: "bitcoinsign.circle.fill", color: .yellow)
                CurrencyDisplay(value: gems, icon: "diamond.fill", color: .cyan)
                Button { vibrate() } label: { Image(systemName: "bell.fill").font(.title3).padding(8).background(Circle().fill(Color.black.opacity(0.2))) }
            }
        }
        .padding(.horizontal)
        // Add top padding to move the content down from the status bar
        .padding(.top, 45)
        .padding(.bottom, 10)
        .background(.black)
    }
}

struct CurrencyDisplay: View {
    let value: Int; let icon: String; let color: Color
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon).foregroundColor(color)
            Text(formatNumber(value))
                .fontWeight(.semibold)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.black.opacity(0.3))
        .cornerRadius(20)
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

// MARK: - Final BottomNavBar
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
        }
        .padding(.top, 15)
        // Add bottom padding to move the content up from the home indicator
        .padding(.bottom, 30)
        .padding(.horizontal)
        .background(.black)
    }
}

struct NavItem: View {
    let title: String; let icon: String; var isSelected: Bool = false
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.title2).foregroundColor(isSelected ? .purple : .white.opacity(0.7))
            Text(title).font(.caption).foregroundColor(isSelected ? .purple : .white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }
}

struct Game: Identifiable {
    let id = UUID()
    let name: String
    let subtitle: String
    let color: Color
}

let trendingGames: [Game] = [ Game(name: "Mines", subtitle: "Uncover the gems", color: .purple), Game(name: "Plinko", subtitle: "Drop and win", color: .pink) ]
let biggestWinners: [Game] = [ Game(name: "Crash", subtitle: "Ride the multiplier", color: .yellow) ]
let originals: [Game] = [ Game(name: "Blackjack", subtitle: "Classic card game", color: .cyan), Game(name: "Slots", subtitle: "Spin the reels", color: .orange) ]

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

#Preview { ContentView().environmentObject(SessionManager()) }
