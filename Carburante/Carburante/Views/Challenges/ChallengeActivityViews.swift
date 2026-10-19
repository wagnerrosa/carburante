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
    @State private var viewing: ViewedPhoto?

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
                                ChallengeActivityRow(entry: entry, standing: standing) { viewing = $0 }
                            }
                        }
                    }
                    .background(Color(.secondarySystemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
        .sheet(item: $viewing) { PhotoViewerSheet(image: $0.image, title: $0.title) }
    }
}

struct ChallengeActivityRow: View {
    let entry: ChallengeEntry
    let standing: ChallengeStanding
    var onOpenPhoto: (ViewedPhoto) -> Void
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
                Button {
                    if let image = ChallengeImageLoader.image(entry.challengePhotoRef) {
                        onOpenPhoto(ViewedPhoto(image: image, title: "Foto do desafio"))
                    }
                } label: {
                    Color.clear
                        .frame(height: 220)
                        .frame(maxWidth: .infinity)
                        .overlay { ChallengePhoto(ref: entry.challengePhotoRef) }
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Foto do desafio de \(standing.displayName)")
            }

            if let detail = entry.statusDetail {
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if entry.odometerPhotoRef != nil {
                OdometerEvidenceButton(entry: entry, onOpenPhoto: onOpenPhoto)
            }
        }
        .padding()
    }
}

/// Miniatura do hodômetro + leitura — a prova do km. "da galeria" quando não
/// veio da câmera: o amigo julga.
struct OdometerEvidenceButton: View {
    let entry: ChallengeEntry
    var onOpenPhoto: (ViewedPhoto) -> Void

    var body: some View {
        Button {
            if let image = ChallengeImageLoader.image(entry.odometerPhotoRef) {
                onOpenPhoto(ViewedPhoto(image: image, title: "Hodômetro"))
            }
        } label: {
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
        .buttonStyle(.plain)
        .accessibilityLabel("Foto do hodômetro, \(entry.odometerText)")
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
    @State private var viewing: ViewedPhoto?
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
                    Button {
                        if let image = ChallengeImageLoader.image(entry.odometerPhotoRef) {
                            viewing = ViewedPhoto(image: image, title: "Hodômetro")
                        }
                    } label: {
                        ParticipantEntryRow(entry: entry, showsBike: standing.bikes.count > 1)
                    }
                    .buttonStyle(.plain)
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
        .sheet(item: $viewing) { PhotoViewerSheet(image: $0.image, title: $0.title) }
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
                }
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(typeSize.isAccessibilitySize ? nil : 2)
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
        return parts.joined(separator: ". ")
    }
}
