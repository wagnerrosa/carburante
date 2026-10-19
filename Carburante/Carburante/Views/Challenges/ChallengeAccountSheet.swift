//
//  ChallengeAccountSheet.swift
//  Carburante
//
//  Desafios exigem conta Apple (decisão 2 do PLAN/desafios.md): a posição na
//  classificação não pode sumir na troca de iPhone. Folha curta antes de
//  criar um desafio; no convite, o botão fica na própria prévia. Entrar
//  PROMOVE a sessão anônima (mesmo user_id, os dados ficam).
//

import SwiftUI

struct ChallengeAccountSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Image(systemName: "flag.checkered")
                        .font(.system(size: 44))
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)
                    Text("Desafios ficam na sua conta Apple")
                        .font(.title2.weight(.bold))
                        .multilineTextAlignment(.center)
                    Text("Sua posição e seus desafios continuam com você se trocar de iPhone. O que você já registrou continua aqui.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    AppleSignInButton(errorMessage: $errorMessage) { dismiss() }
                        .padding(.top, 8)
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Agora não") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
