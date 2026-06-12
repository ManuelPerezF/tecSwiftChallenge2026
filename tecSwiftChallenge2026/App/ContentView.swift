import SwiftUI

struct ContentView: View {
    @AppStorage("aco_authToken")  private var savedToken: String = ""
    @AppStorage("aco_userRole")   private var savedRoleRaw: String = ""
    @AppStorage("aco_userName")   private var savedName: String = ""
    @AppStorage("aco_familyCode") private var savedFamilyCode: String = ""
    @AppStorage("aco_joinedFamily") private var joinedFamily: Bool = false

    private var currentRole: AppRole? {
        guard !savedToken.isEmpty else { return nil }
        return AppRole(rawValue: savedRoleRaw)
    }

    var body: some View {
        Group {
            if let role = currentRole {
                roleRoot(for: role)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.97)),
                        removal: .opacity
                    ))
            } else {
                LoginView()
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.28), value: currentRole != nil)
    }

    @ViewBuilder
    private func roleRoot(for role: AppRole) -> some View {
        switch role {
        case .family:    FamilyRootView(onLogout: logout)
        case .student:   StudentRootView(onLogout: logout)
        case .elderly:   ElderlyRootView(onLogout: logout)
        case .organizer: OrganizerRootView(onLogout: logout)
        }
    }

    private func logout() {
        let token = savedToken
        withAnimation(.easeOut(duration: 0.22)) {
            savedToken = ""
            savedRoleRaw = ""
            savedName = ""
            savedFamilyCode = ""
            joinedFamily = false
        }
        Task {
            await APIClient.shared.logout(token: token)
        }
    }
}

#Preview {
    ContentView()
}
