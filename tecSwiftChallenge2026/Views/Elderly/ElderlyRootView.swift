import SwiftUI

enum ElderlyDestination: Hashable {
    case rating
}

struct ElderlyRootView: View {
    let onSwitchRole: () -> Void

    var body: some View {
        NavigationStack {
            ElderlyVisitView()
                .navigationDestination(for: ElderlyDestination.self) { dest in
                    switch dest {
                    case .rating: ElderlyRatingView()
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Cambiar rol", action: onSwitchRole)
                            .font(.caption)
                            .foregroundStyle(Color.acoInk3)
                    }
                }
        }
        .tint(.acoElderly)
    }
}

#Preview {
    ElderlyRootView(onSwitchRole: {})
}
