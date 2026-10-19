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
                                // O card inteiro abre o abastecimento (fotos grandes + comentários).
                                NavigationLink(value: ChallengeRoute.entry(challenge: challenge.id, entry: entry.id)) {
                                    ChallengeActivityRow(entry: entry, standing: standing,
                                                         commentCount: challenge.commentCount(on: entry.id))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .background(Color(.secondarySystemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
    }
}

struct ChallengeActivityRow: View {
    let entry: ChallengeEntry
    let standing: ChallengeStanding
    /// No mural: rodapé "Comentar" / "2 comentários". nil na tela do abastecimento,
    /// onde a conversa vem logo abaixo.
    var commentCount: Int?
    /// Na tela do abastecimento as fotos abrem em tela cheia. No mural é nil:
    /// o card inteiro é um toque só.
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

            if entry.odometerPhotoRef != nil {
                openable(entry.odometerPhotoRef, title: "Hodômetro") {
                    OdometerEvidence(entry: entry)
                }
                .accessibilityLabel("Foto do hodômetro, \(entry.odometerText)")
            }

            if let commentCount {
                Label(commentText(commentCount), systemImage: "bubble.left")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
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

    private func commentText(_ count: Int) -> String {
        switch count {
        case 0: "Comentar"
        case 1: "1 comentário"
        default: "\(count) comentários"
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

/// Um abastecimento do mural: fotos em tela cheia e a conversa da turma
/// (padrão Álbuns Compartilhados do Fotos). Só texto, curto, só quem está no
/// desafio vê. Sem resposta encadeada nem edição: apagou, escreve de novo.
struct ChallengeEntryView: View {
    let challenge: Challenge
    let entry: ChallengeEntry
    let standing: ChallengeStanding
    var onPost: (String) -> Void = { _ in }
    var onDelete: (ChallengeComment) -> Void = { _ in }

    @State private var draft = ""
    @State private var viewing: ViewedPhoto?
    @State private var reporting: ChallengeComment?

    private var comments: [ChallengeComment] { challenge.comments(on: entry.id) }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ChallengeActivityRow(entry: entry, standing: standing) { viewing = $0 }
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
