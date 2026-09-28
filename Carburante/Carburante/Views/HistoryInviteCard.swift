//
//  HistoryInviteCard.swift
//  Carburante
//
//  Convite pós-cadastro "Sua moto já tem histórico?" (PLAN/registro-retroativo.md,
//  decisão 3): moto usada chega ao app com passado — trocas de óleo, pneus,
//  revisões. Sem convite, o usuário só registra "daqui pra frente" e o
//  vencimento da próxima troca nasce errado. Aparece no Resumo DEPOIS dos
//  primeiros passos (nunca empilhado com o checklist), só para moto que parece
//  usada, some sozinho no 1º registro de histórico e pode ser dispensado.
//

import SwiftUI

struct HistoryInviteCard: View {
    /// Abre o registro de histórico.
    let onRegister: () -> Void
    /// Dispensa o card (gravado pelo chamador em @AppStorage, por moto).
    let onDismiss: () -> Void

    var body: some View {
        GroupedCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Label("Sua moto já tem histórico?", systemImage: "clock.arrow.circlepath")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    // Caminho de saída explícito (HIG), igual ao checklist.
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.tertiary)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Dispensar convite de histórico")
                }
                Text("Registre trocas de óleo, pneus e revisões feitas antes de usar o app — o próximo vencimento fica certo.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Registrar histórico", action: onRegister)
                    .buttonStyle(.bordered)
            }
        }
    }
}

extension Motorcycle {
    /// Menor leitura conhecida da moto: km do cadastro (se informado) e de
    /// qualquer registro. Moto que já chegou rodada tem passado para registrar.
    var firstKnownOdometer: Double? {
        var readings = activeFuelLogs.map(\.odometer) + activeMaintenanceLogs.map(\.mileage)
        if odometerBaseline > 0 { readings.append(odometerBaseline) }
        return readings.filter { $0 > 0 }.min()
    }

    /// Chegou ao app já rodada (≥ 1.000 km na 1ª leitura) — moto zero não tem
    /// histórico a registrar, o convite seria ruído.
    var looksUsed: Bool { (firstKnownOdometer ?? 0) >= 1_000 }

    /// Já tem algum registro de histórico (abastecimento ou manutenção).
    var hasHistoricalRecords: Bool {
        activeFuelLogs.contains(where: \.isHistorical)
            || activeMaintenanceLogs.contains(where: \.isHistorical)
    }
}

#Preview {
    HistoryInviteCard(onRegister: {}, onDismiss: {})
        .padding()
        .background(Color(.systemGroupedBackground))
        .tint(BrandTheme.default)
}
