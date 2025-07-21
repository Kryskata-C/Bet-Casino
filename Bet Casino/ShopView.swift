import SwiftUI
#if canImport(PassKit)
import PassKit
#endif

struct ApplePayButton: UIViewRepresentable {
    func makeUIView(context: Context) -> PKPaymentButton {
        PKPaymentButton(paymentButtonType: .buy, paymentButtonStyle: .black)
    }
    func updateUIView(_ uiView: PKPaymentButton, context: Context) {}
}

enum ShopTab {
    case gems
    case gold
}
struct CurrencyPackage: Identifiable {
    let id = UUID()
    let name: String
    let amount: String
    let bonus: String?
    let price: String
    let iconName: String
    let highlightColor: Color
    var isMostPopular: Bool = false
    var hasShineAnimation: Bool = false
}

struct SpecialOffer: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let price: String
    let iconName: String
    let tintColor: Color
}

let specialOffers = [
    SpecialOffer(title: "Starter Bundle", description: "500 Gems & 1K Gold", price: "$0.00", iconName: "sparkles", tintColor: .orange),
    SpecialOffer(title: "Weekend Warrior", description: "2x Boost For 48h", price: "$0.00", iconName: "timer", tintColor: .mint)
]

let goldPackagesV2 = [
    CurrencyPackage(name: "Gold Pouch", amount: "1,000", bonus: nil, price: "$0.99", iconName: "bitcoinsign.circle.fill", highlightColor: .yellow),
    CurrencyPackage(name: "Gold Crate", amount: "5,500", bonus: "+10% BONUS", price: "$3.99", iconName: "bitcoinsign.circle.fill", highlightColor: .yellow, isMostPopular: true),
    CurrencyPackage(name: "Gold Barrel", amount: "15,000", bonus: "+15% BONUS", price: "$9.99", iconName: "bitcoinsign.circle.fill", highlightColor: .yellow, hasShineAnimation: true),
]

let gemPackagesV2 = [
    CurrencyPackage(name: "Gem Pile", amount: "500", bonus: nil, price: "$0.99", iconName: "diamond.fill", highlightColor: .cyan),
    CurrencyPackage(name: "Gem Stash", amount: "1,200", bonus: "+10% BONUS", price: "$3.99", iconName: "diamond.fill", highlightColor: .cyan, isMostPopular: true),
    CurrencyPackage(name: "Gem Treasure", amount: "6,500", bonus: "+15% BONUS", price: "$9.99", iconName: "diamond.fill", highlightColor: .cyan, hasShineAnimation: true),
]

struct ShopView: View {
    @State private var selectedTab: ShopTab = .gems
    
    var body: some View {
        ZStack {
            StaticShopBackground()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    ElitePassCardView()
                    SpecialOffersView()
                    ShopTabView(selectedTab: $selectedTab)
                    if selectedTab == .gems {
                        CurrencyGridView(packages: gemPackagesV2)
                    } else {
                        CurrencyGridView(packages: goldPackagesV2)
                    }
                }
                .padding(.vertical)
            }
        }
    }
}
struct ApplePayButtonWrapperButton: UIViewRepresentable {
    let action: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }

    func makeUIView(context: Context) -> PKPaymentButton {
        let button = PKPaymentButton(paymentButtonType: .buy, paymentButtonStyle: .black)
        button.addTarget(context.coordinator, action: #selector(Coordinator.buttonPressed), for: .touchUpInside)
        return button
    }

    func updateUIView(_ uiView: PKPaymentButton, context: Context) {}

    class Coordinator: NSObject {
        let action: () -> Void
        init(action: @escaping () -> Void) {
            self.action = action
        }

        @objc func buttonPressed() {
            action()
        }
    }
}

class ApplePayDelegate: NSObject, PKPaymentAuthorizationViewControllerDelegate {
    let onSuccess: () -> Void
    init(onSuccess: @escaping () -> Void) { self.onSuccess = onSuccess }
    func paymentAuthorizationViewController(_ controller: PKPaymentAuthorizationViewController, didAuthorizePayment payment: PKPayment, handler completion: @escaping (PKPaymentAuthorizationResult) -> Void) {
        completion(PKPaymentAuthorizationResult(status: .success, errors: nil))
        onSuccess()
    }
    func paymentAuthorizationViewControllerDidFinish(_ controller: PKPaymentAuthorizationViewController) {
        controller.dismiss(animated: true)
    }
}

struct ApplePayButtonWrapper: View {
    let price: String
    let onSuccess: () -> Void

    var body: some View {
        ApplePayButtonWrapperButton(action: startApplePay)
            .frame(width: 120, height: 44)

    }

    func startApplePay() {
        let request = PKPaymentRequest()
        request.merchantIdentifier = "merchant.com.kryskata"
        request.supportedNetworks = [.visa, .masterCard, .amex]
        request.merchantCapabilities = .capability3DS
        request.countryCode = "US"
        request.currencyCode = "USD"
        request.paymentSummaryItems = [PKPaymentSummaryItem(label: "Purchase", amount: NSDecimalNumber(string: price.replacingOccurrences(of: "$", with: "")))]

        if let controller = PKPaymentAuthorizationViewController(paymentRequest: request),
           let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            controller.delegate = ApplePayDelegate(onSuccess: onSuccess)
            scene.windows.first?.rootViewController?.present(controller, animated: true)
        }
    }
}

