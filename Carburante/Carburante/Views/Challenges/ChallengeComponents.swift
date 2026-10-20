//
//  ChallengeComponents.swift
//  Carburante
//
//  Peças dos Desafios (PLAN/desafios.md §Telas): capa, monograma do piloto,
//  tabela de classificação (padrão Esportes) e card do Resumo (§6b).
//

import SwiftUI

// MARK: - Imagens

/// Fotos do protótipo D0 (referência sem pasta = arquivo local em
/// Documents/ChallengePreview). As do servidor vêm do `ChallengeImageStore`.
enum ChallengeImageLoader {
    static func image(_ ref: String?) -> UIImage? {
        guard let ref else { return nil }
        #if DEBUG
        let url = URL.documentsDirectory.appending(path: "ChallengePreview/\(ref).jpg")
        return UIImage(contentsOfFile: url.path(percentEncoded: false))
        #else
        return nil
        #endif
    }
}

/// Foto de um abastecimento (hodômetro ou foto do desafio) preenchendo o
/// quadro. Do cache na hora; senão quadro neutro enquanto baixa do bucket
/// (a policy da turma libera). Sem foto ou sem acesso, o símbolo.
struct ChallengePhoto: View {
    let ref: String?
    var placeholderSymbol = "photo"
    /// Lado maior para decodificar (miniatura, mural). nil = inteira.
    var maxPixel: Int? = nil
    @State private var loaded: (ref: String, image: UIImage)?
    @State private var failedRef: String?

    /// Lado maior das miniaturas (44 pt em 3x, com folga).
    static let thumbnailPixels = 160
    /// Foto do mural (largura da tela em 3x).
    static let feedPixels = 1200

    private var store: ChallengeImageStore { .shared }

    private var image: UIImage? {
        // Ler `replacements` faz a foto trocada aparecer sem recarregar a tela.
        _ = store.replacements
        if let cached = store.cachedImage(ref, bucket: PhotoReference.bucket, maxPixel: maxPixel) { return cached }
        if let loaded, loaded.ref == ref { return loaded.image }
        return nil
    }

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle()
                    .fill(Color(.tertiarySystemFill))
                    .overlay {
                        if ref == nil || failedRef == ref {
                            Image(systemName: placeholderSymbol)
                                .font(.title2)
                                .foregroundStyle(.tertiary)
                        }
                    }
            }
        }
        .task(id: ref) { await load() }
    }

    /// Baixa (ou confere a cópia guardada, 1 vez por abertura do app).
    private func load() async {
        guard let ref else { return }
        if let image = await store.image(ref, bucket: PhotoReference.bucket, maxPixel: maxPixel) {
            loaded = (ref, image)
        } else {
            failedRef = ref
        }
    }
}

/// Capa do desafio. Sem foto = capa padrão com a arte do app (chama). Foto
/// do Storage: do cache na hora; senão um quadro neutro enquanto baixa (a
/// capa padrão piscando antes da foto pareceria outra capa).
struct ChallengeCoverImage: View {
    let ref: String?
    @State private var loaded: (ref: String, image: UIImage)?

    private var image: UIImage? {
        if let loaded, loaded.ref == ref { return loaded.image }
        return ChallengeImageStore.shared.cachedImage(ref)
    }

    var body: some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else if ChallengeCover.isRemote(ref) {
            Rectangle()
                .fill(Color(.tertiarySystemFill))
                .task(id: ref) {
                    guard let ref, let image = await ChallengeImageStore.shared.image(ref) else { return }
                    loaded = (ref, image)
                }
        } else {
            Self.defaultCover
        }
    }

    static var defaultCover: some View {
        BrandTheme.flame
            .overlay(alignment: .trailing) {
                Image(systemName: "flag.checkered")
                    .font(.system(size: 120, weight: .bold))
                    .foregroundStyle(.white.opacity(0.18))
                    .rotationEffect(.degrees(-12))
                    .offset(x: 20)
            }
    }
}

