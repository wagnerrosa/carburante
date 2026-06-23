//
//  ActivationChecklist.swift
//  Carburante
//
//  Checklist de ativação (PLAN/onboarding.md): leva o usuário ao momento de
//  valor o mais rápido possível. Quatro passos, marcados automaticamente a
//  partir dos dados reais (não há estado próprio a sincronizar — derivado do
//  SwiftData). Some sozinho quando os quatro estão concluídos, e pode ser
//  dispensado a qualquer momento (não fica incomodando no uso recorrente).
//
//  Visual: card agrupado nativo. Passo concluído = check na cor do tema; passo
//  pendente = círculo vazio + chevron (acionável). O 1º passo pendente vira a
//  próxima ação sugerida.
//

import SwiftUI

/// Um passo do checklist. `action` nil = passo sem ação direta (raro).
struct ActivationStep: Identifiable {
    let id = UUID()
    let title: String
    let isDone: Bool
    let action: (() -> Void)?
}

struct ActivationChecklist: View {
    let steps: [ActivationStep]
    /// Dispensa o card (gravado pelo chamador em @AppStorage).
    let onDismiss: () -> Void

    private var doneCount: Int { steps.filter(\.isDone).count }
    /// Índice do 1º passo pendente — é a "próxima ação" em destaque.
    private var nextPendingID: ActivationStep.ID? {
        steps.first(where: { !$0.isDone })?.id
    }

    var body: some View {
        GroupedCard {
            VStack(alignment: .leading, spacing: 14) {
                header

                VStack(spacing: 0) {
                    ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                        row(step, isNext: step.id == nextPendingID)
                        if index < steps.count - 1 {
                            Divider().padding(.leading, 34)
                        }
                    }
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("Primeiros passos")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
            Text("\(doneCount) de \(steps.count)")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .monospacedDigit()
            Spacer()
            // Dispensar — caminho de saída explícito (HIG); o card não é obrigatório.
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dispensar primeiros passos")
        }
    }

    @ViewBuilder
    private func row(_ step: ActivationStep, isNext: Bool) -> some View {
        let content = HStack(spacing: 12) {
            Image(systemName: step.isDone ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(step.isDone ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))

            Text(step.title)
                .font(.body)
                // Concluído fica esmaecido (passou); pendente em destaque.
                .foregroundStyle(step.isDone ? .secondary : .primary)
                .strikethrough(step.isDone, color: .secondary)

            Spacer(minLength: 8)

            // Só o próximo passo pendente acionável mostra o chevron (uma sugestão
            // por vez — sem poluir a lista com setas em tudo).
            if !step.isDone, isNext, step.action != nil {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 10)
        .contentShape(.rect)

        // Passo pendente com ação → linha tocável; concluído → estático.
        if let action = step.action, !step.isDone {
            Button(action: action) { content }
                .buttonStyle(.plain)
                .accessibilityHint("Toque para concluir este passo")
        } else {
            content
                .accessibilityElement(children: .combine)
                .accessibilityValue(step.isDone ? "Concluído" : "Pendente")
        }
    }
}

#Preview {
    ActivationChecklist(
        steps: [
            ActivationStep(title: "Cadastre sua primeira moto", isDone: true, action: {}),
            ActivationStep(title: "Registre seu primeiro abastecimento", isDone: false, action: {}),
            ActivationStep(title: "Registre uma manutenção", isDone: false, action: {}),
            ActivationStep(title: "Veja seu primeiro consumo", isDone: false, action: nil),
        ],
        onDismiss: {}
    )
    .padding()
    .background(Color(.systemGroupedBackground))
    .tint(BrandTheme.default)
}
