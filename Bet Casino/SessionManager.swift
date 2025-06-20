import Foundation
import Combine

class SessionManager: ObservableObject {
    @Published var isLoggedIn: Bool = false
}
