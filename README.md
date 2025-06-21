# Bet Casino SwiftUI App

Welcome to the Bet Casino project! This is a modern casino-style game application built entirely with SwiftUI. It serves as an excellent example of a complex, state-driven SwiftUI application, featuring multiple games, a robust session and data management system, and a sleek, engaging user interface.

## Table of Contents
- [Project Overview](#project-overview)
- [Core Features](#core-features)
- [App Structure](#app-structure)
- [Core Components](#core-components)
  - [SessionManager](#sessionmanager)
  - [Authentication Flow](#authentication-flow)
  - [Profile & Leveling System](#profile--leveling-system)
- [Game Logic: In-Depth](#game-logic-in-depth)
  - [Mines](#-mines)
  - [Towers](#-towers)
- [How To Run](#how-to-run)


## Project Overview

Bet Casino is a single-player, simulated gambling app where users can play various games of chance to increase their virtual currency. The app features persistent user accounts, saved progress, and a dynamic leveling system to keep players engaged. It's built with a focus on modern SwiftUI principles, including state management with `ObservableObject`, dynamic views, and rich animations.

## Core Features

* **Local User Authentication**: A complete registration and login system that persists user data locally using `UserDefaults`. Includes support for email/password and Sign in with Apple.
* **Two Feature-Rich Games**:
    * **Mines**: A strategic grid game where players uncover tiles to find gems while avoiding mines.
    * **Towers**: A vertical progression game where players climb a tower, choosing safe spots at each level.
* **Advanced State Management**: Centralized session and user data management via the `SessionManager` class, injected as an `EnvironmentObject`.
* **Dynamic UI**: The UI is rich with animations, custom components, and views that dynamically adapt to the game state. This includes a custom flip animation for cards and tiles, particle effects, and shake animations for input errors.
* **Player Progression**: A leveling system based on total winnings and a profile page with detailed player statistics.
* **Sound Effects**: The Mines game includes a `SoundManager` to play sounds for different game events like tile flips, cashouts, and bomb explosions.

## App Structure

The project is organized logically, with views, view models, and managers separated into their own files.

* `Bet_CasinoApp.swift`: The main entry point of the app, which handles the initial view logic (Splash screen vs. Login/Content).
* `SessionManager.swift`: The brain of the app, managing all shared data and state.
* `ContentView.swift`: The main container view after login, which holds the navigation and switches between different game screens.
* `/Views`: Contains all major SwiftUI views (`LoginView`, `ProfileView`, etc.).
* `/ViewModels`: Contains the state and logic for complex views (`MinesViewModel`, `TowersViewModel`).
* `AuthComponents.swift`: Contains reusable UI components for the login and registration forms.
* `Assets.xcassets`: Stores all images, colors, and app icons.

## Core Components

### SessionManager

The `SessionManager` is the most critical component in the app. It's an `ObservableObject` that acts as a single source of truth for the application's state.

* **Data Persistence**: It handles loading and saving all user data to `UserDefaults`. User data is stored in a dictionary, keyed by a unique user identifier (either email or Apple User ID).
* **State Management**: It publishes properties like `@Published var isLoggedIn`, `@Published var currentScreen`, and all user stats (`username`, `money`, `level`, etc.). Changes to these properties automatically update any SwiftUI view that observes the session.
* **Auto-Login**: It remembers the last logged-in user and attempts to auto-login them when the app starts.
* **Leveling Logic**: It contains the function to calculate a user's level based on their total winnings and triggers the level-up animation overlay.

### Authentication Flow

Authentication is handled locally without a backend server.

1.  **Launch**: On first launch, the app shows a `SplashScreen`. On subsequent launches, it checks `UserDefaults` for a `lastUserIdentifier`.
2.  **Login**: `LoginView` allows users to sign in with an email/password or use Sign in with Apple. The credentials are validated against the data stored in `UserDefaults`.
3.  **Registration**: `RegisterView` allows new users to create an account. It performs validation (e.g., password matching, non-empty fields) and, on success, creates a new data dictionary in `UserDefaults` keyed by the user's email.
4.  **Session Start**: Upon successful login or registration, the `SessionManager`'s `loadUser` function is called, which populates all the `@Published` properties with the user's data and sets `isLoggedIn` to `true`, transitioning the user to the `ContentView`.

### Profile & Leveling System

The `ProfileView` provides a dashboard for player stats and accomplishments.

* **Dynamic Stats**: It directly displays stats from the `SessionManager`, such as total bets, total money won, etc..
* **Leveling Formula**: The player's level is not stored directly but is calculated in the `SessionManager` every time data is saved. This ensures the level is always up-to-date. The formula is:
    ```swift
    // From SessionManager.swift
    let baseXP = totalMoneyWon / 500_000.0
    let level = log10(baseXP + 1) * 20.0
    return min(100, Int(level.rounded())) 
    ```
    This logarithmic formula means that leveling up becomes progressively harder.
* **Win Tiers**: The `BiggestWinView` on the profile is highly dynamic. It categorizes the user's single biggest win into "Tiers" (e.g., Gold, Diamond, Legendary, Mythic) and changes its appearance, icon, and gradient accordingly.

---

## Game Logic: In-Depth

Here's a detailed breakdown of the logic for each game.

***

### 💣 Mines

The classic grid-based game of risk and reward. The objective is to uncover as many "gems" as possible without hitting a "bomb".

#### Game Flow

1.  **Setup**: The player sets a bet amount and the number of mines (1-24) on the 25-tile grid.
2.  **Start Game**: When "Place Bet" is clicked, the bet amount is deducted from the player's balance. A random set of bomb locations is generated, and the game state moves to `playing`.
3.  **Gameplay**: The player taps on tiles.
    * If the tile is a gem, it flips over, and the `currentMultiplier` increases. The player can choose to "Cashout" at any point to take their winnings.
    * If the tile is a bomb, the game ends immediately (`gameOver`), and the player loses their initial bet.
4.  **Win Condition**: The player wins by either cashing out before hitting a bomb or by successfully uncovering all non-bomb tiles on the grid.

#### Multiplier Calculation

The multiplier in Mines is complex, designed to be rewarding and fair. It's calculated in `MinesView.swift` and is a combination of three factors:

1.  **Base Multiplier**: This is based on the probability of *not* hitting a mine. The formula calculates the cumulative probability of each successful pick and takes the inverse, with a 2% house edge applied.
    > `calculatedMult *= (n - m - i) / (n - i)`
    > `base = (1 / calculatedMult) * 0.98`
    > Where `n` is total tiles (25), `m` is mine count, and `i` is the number of tiles already picked.

2.  **Mine Bonus**: A small bonus multiplier based on the density of mines on the board. More mines = higher risk = slightly higher reward.
    > `mineBonus = 1.0 + (mineCount / totalTiles) * 0.3`

3.  **Risk Factor**: A bonus that scales with how much of the player's total balance they are betting. This rewards high-stakes players.
    > `risk = min(1.0, betAmount / (sessionManager.money + betAmount))`
    > The final multiplier incorporates this risk with a 15% weight:
    > `finalMultiplier = base * mineBonus * (1 + risk * 0.15)`

#### Auto-Bet Mode

* Players can switch to an "Auto" mode, where they pre-select a pattern of tiles on the grid.
* The `startAutoBet` function runs a specified number of rounds, automatically playing the selected pattern for each round.
* It calculates winnings and losses automatically, tracking the total profit for the run and showing a summary at the end.

***

### 🗼 Towers

A game of vertical progression. The objective is to successfully climb an 8-story tower by picking a safe tile on each floor.

#### Game Flow

1.  **Setup**: The player sets a bet amount and chooses a risk level (Easy, Medium, Hard).
2.  **Start Game**: The bet is deducted, and the game starts at `currentRow = 0` (the bottom row).
3.  **Gameplay**: The player must select one tile from the current row.
    * If the tile is safe (a gem), the `currentRow` increments, and the multiplier increases. The player can now choose a tile from the next row up.
    * If the tile is a bomb, the game ends instantly, and the bet is lost.
4.  **Cashing Out**: The player can press the "Cashout" button at any point after successfully clearing at least one row to take their current winnings.

#### Risk Levels

The risk level, defined in `TowersViewModel.swift`, changes the grid layout:

* **Easy**: 3 columns, 1 bomb per row.
* **Medium**: 2 columns, 1 bomb per row.
* **Hard**: 3 columns, 2 bombs per row.

#### Multiplier Calculation

The multiplier in Towers compounds with each successfully cleared row. The formula for each row's potential multiplier is calculated when the grid is generated.

> `probability = Double(columns - bombs) / Double(columns)`
> `currentMultiplier *= (1.0 / probability) * 0.98`

This means the multiplier for each level is the multiplier of the level below it, times the inverse of the probability of picking a safe tile on the current level (again, with a 2% house edge applied). This creates an exponential growth in potential winnings as the player climbs higher.

## How To Run

1.  Clone the repository.
2.  Open the `Bet Casino.xcodeproj` file in Xcode.
3.  Select a target simulator or a connected physical device.
4.  Click the "Run" button (▶) in Xcode.

The app will build and launch on your selected device/simulator. You can create a new user or use the dev tools (long-press the header on the login screen) to manage data.
