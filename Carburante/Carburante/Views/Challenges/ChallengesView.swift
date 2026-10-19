//
//  ChallengesView.swift
//  Carburante
//
//  Aba Desafios (PLAN/desafios.md §Telas). Um desafio por vez, trocado pela
//  pílula no topo — mesmo padrão "⛽ | moto ▾" do Resumo; no Esportes é o
//  "Fórmula 1 ▾". Capa, "Classificação | Atividade" e a tabela.
//

import SwiftUI

struct ChallengesView: View {
    let challenges: [Challenge]
    /// Tela inicial (protótipo D0 abre direto em cada tela para os prints).
    var start: StartScreen = .board

    enum StartScreen: Equatable {
        case board, activity, details, participant(UUID), invite(anonymous: Bool), form
    }

    @State private var selectedID: UUID?
    @State private var path: [ChallengeRoute] = []
    @State private var invite: InviteRequest?
    @State private var showingNewChallenge = false
    @State private var showingCodeEntry = false
    @State private var code = ""
    @State private var didApplyStart = false

    private var active: [Challenge] { challenges.filter { !$0.isFinished() } }
    private var finished: [Challenge] { challenges.filter { $0.isFinished() } }

    private var selected: Challenge? {
        active.first { $0.id == selectedID } ?? active.first
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if let selected {
                    ChallengeBoard(challenge: selected,
                                   segment: start == .activity ? .activity : .standings)
                        .id(selected.id)
                } else {
                    emptyState
                }
            }
            .navigationTitle("Desafios")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if let selected {
                        challengeControl(selected)
                    } else {
                        addMenu
                    }
                }
            }
            .navigationDestination(for: ChallengeRoute.self, destination: destination)
        }
        .sheet(item: $invite) { request in
            ChallengeInviteView(challenge: request.challenge, isAnonymous: request.anonymous)
        }
        .sheet(isPresented: $showingNewChallenge) {
            ChallengeFormView(prefillName: start == .form ? "Turma da serra" : "")
        }
        .alert("Entrar com código", isPresented: $showingCodeEntry) {
            TextField("Código", text: $code)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
            Button("Cancelar", role: .cancel) { code = "" }
            Button("Continuar") {
                if let match = challenges.first(where: { $0.code == code.uppercased() }) ?? selected {
                    invite = InviteRequest(challenge: match, anonymous: false)
                }
                code = ""
            }
        } message: {
            Text("O código está no convite que a turma mandou.")
        }
        .task { applyStart() }
    }

    // MARK: Toolbar

    /// Controle duplo (padrão do Resumo): convidar a 1 toque | menu do desafio.
    private func challengeControl(_ challenge: Challenge) -> some View {
        HStack(spacing: 0) {
            ShareLink(item: challenge.inviteURL,
                      subject: Text(challenge.name),
                      message: Text("Bora pro desafio \(challenge.name) no Carburante? Os km saem dos abastecimentos.")) {
                Image(systemName: "person.badge.plus")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.tint)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Convidar")

            Divider().frame(height: 20)

            Menu {
                Picker("Desafio", selection: Binding(
                    get: { challenge.id },
                    set: { selectedID = $0; Haptics.selection() }
                )) {
                    ForEach(active) { Text($0.name).tag($0.id) }
                }
                if !finished.isEmpty {
                    Section("Encerrados") {
                        ForEach(finished) { done in
                            Button {
                                path.append(.board(done.id))
                            } label: {
                                Label(done.name, systemImage: "trophy")
                            }
                        }
                    }
                }
                Divider()
                createAndJoinButtons
            } label: {
                HStack(spacing: 6) {
                    Text(challenge.name)
                        .lineLimit(1)
                        .frame(maxWidth: 160)
                        .fixedSize()
                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.bold))
                }
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Trocar de desafio")
            .accessibilityValue(challenge.name)
        }
    }

    private var addMenu: some View {
        Menu {
            createAndJoinButtons
        } label: {
            Image(systemName: "plus")
        }
        .accessibilityLabel("Novo desafio")
    }

    @ViewBuilder
    private var createAndJoinButtons: some View {
        Button {
            showingNewChallenge = true
        } label: {
            Label("Criar desafio", systemImage: "plus")
        }
        Button {
            showingCodeEntry = true
        } label: {
            Label("Entrar com código", systemImage: "number")
        }
    }

    // MARK: Sem desafio ativo

    private var emptyState: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ContentUnavailableView {
                    Label("Nenhum desafio ativo", systemImage: "flag.checkered")
                } description: {
                    Text("Num desafio, os km de cada abastecimento viram a classificação da turma.")
                } actions: {
                    Button("Criar desafio") { showingNewChallenge = true }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    Button("Entrar com código") { showingCodeEntry = true }
                }
                .padding(.top, 24)

                if !finished.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Encerrados")
                            .font(.title3.weight(.semibold))
                            .accessibilityAddTraits(.isHeader)
                        ForEach(finished) { done in
                            NavigationLink(value: ChallengeRoute.board(done.id)) {
                                FinishedChallengeCard(challenge: done)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: Navegação

    @ViewBuilder
    private func destination(_ route: ChallengeRoute) -> some View {
        switch route {
        case .board(let id):
            if let challenge = challenge(id) {
                ChallengeBoard(challenge: challenge, segment: .standings)
                    .navigationTitle(challenge.name)
                    .navigationBarTitleDisplayMode(.inline)
            }
        case .details(let id):
            if let challenge = challenge(id) {
                ChallengeDetailsView(challenge: challenge)
            }
        case .participant(let challengeID, let memberID):
            if let challenge = challenge(challengeID), let standing = challenge.standing(for: memberID) {
                ChallengeParticipantView(challenge: challenge, standing: standing)
            }
        }
    }

    private func challenge(_ id: UUID) -> Challenge? {
        challenges.first { $0.id == id }
    }

    private func applyStart() {
        guard !didApplyStart else { return }
        didApplyStart = true
        guard let first = selected else { return }
        switch start {
        case .board, .activity: break
        case .details: path = [.details(first.id)]
        case .participant(let member): path = [.participant(challenge: first.id, member: member)]
        case .invite(let anonymous): invite = InviteRequest(challenge: first, anonymous: anonymous)
        case .form: showingNewChallenge = true
        }
    }
}

private struct InviteRequest: Identifiable {
    let id = UUID()
    let challenge: Challenge
    let anonymous: Bool
}

// MARK: - Desafio (capa + segmentado)

struct ChallengeBoard: View {
    let challenge: Challenge
    @State var segment: Segment

    enum Segment: Hashable { case standings, activity }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                NavigationLink(value: ChallengeRoute.details(challenge.id)) {
                    ChallengeCoverCard(challenge: challenge)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Detalhes do desafio")

                Picker("Exibir", selection: $segment) {
                    Text("Classificação").tag(Segment.standings)
                    Text("Atividade").tag(Segment.activity)
                }
                .pickerStyle(.segmented)

                switch segment {
                case .standings:
                    ChallengeStandingsTable(challenge: challenge, finished: challenge.isFinished())
                    Text("Km dos abastecimentos registrados na hora, com foto do hodômetro. Toque em um piloto para conferir os registros.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                        .fixedSize(horizontal: false, vertical: true)
                case .activity:
                    ChallengeActivityFeed(challenge: challenge)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Encerrado (padrão Resultados do Esportes)

struct FinishedChallengeCard: View {
    let challenge: Challenge

    var body: some View {
        GroupedCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text(challenge.name)
                        .font(.headline)
                    Spacer()
                    Text(AppFormat.dayRange(challenge.startDate, challenge.endDate))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                ForEach(challenge.standings.prefix(3)) { s in
                    HStack(spacing: 8) {
                        Text("\(s.rank)")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(minWidth: 14, alignment: .leading)
                        Text(s.displayName)
                        if s.rank == 1 {
                            Image(systemName: "trophy.fill")
                                .foregroundStyle(.yellow)
                                .accessibilityLabel("Campeão")
                        }
                        Spacer()
                        Text(AppFormat.km(s.km))
                            .monospacedDigit()
                    }
                    .font(.subheadline)
                }
            }
        }
    }
}

// MARK: - Detalhes (tocar na capa)

struct ChallengeDetailsView: View {
    let challenge: Challenge
    @State private var confirmingLeave = false

    var body: some View {
        List {
            Section {
                LabeledContent("Período", value: AppFormat.dayRange(challenge.startDate, challenge.endDate))
                LabeledContent("Situação", value: AppFormat.sentenceCased(challenge.phaseText()))
                LabeledContent("Criado por", value: challenge.createdByName)
                LabeledContent("Pilotos", value: "\(challenge.memberCount)")
            }

            Section {
                ShareLink(item: challenge.inviteURL, subject: Text(challenge.name)) {
                    Label("Convidar", systemImage: "person.badge.plus")
                }
                LabeledContent("Código", value: challenge.code)
                    .contextMenu {
                        Button("Copiar", systemImage: "doc.on.doc") {
                            UIPasteboard.general.string = challenge.code
                        }
                    }
            } footer: {
                Text("Quem recebe o link ou o código entra no desafio.")
            }

            Section("Como funciona") {
                ChallengeRules()
            }

            Section {
                Button("Sair do desafio") { confirmingLeave = true }
            } footer: {
                Text("Seus abastecimentos continuam no app; só saem da classificação.")
            }
        }
        .navigationTitle(challenge.name)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Sair de \(challenge.name)?", isPresented: $confirmingLeave, titleVisibility: .visible) {
            Button("Sair do desafio") {}
        }
    }
}

/// As três regras do desafio — no convite e nos detalhes, mesmo texto.
struct ChallengeRules: View {
    var body: some View {
        rule("fuelpump.fill", "Os km saem dos seus abastecimentos, registrados na hora.")
        rule("camera.fill", "Só contam abastecimentos com foto do hodômetro.")
        rule("person.2.fill", "Os pilotos veem seus abastecimentos deste período e as fotos.")
    }

    private func rule(_ symbol: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(.tint)
                .frame(width: 24)
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
