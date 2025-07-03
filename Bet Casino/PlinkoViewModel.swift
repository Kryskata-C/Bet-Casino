// Bet Casino/PlinkoViewModel.swift

import SwiftUI
import Combine

// MARK: - Helper Extensions for Physics
extension CGPoint {
    static func - (lhs: CGPoint, rhs: CGPoint) -> CGVector {
        return CGVector(dx: lhs.x - rhs.x, dy: lhs.y - rhs.y)
    }
}

extension CGVector {
    func normalized() -> CGVector {
        let length = hypot(self.dx, self.dy)
        guard length > 0 else { return .zero }
        return CGVector(dx: self.dx / length, dy: self.dy / length)
    }
    
    static func * (vector: CGVector, scalar: CGFloat) -> CGVector {
        return CGVector(dx: vector.dx * scalar, dy: vector.dy * scalar)
    }
}

// MARK: - Models and Enums
struct PlinkoBall: Identifiable {
    let id = UUID()
    var position: CGPoint // Normalized position (0 to 1)
    var velocity: CGVector = .zero
    let color: Color
    var lastCollidedPegID: Int? = nil // To prevent sticking to a peg
}

struct PlinkoPeg: Identifiable {
    let id: Int
    let position: CGPoint // Normalized position
}

enum PlinkoRiskLevel: String, CaseIterable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"

    func multipliers(for rows: Int) -> [Double] {
        switch self {
        case .low:
            switch rows {
            case 7: return [10, 2.5, 1, 0.5, 1, 2.5, 10]
            case 9: return [10, 2.5, 1, 0.5, 0.2, 0.5, 1, 2.5, 10]
            case 11: return [10, 2.5, 1, 0.5, 0.2, 0.2, 0.5, 1, 2.5, 10, 15]
            case 13: return [15, 10, 2.5, 1, 0.5, 0.2, 0.1, 0.2, 0.5, 1, 2.5, 10, 15]
            default: return Array(repeating: 0.1, count: rows + 1)
            }
        case .medium:
            switch rows {
            case 7: return [25, 5, 1.5, 0.5, 1.5, 5, 25]
            case 9: return [25, 5, 1.5, 0.5, 0.1, 0.5, 1.5, 5, 25]
            case 11: return [25, 10, 2, 1, 0.2, 0.1, 0.2, 1, 2, 10, 25]
            case 13: return [50, 25, 10, 2.5, 1, 0.2, 0.1, 0.2, 1, 2.5, 10, 25, 50]
            default: return Array(repeating: 0.1, count: rows + 1)
            }
        case .high:
            switch rows {
            case 7: return [100, 10, 2, 0.2, 2, 10, 100]
            case 9: return [100, 10, 2, 0.2, 0.1, 0.2, 2, 10, 100]
            case 11: return [150, 50, 10, 2.5, 0.2, 0.1, 0.2, 2.5, 10, 50, 150]
            case 13: return [200, 100, 25, 5, 1, 0.2, 0.1, 0.2, 1, 5, 25, 100, 200]
            default: return Array(repeating: 0.1, count: rows + 1)
            }
        }
    }

    private func scaleSymmetric(base: [Double], to count: Int) -> [Double] {
        var pattern = base + base.dropLast().reversed()
        while pattern.count < count {
            pattern.insert(base.last!, at: 0)
            pattern.append(base.last!)
        }
        if pattern.count > count {
            let extra = pattern.count - count
            let start = extra / 2
            pattern = Array(pattern[start..<(start + count)])
        }
        return Array(pattern.reversed())
    }




}

