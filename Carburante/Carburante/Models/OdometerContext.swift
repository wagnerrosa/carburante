//
//  OdometerContext.swift
//  Carburante
//
//  Contexto do hodômetro num registro antigo: regra (km fora da ordem) + texto
//  (faixa esperada, frase de contexto, aviso). Fonte única das duas telas de
//  registro antigo — abastecimento e manutenção falam a mesma língua. Lógica
//  pura, testável.
//
//  Padrão de tela (DESIGN.md §7): uma linha colada ao campo que dá o contexto
//  e VIRA o aviso no mesmo lugar quando o km foge. Nada de seção à parte.
//

import Foundation

/// Km fora da ordem do hodômetro.
enum OdometerIssue: Equatable {
    /// Menor que um registro de dia anterior.
    case belowEarlier(km: Double, date: Date)
    /// Maior que um registro de dia posterior.
    case aboveLater(km: Double, date: Date)
    /// Retroativo maior que o hodômetro atual — o passado não passa do presente
    /// (só manutenção: abastecimento acima do atual é válido e o atualiza).
    case aboveCurrent(km: Double)
    /// Abaixo do maior km conhecido, fora do retroativo (só abastecimento).
    case belowCurrent(km: Double)

    /// O que está estranho, em linguagem de piloto, + o que fazer.
    func message(now: Date = Date(), calendar: Calendar = .current) -> String {
        switch self {
        case let .belowEarlier(km, date):
            return "Em \(AppFormat.dayMonth(date, now: now, calendar: calendar)) a moto já tinha \(AppFormat.km(km)). Confira o número ou a data."
        case let .aboveLater(km, date):
            return "Em \(AppFormat.dayMonth(date, now: now, calendar: calendar)) a moto tinha só \(AppFormat.km(km)). Confira o número ou a data."
        case let .aboveCurrent(km):
            return "A moto está com \(AppFormat.km(km)). Confira o número."
        case let .belowCurrent(km):
            return "A moto já está com \(AppFormat.km(km))."
        }
    }
}

extension OdometerBounds {
    /// Checagem NÃO bloqueante do km de uma manutenção (o hodômetro da moto pode
    /// estar desatualizado e travaria dado verdadeiro). Pega o typo que passaria
    /// calado: 100.000 numa moto em 10.000 escondia o vencimento de pneu/relação
    /// por anos. Só vale no retroativo. Na hora não avisa: km acima do hodômetro
    /// é a moto que andou desde o último abastecimento, e km abaixo é comum no
    /// mesmo dia (troca de óleo de manhã, abastecimento à tarde).
    func maintenanceIssue(km: Double, currentOdometer: Double) -> OdometerIssue? {
        guard isBackdated else { return nil }
        if let floor, let floorDate, km < floor { return .belowEarlier(km: floor, date: floorDate) }
        if let ceiling, let ceilingDate, km > ceiling { return .aboveLater(km: ceiling, date: ceilingDate) }
        if currentOdometer > 0, km > currentOdometer { return .aboveCurrent(km: currentOdometer) }
        return nil
    }

    /// Checagem BLOQUEANTE do km de um abastecimento (nil ⇔ pode avançar) —
    /// abastecimento mexe em `currentOdometer`, um typo travaria os seguintes.
    /// Mesmos limites do `FuelLogValidator`.
    func fuelIssue(km: Double) -> OdometerIssue? {
        if let floor, km < floor {
            return floorDate.map { .belowEarlier(km: floor, date: $0) } ?? .belowCurrent(km: floor)
        }
        if let ceiling, let ceilingDate, km > ceiling { return .aboveLater(km: ceiling, date: ceilingDate) }
        return nil
    }

    /// Faixa em que o km da época deve cair. Só retroativo tem faixa (fora dele
    /// o piso é o hodômetro de sempre, já dito no placeholder "Atual: …").
    /// `capAtCurrent`: sem registro posterior, o hodômetro atual vira o teto —
    /// vale para manutenção; no abastecimento km acima do atual é válido.
    func expectedRange(currentOdometer: Double, capAtCurrent: Bool) -> (low: Double?, high: Double?) {
        let low = floorDate == nil ? nil : floor
        let high = ceiling ?? (capAtCurrent && isBackdated && currentOdometer > 0 ? currentOdometer : nil)
        return (low, high)
    }

    /// Placeholder do campo de km: "19.958 a 20.310", "A partir de 19.958",
    /// "Até 20.310". Nil sem faixa (ou faixa incoerente, de dado antigo ruim).
    func rangePlaceholder(currentOdometer: Double, capAtCurrent: Bool) -> String? {
        switch expectedRange(currentOdometer: currentOdometer, capAtCurrent: capAtCurrent) {
        case let (low?, high?):
            return low <= high ? "\(AppFormat.odometer(low)) a \(AppFormat.odometer(high))" : nil
        case let (low?, nil):
            return "A partir de \(AppFormat.odometer(low))"
        case let (nil, high?):
            return "Até \(AppFormat.odometer(high))"
        case (nil, nil):
            return nil
        }
    }

    /// Frase de contexto (o "mini-histórico"): o km da moto nos registros
    /// vizinhos da data. Ex.: "Em 28 de jun. a moto tinha 19.958 km e, em 10 de
    /// jul., 20.310 km." Nil quando não há o que dizer.
    func contextSentence(
        currentOdometer: Double, capAtCurrent: Bool,
        now: Date = Date(), calendar: Calendar = .current
    ) -> String? {
        func day(_ d: Date) -> String { AppFormat.dayMonth(d, now: now, calendar: calendar) }
        let before = floorDate.flatMap { d in floor.map { (d, $0) } }
        let after = ceilingDate.flatMap { d in ceiling.map { (d, $0) } }
        switch (before, after) {
        case let ((bd, bk)?, (ad, ak)?):
            return "Em \(day(bd)) a moto tinha \(AppFormat.km(bk)) e, em \(day(ad)), \(AppFormat.km(ak))."
        case let ((bd, bk)?, nil):
            if capAtCurrent, currentOdometer > bk {
                return "Em \(day(bd)) a moto tinha \(AppFormat.km(bk)); agora está com \(AppFormat.km(currentOdometer))."
            }
            return "Em \(day(bd)) a moto tinha \(AppFormat.km(bk))."
        case let (nil, (ad, ak)?):
            return "Em \(day(ad)) a moto tinha \(AppFormat.km(ak))."
        case (nil, nil):
            return capAtCurrent && currentOdometer > 0
                ? "A moto está com \(AppFormat.km(currentOdometer))." : nil
        }
    }
}
