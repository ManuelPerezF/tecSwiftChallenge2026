import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedRole: AppRole? = nil

    var body: some View {
        Group {
            if let role = selectedRole {
                roleRoot(for: role)
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
            } else {
                RolePickerView { selected in
                    withAnimation(.easeOut(duration: 0.28)) {
                        selectedRole = selected
                    }
                }
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.28), value: selectedRole)
    }

    @ViewBuilder
    private func roleRoot(for role: AppRole) -> some View {
        switch role {
        case .family:  FamilyRootView(onSwitchRole: switchRole)
        case .student: StudentRootView(onSwitchRole: switchRole)
        case .elderly: ElderlyRootView(onSwitchRole: switchRole)
        }
    }

    private func switchRole() {
        withAnimation(.easeOut(duration: 0.22)) {
            selectedRole = nil
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(ModelContainer.acompana)
}
