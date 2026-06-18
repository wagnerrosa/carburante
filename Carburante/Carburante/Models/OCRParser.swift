//
//  OCRParser.swift
//  Carburante
//
//  Parser puro: transforma linhas de texto reconhecidas (Vision) em campos
//  do abastecimento. Sem UI, sem Vision — recebe [String], testável por XCTest.
//
//  Realidade: displays de bomba e comprovantes são ruidosos (7 segmentos,
//  reflexo, ângulo). O parser é heurístico e best-effort; a revisão manual
//  antes de salvar é obrigatória. Campos que não dá pra inferir ficam nil.
//

import Foundation

/// Resultado da extração — todos opcionais; nil = não reconhecido.
struct OCRResult: Equatable {
    var liters: Double?
    var totalCost: Double?
    var fuelType: FuelType?
    var odometer: Double?
}

enum OCRParser {

    /// Extrai campos de abastecimento das linhas de um comprovante/bomba.
    /// O Vision costuma quebrar rótulo e valor em linhas separadas
    /// ("LITROS" numa linha, "12,500" na seguinte) — por isso o valor é
    /// buscado na própria linha e, se faltar, na linha de baixo.
    static func parseFuelReceipt(_ lines: [String]) -> OCRResult {
        var result = OCRResult()
        let normalized = lines.map { $0.uppercased() }

        for (i, line) in normalized.enumerated() {
            let next = i + 1 < normalized.count ? normalized[i + 1] : nil

            if result.liters == nil, hasLabel(line, ["LITRO", "LTS", "QTDE", "VOLUME"]) {
                result.liters = numbers(in: line).last ?? next.flatMap { numbers(in: $0).first }
            }
            // "PRECO/L" tem "L" mas NÃO é litros — excluído por não casar os labels acima.
            if result.totalCost == nil, hasLabel(line, ["TOTAL", "VL.TOTAL", "VALOR TOTAL", "A PAGAR", "VL TOTAL"]) {
                result.totalCost = numbers(in: line).last ?? next.flatMap { numbers(in: $0).first }
            }
            if result.fuelType == nil, let f = fuelType(in: line) {
                result.fuelType = f
            }
        }
        return result
    }

    private static func hasLabel(_ line: String, _ labels: [String]) -> Bool {
        labels.contains { line.contains($0) }
    }

    /// Extrai o hodômetro de uma foto só do painel: pega o maior inteiro plausível.
    /// Painéis costumam mostrar só o número (e talvez "KM").
    static func parseOdometer(_ lines: [String]) -> Double? {
        let candidates = lines.flatMap { numbers(in: $0.uppercased()) }
        // Hodômetro é inteiro, não tem centavos. Filtra valores com aparência de km.
        let integers = candidates.filter { $0 == $0.rounded() && $0 >= 0 }
        return integers.max()
    }

    // MARK: - Helpers

    /// Identifica tipo de combustível por palavra-chave.
    private static func fuelType(in line: String) -> FuelType? {
        if line.contains("ADITIVAD") { return .gasolinaAditivada }
        if line.contains("GASOLINA") || line.contains("GAS C") || line.contains("GAS.") { return .gasolinaComum }
        if line.contains("ETANOL") || line.contains("ALCOOL") || line.contains("ÁLCOOL") { return .etanol }
        if line.contains("DIESEL") { return .diesel }
        if line.contains("GNV") { return .gnv }
        return nil
    }

    /// Extrai todos os números de uma linha. Aceita formato BR (1.234,56) e simples (1234.56).
    static func numbers(in line: String) -> [Double] {
        // Captura sequências de dígitos com separadores . e ,
        var results: [Double] = []
        let pattern = #"\d[\d.,]*\d|\d"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(line.startIndex..., in: line)
        for match in regex.matches(in: line, range: range) {
            guard let r = Range(match.range, in: line) else { continue }
            let token = String(line[r])
            if let value = normalizeNumber(token) {
                results.append(value)
            }
        }
        return results
    }

    /// Converte um token numérico em Double, resolvendo separadores BR vs. US.
    static func normalizeNumber(_ token: String) -> Double? {
        let hasComma = token.contains(",")
        let hasDot = token.contains(".")

        var cleaned = token
        if hasComma && hasDot {
            // Formato BR: ponto = milhar, vírgula = decimal. Ex.: 1.234,56
            cleaned = token.replacingOccurrences(of: ".", with: "")
                           .replacingOccurrences(of: ",", with: ".")
        } else if hasComma {
            // Só vírgula → decimal BR. Ex.: 12,5
            cleaned = token.replacingOccurrences(of: ",", with: ".")
        } else if hasDot {
            // Só ponto: pode ser milhar (1.234) ou decimal (12.5). Heurística:
            // se há exatamente 3 dígitos após o último ponto e não é o único separador
            // significativo, trata como milhar.
            let parts = token.split(separator: ".")
            if parts.count == 2, parts[1].count == 3, parts[0].count <= 3 {
                cleaned = token.replacingOccurrences(of: ".", with: "")
            }
            // senão, mantém como decimal US.
        }
        return Double(cleaned)
    }
}
