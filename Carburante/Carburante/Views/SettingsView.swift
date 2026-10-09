//
//  SettingsView.swift
//  Carburante
//
//  Ajustes do app. No MVP, o foco é o controle de privacidade exigido pela App
//  Store: ligar/desligar o compartilhamento de dados de uso (analytics). Padrão
//  nativo (Form + Toggle), sem libs.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    /// Planilhas geradas por "Exportar meus dados" → folha de compartilhar.
    @State private var export: ExportedFiles?
    @State private var exportFailed = false

    /// Compartilhar dados de uso (analytics). Default true — analytics de produto
    /// anônimo é opt-out (sem ATT/IDFA). A fonte de verdade do opt-out é aplicada
    /// ao PostHog em `CarburanteApp` no launch e aqui na mudança.
    @AppStorage("analyticsEnabled") private var analyticsEnabled = true

    /// Gesto escondido: 7 toques na versão marcam/desmarcam este aparelho como
    /// interno (dono/time) → sai das métricas. Ver `Analytics.setInternalDevice`.
    @State private var versionTaps = 0
    @State private var isInternalDevice = Analytics.isInternalDevice
    @State private var showInternalAlert = false

    var body: some View {
        NavigationStack {
            Form {
                AccountView()

                Section {
                    Toggle("Compartilhar dados de uso", isOn: $analyticsEnabled)
                        .onChange(of: analyticsEnabled) { _, on in
                            Analytics.setEnabled(on)
                        }
                    // Exigido pela App Store (5.1.1): política acessível de dentro do app.
                    Link("Política de privacidade", destination: Self.privacyPolicyURL)
                } header: {
                    Text("Privacidade")
                } footer: {
                    Text("Estatísticas anônimas de uso ajudam a melhorar o app. Nunca coletamos localização, valores ou quilometragem exatos — só eventos agregados. Você pode desligar a qualquer momento.")
                }

                // Grátis, sempre: dado nunca é refém (PLAN/monetizacao.md).
                Section {
                    Button {
                        exportData()
                    } label: {
                        Label("Exportar meus dados", systemImage: "square.and.arrow.up")
                    }
                } header: {
                    Text("Seus dados")
                } footer: {
                    Text("Planilhas com suas motos, abastecimentos e manutenções. Abrem no Numbers e no Excel.")
                }

                // Canal qualitativo fora do TestFlight (que tem feedback com print):
                // quem baixa da App Store só fala com a gente por aqui.
                Section {
                    Link("Enviar sugestão", destination: feedbackURL)
                } footer: {
                    Text("Travou em algo ou sentiu falta de alguma coisa? Conte pra gente.")
                }

                Section {
                    LabeledContent("Versão", value: isInternalDevice ? "\(appVersion) · interno" : appVersion)
                        .contentShape(Rectangle())
                        .onTapGesture(perform: countVersionTap)
                } footer: {
                    Text("Nomes e logotipos de fabricantes de motos são marcas comerciais ou registradas de seus respectivos detentores e aparecem no app só para identificar a sua moto. O Carburante é independente e não tem afiliação, patrocínio ou endosso de nenhum fabricante.")
                }
            }
            .navigationTitle("Ajustes")
            .sheet(item: $export) { files in
                ActivityView(items: files.urls)
                    .presentationDetents([.medium, .large])
            }
            .alert("Não foi possível exportar", isPresented: $exportFailed) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Tente novamente.")
            }
            .alert(isInternalDevice ? "Aparelho interno" : "Aparelho comum",
                   isPresented: $showInternalAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(isInternalDevice
                     ? "Este aparelho não entra mais nas estatísticas de uso."
                     : "Este aparelho voltou a entrar nas estatísticas de uso.")
            }
            // Sheet sem botão de fechar dependia só do swipe-down.
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                }
            }
        }
    }

    private func exportData() {
        let descriptor = FetchDescriptor<Motorcycle>(predicate: Motorcycle.activePredicate,
                                                     sortBy: [SortDescriptor(\.createdAt)])
        do {
            let motorcycles = try modelContext.fetch(descriptor)
            let urls = try DataExport.write(DataExport.files(for: motorcycles))
            export = ExportedFiles(urls: urls)
            Analytics.dataExported(
                bikeCount: motorcycles.count,
                fuelLogCount: motorcycles.reduce(0) { $0 + $1.activeFuelLogs.count },
                maintenanceCount: motorcycles.reduce(0) { $0 + $1.activeMaintenanceLogs.count }
            )
        } catch {
            exportFailed = true
        }
    }

    private func countVersionTap() {
        versionTaps += 1
        guard versionTaps >= 7 else { return }
        versionTaps = 0
        isInternalDevice.toggle()
        Analytics.setInternalDevice(isInternalDevice)
        Haptics.success()
        showInternalAlert = true
    }

    /// Mesma URL informada no App Store Connect (campo Privacy Policy URL).
    static let privacyPolicyURL = URL(string: "https://carburante.motorcycles/privacidade/")!

    /// Mesmo contato da política de privacidade e do feedback do TestFlight.
    static let feedbackEmail = "contato@wagnerrosa.com"

    /// E-mail com versão, iOS e aparelho já no corpo — ajuda a reproduzir sem
    /// perguntar de volta. O usuário vê tudo e pode apagar antes de enviar.
    private var feedbackURL: URL {
        var c = URLComponents()
        c.scheme = "mailto"
        c.path = Self.feedbackEmail
        c.queryItems = [
            URLQueryItem(name: "subject", value: "Carburante — sugestão"),
            URLQueryItem(name: "body", value: "\n\n\n—\nCarburante \(appVersion) · iOS \(UIDevice.current.systemVersion) · \(deviceModel)"),
        ]
        return c.url!
    }

    /// Identificador do modelo (ex.: "iPhone17,5"); `UIDevice.model` só diz "iPhone".
    private var deviceModel: String {
        var info = utsname()
        uname(&info)
        return withUnsafeBytes(of: &info.machine) { raw in
            String(decoding: raw.prefix { $0 != 0 }, as: UTF8.self)
        }
    }

    private var appVersion: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "\(v) (\(b))"
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: Motorcycle.self, inMemory: true)
}

/// Planilhas prontas para a folha de compartilhar (`.sheet(item:)` pede Identifiable).
private struct ExportedFiles: Identifiable {
    let id = UUID()
    let urls: [URL]
}
