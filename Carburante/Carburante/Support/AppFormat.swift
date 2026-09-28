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

    /// Número como um `TextField(format: .number)` o exibe ("28,49", "1.200");
    /// nil → `placeholder`. Mede a largura do campo p/ a moeda colar no número.
    static func numberInput(_ value: Double?, placeholder: String) -> String {
        value.map { $0.formatted(.number.locale(locale)) } ?? placeholder
    }

    /// Consumo, 1 casa decimal: "19,8 km/l".
    static func kmPerLiter(_ value: Double) -> String {
        "\(kmPerLiterValue(value)) km/l"
    }

    /// Consumo sem unidade: "19,8" — p/ compor número grande + unidade menor.
    static func kmPerLiterValue(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(1)).locale(locale))
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

    /// Dia dentro de uma seção de mês: "Segunda-feira, 28" (mês/ano já estão
    /// no header — repetir era ruído).
    static func weekdayDay(_ date: Date) -> String {
        sentenceCased(date.formatted(Date.FormatStyle().weekday(.wide).day().locale(locale)))
    }

    /// Dia relativo (padrão Mail): "Hoje", "Ontem", dia da semana até 6 dias
    /// atrás, "28 de set." no ano corrente, "28 de set. de 2025" nos anteriores.
    /// Para itens isolados ("último abastecimento"), fora de seção de mês.
    static func relativeDay(_ date: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        let days = calendar.dateComponents([.day],
                                           from: calendar.startOfDay(for: date),
                                           to: calendar.startOfDay(for: now)).day ?? 0
        switch days {
        case 0: return "Hoje"
        case 1: return "Ontem"
        case 2...6:
            return sentenceCased(date.formatted(Date.FormatStyle().weekday(.wide).locale(locale)))
        default:
            let style = calendar.isDate(date, equalTo: now, toGranularity: .year)
                ? Date.FormatStyle().day().month(.abbreviated)
                : Date.FormatStyle().day().month(.abbreviated).year()
            return date.formatted(style.locale(locale))
        }
    }

    /// Header de seção de mês (padrão Fotos/Wallet): "Setembro" no ano corrente,
    /// "Setembro de 2025" nos anteriores.
    static func monthTitle(_ date: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        let style = calendar.isDate(date, equalTo: now, toGranularity: .year)
            ? Date.FormatStyle().month(.wide)
            : Date.FormatStyle().month(.wide).year()
        return sentenceCased(date.formatted(style.locale(locale)))
    }

    /// Só a 1ª letra maiúscula. `.capitalized` sobe toda palavra e gerava
    /// "Setembro De 2026" — em pt-BR preposição fica minúscula.
    static func sentenceCased(_ text: String) -> String {
        text.prefix(1).uppercased(with: locale) + text.dropFirst()
    }
}
