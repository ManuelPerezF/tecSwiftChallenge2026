import SwiftUI
@preconcurrency import CoreLocation

struct FamilyPublishView: View {
    @AppStorage("aco_userName") private var userName: String = ""
    @AppStorage("aco_familyCode") private var familyCode: String = ""

    @State private var familyElderly: [ElderlySummary] = []
    @State private var selectedElderlyId: String?
    @State private var selectedActivity: ActivityType = .mandados
    @State private var scheduledDate: Date = {
        Calendar.current.date(byAdding: .hour, value: 2, to: Date()) ?? Date()
    }()
    @State private var isUrgent: Bool = false
    @State private var descriptionText: String = ""
    @State private var isPublished: Bool = false
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    @State private var familyCoordinate: CLLocationCoordinate2D? = nil
    private let locationGrabber = OneTimeLocationGrabber()

    var body: some View {
        ZStack {
            Color.acoBg.ignoresSafeArea()
            if isPublished {
                publishedConfirmation
            } else {
                publishForm
            }
        }
        .navigationTitle("Nueva solicitud")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if familyElderly.isEmpty {
                let info = try? await APIClient.shared.fetchMyFamily()
                familyElderly = info?.elderly ?? []
                if selectedElderlyId == nil { selectedElderlyId = familyElderly.first?.id }
            }
            familyCoordinate = await locationGrabber.grab()
        }
    }

    // MARK: - Confirmación

    private var publishedConfirmation: some View {
        VStack(spacing: 0) {
            Spacer()
            ZStack {
                Circle().fill(Color.acoFamilySoft).frame(width: 96, height: 96)
                Image(systemName: selectedActivity.symbolName)
                    .font(.system(size: 40))
                    .foregroundStyle(Color.acoFamily)
                    .accessibilityHidden(true)
            }
            Text("¡Solicitud publicada!")
                .font(.title2).bold().foregroundStyle(Color.acoInk)
                .padding(.top, 22)
            Text("Ya aparece en el mapa de becarios.")
                .font(.body).foregroundStyle(Color.acoInk2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36).padding(.top, 10)
            CTAButton(label: "Publicar otra solicitud", tint: .acoFamily) {
                withAnimation(.easeInOut(duration: 0.22)) { resetForm() }
            }
            .padding(.horizontal, 24).padding(.top, 32)
            Spacer()
        }
    }

    // MARK: - Formulario

    private var publishForm: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                if !userName.isEmpty {
                    Text("Publicando como \(userName)")
                        .font(.caption).foregroundStyle(Color.acoInk3)
                        .padding(.horizontal, 20).padding(.bottom, 20)
                }

                // Para quién
                fieldLabel("¿Para quién?").padding(.horizontal, 20)
                if familyElderly.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Aún no hay un adulto mayor vinculado a tu familia.")
                            .font(.subheadline).foregroundStyle(Color.acoInk2)
                        if !familyCode.isEmpty {
                            Text("Comparte tu código **\(familyCode)** para que se una.")
                                .font(.caption).foregroundStyle(Color.acoInk3)
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(acoHex: "FDFBF8"))
                    .clipShape(.rect(cornerRadius: 14))
                    .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(Color(acoHex: "3C3228").opacity(0.10), lineWidth: 1) }
                    .padding(.horizontal, 20)
                } else {
                    HStack(spacing: 8) {
                        ForEach(familyElderly) { elderly in
                            Button {
                                withAnimation(.easeInOut(duration: 0.15)) { selectedElderlyId = elderly.id }
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: "figure.stand")
                                        .font(.title3)
                                        .foregroundStyle(selectedElderlyId == elderly.id ? Color.acoFamily : Color.acoElderly)
                                        .accessibilityHidden(true)
                                    Text(elderly.firstName)
                                        .font(.caption).fontWeight(.semibold)
                                        .foregroundStyle(selectedElderlyId == elderly.id ? Color.acoFamily : Color.acoInk2)
                                        .lineLimit(1)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(selectedElderlyId == elderly.id ? Color.acoFamilySoft : Color(acoHex: "FDFBF8"))
                                .clipShape(.rect(cornerRadius: 12))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(
                                            selectedElderlyId == elderly.id ? Color.acoFamily : Color(acoHex: "3C3228").opacity(0.10),
                                            lineWidth: selectedElderlyId == elderly.id ? 2 : 1
                                        )
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(selectedElderlyId == elderly.id ? .isSelected : [])
                        }
                    }
                    .padding(.horizontal, 20)
                }

                // Tipo de ayuda
                fieldLabel("¿Con qué necesita ayuda?")
                    .padding(.horizontal, 20).padding(.top, 22)
                LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 3), spacing: 8) {
                    ForEach(ActivityType.allCases, id: \.self) { act in
                        ActivityPickerCell(activity: act, isSelected: selectedActivity == act,
                                           tint: .acoFamily, soft: .acoFamilySoft) {
                            withAnimation(.easeInOut(duration: 0.15)) { selectedActivity = act }
                        }
                    }
                }
                .padding(.horizontal, 20)

                // Descripción
                fieldLabel("Detalles").padding(.horizontal, 20).padding(.top, 22)
                TextField("Describe qué necesita…", text: $descriptionText, axis: .vertical)
                    .lineLimit(3...)
                    .font(.body).foregroundStyle(Color.acoInk)
                    .padding(14)
                    .background(Color(acoHex: "FDFBF8"))
                    .clipShape(.rect(cornerRadius: 14))
                    .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(Color(acoHex: "3C3228").opacity(0.10), lineWidth: 1) }
                    .padding(.horizontal, 20)

                // Fecha y hora
                fieldLabel("¿Cuándo?").padding(.horizontal, 20).padding(.top, 22)
                VStack(spacing: 0) {
                    DatePicker("Día", selection: $scheduledDate, in: Date()..., displayedComponents: .date)
                        .datePickerStyle(.compact).tint(.acoFamily)
                        .padding(.horizontal, 16).padding(.vertical, 14)
                    Rectangle().fill(Color.acoHair).frame(height: 1).padding(.horizontal, 16)
                    DatePicker("Hora", selection: $scheduledDate, in: Date()..., displayedComponents: .hourAndMinute)
                        .datePickerStyle(.compact).tint(.acoFamily)
                        .padding(.horizontal, 16).padding(.vertical, 14)
                }
                .background(Color(acoHex: "FDFBF8"))
                .clipShape(.rect(cornerRadius: 14))
                .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(Color(acoHex: "3C3228").opacity(0.10), lineWidth: 1) }
                .padding(.horizontal, 20)

                Text("El becario confirmará su hora exacta.")
                    .font(.caption).foregroundStyle(Color.acoInk3)
                    .padding(.horizontal, 24).padding(.top, 7)

                // Urgencia
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { isUrgent.toggle() }
                } label: {
                    UrgencyToggleRow(isUrgent: isUrgent)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20).padding(.top, 16)

                // Error
                if let err = errorMessage {
                    Label(err, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption).foregroundStyle(.red)
                        .padding(.horizontal, 20).padding(.top, 10)
                }

                // CTA
                CTAButton(
                    label: isLoading ? "Publicando…" : "Publicar solicitud",
                    leadingSymbol: selectedActivity.symbolName,
                    tint: .acoFamily,
                    disabled: isLoading
                ) { Task { await publishRequest() } }
                .padding(.horizontal, 20).padding(.top, 22).padding(.bottom, 40)
            }
            .padding(.top, 4)
        }
        .scrollIndicators(.hidden)
        .background(Color.acoBg)
    }

    // MARK: - API call

    private func publishRequest() async {
        isLoading = true
        errorMessage = nil
        do {
            _ = try await APIClient.shared.createRequest(
                elderlyProfileId: selectedElderlyId,
                activityType: selectedActivity,
                details: descriptionText.isEmpty
                    ? "Ayuda con \(selectedActivity.label.lowercased())."
                    : descriptionText,
                scheduledDate: scheduledDate,
                isUrgent: isUrgent,
                latitude: familyCoordinate?.latitude,
                longitude: familyCoordinate?.longitude
            )
            await MainActor.run {
                isLoading = false
                withAnimation(.easeInOut(duration: 0.22)) { isPublished = true }
            }
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = error.localizedDescription
            }
        }
    }

    private func resetForm() {
        isPublished = false
        descriptionText = ""
        selectedActivity = .mandados
        isUrgent = false
        scheduledDate = Calendar.current.date(byAdding: .hour, value: 2, to: Date()) ?? Date()
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption).bold().textCase(.uppercase)
            .tracking(0.4).foregroundStyle(Color.acoFamily)
            .padding(.bottom, 10)
    }
}

