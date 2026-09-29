//
//  FuelLogValidation.swift
//  Carburante
//
//  Validação pura de abastecimento — sem UI, testável por XCTest.
//

import Foundation

enum FuelLogValidationError: Error, Equatable {
    case odometerNotPositive
    case odometerBelowLast(last: Double)
    /// Registro retroativo com km MAIOR que o de um abastecimento de data
    /// posterior — hodômetro não anda para trás. Bloqueante: abastecimento mexe
    /// em `currentOdometer` (max), e um typo alto travaria todos os seguintes.
    case odometerAboveNext(next: Double)
    case litersNotPositive
    case costNegative

    /// Chave estável para analytics — só o TIPO do erro, nunca o valor (o `last`
    /// é odômetro, dado sensível, fica fora).
    var analyticsKey: String {
        switch self {
        case .odometerNotPositive: return "odometer_not_positive"
        case .odometerBelowLast:   return "odometer_below_last"
        case .odometerAboveNext:   return "odometer_above_next"
        case .litersNotPositive:   return "liters_not_positive"
        case .costNegative:        return "cost_negative"
        }
    }
}

enum FuelLogValidator {
    /// Valida os campos de um abastecimento.
    /// - Parameter lastOdometer: piso do hodômetro (`OdometerBounds.floor`) — o
    ///   maior já registrado, ou, num registro retroativo, o maior ANTES da data.
    /// - Parameter nextOdometer: teto (`OdometerBounds.ceiling`) — só num registro
    ///   retroativo com abastecimento de data posterior. nil = sem teto.
    static func validate(
        odometer: Double,
        liters: Double,
        totalCost: Double,
        lastOdometer: Double?,
        nextOdometer: Double? = nil
    ) -> [FuelLogValidationError] {
        var errors: [FuelLogValidationError] = []

        if odometer <= 0 {
            errors.append(.odometerNotPositive)
        } else if let last = lastOdometer, odometer < last {
            errors.append(.odometerBelowLast(last: last))
        } else if let next = nextOdometer, odometer > next {
            errors.append(.odometerAboveNext(next: next))
        }

        if liters <= 0 {
            errors.append(.litersNotPositive)
        }
        if totalCost < 0 {
            errors.append(.costNegative)
        }

        return errors
    }
}

/// Limites do hodômetro para um abastecimento NOVO, conforme a DATA dele
/// (PLAN/registro-retroativo.md, item 2). Hodômetro só anda para frente, então
/// um registro antigo tem de caber entre o abastecimento anterior e o seguinte.
///
/// - Não retroativo (o caso de todo dia): piso = maior km conhecido (logs e
///   leitura do cadastro), sem teto — idêntico ao comportamento de sempre.
/// - Retroativo (data antes do último abastecimento, antes do cadastro da moto,
///   ou histórica): piso = maior km dos dias ANTERIORES, teto = menor km dos dias
///   POSTERIORES. A leitura do cadastro não entra: não tem data (e é regravada a
///   cada edição da moto). Logs do MESMO dia ficam fora dos dois limites — não dá
///   para ordenar dentro do dia.
struct OdometerBounds: Equatable {
    /// Km mínimo aceito (bloqueante). nil = sem piso.
    let floor: Double?
    /// Data do abastecimento que define o piso (nil no caso não retroativo).
    let floorDate: Date?
    /// Km máximo aceito (bloqueante). nil = sem teto.
    let ceiling: Double?
    /// Data do abastecimento que define o teto.
    let ceilingDate: Date?
    /// A data escolhida cai antes do que já está registrado.
    let isBackdated: Bool

    static func forEntry(
        on date: Date,
        logs: [(date: Date, odometer: Double)],
        currentOdometer: Double,
        registeredAt: Date? = nil,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> OdometerBounds {
        let day = calendar.startOfDay(for: date)
        let latestDay = logs.map { calendar.startOfDay(for: $0.date) }.max()
        let daysAgo = calendar.dateComponents([.day], from: day, to: calendar.startOfDay(for: now)).day ?? 0
        let beforeRegistration = registeredAt.map { day < calendar.startOfDay(for: $0) } ?? false
        let backdated = (latestDay.map { day < $0 } ?? false)
            || beforeRegistration
            || daysAgo > EventProvenance.historyThresholdDays

        guard backdated else {
            let known = max(logs.map(\.odometer).max() ?? 0, currentOdometer)
            return OdometerBounds(floor: known > 0 ? known : nil, floorDate: nil,
                                  ceiling: nil, ceilingDate: nil, isBackdated: false)
        }
        let before = logs.filter { calendar.startOfDay(for: $0.date) < day }
            .max { $0.odometer < $1.odometer }
        let after = logs.filter { calendar.startOfDay(for: $0.date) > day }
            .min { $0.odometer < $1.odometer }
        return OdometerBounds(floor: before?.odometer, floorDate: before?.date,
                              ceiling: after?.odometer, ceilingDate: after?.date,
                              isBackdated: true)
    }
}

/// Km de uma manutenção fora da ordem do hodômetro. Só AVISO — manutenção nunca
/// bloqueia o Salvar (o hodômetro da moto pode estar desatualizado e travaria
/// dado verdadeiro). Pega o typo que passaria calado: 100.000 numa moto em
/// 10.000 escondia o vencimento de pneu/relação por anos.
enum MaintenanceOdometerIssue: Equatable {
    /// Menor que um registro de dia anterior.
    case belowEarlier(km: Double, date: Date)
    /// Maior que um registro de dia posterior.
    case aboveLater(km: Double, date: Date)
    /// Retroativo maior que o hodômetro atual — o passado não passa do presente.
    case aboveCurrent(km: Double)
}

extension OdometerBounds {
    /// Checagem não bloqueante do km de uma manutenção contra estes limites.
    /// Só vale no retroativo. Na hora não avisa nada: km acima do hodômetro é a
    /// moto que andou desde o último abastecimento, e km abaixo é comum no mesmo
    /// dia (troca de óleo de manhã, abastecimento à tarde) — o piso global
    /// incluiria o abastecimento de hoje. Km menor que a última do mesmo tipo já
    /// tem aviso próprio no form (`backfillWarning`).
    func maintenanceIssue(km: Double, currentOdometer: Double) -> MaintenanceOdometerIssue? {
        guard isBackdated else { return nil }
        if let floor, let floorDate, km < floor { return .belowEarlier(km: floor, date: floorDate) }
        if let ceiling, let ceilingDate, km > ceiling { return .aboveLater(km: ceiling, date: ceilingDate) }
        if currentOdometer > 0, km > currentOdometer { return .aboveCurrent(km: currentOdometer) }
        return nil
    }
}