struct StaticShopBackground: View {
    var body: some View {
        LinearGradient(gradient: Gradient(colors: [Color(red: 20/255, green: 0, blue: 40/255), .black]), startPoint: .top, endPoint: .bottom).ignoresSafeArea()
    }
}

struct ElitePassCardView: View {
    @State private var isGlowing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("ELITE PASS")
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .kerning(1)
                Spacer()
                Image(systemName: "star.shield.fill")
                    .font(.largeTitle)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .yellow)
            }
            Text("Unlock exclusive perks, daily rewards, and unique boosts!")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            ApplePayButtonWrapper(price: "$4.99") {
                print("Elite Pass Tapped!")
            }
        }
        .padding(20)
        .frame(height: 180)
        .background(Color.purple.opacity(0.3).background(.ultraThinMaterial))
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20)
            .stroke(LinearGradient(colors: [.purple, .blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 3)
            .shadow(color: .purple, radius: isGlowing ? 10 : 5, x: 0, y: 0)
        )
        .padding(.horizontal)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                isGlowing = true
            }
        }
    }
}

struct SpecialOffersView: View {
    var body: some View {
        VStack(alignment: .leading) {
            SectionHeaderView(title: "LIMITED TIME OFFERS")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 15) {
                    ForEach(specialOffers) { offer in
                        SpecialOfferCardView(offer: offer)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

struct SpecialOfferCardView: View {
    let offer: SpecialOffer

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: offer.iconName)
                .font(.largeTitle)
                .foregroundColor(offer.tintColor)
            Text(offer.title).font(.headline).bold()
            Text(offer.description).font(.caption2).foregroundColor(.gray)
            ApplePayButtonWrapper(price: offer.price) {
                print("Bought: \(offer.title)")
            }
        }
        .padding()
        .background(Color.black.opacity(0.25))
        .cornerRadius(15)
        .frame(width: 160)
    }
}

struct ShopTabView: View {
    @Binding var selectedTab: ShopTab
    @Namespace private var tabNamespace

    var body: some View {
        HStack(spacing: 0) {
            TabButton(title: "GEMS", icon: "diamond.fill", isSelected: selectedTab == .gems, namespace: tabNamespace) {
                selectedTab = .gems
            }
            TabButton(title: "GOLD", icon: "bitcoinsign.circle.fill", isSelected: selectedTab == .gold, namespace: tabNamespace) {
                selectedTab = .gold
            }
        }
        .background(Color.black.opacity(0.3))
        .cornerRadius(15)
        .padding(.horizontal)
    }
}

struct TabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                Text(title)
            }
            .font(.headline.bold())
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .foregroundColor(isSelected ? .white : .gray)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 15)
                        .fill(Color.purple.opacity(0.4))
                        .matchedGeometryEffect(id: "selectedTabHighlight", in: namespace)
                }
            }
        }
    }
}

struct CurrencyGridView: View {
    let packages: [CurrencyPackage]
    let columns = [GridItem(.flexible(), spacing: 15), GridItem(.flexible(), spacing: 15)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 15) {
            ForEach(packages) { package in
                CurrencyPackageCardView(package: package)
            }
        }
        .padding(.horizontal)
    }
}

struct CurrencyPackageCardView: View {
    let package: CurrencyPackage

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: package.iconName)
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(package.highlightColor)
            Text(package.amount)
                .font(.system(size: 24, weight: .heavy, design: .rounded))
            Text(package.name)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(.gray)
            if let bonusText = package.bonus {
                Text(bonusText)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.2))
                    .cornerRadius(8)
            } else {
                Text("NO BONUS")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.gray.opacity(0.5))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
            }
            Spacer()
            ApplePayButtonWrapper(price: package.price) {
                print("Bought: \(package.name)")
            }
        }
        .padding()
        .frame(height: 200)
        .background(Color.black.opacity(0.25))
        .cornerRadius(15)
        .overlay(
            ZStack {
                if package.isMostPopular {
                    VStack {
                        HStack {
                            Image(systemName: "crown.fill")
                                .foregroundColor(.yellow)
                                .font(.subheadline)
                                .padding(6)
                                .background(Color.yellow.opacity(0.3).blur(radius: 5))
                                .cornerRadius(30)
                            Spacer()
                        }
                        Spacer()
                    }
                    .padding(5)
                }
                if package.hasShineAnimation {
                    ShineEffect()
                }
            }
        )
    }
}

struct ShineEffect: View {
    @State private var shinePosition: CGFloat = -1.5
    var body: some View {
        GeometryReader { geo in
            Rectangle()
                .fill(LinearGradient(colors: [.clear, .white.opacity(0.3), .clear], startPoint: .top, endPoint: .bottom))
                .rotationEffect(.degrees(120))
                .offset(x: shinePosition * geo.size.width)
                .onAppear {
                    withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false).delay(Double.random(in: 0...2))) {
                        shinePosition = 1.5
                    }
                }
        }
        .mask(RoundedRectangle(cornerRadius: 15))
    }
}

struct SectionHeaderView: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .kerning(1.5)
            .foregroundColor(.gray)
            .padding(.horizontal)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
#Preview {
    ContentView()
        .environmentObject(SessionManager.shopPreviewV4())
}
extension SessionManager {
    static func shopPreviewV4() -> SessionManager {
        let session = SessionManager()
        session.isLoggedIn = true
        session.username = "Player1"
        session.money = 10000
        session.gems = 500
        session.currentScreen = .shop
        return session
    }
}

