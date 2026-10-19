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
    /// O que a aba mostra. Ao vivo = cópia do `ChallengeService` (comentar e
    /// reagir ainda mexem só aqui até a D7); D0 = dados fictícios em memória.
    @State var challenges: [Challenge]
    /// Tela inicial (protótipo D0 abre direto em cada tela para os prints).
    var start: StartScreen = .board
    /// Dados do servidor. false = protótipo D0.
    var isLive = false

    enum StartScreen: Equatable {
        case board, activity, details, participant(UUID), entry(UUID), invite(anonymous: Bool), form
    }

    private var service: ChallengeService { .shared }
    private var sync: SyncService { .shared }

    @State private var selectedID: UUID?
    @State private var path: [ChallengeRoute] = []
    @State private var invite: InviteRequest?
    @State private var showingNewChallenge = false
    @State private var showingCodeEntry = false
    @State private var showingAccount = false
    /// O que fazer depois de entrar com a Apple (criar desafio).
    @State private var afterAccount: (() -> Void)?
    @State private var code = ""
    @State private var isCheckingCode = false
    @State private var alert: ChallengeAlert?
    @State private var didApplyStart = false

    private var active: [Challenge] { challenges.filter { !$0.isFinished() } }
    private var finished: [Challenge] { challenges.filter { $0.isFinished() } }

    private var selected: Challenge? {
        active.first { $0.id == selectedID } ?? active.first
    }

    /// Recarrega quando a conta muda (entrou com a Apple, saiu).
    private var accountKey: String {
        "\(sync.userID?.uuidString ?? "-")|\(sync.isAnonymous)"
    }

    var body: some View {
        withAlerts(withSheets(navigation))
            .task { applyStart() }
            .task(id: accountKey) {
                guard isLive else { return }
                await service.refresh()
            }
            .onChange(of: service.challenges) { _, loaded in
                if isLive { challenges = loaded }
            }
    }

    private var navigation: some View {
        NavigationStack(path: $path) {
            Group {
                if let selected {
                    ChallengeBoard(challenge: selected,
                                   segment: start == .activity ? .activity : .standings,
                                   onReact: { react($0, on: $1, in: selected.id) })
                        .id(selected.id)
                } else if isLive && challenges.isEmpty && service.updatedAt == nil && service.state != .loaded {
                    loadingOrOffline
                } else {
                    emptyState
                }
            }
            .refreshable { if isLive { await service.refresh() } }
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
    }

    private func withSheets(_ content: some View) -> some View {
        content
        .sheet(item: $invite) { request in
            ChallengeInviteView(invite: request.invite, previewAnonymous: request.previewAnonymous) { name in
                try await join(request.invite, as: name)
            } onOpen: {
                selectedID = request.invite.id
                path = []
            }
        }
        .sheet(isPresented: $showingNewChallenge) {
            ChallengeFormView(prefillName: start == .form ? "Turma da serra" : "") { name, period, pilot in
                try await create(name, period: period, pilotName: pilot)
            }
        }
        .sheet(isPresented: $showingAccount, onDismiss: {
            // Entrou com a Apple: segue para o que ia fazer.
            if !sync.isAnonymous, let afterAccount {
                DispatchQueue.main.async { afterAccount() }
            }
            afterAccount = nil
        }) {
            ChallengeAccountSheet()
        }
    }

    private func withAlerts(_ content: some View) -> some View {
        content
        .alert("Entrar com código", isPresented: $showingCodeEntry) {
            TextField("Código", text: $code)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
            Button("Cancelar", role: .cancel) { code = "" }
            Button("Continuar") {
                openCode(code)
                code = ""
            }
        } message: {
            Text("O código está no convite que a turma mandou.")
        }
        .alert(alert?.title ?? "", isPresented: Binding(
            get: { alert != nil },
            set: { if !$0 { alert = nil } }
        ), presenting: alert) { _ in
            Button("OK", role: .cancel) {}
        } message: { alert in
            Text(alert.message)
        }
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
            requireAccount { showingNewChallenge = true }
        } label: {
            Label("Criar desafio", systemImage: "plus")
        }
        Button {
            showingCodeEntry = true
        } label: {
            Label("Entrar com código", systemImage: "number")
        }
        .disabled(isCheckingCode)
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
                    Button("Criar desafio") { requireAccount { showingNewChallenge = true } }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    Button("Entrar com código") { showingCodeEntry = true }
                        .disabled(isCheckingCode)
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

    /// 1ª carga: esperando o servidor, ou sem conexão.
    @ViewBuilder
    private var loadingOrOffline: some View {
        if case .failed(let error) = service.state {
            ContentUnavailableView {
                Label("Desafios indisponíveis", systemImage: "icloud.slash")
            } description: {
                Text(error.message)
            } actions: {
                Button("Tentar de novo") { Task { await service.refresh() } }
            }
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: Navegação

    @ViewBuilder
    private func destination(_ route: ChallengeRoute) -> some View {
        switch route {
        case .board(let id):
            if let challenge = challenge(id) {
                ChallengeBoard(challenge: challenge, segment: .standings,
                               onReact: { react($0, on: $1, in: id) })
                    .navigationTitle(challenge.name)
                    .navigationBarTitleDisplayMode(.inline)
            }
        case .details(let id):
            if let challenge = challenge(id) {
                // Trocar o código chega com a D8 (função nova no servidor).
                ChallengeDetailsView(challenge: challenge,
                                     onNewCode: isLive ? nil : { update(id) { $0.code = InviteCode.random() } },
                                     onLeave: { leave(id) })
            }
        case .participant(let challengeID, let memberID):
            if let challenge = challenge(challengeID), let standing = challenge.standing(for: memberID) {
                ChallengeParticipantView(challenge: challenge, standing: standing)
            }
        case .entry(let challengeID, let entryID):
            if let challenge = challenge(challengeID),
               let entry = challenge.entries.first(where: { $0.id == entryID }),
               let standing = challenge.standing(for: entry.memberID) {
                ChallengeEntryView(challenge: challenge, entry: entry, standing: standing) { text in
                    update(challengeID) { c in
                        guard let me = c.me else { return }
                        c.comments.append(ChallengeComment(id: UUID(), entryID: entryID, memberID: me.id,
                                                           text: text, date: Date()))
                    }
                } onDelete: { comment in
                    update(challengeID) { $0.comments.removeAll { $0.id == comment.id } }
                } onReact: { reaction in
                    react(reaction, on: entry, in: challengeID)
                } onVote: { vote in
                    Haptics.selection()
                    update(challengeID) { $0.vote(vote, on: entry) }
                }
            }
        }
    }

    private func challenge(_ id: UUID) -> Challenge? {
        challenges.first { $0.id == id }
    }

    private func react(_ emoji: String, on entry: ChallengeEntry, in id: UUID) {
        Haptics.selection()
        update(id) { $0.react(emoji, on: entry) }
    }

    private func update(_ id: UUID, _ change: (inout Challenge) -> Void) {
        guard let index = challenges.firstIndex(where: { $0.id == id }) else { return }
        change(&challenges[index])
    }

    // MARK: Servidor

    /// Criar exige conta Apple; anônimo passa antes pela folha da Apple.
    private func requireAccount(_ action: @escaping () -> Void) {
        guard isLive, sync.isAnonymous else { return action() }
        afterAccount = action
        showingAccount = true
    }

    private func create(_ name: String, period: ChallengePeriod, pilotName: String) async throws(ChallengeError) {
        guard isLive else { return }
        let id = try await service.create(name: name, period: period, displayName: pilotName)
        selectedID = id
        path = []
    }

    /// Código digitado → prévia do convite. Anônimo também vê a prévia (a
    /// Apple entra na própria prévia).
    private func openCode(_ typed: String) {
        guard isLive else {
            // D0: procura nos desafios em memória.
            let normalized = InviteCode.normalized(typed)
            if let match = challenges.first(where: { $0.code == normalized }) ?? selected {
                invite = InviteRequest(invite: ChallengeInvite(challenge: match), previewAnonymous: false)
            }
            return
        }
        guard InviteCode.normalized(typed) != nil else {
            alert = ChallengeAlert(title: "Código incompleto",
                                   message: "São 8 letras e números, como K7QM-4XPR.")
            return
        }
        isCheckingCode = true
        Task {
            do {
                if let found = try await service.preview(code: typed) {
                    invite = InviteRequest(invite: found)
                } else {
                    alert = ChallengeAlert(title: "Código não encontrado",
                                           message: "Confira o código com quem te convidou.")
                }
            } catch {
                alert = ChallengeAlert(title: "Não deu para abrir o convite",
                                       message: ChallengeService.challengeError(error).message)
            }
            isCheckingCode = false
        }
    }

    private func join(_ invite: ChallengeInvite, as name: String) async throws(ChallengeError) {
        guard isLive else { return }
        // nil = o código foi trocado entre a prévia e o "Entrar".
        guard try await service.join(code: invite.code, displayName: name) != nil else {
            throw .notFound
        }
        selectedID = invite.id
        path = []
    }

    private func leave(_ id: UUID) {
        guard isLive else { return }
        Task {
            do {
                try await service.leave(id)
                path = []
                Haptics.success()
            } catch {
                alert = ChallengeAlert(title: "Não deu para sair do desafio",
                                       message: ChallengeService.challengeError(error).message)
            }
        }
    }

    private func applyStart() {
        guard !didApplyStart else { return }
        didApplyStart = true
        guard let first = selected else { return }
        switch start {
        case .board, .activity: break
        case .details: path = [.details(first.id)]
        case .participant(let member): path = [.participant(challenge: first.id, member: member)]
        case .entry(let entry): path = [.entry(challenge: first.id, entry: entry)]
        case .invite(let anonymous):
            invite = InviteRequest(invite: ChallengeInvite(challenge: first), previewAnonymous: anonymous)
        case .form: showingNewChallenge = true
        }
    }
}

private struct ChallengeAlert {
    let title: String
    let message: String
}

private struct InviteRequest: Identifiable {
    let id = UUID()
    let invite: ChallengeInvite
    /// D0: força (ou não) o passo da Apple. nil = conta de verdade.
    var previewAnonymous: Bool? = nil
}

// MARK: - Desafio (capa + segmentado)

struct ChallengeBoard: View {
    let challenge: Challenge
    @State var segment: Segment
    var onReact: (String, ChallengeEntry) -> Void = { _, _ in }
    /// Abastecimento esperando um emoji do teclado ("Outro emoji").
    @State private var emojiTarget: ChallengeEntry?

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
                    ChallengeActivityFeed(challenge: challenge, onReact: onReact,
                                          onMoreEmoji: { emojiTarget = $0 })
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        // Fora da rolagem e com 1 pt: dentro dela, o UIKit rolava a lista
        // para "mostrar" o campo quando o teclado abria.
        .background {
            EmojiKeyboard(isPresented: Binding(
                get: { emojiTarget != nil },
                set: { if !$0 { emojiTarget = nil } }
            )) { emoji in
                if let emojiTarget { onReact(emoji, emojiTarget) }
            }
            .frame(width: 1, height: 1)
        }
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
    /// nil = trocar o código ainda não existe no servidor (D8).
    var onNewCode: (() -> Void)? = nil
    var onLeave: () -> Void = {}
    @State private var confirmingLeave = false
    @State private var confirmingNewCode = false

    private var code: String { InviteCode.formatted(challenge.code) }

    var body: some View {
        List {
            Section {
                LabeledContent("Período", value: AppFormat.dayRange(challenge.startDate, challenge.endDate))
                LabeledContent("Situação", value: AppFormat.sentenceCased(challenge.phaseText()))
                if challenge.createdByMe {
                    LabeledContent("Criado por", value: "Você")
                } else if let createdBy = challenge.createdByName {
                    LabeledContent("Criado por", value: createdBy)
                }
                LabeledContent("Pilotos", value: "\(challenge.memberCount)")
            }

            Section {
                ShareLink(item: challenge.inviteURL, subject: Text(challenge.name)) {
                    Label("Convidar", systemImage: "person.badge.plus")
                }
                LabeledContent("Código", value: code)
                    .contextMenu {
                        Button("Copiar", systemImage: "doc.on.doc") {
                            UIPasteboard.general.string = code
                        }
                    }
                if challenge.createdByMe, let onNewCode {
                    Button("Trocar código") { confirmingNewCode = true }
                        .confirmationDialog("Trocar o código?", isPresented: $confirmingNewCode,
                                            titleVisibility: .visible) {
                            Button("Trocar código") {
                                onNewCode()
                                Haptics.success()
                            }
                        } message: {
                            Text("O link e o código atuais param de funcionar. Quem já está no desafio continua.")
                        }
                }
            } footer: {
                Text(challenge.createdByMe
                     ? "Quem recebe o link ou o código entra no desafio. Se o convite foi parar onde não devia, troque o código."
                     : "Quem recebe o link ou o código entra no desafio.")
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
            Button("Sair do desafio", action: onLeave)
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
