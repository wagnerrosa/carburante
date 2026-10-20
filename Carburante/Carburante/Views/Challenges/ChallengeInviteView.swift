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
    let invite: ChallengeInvite
    /// D0: mostra o passo da Apple sem tocar na conta. nil = conta de verdade.
    var previewAnonymous: Bool? = nil
    /// Entra no desafio com o nome escolhido.
    var onJoin: (String) async throws -> Void = { _ in }
    /// Já está no desafio: abre ele.
    var onOpen: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var nickname = ChallengeName.suggestedPilotName()
    @State private var previewLinked = false
    @State private var isJoining = false
    @State private var errorMessage: String?
    @ScaledMetric(relativeTo: .largeTitle) private var coverHeight: CGFloat = 320

    private var needsAccount: Bool {
        if let previewAnonymous { return previewAnonymous && !previewLinked }
        return SyncService.shared.isAnonymous
    }

    /// Ainda vai entrar: mostra o que a turma vai ver (consentimento).
    private var canJoin: Bool { !invite.isMember && invite.blocker == nil }

    private var cleanNickname: String? {
        ChallengeName.cleaned(nickname, maxLength: ChallengeName.pilotMaxLength)
    }

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
                                ChallengeRules(includesSharing: !canJoin)
                            }
                        }
                        if canJoin {
                            sharing
                        }
                        if invite.isMember {
                            memberStep
                        } else if let blocker = invite.blocker {
                            Label(blocker, systemImage: "exclamationmark.circle")
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        } else if needsAccount {
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
            .overlay { ChallengeCoverImage(ref: invite.coverRef) }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Convite para o desafio")
                        .font(.subheadline.weight(.semibold))
                        .opacity(0.85)
                    Text(invite.name)
                        .font(.largeTitle.weight(.bold))
                    if let createdBy = invite.createdByName {
                        Text("Criado por \(createdBy)")
                            .font(.headline)
                            .opacity(0.9)
                    }
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
                    Text(AppFormat.dayRange(invite.period.firstDay, invite.period.lastDay))
                        .font(.body.weight(.semibold))
                    Text(AppFormat.sentenceCased(invite.period.phaseText()))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityElement(children: .combine)

            HStack(spacing: 12) {
                // Monogramas sobrepostos (os convidados do Convites).
                HStack(spacing: -10) {
                    ForEach(Array(invite.memberNames.prefix(4).enumerated()), id: \.offset) { _, name in
                        PilotMonogram(initials: ChallengeStanding.initials(of: name), make: nil,
                                      size: 34, ringColor: Color(.systemGroupedBackground))
                            .padding(2)
                            .background(Color(.systemGroupedBackground), in: Circle())
                    }
                }
                Text(invite.membersText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
        }
    }

    /// Consentimento: o que a turma vê, antes da conta e do nome — quem lê
    /// decide antes de entrar com a Apple.
    private var sharing: some View {
        GroupedCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(ChallengeSharing.title)
                    .font(.headline)
                ChallengeSharing.Rows()
                Text(ChallengeSharing.privateNote)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var appleStep: some View {
        VStack(spacing: 10) {
            if previewAnonymous != nil {
                // D0: não mexe na conta do simulador.
                SignInWithAppleButton(.continue) { request in
                    request.requestedScopes = [.fullName]
                } onCompletion: { _ in
                    withAnimation { previewLinked = true }
                }
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(height: 50)
            } else {
                AppleSignInButton(errorMessage: $errorMessage) {
                    // A Apple acabou de mandar o 1º nome (só vem na 1ª vez).
                    if nickname.isEmpty { nickname = ChallengeName.suggestedPilotName() }
                }
            }

            Text("A classificação fica na sua conta Apple: se trocar de iPhone, sua posição continua. Seus registros continuam os mesmos.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var joinStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                LabeledContent("Seu nome") {
                    TextField("Nome", text: $nickname)
                        .multilineTextAlignment(.trailing)
                        .textContentType(.givenName)
                        .onChange(of: nickname) { _, typed in
                            let cut = ChallengeName.truncated(typed, maxLength: ChallengeName.pilotMaxLength)
                            if cut != typed { nickname = cut }
                        }
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
                join()
            } label: {
                Group {
                    if isJoining {
                        ProgressView()
                    } else {
                        Text("Entrar no desafio")
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(cleanNickname == nil || isJoining)

            // Colado ao botão: tocar em "Entrar" é aceitar.
            Text(LocalizedStringKey(ChallengeSharing.joinConsent))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, -10)

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
    }

    private var memberStep: some View {
        Button {
            dismiss()
            onOpen()
        } label: {
            Text("Abrir desafio")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }

    private func join() {
        guard let name = cleanNickname else { return }
        isJoining = true
        errorMessage = nil
        Task {
            do {
                try await onJoin(name)
                UserDefaults.standard.set(name, forKey: ChallengeName.pilotNameKey)
                Haptics.success()
                dismiss()
            } catch {
                errorMessage = ChallengeService.challengeError(error).message
            }
            isJoining = false
        }
    }
}

extension ChallengeInvite {
    /// Prévia de um desafio que o app já tem (protótipo D0).
    init(challenge: Challenge) {
        let others = challenge.standings.filter { !$0.isMe }
        self.init(id: challenge.id, code: challenge.code, name: challenge.name,
                  period: challenge.period, coverRef: challenge.coverRef,
                  createdByName: challenge.createdByName, memberCount: others.count + 1,
                  memberNames: others.prefix(3).map(\.name), maxMembers: 50)
    }
}
