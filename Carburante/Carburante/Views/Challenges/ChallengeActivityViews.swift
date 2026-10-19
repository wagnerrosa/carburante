//
//  ChallengeActivityViews.swift
//  Carburante
//
//  Atividade (linha do tempo dos abastecimentos da turma) e os registros de
//  um participante — a conferência entre amigos (PLAN/desafios.md §Telas).
//  Tudo nasce de um abastecimento: o hodômetro prova o km, a foto do desafio
//  é a graça.
//

import SwiftUI

/// Foto aberta em tela cheia.
struct ViewedPhoto: Identifiable {
    let id = UUID()
    let image: UIImage
    let title: String
}

// MARK: - Atividade

struct ChallengeActivityFeed: View {
    let challenge: Challenge
    var onReact: (String, ChallengeEntry) -> Void = { _, _ in }
    /// "Outro emoji": o teclado mora fora da rolagem (`ChallengeBoard`).
    var onMoreEmoji: (ChallengeEntry) -> Void = { _ in }

    /// Agrupado por dia, mais novo primeiro (dia relativo do Mail).
    private var days: [(date: Date, entries: [ChallengeEntry])] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: challenge.entries) { calendar.startOfDay(for: $0.date) }
        return groups.keys.sorted(by: >).map { day in
            (day, groups[day, default: []].sorted { $0.date > $1.date })
        }
    }

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 20) {
            if challenge.entries.isEmpty {
                ContentUnavailableView {
                    Label("Nenhum abastecimento ainda", systemImage: "fuelpump")
                } description: {
                    Text("Os abastecimentos da turma neste desafio aparecem aqui.")
                }
            }
            ForEach(days, id: \.date) { day in
                VStack(alignment: .leading, spacing: 8) {
                    Text(AppFormat.relativeDay(day.date))
                        .font(.headline)
                        .padding(.horizontal, 4)
                        .accessibilityAddTraits(.isHeader)
                    VStack(spacing: 0) {
                        ForEach(Array(day.entries.enumerated()), id: \.element.id) { index, entry in
                            if index > 0 { Divider().padding(.leading, 16) }
                            if let standing = challenge.standing(for: entry.memberID) {
                                card(entry, standing)
                            }
                        }
                    }
                    .background(Color(.secondarySystemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
    }

    /// Topo do card abre o abastecimento (fotos grandes + conversa); o pé
    /// reage com 1 toque sem sair do mural.
    private func card(_ entry: ChallengeEntry, _ standing: ChallengeStanding) -> some View {
        let route = ChallengeRoute.entry(challenge: challenge.id, entry: entry.id)
        return VStack(alignment: .leading, spacing: 10) {
            NavigationLink(value: route) {
                ChallengeActivityRow(entry: entry, standing: standing)
            }
            .buttonStyle(.plain)
            ChallengeEntryFooter(challenge: challenge, entry: entry, commentsRoute: route,
                                 onReact: { onReact($0, entry) },
                                 onMoreEmoji: { onMoreEmoji(entry) })
        }
        .padding()
    }
}

/// Cabeçalho (piloto, +km, hora), foto do desafio e o motivo quando não somou.
/// O hodômetro só aparece na tela do abastecimento: no mural toda miniatura
/// seria igual — a prova fica a um toque.
struct ChallengeActivityRow: View {
    let entry: ChallengeEntry
    let standing: ChallengeStanding
    var showsOdometer = false
    /// Na tela do abastecimento as fotos abrem em tela cheia. No mural é nil:
    /// o topo do card inteiro é um toque só.
    var onOpenPhoto: ((ViewedPhoto) -> Void)?
    @Environment(\.dynamicTypeSize) private var typeSize

    /// Tamanhos de acessibilidade: a coluna da direita desce para baixo do nome.
    private var stacked: Bool { typeSize.isAccessibilitySize }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            let layout = stacked
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
                : AnyLayout(HStackLayout(spacing: 12))
            layout {
                standing.monogram(size: 36)
                VStack(alignment: .leading, spacing: 1) {
                    Text(standing.displayName)
                        .font(.body.weight(.semibold))
                    Text(entry.bike.model)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .lineLimit(stacked ? nil : 1)
                if !stacked { Spacer(minLength: 8) }
                // Coluna da direita em 2 linhas (Esportes/Bolsa): valor forte
                // em cima, cinza embaixo.
                VStack(alignment: stacked ? .leading : .trailing, spacing: 1) {
                    if let km = entry.km {
                        Text("+\(AppFormat.km(km))")
                            .font(.body.weight(.semibold))
                            .fontDesign(.rounded)
                            .monospacedDigit()
                    } else if let title = entry.statusTitle {
                        Text(title)
                            .foregroundStyle(.secondary)
                    }
                    Text(entry.date.formatted(.dateTime.hour().minute().locale(AppFormat.locale)))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            .accessibilityElement(children: .combine)

            if entry.challengePhotoRef != nil {
                openable(entry.challengePhotoRef, title: "Foto do desafio") {
                    Color.clear
                        .frame(height: 220)
                        .frame(maxWidth: .infinity)
                        .overlay { ChallengePhoto(ref: entry.challengePhotoRef) }
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .accessibilityLabel("Foto do desafio de \(standing.displayName)")
            }

            if let detail = entry.statusDetail {
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if showsOdometer, entry.odometerPhotoRef != nil {
                openable(entry.odometerPhotoRef, title: "Hodômetro") {
                    OdometerEvidence(entry: entry)
                }
                .accessibilityLabel("Foto do hodômetro, \(entry.odometerText)")
            }
        }
        .contentShape(.rect)
    }

    /// Foto que abre em tela cheia quando a tela deixa; senão, só a foto.
    @ViewBuilder
    private func openable<Content: View>(_ ref: String?, title: String,
                                         @ViewBuilder content: () -> Content) -> some View {
        if let onOpenPhoto {
            Button {
                if let image = ChallengeImageLoader.image(ref) {
                    onOpenPhoto(ViewedPhoto(image: image, title: title))
                }
            } label: {
                content()
            }
            .buttonStyle(.plain)
        } else {
            content()
        }
    }
}

// MARK: - Reações

/// Pé do card: reações à esquerda, comentários à direita (ocupa a linha que
/// sobrava ao lado, sem empilhar).
struct ChallengeEntryFooter: View {
    let challenge: Challenge
    let entry: ChallengeEntry
    /// No mural: o balão abre a conversa. nil na tela do abastecimento, onde
    /// a conversa vem logo abaixo — lá as reações quebram linha e mostram todas.
    var commentsRoute: ChallengeRoute?
    var onReact: (String) -> Void
    /// "Outro emoji": quem mostra a tela abre o teclado de emoji.
    var onMoreEmoji: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize

    /// No mural, até 4 emojis; o resto vira "+N" (tudo na tela do abastecimento).
    private let feedLimit = 4

    var body: some View {
        let tallies = challenge.reactionTallies(on: entry.id)
        let canReact = challenge.canReact(to: entry)
        if let commentsRoute {
            if typeSize.isAccessibilitySize {
                // Fonte grande: as cápsulas não cabem numa linha — quebram.
                ReactionFlowLayout(spacing: 6) {
                    feedReactions(tallies, canReact: canReact)
                    commentsButton(commentsRoute)
                }
            } else {
                HStack(spacing: 6) {
                    feedReactions(tallies, canReact: canReact)
                    Spacer(minLength: 8)
                    commentsButton(commentsRoute)
                }
            }
        } else if !tallies.isEmpty || canReact {
            VStack(alignment: .leading, spacing: 8) {
                ReactionFlowLayout(spacing: 6) {
                    ForEach(tallies) { chip($0, enabled: canReact) }
                    if canReact { picker }
                }
                if !tallies.isEmpty {
                    // Quem mandou o quê — a parte social da reação.
                    Text(tallies.map { "\($0.emoji) \($0.names.joined(separator: ", "))" }
                        .joined(separator: " · "))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    @ViewBuilder
    private func feedReactions(_ tallies: [ReactionTally], canReact: Bool) -> some View {
        ForEach(tallies.prefix(feedLimit)) { chip($0, enabled: canReact) }
        if tallies.count > feedLimit {
            Text("+\(tallies.count - feedLimit)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        if canReact { picker }
    }

    private var picker: some View {
        ReactionPicker(current: challenge.myReaction(on: entry.id), onReact: onReact, onMore: onMoreEmoji)
    }

    private func chip(_ tally: ReactionTally, enabled: Bool) -> some View {
        ReactionChip(tally: tally) { onReact(tally.emoji) }
            .allowsHitTesting(enabled)
    }

    private func commentsButton(_ route: ChallengeRoute) -> some View {
        let count = challenge.commentCount(on: entry.id)
        return NavigationLink(value: route) {
            HStack(spacing: 4) {
                Image(systemName: "bubble.left")
                if count > 0 { Text("\(count)").monospacedDigit() }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.vertical, 6)
            .padding(.leading, 12)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(count == 0 ? "Comentar" : count == 1 ? "1 comentário" : "\(count) comentários")
    }
}

/// Emoji + contagem numa cápsula; a sua em destaque (toque de novo tira).
struct ReactionChip: View {
    let tally: ReactionTally
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(tally.emoji)
                Text("\(tally.count)")
                    .font(.subheadline.weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(tally.includesMe ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(tally.includesMe ? AnyShapeStyle(.tint.opacity(0.15)) : AnyShapeStyle(Color(.tertiarySystemFill)),
                        in: Capsule())
            .overlay {
                if tally.includesMe { Capsule().strokeBorder(.tint, lineWidth: 1) }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        // O VoiceOver lê o nome do emoji sozinho.
        .accessibilityLabel("\(tally.emoji), \(tally.count)")
        .accessibilityValue(tally.includesMe ? "inclui a sua" : "")
    }
}

/// Botão de reagir: menu nativo com os 6 atalhos em linha e "Outro emoji"
/// (teclado de emoji) — o Tapback do iOS 18.
struct ReactionPicker: View {
    let current: String?
    let onReact: (String) -> Void
    let onMore: () -> Void

    var body: some View {
        Menu {
            Picker("Reagir", selection: Binding(
                get: { current },
                set: { if let emoji = $0 { onReact(emoji) } }
            )) {
                ForEach(ChallengeReaction.quick, id: \.self) { emoji in
                    Text(emoji).tag(Optional(emoji))
                }
            }
            .pickerStyle(.palette)
            // Escolheu, fecha (Tapback). A paleta, sozinha, deixa o menu aberto.
            .menuActionDismissBehavior(.enabled)
            Button("Outro emoji", systemImage: "face.smiling", action: onMore)
        } label: {
            HStack(spacing: 1) {
                Image(systemName: "face.smiling")
                Image(systemName: "plus")
                    .font(.caption2.weight(.bold))
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color(.tertiarySystemFill), in: Capsule())
            .contentShape(Capsule())
        }
        .accessibilityLabel("Reagir")
    }
}

/// Quebra linha quando os chips não cabem (tela do abastecimento, fonte grande).
struct ReactionFlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, width: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            width = max(width, x + size.width)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

/// Miniatura do hodômetro + leitura — a prova do km. "da galeria" quando não
/// veio da câmera: o amigo julga.
struct OdometerEvidence: View {
    let entry: ChallengeEntry

    var body: some View {
        HStack(spacing: 10) {
            Color.clear
                .frame(width: 40, height: 40)
                .overlay { ChallengePhoto(ref: entry.odometerPhotoRef, placeholderSymbol: "gauge.with.dots.needle.67percent") }
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text("Hodômetro")
                    .font(.subheadline)
                Text(entry.odometerText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(.rect)
    }
}

extension ChallengeEntry {
    /// "22.035 km" ou "22.035 km · da galeria".
    var odometerText: String {
        let reading = AppFormat.km(odometer)
        return odometerFromGallery ? "\(reading) · da galeria" : reading
    }
}

// MARK: - Registros do participante

struct ChallengeParticipantView: View {
    let challenge: Challenge
    let standing: ChallengeStanding
    @Environment(\.dynamicTypeSize) private var typeSize

    private var entries: [ChallengeEntry] {
        challenge.entries(of: standing.id).sorted { $0.date > $1.date }
    }

    var body: some View {
        List {
            Section {
                VStack(spacing: 6) {
                    standing.monogram(size: 72, ring: Color(.systemGroupedBackground))
                        .padding(.bottom, 4)
                    Text(standing.displayName)
                        .font(.title2.weight(.bold))
                    Text(standing.bikes.map(\.label).joined(separator: " · "))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
                .accessibilityElement(children: .combine)
            }

            Section {
                if typeSize.isAccessibilitySize {
                    // Fonte grande: uma linha por número ("abastecimentos" não
                    // cabe num terço da tela).
                    stat("\(standing.rank)º", "lugar")
                    stat(AppFormat.odometer(standing.km), "km")
                    stat("\(standing.fuelUps)", standing.fuelUps == 1 ? "abastecimento" : "abastecimentos")
                } else {
                    HStack(spacing: 0) {
                        stat("\(standing.rank)º", "lugar")
                        Divider()
                        stat(AppFormat.odometer(standing.km), "km")
                        Divider()
                        stat("\(standing.fuelUps)", standing.fuelUps == 1 ? "abastecimento" : "abastecimentos")
                    }
                    .padding(.vertical, 4)
                }
            }

            Section {
                ForEach(entries) { entry in
                    NavigationLink(value: ChallengeRoute.entry(challenge: challenge.id, entry: entry.id)) {
                        ParticipantEntryRow(entry: entry, showsBike: standing.bikes.count > 1,
                                            commentCount: challenge.commentCount(on: entry.id))
                    }
                }
            } header: {
                Text("Abastecimentos neste desafio")
            } footer: {
                Text("Só contam abastecimentos registrados na hora, com foto do hodômetro. O km de cada trecho é dividido pelos dias: o que cruza o início ou o fim do desafio entra só com a parte de dentro.")
            }
        }
        .navigationTitle(standing.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !standing.isMe {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Denunciar nome", systemImage: "exclamationmark.bubble") {}
                        Button("Bloquear", systemImage: "hand.raised") {}
                        Button("Remover do desafio", systemImage: "person.badge.minus") {}
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                    .accessibilityLabel("Mais")
                }
            }
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3.weight(.semibold))
                .fontDesign(.rounded)
                .monospacedDigit()
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

/// Linha de um abastecimento do participante (§6: máx. 2 linhas). Miniatura
/// do hodômetro à esquerda varia de linha para linha — é a prova.
struct ParticipantEntryRow: View {
    let entry: ChallengeEntry
    var showsBike = false
    var commentCount = 0
    @Environment(\.dynamicTypeSize) private var typeSize

    private var detail: String {
        if case .counted = entry.status {
            return showsBike ? "\(entry.bike.model) · \(entry.odometerText)" : entry.odometerText
        }
        return entry.statusDetail ?? entry.odometerText
    }

    var body: some View {
        HStack(spacing: 12) {
            Color.clear
                .frame(width: 44, height: 44)
                .overlay {
                    if entry.odometerPhotoRef != nil {
                        ChallengePhoto(ref: entry.odometerPhotoRef, placeholderSymbol: "gauge.with.dots.needle.67percent")
                    } else {
                        Rectangle()
                            .fill(Color(.tertiarySystemFill))
                            .overlay {
                                Image(systemName: "camera.badge.ellipsis")
                                    .foregroundStyle(.tertiary)
                            }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(AppFormat.relativeDay(entry.date))
                    if entry.challengePhotoRef != nil {
                        Image(systemName: "photo")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    if commentCount > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "bubble.left")
                            Text("\(commentCount)").monospacedDigit()
                        }
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    }
                }
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    // 3 linhas: a explicação de "Sem foto" não pode cortar (o chevron come largura).
                    .lineLimit(typeSize.isAccessibilitySize ? nil : 3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            if let km = entry.km {
                RowValue(value: "+\(AppFormat.odometer(km))", unit: "km")
            } else if let title = entry.statusTitle {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
        }
        .contentShape(.rect)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        var parts = [AppFormat.relativeDay(entry.date)]
        if let km = entry.km { parts.append("mais \(AppFormat.km(km))") }
        else if let title = entry.statusTitle { parts.append(title) }
        parts.append(detail)
        if entry.challengePhotoRef != nil { parts.append("com foto do desafio") }
        if commentCount > 0 { parts.append(commentCount == 1 ? "1 comentário" : "\(commentCount) comentários") }
        return parts.joined(separator: ". ")
    }
}

// MARK: - Abastecimento (fotos + comentários)

/// Um abastecimento do mural: fotos em tela cheia, reações e a conversa da turma
/// (padrão Álbuns Compartilhados do Fotos). Só texto, curto, só quem está no
/// desafio vê. Sem resposta encadeada nem edição: apagou, escreve de novo.
struct ChallengeEntryView: View {
    let challenge: Challenge
    let entry: ChallengeEntry
    let standing: ChallengeStanding
    var onPost: (String) -> Void = { _ in }
    var onDelete: (ChallengeComment) -> Void = { _ in }
    var onReact: (String) -> Void = { _ in }

    @State private var draft = ""
    @State private var pickingEmoji = false
    @State private var viewing: ViewedPhoto?
    @State private var reporting: ChallengeComment?

    private var comments: [ChallengeComment] { challenge.comments(on: entry.id) }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 12) {
                        ChallengeActivityRow(entry: entry, standing: standing, showsOdometer: true) { viewing = $0 }
                        ChallengeEntryFooter(challenge: challenge, entry: entry,
                                             onReact: onReact, onMoreEmoji: { pickingEmoji = true })
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                    VStack(alignment: .leading, spacing: 8) {
                        if !comments.isEmpty {
                            Text("Comentários")
                                .font(.headline)
                                .padding(.horizontal, 4)
                                .accessibilityAddTraits(.isHeader)
                            VStack(spacing: 0) {
                                ForEach(Array(comments.enumerated()), id: \.element.id) { index, comment in
                                    if index > 0 { Divider().padding(.leading, 58) }
                                    commentRow(comment)
                                }
                            }
                            .background(Color(.secondarySystemGroupedBackground),
                                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        Text("Só quem está no desafio vê os comentários.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                    }
                    .id("bottom")
                }
                .padding()
            }
            .onChange(of: comments.count) { old, new in
                if new > old { withAnimation { proxy.scrollTo("bottom", anchor: .bottom) } }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color(.systemGroupedBackground))
        .background { EmojiKeyboard(isPresented: $pickingEmoji, onPick: onReact).frame(width: 1, height: 1) }
        .safeAreaInset(edge: .bottom) {
            CommentComposer(draft: $draft) {
                guard let text = ChallengeComment.cleaned(draft) else { return }
                onPost(text)
                draft = ""
            }
        }
        // Como no Fotos: o dia é o título.
        .navigationTitle(AppFormat.relativeDay(entry.date))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .sheet(item: $viewing) { PhotoViewerSheet(image: $0.image, title: $0.title) }
        .confirmationDialog("Denunciar comentário?", isPresented: Binding(
            get: { reporting != nil },
            set: { if !$0 { reporting = nil } }
        ), titleVisibility: .visible) {
            Button("Denunciar", role: .destructive) { reporting = nil }
        } message: {
            Text("A equipe do Carburante analisa e pode remover o comentário.")
        }
    }

    private func commentRow(_ comment: ChallengeComment) -> some View {
        let author = challenge.standing(for: comment.memberID)
        return HStack(alignment: .top, spacing: 10) {
            // Sem selo da marca: na conversa, a moto não importa.
            PilotMonogram(initials: author?.initials ?? "?", make: nil, size: 32)
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(author?.displayName ?? "Ex-participante")
                        .font(.subheadline.weight(.semibold))
                    Text(comment.date, format: .relative(presentation: .named, unitsStyle: .abbreviated))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(comment.text)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .contextMenu {
            Button("Copiar", systemImage: "doc.on.doc") {
                UIPasteboard.general.string = comment.text
            }
            if comment.memberID != challenge.me?.id {
                Button("Denunciar", systemImage: "exclamationmark.bubble") { reporting = comment }
            }
            if challenge.canDelete(comment) {
                Button("Apagar", systemImage: "trash", role: .destructive) { onDelete(comment) }
            }
        }
    }
}

/// Barra de escrever no pé da tela (padrão Mensagens). Corta no limite e só
/// mostra o contador perto dele.
struct CommentComposer: View {
    @Binding var draft: String
    let onSend: () -> Void

    private var canSend: Bool { ChallengeComment.cleaned(draft) != nil }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("Comentar", text: $draft, axis: .vertical)
                .lineLimit(1...5)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color(.secondarySystemGroupedBackground),
                            in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color(.separator), lineWidth: 0.5)
                }
            VStack(spacing: 2) {
                if let left = ChallengeComment.remaining(draft) {
                    Text("\(left)")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(left == 0 ? Color.red : Color.secondary)
                        .accessibilityLabel("Faltam \(left) caracteres")
                }
                Button(action: onSend) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 30))
                }
                .disabled(!canSend)
                .accessibilityLabel("Enviar")
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
        .onChange(of: draft) { _, new in
            if new.count > ChallengeComment.maxLength {
                draft = String(new.prefix(ChallengeComment.maxLength))
            }
        }
    }
}
