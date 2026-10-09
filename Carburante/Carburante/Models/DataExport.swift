//
//  DataExport.swift
//  Carburante
//
//  "Exportar meus dados" — grátis, sempre (dado nunca é refém; ver
//  PLAN/monetizacao.md). Três planilhas CSV: motos, abastecimentos e
//  manutenções, só registros ativos (soft-delete fica fora).
//
//  Formato da planilha brasileira, para abrir direto no Excel e no Numbers:
//  `;` separa colunas, vírgula decimal sem separador de milhar, data
//  dd/MM/aaaa HH:mm e UTF-8 com BOM (sem ele o Excel quebra os acentos).
//  Tipos persistidos saem pelo rótulo de tela; chave desconhecida (gravada
//  por um build mais novo) sai crua, nunca vira o fallback.
//
//  Também é pré-requisito do limite de motos do Premium: "só leitura, mas
//  exportável" (PLAN/premium-mvp.md).
//

import Foundation

enum DataExport {

    struct File: Equatable {
        let name: String
        let contents: String
    }

    /// As três planilhas das motos informadas (passe só as ativas).
    static func files(for motorcycles: [Motorcycle], date: Date = Date()) -> [File] {
        let day = fileDate.string(from: date)
        return [
            File(name: "carburante-motos-\(day).csv", contents: motorcyclesCSV(motorcycles)),
            File(name: "carburante-abastecimentos-\(day).csv", contents: fuelLogsCSV(motorcycles)),
            File(name: "carburante-manutencoes-\(day).csv", contents: maintenanceCSV(motorcycles)),
        ]
    }

    /// Grava numa pasta temporária nova → URLs para a folha de compartilhar.
    static func write(_ files: [File]) throws -> [URL] {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("Carburante-exportacao-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return try files.map { file in
            let url = folder.appendingPathComponent(file.name)
            try file.contents.write(to: url, atomically: true, encoding: .utf8)
            return url
        }
    }

    // MARK: - Planilhas

    static func motorcyclesCSV(_ motorcycles: [Motorcycle]) -> String {
        let header = ["ID", "Marca", "Modelo", "Ano", "País", "Categoria", "Cilindrada (cc)",
                      "Hodômetro atual (km)", "Cadastrada em"]
        let rows = motorcycles.map { m in
            [
                m.id.uuidString,
                m.make,
                m.model,
                String(m.year),
                m.country,
                m.category.map { MotorcycleCategory(rawValue: $0)?.label ?? $0 } ?? "",
                m.displacementCC.map(String.init) ?? "",
                number(m.currentOdometer, max: 1),
                dateTime(m.createdAt),
            ]
        }
        return csv([header] + rows)
    }

    static func fuelLogsCSV(_ motorcycles: [Motorcycle]) -> String {
        let header = ["Moto", "ID da moto", "Data", "Hodômetro (km)", "Litros", "Total (R$)",
                      "Preço por litro (R$)", "Combustível", "Tanque cheio",
                      "Abastecimento anterior não registrado", "Cidade", "Estado", "País",
                      "Latitude", "Longitude", "Registro de histórico", "Registrado em"]
        let rows = motorcycles.flatMap { m in
            m.activeFuelLogs.sorted { $0.date < $1.date }.map { log in
                [
                    bikeName(m),
                    m.id.uuidString,
                    dateTime(log.date),
                    number(log.odometer, max: 1),
                    number(log.liters, max: 3),
                    number(log.totalCost, min: 2, max: 2),
                    log.pricePerLiter.map { number($0, min: 3, max: 3) } ?? "",
                    FuelType(rawValue: log.fuelTypeRaw)?.label ?? log.fuelTypeRaw,
                    yesNo(log.isFullTank),
                    yesNo(log.missedPrevious),
                    log.city ?? "",
                    log.state ?? "",
                    log.country ?? "",
                    log.latitude.map { number($0, max: 6) } ?? "",
                    log.longitude.map { number($0, max: 6) } ?? "",
                    yesNo(log.isHistorical),
                    dateTime(log.createdAt),
                ]
            }
        }
        return csv([header] + rows)
    }

    static func maintenanceCSV(_ motorcycles: [Motorcycle]) -> String {
        let header = ["Moto", "ID da moto", "Data", "Tipo", "Hodômetro (km)", "Custo (R$)",
                      "Intervalo (km)", "Intervalo (meses)", "Observações", "Parte de uma revisão",
                      "Registro de histórico", "Registrado em"]
        let rows = motorcycles.flatMap { m in
            m.activeMaintenanceLogs.sorted { $0.date < $1.date }.map { log in
                [
                    bikeName(m),
                    m.id.uuidString,
                    dateTime(log.date),
                    MaintenanceType(rawValue: log.typeRaw) != nil ? log.displayName : log.typeRaw,
                    number(log.mileage, max: 1),
                    number(log.cost, min: 2, max: 2),
                    log.intervalKm.map { number($0, max: 1) } ?? "",
                    log.intervalMonths.map(String.init) ?? "",
                    log.notes,
                    yesNo(log.partOfMaintenanceID != nil),
                    yesNo(log.isHistorical),
                    dateTime(log.createdAt),
                ]
            }
        }
        return csv([header] + rows)
    }

    // MARK: - Formato

    /// Monta o CSV: BOM + linhas com `;` + CRLF (o que o Excel espera).
    static func csv(_ rows: [[String]]) -> String {
        "\u{FEFF}" + rows.map { $0.map(field).joined(separator: ";") }.joined(separator: "\r\n") + "\r\n"
    }

    /// Aspas só quando precisa: campo com `;`, aspas ou quebra de linha
    /// (aspas internas dobram — RFC 4180).
    static func field(_ value: String) -> String {
        guard value.contains(where: { $0 == ";" || $0 == "\"" || $0.isNewline }) else { return value }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    /// Número pt-BR sem separador de milhar ("1234,5") — a planilha lê como número.
    static func number(_ value: Double, min: Int = 0, max: Int) -> String {
        value.formatted(.number.locale(AppFormat.locale).grouping(.never)
            .precision(.fractionLength(min...max)))
    }

    static func yesNo(_ value: Bool) -> String { value ? "sim" : "não" }

    static func dateTime(_ date: Date) -> String { dateTimeFormatter.string(from: date) }

    private static func bikeName(_ m: Motorcycle) -> String { "\(m.make) \(m.model)" }

    private static let dateTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = AppFormat.locale
        f.dateFormat = "dd/MM/yyyy HH:mm"
        return f
    }()

    private static let fileDate: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}
