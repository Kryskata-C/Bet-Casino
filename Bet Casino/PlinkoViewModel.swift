// Bet Casino/PlinkoViewModel.swift

import SwiftUI
import Combine

struct DropData: Codable {
    let rowCount: Int
    let bucketIndex: Int
    let dropX: CGFloat
}


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
    @Published var pegRows: Int = 7 {
        didSet {
            setupPegs()
            riskLevel = riskLevel
        }
    }
    
    let recordedDrops: [DropData] = [
        DropData(rowCount: 7, bucketIndex: 4, dropX: 0.6575419934562925),
        DropData(rowCount: 7, bucketIndex: 3, dropX: 0.47668964666233904),
        DropData(rowCount: 7, bucketIndex: 2, dropX: 0.3493232067074431),
        DropData(rowCount: 7, bucketIndex: 1, dropX: 0.2129649829726786),
        DropData(rowCount: 7, bucketIndex: 5, dropX: 0.7465703087271541),
        DropData(rowCount: 7, bucketIndex: 5, dropX: 0.7144507123818282),
        DropData(rowCount: 7, bucketIndex: 0, dropX: 0.02641300604948732),
        DropData(rowCount: 7, bucketIndex: 5, dropX: 0.7203502629438671),
        DropData(rowCount: 7, bucketIndex: 4, dropX: 0.6698910045916702),
        DropData(rowCount: 7, bucketIndex: 3, dropX: 0.5358557736882021),
        DropData(rowCount: 7, bucketIndex: 6, dropX: 0.9600226506479844),
        DropData(rowCount: 7, bucketIndex: 3, dropX: 0.5199178440540861),
        DropData(rowCount: 7, bucketIndex: 2, dropX: 0.29362282563687353),
        DropData(rowCount: 7, bucketIndex: 2, dropX: 0.31913443956105075),
        DropData(rowCount: 7, bucketIndex: 6, dropX: 0.9660158505401629),
        DropData(rowCount: 7, bucketIndex: 6, dropX: 0.8731781446436307),
        DropData(rowCount: 7, bucketIndex: 2, dropX: 0.3940935620085475),
        DropData(rowCount: 7, bucketIndex: 5, dropX: 0.8298601461868997),
        DropData(rowCount: 7, bucketIndex: 2, dropX: 0.3449786191419718),
        DropData(rowCount: 7, bucketIndex: 2, dropX: 0.3385862907584678),
        DropData(rowCount: 7, bucketIndex: 1, dropX: 0.19832064466467042),
        DropData(rowCount: 7, bucketIndex: 4, dropX: 0.662786713685372),
        DropData(rowCount: 7, bucketIndex: 5, dropX: 0.7213862898639674),
        DropData(rowCount: 7, bucketIndex: 0, dropX: 0.03897898134520006),
        DropData(rowCount: 7, bucketIndex: 6, dropX: 0.9460028113208001),
        DropData(rowCount: 7, bucketIndex: 5, dropX: 0.8533634676748515),
        DropData(rowCount: 7, bucketIndex: 0, dropX: 0.09583636177261597),
        DropData(rowCount: 7, bucketIndex: 5, dropX: 0.7299405586071955),
        DropData(rowCount: 7, bucketIndex: 4, dropX: 0.6031447728574919),
        DropData(rowCount: 7, bucketIndex: 3, dropX: 0.4811116363740083),
        DropData(rowCount: 7, bucketIndex: 1, dropX: 0.17084272960636754),
        DropData(rowCount: 7, bucketIndex: 5, dropX: 0.8113547994859658),
        DropData(rowCount: 7, bucketIndex: 1, dropX: 0.19855157058030742),
        DropData(rowCount: 7, bucketIndex: 6, dropX: 0.8613933739036449),
        DropData(rowCount: 7, bucketIndex: 0, dropX: 0.07644475030902388),
        DropData(rowCount: 7, bucketIndex: 4, dropX: 0.6873409634538008),
        DropData(rowCount: 7, bucketIndex: 5, dropX: 0.7369011065373298),
        DropData(rowCount: 7, bucketIndex: 6, dropX: 0.895482225569795),
        DropData(rowCount: 7, bucketIndex: 3, dropX: 0.5231003340579884),
        DropData(rowCount: 9, bucketIndex: 4, dropX: 0.5534211083007153),
        DropData(rowCount: 9, bucketIndex: 6, dropX: 0.7643476805876158),
        DropData(rowCount: 9, bucketIndex: 3, dropX: 0.37960206746015784),
        DropData(rowCount: 9, bucketIndex: 2, dropX: 0.28418896510175734),
        DropData(rowCount: 9, bucketIndex: 5, dropX: 0.5945984608853305),
        DropData(rowCount: 9, bucketIndex: 3, dropX: 0.3389136612767682),
        DropData(rowCount: 9, bucketIndex: 8, dropX: 0.9408920368158682),
        DropData(rowCount: 9, bucketIndex: 4, dropX: 0.46808770094700863),
        DropData(rowCount: 9, bucketIndex: 0, dropX: 0.09761294301838436),
        DropData(rowCount: 9, bucketIndex: 8, dropX: 0.9254705302820225),
        DropData(rowCount: 9, bucketIndex: 4, dropX: 0.47453354608065523),
        DropData(rowCount: 9, bucketIndex: 7, dropX: 0.81222581641597),
        DropData(rowCount: 9, bucketIndex: 3, dropX: 0.3611679226437838),
        DropData(rowCount: 9, bucketIndex: 6, dropX: 0.7084855081884571),
        DropData(rowCount: 9, bucketIndex: 7, dropX: 0.8587258803261428),
        DropData(rowCount: 9, bucketIndex: 5, dropX: 0.5688985875176317),
        DropData(rowCount: 9, bucketIndex: 2, dropX: 0.29206050094685293),
        DropData(rowCount: 9, bucketIndex: 4, dropX: 0.48963623692935837),
        DropData(rowCount: 9, bucketIndex: 0, dropX: 0.055127210596569144),
        DropData(rowCount: 9, bucketIndex: 4, dropX: 0.44539792664018657),
        DropData(rowCount: 9, bucketIndex: 6, dropX: 0.7716549958843546),
        DropData(rowCount: 9, bucketIndex: 4, dropX: 0.44473913832166784),
        DropData(rowCount: 9, bucketIndex: 4, dropX: 0.5088262052762447),
        DropData(rowCount: 9, bucketIndex: 6, dropX: 0.6759595614800986),
        DropData(rowCount: 9, bucketIndex: 3, dropX: 0.36547244191771716),
        DropData(rowCount: 9, bucketIndex: 4, dropX: 0.5413622482000713),
        DropData(rowCount: 9, bucketIndex: 6, dropX: 0.722577196136638),
        DropData(rowCount: 9, bucketIndex: 6, dropX: 0.7378553042587072),
        DropData(rowCount: 9, bucketIndex: 1, dropX: 0.18140411478854185),
        DropData(rowCount: 9, bucketIndex: 2, dropX: 0.26450918513919197),
        DropData(rowCount: 9, bucketIndex: 7, dropX: 0.8004041270237202),
        DropData(rowCount: 9, bucketIndex: 6, dropX: 0.6669951947753179),
        DropData(rowCount: 9, bucketIndex: 3, dropX: 0.4372426156055984),
        DropData(rowCount: 9, bucketIndex: 1, dropX: 0.15048331993035943),
        DropData(rowCount: 9, bucketIndex: 6, dropX: 0.7267589426892918),
        DropData(rowCount: 9, bucketIndex: 0, dropX: 0.024318819938976884),
        DropData(rowCount: 9, bucketIndex: 3, dropX: 0.3498030561802748),
        DropData(rowCount: 9, bucketIndex: 2, dropX: 0.27117376408871374),
        DropData(rowCount: 9, bucketIndex: 6, dropX: 0.7304066801239599),
        DropData(rowCount: 9, bucketIndex: 2, dropX: 0.2596634277008224),
        DropData(rowCount: 9, bucketIndex: 3, dropX: 0.36792136416499904),
        DropData(rowCount: 9, bucketIndex: 2, dropX: 0.2770895950431665),
        DropData(rowCount: 9, bucketIndex: 2, dropX: 0.3214223772136554),
        DropData(rowCount: 9, bucketIndex: 3, dropX: 0.4376301882688445),
        DropData(rowCount: 9, bucketIndex: 1, dropX: 0.13111292923421586),
        DropData(rowCount: 9, bucketIndex: 4, dropX: 0.4675776376854222),
        DropData(rowCount: 9, bucketIndex: 5, dropX: 0.6441912418448099),
        DropData(rowCount: 9, bucketIndex: 3, dropX: 0.3688423329652605),
        DropData(rowCount: 9, bucketIndex: 4, dropX: 0.5407439240885132),
        DropData(rowCount: 9, bucketIndex: 6, dropX: 0.6862004537743306),
        DropData(rowCount: 9, bucketIndex: 4, dropX: 0.44756420984473044),
        DropData(rowCount: 9, bucketIndex: 0, dropX: 0.055216998242375845),
        DropData(rowCount: 9, bucketIndex: 2, dropX: 0.2406022560917272),
        DropData(rowCount: 9, bucketIndex: 5, dropX: 0.590731570096467),
        DropData(rowCount: 9, bucketIndex: 4, dropX: 0.4751398991622827),
        DropData(rowCount: 9, bucketIndex: 2, dropX: 0.273241023756766),
        DropData(rowCount: 9, bucketIndex: 6, dropX: 0.7361520818476488),
        DropData(rowCount: 9, bucketIndex: 2, dropX: 0.30323931272736027),
        DropData(rowCount: 9, bucketIndex: 6, dropX: 0.6704533364907266),
        DropData(rowCount: 9, bucketIndex: 3, dropX: 0.409835021574513),
        DropData(rowCount: 9, bucketIndex: 6, dropX: 0.6920149221858027),
        DropData(rowCount: 9, bucketIndex: 5, dropX: 0.6300883037028691),
        DropData(rowCount: 9, bucketIndex: 4, dropX: 0.47032431936022856),
        DropData(rowCount: 9, bucketIndex: 5, dropX: 0.6293987749532516),
        DropData(rowCount: 9, bucketIndex: 3, dropX: 0.4389950177345208),
        DropData(rowCount: 9, bucketIndex: 1, dropX: 0.16260648033627284),
        DropData(rowCount: 9, bucketIndex: 1, dropX: 0.16001651669369327),
        DropData(rowCount: 9, bucketIndex: 6, dropX: 0.7045970628836319),
        DropData(rowCount: 9, bucketIndex: 1, dropX: 0.14898068528869543),
        DropData(rowCount: 9, bucketIndex: 6, dropX: 0.7158253587783786),
        DropData(rowCount: 9, bucketIndex: 7, dropX: 0.8325831097939169),
        DropData(rowCount: 9, bucketIndex: 6, dropX: 0.7077433807876535),
        DropData(rowCount: 9, bucketIndex: 6, dropX: 0.744186600210211),
        DropData(rowCount: 9, bucketIndex: 5, dropX: 0.6118102981983705),
        DropData(rowCount: 9, bucketIndex: 4, dropX: 0.45661986028064383),
        DropData(rowCount: 9, bucketIndex: 2, dropX: 0.2765520074726024),
        DropData(rowCount: 9, bucketIndex: 3, dropX: 0.36889567134430323),
        DropData(rowCount: 9, bucketIndex: 3, dropX: 0.4125777049922406),
        DropData(rowCount: 9, bucketIndex: 2, dropX: 0.2618462985271253),
        DropData(rowCount: 9, bucketIndex: 2, dropX: 0.2734674035713916),
        DropData(rowCount: 9, bucketIndex: 7, dropX: 0.818727195466977),
        DropData(rowCount: 9, bucketIndex: 8, dropX: 0.8996386810352404),
        DropData(rowCount: 9, bucketIndex: 2, dropX: 0.2713000461850194),
        DropData(rowCount: 9, bucketIndex: 6, dropX: 0.7354489044493417),
        DropData(rowCount: 9, bucketIndex: 2, dropX: 0.22787309549454982),
        DropData(rowCount: 9, bucketIndex: 5, dropX: 0.6277590374733332),
        DropData(rowCount: 9, bucketIndex: 6, dropX: 0.672332281268029),
        DropData(rowCount: 9, bucketIndex: 6, dropX: 0.7759984265119826),
        DropData(rowCount: 9, bucketIndex: 3, dropX: 0.38698187512404436),
        DropData(rowCount: 9, bucketIndex: 2, dropX: 0.3217613197758558),
        DropData(rowCount: 9, bucketIndex: 0, dropX: 0.04213112049314808),
        DropData(rowCount: 9, bucketIndex: 6, dropX: 0.7417687097777216),
        DropData(rowCount: 9, bucketIndex: 3, dropX: 0.44383453620819974),
        DropData(rowCount: 9, bucketIndex: 5, dropX: 0.62913801254417),
        DropData(rowCount: 11, bucketIndex: 4, dropX: 0.40323778959824713),
        DropData(rowCount: 11, bucketIndex: 3, dropX: 0.3600990415614075),
        DropData(rowCount: 11, bucketIndex: 8, dropX: 0.7724113838037255),
        DropData(rowCount: 11, bucketIndex: 4, dropX: 0.4058205362104468),
        DropData(rowCount: 11, bucketIndex: 4, dropX: 0.4000680803090469),
        DropData(rowCount: 11, bucketIndex: 7, dropX: 0.6862074047247787),
        DropData(rowCount: 11, bucketIndex: 5, dropX: 0.5395414082501487),
        DropData(rowCount: 11, bucketIndex: 6, dropX: 0.5940871966490462),
        DropData(rowCount: 11, bucketIndex: 2, dropX: 0.2091376529358159),
        DropData(rowCount: 11, bucketIndex: 4, dropX: 0.43644849369456995),
        DropData(rowCount: 11, bucketIndex: 6, dropX: 0.6234436223539486),
        DropData(rowCount: 11, bucketIndex: 5, dropX: 0.5167640176468452),
        DropData(rowCount: 11, bucketIndex: 4, dropX: 0.4100995876517739),
        DropData(rowCount: 11, bucketIndex: 6, dropX: 0.6336625787849774),
        DropData(rowCount: 11, bucketIndex: 6, dropX: 0.5525679065459492),
        DropData(rowCount: 11, bucketIndex: 7, dropX: 0.6494199686079712),
        DropData(rowCount: 11, bucketIndex: 1, dropX: 0.17772778945050877),
        DropData(rowCount: 11, bucketIndex: 5, dropX: 0.5065665358340918),
        DropData(rowCount: 11, bucketIndex: 7, dropX: 0.6517755435498465),
        DropData(rowCount: 11, bucketIndex: 3, dropX: 0.34459153863898623),
        DropData(rowCount: 11, bucketIndex: 3, dropX: 0.3510115875341928),
        DropData(rowCount: 11, bucketIndex: 7, dropX: 0.7082038291383332),
        DropData(rowCount: 11, bucketIndex: 5, dropX: 0.46635355329936184),
        DropData(rowCount: 11, bucketIndex: 6, dropX: 0.5782923242297485),
        DropData(rowCount: 11, bucketIndex: 3, dropX: 0.29824379689472363),
        DropData(rowCount: 11, bucketIndex: 6, dropX: 0.6052152968404222),
        DropData(rowCount: 11, bucketIndex: 6, dropX: 0.5848780165239742),
        DropData(rowCount: 11, bucketIndex: 2, dropX: 0.2614006012482124),
        DropData(rowCount: 11, bucketIndex: 4, dropX: 0.4009337240895056),
        DropData(rowCount: 11, bucketIndex: 3, dropX: 0.28777494237105755),
        DropData(rowCount: 11, bucketIndex: 7, dropX: 0.6863205425928526),
        DropData(rowCount: 11, bucketIndex: 5, dropX: 0.49524889997683846),
        DropData(rowCount: 11, bucketIndex: 6, dropX: 0.5913929137599034),
        DropData(rowCount: 11, bucketIndex: 5, dropX: 0.5063635540721633),
        DropData(rowCount: 11, bucketIndex: 2, dropX: 0.20663804925448073),
        DropData(rowCount: 11, bucketIndex: 5, dropX: 0.4779885489789231),
        DropData(rowCount: 11, bucketIndex: 1, dropX: 0.1335765648124165),
        DropData(rowCount: 11, bucketIndex: 6, dropX: 0.5810564910628854),
        DropData(rowCount: 11, bucketIndex: 5, dropX: 0.48168427294455707),
        DropData(rowCount: 11, bucketIndex: 10, dropX: 0.9431429046598515),
        DropData(rowCount: 11, bucketIndex: 6, dropX: 0.5871269033809595),
        DropData(rowCount: 11, bucketIndex: 1, dropX: 0.1534527349545443),
        DropData(rowCount: 11, bucketIndex: 6, dropX: 0.548121629170459),
        DropData(rowCount: 11, bucketIndex: 6, dropX: 0.5929850290565186),
        DropData(rowCount: 11, bucketIndex: 5, dropX: 0.5304079839004465),
        DropData(rowCount: 11, bucketIndex: 4, dropX: 0.43337602139211556),
        DropData(rowCount: 11, bucketIndex: 7, dropX: 0.657841146402373),
        DropData(rowCount: 11, bucketIndex: 6, dropX: 0.5820014413022349),
        DropData(rowCount: 11, bucketIndex: 4, dropX: 0.3822108347043682),
        DropData(rowCount: 11, bucketIndex: 5, dropX: 0.48308845127049604),
        DropData(rowCount: 11, bucketIndex: 6, dropX: 0.6141238178483828),
        DropData(rowCount: 11, bucketIndex: 3, dropX: 0.3436554337072978),
        DropData(rowCount: 11, bucketIndex: 6, dropX: 0.6206685728484004),
        DropData(rowCount: 11, bucketIndex: 7, dropX: 0.6403843218295295),
        DropData(rowCount: 11, bucketIndex: 5, dropX: 0.48824145508952155),
        DropData(rowCount: 11, bucketIndex: 6, dropX: 0.592813741124833),
        DropData(rowCount: 11, bucketIndex: 4, dropX: 0.42238486064183006),
        DropData(rowCount: 11, bucketIndex: 8, dropX: 0.7610246287337002),
        DropData(rowCount: 11, bucketIndex: 5, dropX: 0.4798441665465984),
        DropData(rowCount: 11, bucketIndex: 5, dropX: 0.46699449011245864),
        DropData(rowCount: 11, bucketIndex: 5, dropX: 0.5267822407848987),
        DropData(rowCount: 11, bucketIndex: 5, dropX: 0.5333987739284493),
        DropData(rowCount: 11, bucketIndex: 6, dropX: 0.5634999787044764),
        DropData(rowCount: 11, bucketIndex: 6, dropX: 0.5521971630360032),
        DropData(rowCount: 11, bucketIndex: 3, dropX: 0.2960107208919619),
        DropData(rowCount: 11, bucketIndex: 3, dropX: 0.3260489086973929),
        DropData(rowCount: 11, bucketIndex: 4, dropX: 0.43867166830757837),
        DropData(rowCount: 11, bucketIndex: 4, dropX: 0.3927065090753267),
        DropData(rowCount: 11, bucketIndex: 4, dropX: 0.42133056952241943),
        DropData(rowCount: 11, bucketIndex: 5, dropX: 0.46995292450941006),
        DropData(rowCount: 11, bucketIndex: 6, dropX: 0.5901366493429356),
        DropData(rowCount: 11, bucketIndex: 5, dropX: 0.4817399285105798),
        DropData(rowCount: 11, bucketIndex: 6, dropX: 0.575715368226182),
        DropData(rowCount: 11, bucketIndex: 9, dropX: 0.8392963464861213),
        DropData(rowCount: 11, bucketIndex: 2, dropX: 0.2582497284186217),
        DropData(rowCount: 11, bucketIndex: 4, dropX: 0.45249045594022286),
        DropData(rowCount: 11, bucketIndex: 3, dropX: 0.29710662357018075),
        DropData(rowCount: 11, bucketIndex: 4, dropX: 0.4484168086963177),
        DropData(rowCount: 11, bucketIndex: 6, dropX: 0.6107909100410981),
        DropData(rowCount: 11, bucketIndex: 8, dropX: 0.7567493478109962),
        DropData(rowCount: 11, bucketIndex: 3, dropX: 0.32211635901472524),
        DropData(rowCount: 11, bucketIndex: 5, dropX: 0.5215343664601181),
        DropData(rowCount: 11, bucketIndex: 3, dropX: 0.2825401896205322),
        DropData(rowCount: 11, bucketIndex: 9, dropX: 0.86463934949699),
        DropData(rowCount: 11, bucketIndex: 7, dropX: 0.6744628970593493),
        DropData(rowCount: 11, bucketIndex: 4, dropX: 0.40168708588895324),
        DropData(rowCount: 11, bucketIndex: 10, dropX: 0.9250965353062498),
        DropData(rowCount: 11, bucketIndex: 3, dropX: 0.3516529286428892),
        DropData(rowCount: 11, bucketIndex: 4, dropX: 0.3963279919300693),
        DropData(rowCount: 11, bucketIndex: 6, dropX: 0.5614667377692526),
        DropData(rowCount: 11, bucketIndex: 4, dropX: 0.3885101684937504),
        DropData(rowCount: 11, bucketIndex: 10, dropX: 0.9503618095897876),
        DropData(rowCount: 11, bucketIndex: 9, dropX: 0.8487819845821678),
        DropData(rowCount: 11, bucketIndex: 4, dropX: 0.3826102077076941),
        DropData(rowCount: 11, bucketIndex: 3, dropX: 0.3402277895642009),
        DropData(rowCount: 11, bucketIndex: 3, dropX: 0.3428722812287367),
        DropData(rowCount: 11, bucketIndex: 8, dropX: 0.7388962825957098),
        DropData(rowCount: 11, bucketIndex: 5, dropX: 0.47867750313121477),
        DropData(rowCount: 11, bucketIndex: 8, dropX: 0.7881820776814702),
        DropData(rowCount: 11, bucketIndex: 4, dropX: 0.4538155056752087),
        DropData(rowCount: 11, bucketIndex: 5, dropX: 0.5058815659888857),
        DropData(rowCount: 11, bucketIndex: 7, dropX: 0.6505984755467714),
        DropData(rowCount: 11, bucketIndex: 6, dropX: 0.6310662729610141),
        DropData(rowCount: 11, bucketIndex: 4, dropX: 0.38784326170612105),
        DropData(rowCount: 11, bucketIndex: 7, dropX: 0.668250022497768),
        DropData(rowCount: 11, bucketIndex: 2, dropX: 0.2504100411550684),
        DropData(rowCount: 11, bucketIndex: 6, dropX: 0.6256786105023556),
        DropData(rowCount: 11, bucketIndex: 6, dropX: 0.6002485047147946),
        DropData(rowCount: 11, bucketIndex: 6, dropX: 0.6319383321700944),
        DropData(rowCount: 11, bucketIndex: 7, dropX: 0.6505758401466539),
        DropData(rowCount: 11, bucketIndex: 7, dropX: 0.6447865590218342),
        DropData(rowCount: 11, bucketIndex: 6, dropX: 0.6006063298566818),
        DropData(rowCount: 11, bucketIndex: 6, dropX: 0.5998238363128597),
        DropData(rowCount: 11, bucketIndex: 3, dropX: 0.2959721940769378),
        DropData(rowCount: 11, bucketIndex: 7, dropX: 0.705689864837741),
        DropData(rowCount: 11, bucketIndex: 3, dropX: 0.345000629922808),
        DropData(rowCount: 11, bucketIndex: 7, dropX: 0.6635929334683046),
        DropData(rowCount: 11, bucketIndex: 6, dropX: 0.6170954559621843),
        DropData(rowCount: 11, bucketIndex: 4, dropX: 0.4232275151856638),
        DropData(rowCount: 11, bucketIndex: 3, dropX: 0.3465552975193962),
        DropData(rowCount: 11, bucketIndex: 6, dropX: 0.628866600691054),
        DropData(rowCount: 11, bucketIndex: 5, dropX: 0.5121329628406261),
        DropData(rowCount: 11, bucketIndex: 5, dropX: 0.4971248010554355),
        DropData(rowCount: 11, bucketIndex: 4, dropX: 0.41672893205752837),
        DropData(rowCount: 11, bucketIndex: 7, dropX: 0.6771036728786508),
        DropData(rowCount: 11, bucketIndex: 5, dropX: 0.5328861035399264),
        DropData(rowCount: 11, bucketIndex: 4, dropX: 0.39334851201063176),
        DropData(rowCount: 11, bucketIndex: 2, dropX: 0.254131358052551),
        DropData(rowCount: 11, bucketIndex: 3, dropX: 0.3088007222287708),
        DropData(rowCount: 11, bucketIndex: 6, dropX: 0.6081795471095569),
        DropData(rowCount: 11, bucketIndex: 6, dropX: 0.5825925525630777),
        DropData(rowCount: 11, bucketIndex: 6, dropX: 0.603189449338103),
        DropData(rowCount: 11, bucketIndex: 6, dropX: 0.5979855031374767),
        DropData(rowCount: 11, bucketIndex: 6, dropX: 0.6339626495171325),
        DropData(rowCount: 11, bucketIndex: 4, dropX: 0.3940356382402206),
        DropData(rowCount: 11, bucketIndex: 4, dropX: 0.4468922360350845),
        DropData(rowCount: 11, bucketIndex: 6, dropX: 0.6128699645193668),
        DropData(rowCount: 11, bucketIndex: 2, dropX: 0.26270173831763827),
        DropData(rowCount: 11, bucketIndex: 5, dropX: 0.48350965819089253),
        DropData(rowCount: 11, bucketIndex: 4, dropX: 0.40900204571148424),
        DropData(rowCount: 11, bucketIndex: 1, dropX: 0.14159136256725985),
        DropData(rowCount: 11, bucketIndex: 6, dropX: 0.5580802871652055),
        DropData(rowCount: 11, bucketIndex: 3, dropX: 0.3292899316358544),
        DropData(rowCount: 11, bucketIndex: 7, dropX: 0.7017358259745313),
        DropData(rowCount: 11, bucketIndex: 5, dropX: 0.4625388640352288),
        DropData(rowCount: 11, bucketIndex: 6, dropX: 0.6240980364195072),
        DropData(rowCount: 11, bucketIndex: 8, dropX: 0.7789567549349008),
        DropData(rowCount: 11, bucketIndex: 5, dropX: 0.49515154156487146),
        DropData(rowCount: 11, bucketIndex: 5, dropX: 0.509660259709766),
        DropData(rowCount: 11, bucketIndex: 4, dropX: 0.38843885435814435),
        DropData(rowCount: 11, bucketIndex: 5, dropX: 0.46420894721130823),
        DropData(rowCount: 11, bucketIndex: 5, dropX: 0.49825103788785413),
        DropData(rowCount: 11, bucketIndex: 3, dropX: 0.34170445487566814),
        DropData(rowCount: 11, bucketIndex: 3, dropX: 0.28642450527997815),
        DropData(rowCount: 11, bucketIndex: 8, dropX: 0.7285661221488109),
        DropData(rowCount: 11, bucketIndex: 8, dropX: 0.7834226219043946),
        DropData(rowCount: 11, bucketIndex: 3, dropX: 0.32154069134699287),
        DropData(rowCount: 11, bucketIndex: 5, dropX: 0.52088703626516),
        DropData(rowCount: 11, bucketIndex: 4, dropX: 0.4510836285866814),
        DropData(rowCount: 11, bucketIndex: 6, dropX: 0.6084073779631067),
        DropData(rowCount: 11, bucketIndex: 8, dropX: 0.7450725613516737),
        DropData(rowCount: 11, bucketIndex: 7, dropX: 0.6468936691193637),
        DropData(rowCount: 11, bucketIndex: 3, dropX: 0.33982217052038),
        DropData(rowCount: 11, bucketIndex: 5, dropX: 0.5216107422127733),
        DropData(rowCount: 11, bucketIndex: 7, dropX: 0.6939778265107689),
        DropData(rowCount: 11, bucketIndex: 3, dropX: 0.35127273816954296),
        DropData(rowCount: 11, bucketIndex: 5, dropX: 0.4773686447803751),
        DropData(rowCount: 11, bucketIndex: 6, dropX: 0.5619955163176863),
        DropData(rowCount: 11, bucketIndex: 7, dropX: 0.701671501841733),
        DropData(rowCount: 11, bucketIndex: 4, dropX: 0.43127401560234657),
        DropData(rowCount: 11, bucketIndex: 3, dropX: 0.36115146591349945),
        DropData(rowCount: 11, bucketIndex: 7, dropX: 0.6842042284663712),
        DropData(rowCount: 11, bucketIndex: 7, dropX: 0.7026879963099828),
        DropData(rowCount: 11, bucketIndex: 3, dropX: 0.29668296570322017),
        DropData(rowCount: 11, bucketIndex: 5, dropX: 0.5054971010877908),
        DropData(rowCount: 11, bucketIndex: 7, dropX: 0.6559737472119509),
        DropData(rowCount: 11, bucketIndex: 6, dropX: 0.5549973331058962),
        DropData(rowCount: 11, bucketIndex: 6, dropX: 0.6260679252049145),
        DropData(rowCount: 11, bucketIndex: 5, dropX: 0.46125496780187286),
        DropData(rowCount: 11, bucketIndex: 4, dropX: 0.36694096807663884),
        DropData(rowCount: 11, bucketIndex: 7, dropX: 0.6519615788846645),
        DropData(rowCount: 11, bucketIndex: 5, dropX: 0.4835976957514934),
        DropData(rowCount: 11, bucketIndex: 7, dropX: 0.6920802462277086),
        DropData(rowCount: 11, bucketIndex: 7, dropX: 0.6606365997137309),
        DropData(rowCount: 11, bucketIndex: 2, dropX: 0.266957911424612),
        DropData(rowCount: 11, bucketIndex: 6, dropX: 0.6284208512896827),
        DropData(rowCount: 11, bucketIndex: 4, dropX: 0.3715256127295794),
        DropData(rowCount: 11, bucketIndex: 5, dropX: 0.46139075222206877),
        DropData(rowCount: 11, bucketIndex: 6, dropX: 0.6004520965735297),
        DropData(rowCount: 11, bucketIndex: 7, dropX: 0.6824573284285795),
        DropData(rowCount: 11, bucketIndex: 6, dropX: 0.5574181014128792),
        DropData(rowCount: 11, bucketIndex: 6, dropX: 0.6151153479243066),
        DropData(rowCount: 11, bucketIndex: 7, dropX: 0.6905807822799009),
        DropData(rowCount: 11, bucketIndex: 6, dropX: 0.5693166115029452),
        DropData(rowCount: 11, bucketIndex: 4, dropX: 0.36821452147752337),
        DropData(rowCount: 11, bucketIndex: 4, dropX: 0.43355559135101074),
        DropData(rowCount: 11, bucketIndex: 5, dropX: 0.4797233626118106),
        DropData(rowCount: 11, bucketIndex: 6, dropX: 0.5953638862150762),
        DropData(rowCount: 11, bucketIndex: 6, dropX: 0.6330373575114269),
        DropData(rowCount: 11, bucketIndex: 5, dropX: 0.5395975727292515),
        DropData(rowCount: 11, bucketIndex: 7, dropX: 0.6504697297848306),
        DropData(rowCount: 11, bucketIndex: 4, dropX: 0.420225844458788),
        DropData(rowCount: 11, bucketIndex: 5, dropX: 0.5106982484058395),
        DropData(rowCount: 11, bucketIndex: 5, dropX: 0.4775292088792852),
        DropData(rowCount: 11, bucketIndex: 4, dropX: 0.40192557165806875),
        DropData(rowCount: 11, bucketIndex: 7, dropX: 0.6941528565711695),
        DropData(rowCount: 11, bucketIndex: 3, dropX: 0.35459207116969477),
        DropData(rowCount: 11, bucketIndex: 7, dropX: 0.6450698026472846),
        DropData(rowCount: 11, bucketIndex: 9, dropX: 0.8296839834809776),
        DropData(rowCount: 11, bucketIndex: 6, dropX: 0.5919788960833958),
        DropData(rowCount: 11, bucketIndex: 2, dropX: 0.23588091876506034),
        DropData(rowCount: 11, bucketIndex: 6, dropX: 0.5589865485758377),
        DropData(rowCount: 11, bucketIndex: 5, dropX: 0.45684997406566924),
        DropData(rowCount: 11, bucketIndex: 6, dropX: 0.6078634324479247),
        DropData(rowCount: 11, bucketIndex: 5, dropX: 0.4552715584962502),
        DropData(rowCount: 11, bucketIndex: 3, dropX: 0.327678862723333),
        DropData(rowCount: 11, bucketIndex: 2, dropX: 0.23211976328751455),
        DropData(rowCount: 11, bucketIndex: 7, dropX: 0.7054283235941813),
        DropData(rowCount: 11, bucketIndex: 5, dropX: 0.46558048103614563),
        DropData(rowCount: 11, bucketIndex: 5, dropX: 0.46363358685228295),
        DropData(rowCount: 11, bucketIndex: 2, dropX: 0.20079436595452382),
        DropData(rowCount: 11, bucketIndex: 5, dropX: 0.47547067406247784),
        DropData(rowCount: 11, bucketIndex: 6, dropX: 0.618264845606366),
        DropData(rowCount: 11, bucketIndex: 7, dropX: 0.6533108044535623),
        DropData(rowCount: 11, bucketIndex: 5, dropX: 0.4857231929098478),
        DropData(rowCount: 11, bucketIndex: 8, dropX: 0.7439594362563564),
        DropData(rowCount: 11, bucketIndex: 4, dropX: 0.44166761902107055),
        DropData(rowCount: 11, bucketIndex: 8, dropX: 0.760047849731992),
        DropData(rowCount: 11, bucketIndex: 7, dropX: 0.6975425596169776),
        DropData(rowCount: 11, bucketIndex: 9, dropX: 0.8547647808873862),
        DropData(rowCount: 11, bucketIndex: 8, dropX: 0.789296896752284),
        DropData(rowCount: 11, bucketIndex: 1, dropX: 0.15869617389468985),
        DropData(rowCount: 11, bucketIndex: 2, dropX: 0.25027249248401545),
        DropData(rowCount: 11, bucketIndex: 7, dropX: 0.7056500069657922),
        DropData(rowCount: 11, bucketIndex: 6, dropX: 0.6232771231786219),
        DropData(rowCount: 11, bucketIndex: 3, dropX: 0.3454250942655335),
        DropData(rowCount: 11, bucketIndex: 6, dropX: 0.5749571437622453),
        DropData(rowCount: 11, bucketIndex: 5, dropX: 0.5375506178567516),
        DropData(rowCount: 11, bucketIndex: 9, dropX: 0.8483941671324461),
        DropData(rowCount: 11, bucketIndex: 5, dropX: 0.4560312060925324),
        DropData(rowCount: 11, bucketIndex: 4, dropX: 0.4093600423333443),
        DropData(rowCount: 11, bucketIndex: 9, dropX: 0.8663398517450074),
        DropData(rowCount: 11, bucketIndex: 3, dropX: 0.30400932838890754),
        DropData(rowCount: 11, bucketIndex: 4, dropX: 0.41337732076130146),
        DropData(rowCount: 11, bucketIndex: 4, dropX: 0.38883707692528263),
        DropData(rowCount: 11, bucketIndex: 3, dropX: 0.3147959162285906),
        DropData(rowCount: 11, bucketIndex: 4, dropX: 0.3976195111249076),
        DropData(rowCount: 11, bucketIndex: 5, dropX: 0.48379456063219983),
        DropData(rowCount: 11, bucketIndex: 3, dropX: 0.3327196908020734),
        DropData(rowCount: 11, bucketIndex: 9, dropX: 0.8660528113806332),
        DropData(rowCount: 11, bucketIndex: 5, dropX: 0.5036458630917218),
        DropData(rowCount: 11, bucketIndex: 2, dropX: 0.21050785344751244),
        DropData(rowCount: 11, bucketIndex: 5, dropX: 0.5120203735695862),
        DropData(rowCount: 11, bucketIndex: 2, dropX: 0.22701067508870915),
        DropData(rowCount: 11, bucketIndex: 6, dropX: 0.5705336245603632),
        DropData(rowCount: 11, bucketIndex: 3, dropX: 0.32786473550694745),
        DropData(rowCount: 11, bucketIndex: 4, dropX: 0.40414682079082903),
        DropData(rowCount: 11, bucketIndex: 7, dropX: 0.6410433315976941),
        DropData(rowCount: 11, bucketIndex: 7, dropX: 0.717774811098261),
        DropData(rowCount: 11, bucketIndex: 4, dropX: 0.4056348669473888),
        DropData(rowCount: 11, bucketIndex: 5, dropX: 0.5394949120393183),
        DropData(rowCount: 11, bucketIndex: 3, dropX: 0.32921077349988953),
        DropData(rowCount: 11, bucketIndex: 3, dropX: 0.29392454224185677),
        DropData(rowCount: 11, bucketIndex: 5, dropX: 0.47401891173964716),
        DropData(rowCount: 11, bucketIndex: 2, dropX: 0.25954906271791145),
        DropData(rowCount: 11, bucketIndex: 3, dropX: 0.31290035277134526),
        DropData(rowCount: 11, bucketIndex: 7, dropX: 0.6628334657653755),
        DropData(rowCount: 11, bucketIndex: 7, dropX: 0.6595254967466904),
        DropData(rowCount: 11, bucketIndex: 2, dropX: 0.24265376848645592),
        DropData(rowCount: 11, bucketIndex: 7, dropX: 0.6675210692025839),
        DropData(rowCount: 11, bucketIndex: 5, dropX: 0.456139770971008),
        DropData(rowCount: 11, bucketIndex: 3, dropX: 0.3262489220045195),
        DropData(rowCount: 11, bucketIndex: 7, dropX: 0.6430299585159692),
        DropData(rowCount: 11, bucketIndex: 7, dropX: 0.6645300237460104),
        DropData(rowCount: 11, bucketIndex: 5, dropX: 0.4820367563874123),
        DropData(rowCount: 11, bucketIndex: 3, dropX: 0.27600766071085664),
        DropData(rowCount: 11, bucketIndex: 7, dropX: 0.648684479117466),
        DropData(rowCount: 11, bucketIndex: 4, dropX: 0.41915855904791566),
        DropData(rowCount: 11, bucketIndex: 4, dropX: 0.3715256332933204),
        DropData(rowCount: 11, bucketIndex: 2, dropX: 0.25693727607536926),
        DropData(rowCount: 11, bucketIndex: 6, dropX: 0.6088270947343636),
        DropData(rowCount: 11, bucketIndex: 2, dropX: 0.19416922833916658),
        DropData(rowCount: 11, bucketIndex: 4, dropX: 0.44421023269328264),
        DropData(rowCount: 11, bucketIndex: 4, dropX: 0.3716632115196337),
        DropData(rowCount: 11, bucketIndex: 6, dropX: 0.6104208304210736),
        DropData(rowCount: 11, bucketIndex: 6, dropX: 0.557389348899261),
        DropData(rowCount: 11, bucketIndex: 8, dropX: 0.7531127489393898),
        DropData(rowCount: 11, bucketIndex: 4, dropX: 0.4462582768138421),
        DropData(rowCount: 11, bucketIndex: 4, dropX: 0.4399320220023495),
        DropData(rowCount: 11, bucketIndex: 3, dropX: 0.3451378167434834),
        DropData(rowCount: 11, bucketIndex: 4, dropX: 0.3833897434276413),
        DropData(rowCount: 11, bucketIndex: 5, dropX: 0.46148754021670507),
        DropData(rowCount: 11, bucketIndex: 5, dropX: 0.4555688824747788),
        DropData(rowCount: 11, bucketIndex: 6, dropX: 0.5913942947855969),
        DropData(rowCount: 11, bucketIndex: 1, dropX: 0.17382708562761645),
        DropData(rowCount: 11, bucketIndex: 5, dropX: 0.5212520334811708),
        DropData(rowCount: 11, bucketIndex: 4, dropX: 0.44653540675805053),
        DropData(rowCount: 11, bucketIndex: 7, dropX: 0.6687831092552363),
        DropData(rowCount: 11, bucketIndex: 6, dropX: 0.552078361800831),
        DropData(rowCount: 11, bucketIndex: 6, dropX: 0.5646074521346354),
        DropData(rowCount: 11, bucketIndex: 2, dropX: 0.21623591533576741),
        DropData(rowCount: 11, bucketIndex: 5, dropX: 0.5142623532084546),
        DropData(rowCount: 11, bucketIndex: 4, dropX: 0.4295120998212973),
        DropData(rowCount: 11, bucketIndex: 6, dropX: 0.5602088057913256),
        DropData(rowCount: 11, bucketIndex: 4, dropX: 0.3707438166657666),
        DropData(rowCount: 11, bucketIndex: 7, dropX: 0.6663461045369048),
        DropData(rowCount: 11, bucketIndex: 4, dropX: 0.39600253544555),
        DropData(rowCount: 11, bucketIndex: 3, dropX: 0.3143558898292724),
        DropData(rowCount: 11, bucketIndex: 6, dropX: 0.5595741194862867),
        DropData(rowCount: 11, bucketIndex: 6, dropX: 0.554479734788785),
        DropData(rowCount: 11, bucketIndex: 6, dropX: 0.5976761361563554),
        DropData(rowCount: 11, bucketIndex: 2, dropX: 0.2586010006121081),
        DropData(rowCount: 11, bucketIndex: 4, dropX: 0.4005660081635809),
        DropData(rowCount: 11, bucketIndex: 8, dropX: 0.7783562557259838),
        DropData(rowCount: 11, bucketIndex: 6, dropX: 0.5804832080659542),
        DropData(rowCount: 11, bucketIndex: 4, dropX: 0.3728443529831557),
        DropData(rowCount: 11, bucketIndex: 7, dropX: 0.6605593142799718),
        DropData(rowCount: 11, bucketIndex: 3, dropX: 0.29384837162530186),
        DropData(rowCount: 11, bucketIndex: 9, dropX: 0.8424952622383584),
        DropData(rowCount: 11, bucketIndex: 4, dropX: 0.40254034551075984),
        DropData(rowCount: 11, bucketIndex: 4, dropX: 0.4498851243161676),
        DropData(rowCount: 11, bucketIndex: 6, dropX: 0.568321988516331),
        DropData(rowCount: 11, bucketIndex: 5, dropX: 0.4576270571328412),
        DropData(rowCount: 11, bucketIndex: 6, dropX: 0.5791609180539083),
        DropData(rowCount: 11, bucketIndex: 7, dropX: 0.7116393272840374),
        DropData(rowCount: 11, bucketIndex: 5, dropX: 0.5248446252326594),
        DropData(rowCount: 11, bucketIndex: 5, dropX: 0.46196113156488877),
        DropData(rowCount: 11, bucketIndex: 8, dropX: 0.7394043340336269),
        DropData(rowCount: 11, bucketIndex: 7, dropX: 0.7071334393537269),
        DropData(rowCount: 11, bucketIndex: 4, dropX: 0.38837374467302466),
        DropData(rowCount: 11, bucketIndex: 2, dropX: 0.2537647765027013),
        DropData(rowCount: 11, bucketIndex: 3, dropX: 0.30661030198075595),
        DropData(rowCount: 11, bucketIndex: 5, dropX: 0.4642404639288801),
        DropData(rowCount: 11, bucketIndex: 3, dropX: 0.33468278476673646),
        DropData(rowCount: 11, bucketIndex: 4, dropX: 0.3719854182332987),
        DropData(rowCount: 11, bucketIndex: 6, dropX: 0.6242068336313668),
        DropData(rowCount: 11, bucketIndex: 6, dropX: 0.5649781435471048),
        DropData(rowCount: 11, bucketIndex: 3, dropX: 0.3466165613517629)
    ]
    func possibleDropPositions(forRow row: Int, bucketIndex: Int) -> [CGFloat] {
        recordedDrops
            .filter { $0.rowCount == row && $0.bucketIndex == bucketIndex }
            .map { $0.dropX }
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
    func dropBall(forBucketIndex index: Int) {
        guard boardSize != .zero else { return }

        let multipliers = riskLevel.multipliers(for: pegRows)
        let bucketWidth = 1.0 / CGFloat(multipliers.count)
        let centerX = (CGFloat(index) + 0.5) * bucketWidth
        let offset = CGFloat.random(in: -bucketWidth * 0.15...bucketWidth * 0.15)
        let finalX = min(max(centerX + offset, 0.05), 0.95)

        let ball = PlinkoBall(position: CGPoint(x: finalX, y: 0), color: .blue)
        balls.append(ball)
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
        print("RowCount: \(pegRows) | BucketIndex: \(bucketIndex) | DropX: \(ball.position.x)")
        balls.remove(at: index)
    }

}
