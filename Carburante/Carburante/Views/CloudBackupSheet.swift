//
//  CloudBackupSheet.swift
//  Carburante
//
//  Passo "Guarde seu histórico" dos primeiros passos (`CloudBackupStep`): diz
//  por que entrar com a Apple e oferece o botão oficial. Meia altura, com saída
//  explícita ("Agora não") — convite, nunca obrigação.
//

import SwiftUI

struct CloudBackupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 44))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text("Guarde seu histórico")
                    .font(.title2.weight(.bold))
                Text("Entre com a Apple para não perder seus abastecimentos e manutenções se trocar ou perder o iPhone. O que você já registrou continua aqui.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                AppleSignInButton(errorMessage: $errorMessage) { dismiss() }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                Button("Agora não") { dismiss() }
                    .padding(.top, 4)
            }
        }
        .padding(24)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

#Preview {
    Text("Resumo")
        .sheet(isPresented: .constant(true)) { CloudBackupSheet() }
}