// MARK: - ViewModel
class PlinkoViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var balls: [PlinkoBall] = []
    @Published var betAmount: String = "1000"
    @Published var riskLevel: PlinkoRiskLevel = .medium {
        didSet {
            // Re-calculate peg positions if risk level changes board structure (future-proof)
            if oldValue != riskLevel {
                setupPegs()
            }
        }
    }
    @Published var isDropping: Bool = false
    
    // Stats
    @Published var lastWin: Double = 0
    @Published var totalProfit: Double = 0
    @Published var lastHitMultiplierIndex: Int?

    // MARK: - Internal Properties
    var sessionManager: SessionManager
    var boardSize: CGSize = .zero {
        didSet {
            if oldValue != boardSize {
                setupPegs()
            }
        }
    }
    @Published var pegRows: Int = 8 {
        didSet { setupPegs() }
    }

    
    private var pegs: [PlinkoPeg] = []
    private let restitution: CGFloat = 0.6 // Bounciness factor
    private var displayLink: CADisplayLink?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init and Deinit
    init(sessionManager: SessionManager) {
        self.sessionManager = sessionManager
    }

    deinit {
        stopDisplayLink()
    }
    
    private func setupPegs() {
        guard boardSize != .zero else { return }
        var newPegs: [PlinkoPeg] = []
        var pegID = 0
        
        let spacing = 1.0 / CGFloat(pegRows + 1)
        
        for row in 0..<pegRows {
            let pegCount = row + 2
            let yPos = (0.9 / CGFloat(pegRows)) * CGFloat(row)
            
            for peg in 0..<pegCount {
                let xPos = (1.0 - (CGFloat(pegCount - 1) * spacing)) / 2 + (CGFloat(peg) * spacing)
                newPegs.append(PlinkoPeg(id: pegID, position: CGPoint(x: xPos, y: yPos)))
                pegID += 1
            }
        }
        self.pegs = newPegs
    }

    // MARK: - Game Actions
    func dropBall() {
        guard let bet = Int(betAmount), bet > 0, sessionManager.money >= bet else { return }

        
        isDropping = true
        sessionManager.money -= bet
        sessionManager.plinkoBets += 1
        
        // Start the ball with a slight random horizontal offset for variety
        let randomOffset = CGFloat.random(in: -0.05...0.05)
        let newBall = PlinkoBall(
            position: CGPoint(x: 0.5 + randomOffset, y: 0),
            color: [.cyan, .purple, .green, .yellow].randomElement()!
        )
        balls.append(newBall)
        
        startDisplayLink()
    }

    // MARK: - Physics Simulation
    private func startDisplayLink() {
        if displayLink == nil {
            displayLink = CADisplayLink(target: self, selector: #selector(update))
            displayLink?.add(to: .main, forMode: .common)
        }
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func update() {
        guard !balls.isEmpty else {
            stopDisplayLink()
            isDropping = false
            return
        }

        for i in (0..<balls.count).reversed() {
            var ball = balls[i]
            
            ball.velocity.dy += 0.0008

            let ballRadius: CGFloat = 0.02
            if ball.position.x < ballRadius {
                ball.position.x = ballRadius
                ball.velocity.dx *= -restitution
            }
            if ball.position.x > 1 - ballRadius {
                ball.position.x = 1 - ballRadius
                ball.velocity.dx *= -restitution
            }

            ball.position.x += ball.velocity.dx
            ball.position.y += ball.velocity.dy
            ball.velocity.dx *= 0.99

            handlePegCollisions(for: &ball)

            if ball.position.y >= 0.95 {
                handleBallFinished(ball: ball, index: i)
                continue
            }

            balls[i] = ball
        }

    }
    
    private func handlePegCollisions(for ball: inout PlinkoBall) {
        let ballRadius: CGFloat = 0.025 // A slightly larger radius for more reliable collisions
        let pegRadius: CGFloat = 0.01
        let combinedRadius = ballRadius + pegRadius

        for peg in self.pegs {
            if ball.lastCollidedPegID == peg.id { continue }

            let distance = hypot(ball.position.x - peg.position.x, ball.position.y - peg.position.y)

            if distance < combinedRadius {
                // --- Realistic Collision Response ---
                let overlap = combinedRadius - distance
                let correctionVector = (ball.position - peg.position).normalized() * overlap
                ball.position.x += correctionVector.dx
                ball.position.y += correctionVector.dy

                let normal = (ball.position - peg.position).normalized()
                let dotProduct = (ball.velocity.dx * normal.dx) + (ball.velocity.dy * normal.dy)
                
                let reflectionVx = ball.velocity.dx - 2 * dotProduct * normal.dx
                let reflectionVy = ball.velocity.dy - 2 * dotProduct * normal.dy

                ball.velocity.dx = reflectionVx * restitution
                ball.velocity.dy = reflectionVy * restitution
                
                ball.lastCollidedPegID = peg.id
                return
            }
        }
        
        // Allow re-collision with a peg once the ball has moved away from it
        if let lastPegID = ball.lastCollidedPegID, let lastPeg = pegs.first(where: {$0.id == lastPegID}) {
            let dist = hypot(ball.position.x - lastPeg.position.x, ball.position.y - lastPeg.position.y)
            if dist > combinedRadius * 1.1 {
                 ball.lastCollidedPegID = nil
            }
        }
    }

    private func handleBallFinished(ball: PlinkoBall, index: Int) {
        let finalX = ball.position.x
        let multipliers = riskLevel.multipliers(for: pegRows)
        let bucketWidth = 1.0 / CGFloat(multipliers.count)

        var bucketIndex = Int(finalX / bucketWidth)
        bucketIndex = max(0, min(multipliers.count - 1, bucketIndex))

        let multiplier = multipliers[bucketIndex]
        let bet = Double(betAmount) ?? 0
        let winnings = bet * multiplier

        lastWin = winnings
        totalProfit += (winnings - bet)

        sessionManager.money += Int(winnings)
        sessionManager.totalMoneyWon += Int(winnings - bet)
        sessionManager.addGameHistory(gameName: "Plinko", profit: Int(winnings - bet), betAmount: Int(bet))
        sessionManager.saveData()

        withAnimation {
            lastHitMultiplierIndex = bucketIndex
        }

        balls.remove(at: index)
    }

}