// MARK: - Piloto

/// Monograma (padrão Contatos) com o logo da marca da moto como selo — no
/// lugar da bandeira do Esportes. Sem foto de perfil na v1.
struct PilotMonogram: View {
    let initials: String
    let make: String?
    var size: CGFloat = 40
    /// Cor do anel do selo = fundo atrás do monograma.
    var ringColor = Color(.secondarySystemGroupedBackground)

    var body: some View {
        Text(initials)
            .font(.system(size: size * 0.38, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(
                LinearGradient(colors: [Color(.systemGray2), Color(.systemGray)],
                               startPoint: .top, endPoint: .bottom),
                in: Circle()
            )
            .overlay(alignment: .bottomTrailing) {
                if let make, let logo = BrandTheme.logoAsset(make: make) {
                    BrandLogoTile(assetName: logo, size: size * 0.38, tileShape: .circle)
                        .padding(2)
                        .background(ringColor, in: Circle())
                        .offset(x: size * 0.14, y: size * 0.14)
                }
            }
            .accessibilityHidden(true)
    }
}

extension ChallengeStanding {
    func monogram(size: CGFloat = 40, ring: Color = Color(.secondarySystemGroupedBackground)) -> PilotMonogram {
        PilotMonogram(initials: initials, make: badgeMake, size: size, ringColor: ring)
    }
}

// MARK: - Capa

/// Card de capa no topo do desafio (padrão card da Programação do Esportes):
/// foto, nome, período · prazo · pilotos.
struct ChallengeCoverCard: View {
    let challenge: Challenge
    @ScaledMetric(relativeTo: .title) private var height: CGFloat = 170

    var body: some View {
        // A foto vai num overlay: preenchendo direto, a largura dela (maior que
        // a tela em fonte grande) empurrava o layout para os lados.
        Color.clear
            .frame(height: height)
            .frame(maxWidth: .infinity)
            .overlay { ChallengeCoverImage(ref: challenge.coverRef) }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(challenge.name)
                        .font(.title2.weight(.bold))
                    Text(subtitle)
                        .font(.subheadline.weight(.medium))
                        .opacity(0.9)
                }
                .foregroundStyle(.white)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    LinearGradient(colors: [.clear, .black.opacity(0.65)],
                                   startPoint: .top, endPoint: .bottom)
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(challenge.name). \(subtitle)")
    }

    private var subtitle: String {
        [AppFormat.dayRange(challenge.startDate, challenge.endDate),
         challenge.phaseText(),
         challenge.pilotsText].joined(separator: " · ")
    }
}

// MARK: - Classificação

/// Tabela de classificação (padrão Esportes): posição, monograma com selo da
/// marca, nome + moto, colunas Abast. e KM. Sua linha em destaque.
struct ChallengeStandingsTable: View {
    let challenge: Challenge
    var finished = false

    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .body) private var rankWidth: CGFloat = 18
    @ScaledMetric(relativeTo: .body) private var fuelWidth: CGFloat = 42
    @ScaledMetric(relativeTo: .body) private var kmWidth: CGFloat = 58

    private var stacked: Bool { typeSize.isAccessibilitySize }

