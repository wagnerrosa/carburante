//
//  ProfileLevel.swift
//  Carburante
//
//  Nível do perfil estilo Garmin: cada medalha vale pontos (`Badge.points`),
//  o total (derivado em `BadgeEvaluator.totalPoints`) cai numa faixa de nível.
//  Tipo PURO — sem UI, sem SwiftData — testável com valores. A UI lê isto p/
//  desenhar o hexágono de nível + a barra ("N pontos para o próximo nível").
//
//  Curva ÍNGREME (decisão 2026-06-28): níveis 1-2 fáceis (cadastrar moto +
//  primeiros abastecimentos engajam), níveis altos exigem coleção quase completa
//  de medalhas / frota diversa. Subir de nível é conquista real, não inflação.
//

import Foundation

struct ProfileLevel: Equatable {
    /// Nível atual (1-based).
    let level: Int
    /// Pontos já feitos DENTRO do nível atual (offset desde o limiar do nível).
    let pointsIntoLevel: Int
    /// Pontos que faltam p/ o próximo nível. 0 quando já no nível máximo.
    let pointsForNext: Int
    /// Tamanho da faixa do nível atual (limiar do próximo − limiar atual).
    /// 0 no nível máximo (não há "próxima faixa").
    let spanOfLevel: Int

    /// Total bruto de pontos que gerou este nível (eco do input, p/ a UI exibir).
    let totalPoints: Int

    /// É o nível mais alto que a curva alcança? (barra cheia, sem "faltam X").
    var isMax: Bool { spanOfLevel == 0 }

    /// Progresso 0…1 dentro do nível atual, p/ a barra. Máximo → cheia.
    var progress: Double {
        guard spanOfLevel > 0 else { return 1 }
        return min(1, Double(pointsIntoLevel) / Double(spanOfLevel))
    }

    /// Limiares cumulativos de pontos. Índice = (nível − 1); `thresholds[0] == 0`
    /// é o piso do nível 1. Curva crescente e íngreme. Último valor = piso do
    /// nível máximo (a partir dele não há próximo). Constante editável.
    static let thresholds: [Int] = [0, 3, 10, 22, 40, 65, 100, 150, 220, 320]

    /// Mapeia um total de pontos para o nível + progresso. Clampa em 0.
    static func from(points: Int) -> ProfileLevel {
        let pts = max(0, points)
        let t = thresholds
        let maxLevel = t.count

        // Acha o maior índice cujo limiar é <= pts → nível atual (1-based).
        var idx = 0
        for i in t.indices where pts >= t[i] { idx = i }

        // Nível máximo: nada acima.
        if idx >= maxLevel - 1 {
            return ProfileLevel(
                level: maxLevel,
                pointsIntoLevel: pts - t[maxLevel - 1],
                pointsForNext: 0,
                spanOfLevel: 0,
                totalPoints: pts
            )
        }

        let floor = t[idx]
        let next = t[idx + 1]
        return ProfileLevel(
            level: idx + 1,
            pointsIntoLevel: pts - floor,
            pointsForNext: next - pts,
            spanOfLevel: next - floor,
            totalPoints: pts
        )
    }
}
