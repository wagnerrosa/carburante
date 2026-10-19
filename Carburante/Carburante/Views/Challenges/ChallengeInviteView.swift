//
//  ChallengeInviteView.swift
//  Carburante
//
//  Prévia do convite (padrão Convites da Apple): capa grande, quem criou,
//  período, quem já está, como funciona — e Entrar. Anônimo entra com a Apple
//  antes: a posição na classificação não pode sumir na troca de iPhone.
//

import SwiftUI
import AuthenticationServices

struct ChallengeInviteView: View {
    let challenge: Challenge
    var isAnonymous: Bool

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var nickname = "Wagner"
    /// D0: a conta Apple "entra" sem chamar o servidor.
    @State private var linked = false
    @ScaledMetric(relativeTo: .largeTitle) private var coverHeight: CGFloat = 320

    /// Quem já está no desafio (o convidado ainda não está).
    private var members: [ChallengeStanding] { challenge.standings.filter { !$0.isMe } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    cover
                    VStack(alignment: .leading, spacing: 20) {
                        facts
                        GroupedCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Como funciona")
                                    .font(.headline)
                                ChallengeRules()
                            }
                        }
                        if isAnonymous && !linked {
                            appleStep
                        } else {
                            joinStep
                        }
                    }
                    .padding()
                }
            }
            .ignoresSafeArea(edges: .top)
            .background(Color(.systemGroupedBackground))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar", systemImage: "xmark") { dismiss() }
                }
            }
        }
    }

    private var cover: some View {
        Color.clear
            .frame(height: coverHeight)
            .frame(maxWidth: .infinity)
            .overlay { ChallengeCoverImage(ref: challenge.coverRef) }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Convite para o desafio")
                        .font(.subheadline.weight(.semibold))
                        .opacity(0.85)
                    Text(challenge.name)
                        .font(.largeTitle.weight(.bold))
                    Text("Criado por \(challenge.createdByName)")
                        .font(.headline)
                        .opacity(0.9)
                }
                .foregroundStyle(.white)
                .padding()
                .padding(.top, 60)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    LinearGradient(colors: [.clear, .black.opacity(0.7)],
                                   startPoint: .top, endPoint: .bottom)
                )
            }
            .clipped()
            .accessibilityElement(children: .combine)
    }

    private var facts: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "calendar")
                    .foregroundStyle(.tint)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 1) {
                    Text(AppFormat.dayRange(challenge.startDate, challenge.endDate))
                        .font(.body.weight(.semibold))
                    Text(AppFormat.sentenceCased(challenge.phaseText()))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityElement(children: .combine)

            HStack(spacing: 12) {
                // Monogramas sobrepostos (os convidados do Convites).
                HStack(spacing: -10) {
                    ForEach(members.prefix(4)) { member in
                        member.monogram(size: 34, ring: Color(.systemGroupedBackground))
                            .padding(2)
                            .background(Color(.systemGroupedBackground), in: Circle())
                    }
                }
                Text(membersText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
        }
    }

    private var membersText: String {
        let names = members.prefix(2).map(\.firstName)
        let rest = members.count - names.count
        switch (names.count, rest) {
        case (0, _): return "Ninguém entrou ainda"
        case (1, 0): return "\(names[0]) já está"
        case (2, 0): return "\(names[0]) e \(names[1]) já estão"
        default: return "\(names.joined(separator: ", ")) e mais \(rest) já estão"
        }
    }

    private var appleStep: some View {
        VStack(spacing: 10) {
            SignInWithAppleButton(.continue) { request in
                request.requestedScopes = [.fullName]
            } onCompletion: { _ in
                withAnimation { linked = true }
            }
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            .frame(height: 50)

            Text("A classificação fica na sua conta Apple: se trocar de iPhone, sua posição continua. Seus registros continuam os mesmos.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var joinStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                LabeledContent("Seu nome") {
                    TextField("Nome", text: $nickname)
                        .multilineTextAlignment(.trailing)
                        .textContentType(.givenName)
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                Text("É o nome que a turma vê na classificação.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }

            Button {
                Haptics.success()
                dismiss()
            } label: {
                Text("Entrar no desafio")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(nickname.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }
}
