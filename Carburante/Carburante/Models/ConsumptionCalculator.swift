//
//  ConsumptionCalculator.swift
//  Carburante
//
//  Núcleo do produto: cálculo de consumo. Lógica pura, sem UI, sem SwiftData
//  — recebe valores simples, totalmente testável por XCTest.
//
//  Método full-to-full: consumo só é confiável entre dois abastecimentos com
//  tanque cheio. Litros de abastecimentos parciais entre dois cheios são
//  somados ao segmento. O primeiro registro é só uma âncora (sem consumo).
//

import Foundation

/// Entrada mínima para o cálculo — desacopla a lógica do modelo SwiftData.
struct FuelEntry {
    let odometer: Double
    let liters: Double
    let totalCost: Double
    let isFullTank: Bool
    let date: Date
}

/// Consumo de um segmento entre dois tanques cheios consecutivos.
struct ConsumptionSegment: Equatable {
    /// km rodados no segmento (odômetro do cheio final − odômetro do cheio inicial).
    let distance: Double
    /// litros consumidos no segmento (soma dos abastecimentos após o cheio inicial até o cheio final).
    let liters: Double
    /// custo dos litros do segmento.
    let cost: Double
    /// data do cheio que fecha o segmento (eixo X dos gráficos / filtro de período).
    let endDate: Date

    /// km por litro.
    var kmPerLiter: Double { liters > 0 ? distance / liters : 0 }
}

/// Resumo agregado para uma moto.
struct ConsumptionSummary: Equatable {
    let averageKmPerLiter: Double?
    let totalDistance: Double
    let totalLitersInSegments: Double
    let totalCostInSegments: Double
    let segmentCount: Int

    /// custo por km, com base nos segmentos medidos.
    var costPerKm: Double? {
        guard totalDistance > 0 else { return nil }
        return totalCostInSegments / totalDistance
    }
}

extension FuelLog {
    var asFuelEntry: FuelEntry {
        FuelEntry(odometer: odometer, liters: liters, totalCost: totalCost, isFullTank: isFullTank, date: date)
    }
}

extension Motorcycle {
    /// Resumo de consumo da moto a partir dos seus abastecimentos.
    var consumptionSummary: ConsumptionSummary {
        ConsumptionCalculator.summary(from: fuelLogs.map(\.asFuelEntry))
    }

    /// Abastecimento mais recente por data.
    var latestFuelLog: FuelLog? {
        fuelLogs.max { $0.date < $1.date }
    }
}

enum ConsumptionCalculator {

    /// Quebra os abastecimentos em segmentos full-to-full.
    /// Entradas em qualquer ordem — são ordenadas por odômetro asc.
    static func segments(from entries: [FuelEntry]) -> [ConsumptionSegment] {
        let ordered = entries.sorted { $0.odometer < $1.odometer }
        guard ordered.count >= 2 else { return [] }

        var segments: [ConsumptionSegment] = []
        var anchor: FuelEntry?          // último cheio que abre um segmento
        var litersSinceAnchor = 0.0     // litros acumulados após a âncora
        var costSinceAnchor = 0.0

        for entry in ordered {
            if let start = anchor {
                // Tudo que entra depois da âncora conta para o segmento atual.
                litersSinceAnchor += entry.liters
                costSinceAnchor += entry.totalCost

                if entry.isFullTank {
                    let distance = entry.odometer - start.odometer
                    // Distância inválida (odômetro não avançou) → ignora o segmento,
                    // mas mantém este cheio como nova âncora.
                    if distance > 0 {
                        segments.append(ConsumptionSegment(
                            distance: distance,
                            liters: litersSinceAnchor,
                            cost: costSinceAnchor,
                            endDate: entry.date
                        ))
                    }
                    anchor = entry
                    litersSinceAnchor = 0
                    costSinceAnchor = 0
                }
            } else if entry.isFullTank {
                // Primeiro cheio = âncora inicial, sem consumo associado.
                anchor = entry
            }
            // Abastecimentos parciais antes do primeiro cheio são descartados
            // (não há âncora confiável para medir).
        }

        return segments
    }

    /// Resumo agregado. `averageKmPerLiter` é nil quando não há segmento medível.
    static func summary(from entries: [FuelEntry]) -> ConsumptionSummary {
        let segs = segments(from: entries)
        let totalDistance = segs.reduce(0) { $0 + $1.distance }
        let totalLiters = segs.reduce(0) { $0 + $1.liters }
        let totalCost = segs.reduce(0) { $0 + $1.cost }
        let average: Double? = totalLiters > 0 ? totalDistance / totalLiters : nil

        return ConsumptionSummary(
            averageKmPerLiter: average,
            totalDistance: totalDistance,
            totalLitersInSegments: totalLiters,
            totalCostInSegments: totalCost,
            segmentCount: segs.count
        )
    }
}
