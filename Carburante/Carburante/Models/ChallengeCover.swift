//
//  ChallengeCover.swift
//  Carburante
//
//  Capa do desafio (PLAN/desafios.md D3): foto da galeria recortada no centro
//  em faixa larga, reduzida e guardada como JPEG no bucket PRIVADO
//  `challenge-covers` (grava quem criou; lê a turma e quem acertou o código).
//  Regras puras — o desenho e o cache ficam no `ChallengeImageStore`.
//  `nonisolated`: o recorte roda fora da main (foto de 12 MP).
//

import CoreGraphics
import Foundation

nonisolated enum ChallengeCover {
    static let bucket = "challenge-covers"
    /// Proporção guardada (3:2). Mais alta que o card do desafio (≈ 2,3:1) e
    /// mais larga que a prévia do convite (≈ 1,2:1): cada tela corta um pouco
    /// da foto e nenhuma perde muito.
    static let aspectRatio: CGFloat = 3 / 2
    /// Largura máxima do JPEG: nítido em tela cheia de iPhone (3x) e leve
    /// (~250 KB) para quem abre o convite no 4G.
    static let maxWidth: CGFloat = 1500
    static let jpegQuality: CGFloat = 0.75

    /// Maior retângulo 3:2 no centro da foto (em pé ou deitada).
    static func cropRect(for size: CGSize) -> CGRect {
        guard size.width > 0, size.height > 0 else { return .zero }
        if size.width / size.height > aspectRatio {
            let width = (size.height * aspectRatio).rounded(.down)
            return CGRect(x: ((size.width - width) / 2).rounded(.down), y: 0,
                          width: width, height: size.height)
        }
        let height = (size.width / aspectRatio).rounded(.down)
        return CGRect(x: 0, y: ((size.height - height) / 2).rounded(.down),
                      width: size.width, height: height)
    }

    /// Tamanho final: o recorte reduzido a `maxWidth` (foto pequena não aumenta).
    static func outputSize(for crop: CGSize) -> CGSize {
        guard crop.width > maxWidth else { return CGSize(width: crop.width.rounded(), height: crop.height.rounded()) }
        return CGSize(width: maxWidth, height: (maxWidth / crop.width * crop.height).rounded())
    }

    /// Caminho no bucket: `<challenge_id>/cover-<versão>.jpg`. O id vai em
    /// minúsculas (o `set_challenge_cover` compara com o `uuid::text` do
    /// Postgres). Cada capa nova ganha um nome novo, então o cache no aparelho
    /// nunca mostra uma capa trocada.
    static func path(challengeID: UUID, version: String = newVersion()) -> String {
        "\(challengeID.uuidString.lowercased())/cover-\(version).jpg"
    }

    /// 8 caracteres hexadecimais minúsculos.
    static func newVersion() -> String {
        String(UUID().uuidString.lowercased().replacingOccurrences(of: "-", with: "").prefix(8))
    }

    /// Referência de capa no Storage (o protótipo D0 usa só o nome de um
    /// arquivo local, sem pasta).
    static func isRemote(_ ref: String?) -> Bool {
        ref?.contains("/") == true
    }
}