    var body: some View {
        VStack(spacing: 0) {
            if !stacked {
                HStack(spacing: 8) {
                    Text("Piloto")
                    Spacer()
                    Text("Abast.").frame(width: fuelWidth, alignment: .trailing)
                    Text("KM").frame(width: kmWidth, alignment: .trailing)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 6)
                .accessibilityHidden(true)
            }
            ForEach(Array(challenge.standings.enumerated()), id: \.element.id) { index, standing in
                if index > 0 {
                    Divider().padding(.leading, stacked ? 16 : 16 + rankWidth + 10 + 38 + 10)
                }
                NavigationLink(value: ChallengeRoute.participant(challenge: challenge.id, member: standing.id)) {
                    row(standing)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.bottom, 4)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func row(_ s: ChallengeStanding) -> some View {
        let trophy = finished && s.rank == 1
        return Group {
            if stacked {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 12) {
                        Text("\(s.rank)").font(.headline).monospacedDigit().foregroundStyle(.secondary)
                        s.monogram()
                    }
                    nameBlock(s, trophy: trophy)
                    Text("\(AppFormat.km(s.km)) · \(fuelUpsText(s.fuelUps))")
                        .font(.body.weight(.semibold))
                        .monospacedDigit()
                }
            } else {
                HStack(spacing: 8) {
                    Text("\(s.rank)")
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: rankWidth)
                    s.monogram(size: 38)
                        .padding(.horizontal, 2)
                    nameBlock(s, trophy: trophy)
                    Spacer(minLength: 0)
                    Text("\(s.fuelUps)")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: fuelWidth, alignment: .trailing)
                    Text(AppFormat.odometer(s.km))
                        .font(.body.weight(.semibold))
                        .monospacedDigit()
                        .frame(width: kmWidth, alignment: .trailing)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(s.isMe ? AnyShapeStyle(.tint.opacity(0.12)) : AnyShapeStyle(.clear))
        .contentShape(.rect)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText(s, trophy: trophy))
    }

    private func nameBlock(_ s: ChallengeStanding, trophy: Bool) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                Text(s.displayName)
                    .font(.body.weight(.semibold))
                if trophy {
                    Image(systemName: "trophy.fill")
                        .font(.subheadline)
                        .foregroundStyle(.yellow)
                }
            }
            Text(s.bikeLabel)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .lineLimit(stacked ? nil : 1)
    }

    private func fuelUpsText(_ n: Int) -> String {
        n == 1 ? "1 abastecimento" : "\(n) abastecimentos"
    }

    private func accessibilityText(_ s: ChallengeStanding, trophy: Bool) -> String {
        var text = "\(s.rank)º lugar, \(s.displayName), \(s.bikeLabel). \(AppFormat.km(s.km)), \(fuelUpsText(s.fuelUps))."
        if trophy { text += " Campeão." }
        return text
    }
}

extension EnvironmentValues {
    /// Aba com dados do servidor: esconde o que ele ainda não guarda —
    /// denunciar e bloquear (D8). Sem isso, a turma mexeria em botões que não
    /// fazem nada. O protótipo D0 mostra tudo.
    @Entry var challengeServerOnly = false
}

/// Destinos dentro da aba Desafios.
enum ChallengeRoute: Hashable {
    case board(UUID)
    case details(UUID)
    case participant(challenge: UUID, member: UUID)
    /// Um abastecimento do mural: fotos + comentários.
    case entry(challenge: UUID, entry: UUID)
}

// MARK: - Resumo

/// Card do desafio no Resumo (template `CardHeader`, DESIGN §6b): posição e
/// a "pressão boa" — quem está logo à frente e por quanto.
struct ChallengeSummaryCard: View {
    let challenge: Challenge
    /// O que o último abastecimento mexeu ("+230 km … subiu para 2º").
    var gain: ChallengeGain? = nil

    var body: some View {
        GroupedCard {
            VStack(alignment: .leading, spacing: 6) {
                CardHeader(symbol: "flag.checkered", title: challenge.name)
                if let me = challenge.me {
                    Text("\(me.rank)º de \(challenge.memberCount) · \(AppFormat.km(me.km))")
                        .font(.title3.weight(.semibold))
                        .fontDesign(.rounded)
                        .monospacedDigit()
                }
                // Retorno ao registrar: accent + símbolo (nunca só cor).
                if let gain {
                    Label(gain.text, systemImage: "arrow.up.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.tint)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(support)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint("Abre o desafio")
    }

    private var support: String {
        let phase = AppFormat.sentenceCased(challenge.phaseText()) + "."
        return [challenge.gapSentence, phase].compactMap { $0 }.joined(separator: " ")
    }
}