// MARK: - Activity picker cell

private struct ActivityPickerCell: View {
    let activity: ActivityType
    let isSelected: Bool
    let tint: Color
    let soft: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: activity.symbolName)
                    .font(.system(size: 24))
                    .foregroundStyle(isSelected ? tint : Color.acoInk2)
                    .accessibilityHidden(true)
                Text(activity.label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isSelected ? tint : Color.acoInk2)
                    .multilineTextAlignment(.center).lineLimit(2, reservesSpace: true)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 12)
            .background(isSelected ? soft : Color(acoHex: "FDFBF8"))
            .clipShape(.rect(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isSelected ? tint : Color(acoHex: "3C3228").opacity(0.08),
                                  lineWidth: isSelected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(activity.label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Urgency toggle

private struct UrgencyToggleRow: View {
    let isUrgent: Bool

    var body: some View {
        HStack(spacing: 12) {
            Circle().fill(isUrgent ? Color.acoUrgent : Color(acoHex: "D8CFC4")).frame(width: 12, height: 12)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Marcar como urgente").font(.body).fontWeight(.semibold).foregroundStyle(Color.acoInk)
                Text("Resalta en el mapa de becarios").font(.caption).foregroundStyle(Color.acoInk2)
            }
            Spacer()
            ZStack(alignment: isUrgent ? .trailing : .leading) {
                Capsule().fill(isUrgent ? Color.acoUrgent : Color(acoHex: "D8CFC4")).frame(width: 46, height: 28)
                Circle().fill(Color.white).frame(width: 24, height: 24)
                    .shadow(color: .black.opacity(0.18), radius: 2, y: 1).padding(.horizontal, 2)
            }
            .animation(.easeInOut(duration: 0.15), value: isUrgent)
        }
        .padding(13)
        .background(isUrgent ? Color(acoHex: "FBEDE2") : Color(acoHex: "FDFBF8"))
        .clipShape(.rect(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(isUrgent ? Color.acoUrgent : Color(acoHex: "3C3228").opacity(0.08),
                              lineWidth: isUrgent ? 1.5 : 1)
        }
    }
}

// MARK: - One-shot location helper

private final class OneTimeLocationGrabber: NSObject, CLLocationManagerDelegate, @unchecked Sendable {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocationCoordinate2D?, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func grab() async -> CLLocationCoordinate2D? {
        return await withCheckedContinuation { cont in
            continuation = cont
            switch manager.authorizationStatus {
            case .notDetermined:
                manager.requestWhenInUseAuthorization()
            case .authorizedAlways, .authorizedWhenInUse:
                manager.requestLocation()
            default:
                cont.resume(returning: nil)
                continuation = nil
            }
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse ||
           manager.authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        } else if manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted {
            continuation?.resume(returning: nil)
            continuation = nil
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        continuation?.resume(returning: locations.last?.coordinate)
        continuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        continuation?.resume(returning: nil)
        continuation = nil
    }
}

#Preview {
    NavigationStack { FamilyPublishView() }
}
