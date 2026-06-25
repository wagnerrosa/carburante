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
    case litersNotPositive
    case costNegative

    /// Chave estável para analytics — só o TIPO do erro, nunca o valor (o `last`
    /// é odômetro, dado sensível, fica fora).
    var analyticsKey: String {
        switch self {
        case .odometerNotPositive: return "odometer_not_positive"
        case .odometerBelowLast:   return "odometer_below_last"
        case .litersNotPositive:   return "liters_not_positive"
        case .costNegative:        return "cost_negative"
        }
    }
}

enum FuelLogValidator {
    /// Valida os campos de um abastecimento.
    /// - Parameter lastOdometer: maior hodômetro já registrado para a moto (nil se primeiro).
    static func validate(
        odometer: Double,
        liters: Double,
        totalCost: Double,
        lastOdometer: Double?
    ) -> [FuelLogValidationError] {
        var errors: [FuelLogValidationError] = []

        if odometer <= 0 {
            errors.append(.odometerNotPositive)
        } else if let last = lastOdometer, odometer < last {
            errors.append(.odometerBelowLast(last: last))
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
