//
//  AppFormat.swift
//  Carburante
//
//  Camada única de formatação (Fase 11 — refinamento UI). Centraliza moeda,
//  número, distância, consumo e data num só lugar para o app inteiro:
//  evita moeda montada à mão, datas em inglês e hodômetro sem separador.
//
//  MVP é Brasil-only: locale e moeda fixos em pt-BR / BRL. Quando houver
//  multi-país, derivar de `users.country`/locale e parametrizar aqui.
//

import Foundation

// `nonisolated`: o projeto usa SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor, que
// marcaria estes helpers como @MainActor. Como são formatação PURA (sem estado,
// sem UI, thread-safe), liberá-los do ator evita warnings de "main actor-isolated
// em contexto nonisolated" ao chamá-los de builders do Charts / closures síncronas.
nonisolated enum AppFormat {
    /// Locale canônico do MVP. Fixo para garantir datas/números em pt-BR
    /// independente do idioma do dispositivo de teste.
    static let locale = Locale(identifier: "pt_BR")
    static let currencyCode = "BRL"

    /// Moeda padrão: "R$ 30,00".
    static func currency(_ value: Double) -> String {
        value.formatted(.currency(code: currencyCode).locale(locale))
    }

    /// Moeda com 3 casas — preço por litro: "R$ 5,556".
    static func currencyPrecise(_ value: Double) -> String {
        value.formatted(.currency(code: currencyCode).precision(.fractionLength(3)).locale(locale))
    }

    /// Distância/hodômetro com separador de milhar e unidade: "20.100 km".
    static func km(_ value: Double) -> String {
        "\(odometer(value)) km"
    }

    /// Número inteiro agrupado, sem unidade — para prompts: "20.100".
    static func odometer(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0)).grouping(.automatic).locale(locale))
    }

    /// Litros, até 1 casa: "5 L", "12,5 L".
    static func liters(_ value: Double) -> String {
        "\(value.formatted(.number.precision(.fractionLength(0...1)).locale(locale))) L"
    }

    /// Consumo, 1 casa decimal: "19,8 km/l".
    static func kmPerLiter(_ value: Double) -> String {
        "\(value.formatted(.number.precision(.fractionLength(1)).locale(locale))) km/l"
    }

    /// Data abreviada localizada: "18 de jun. de 2026".
    static func date(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted).locale(locale))
    }

    /// Data + hora: "18 de jun. de 2026 21:41".
    static func dateTime(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened).locale(locale))
    }

    /// Data por extenso (estilo conquista, à la Garmin): "8 de novembro de 2025".
    static func dateLong(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(date: .long, time: .omitted).locale(locale))
    }
}
