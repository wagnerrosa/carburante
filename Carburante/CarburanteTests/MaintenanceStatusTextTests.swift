//
//  MaintenanceStatusTextTests.swift
//  CarburanteTests
//
//  Texto de prazo compartilhado por Resumo e Programadas
//  (`MaintenanceStatus.remainingShort`) e cor do indicador
//  (`indicatorColor`: em dia neutro, atenção laranja, vencida vermelha).
//

import XCTest
import SwiftUI
@testable import Carburante

final class MaintenanceStatusTextTests: XCTestCase {

    private func status(
        kmRemaining: Double? = nil,
        daysRemaining: Int? = nil,
        dueDate: Date? = nil,
        progress: Double = 0.1,
        overdue: Bool = false
    ) -> MaintenanceStatus {
        MaintenanceStatus(
            type: .oleo, intervalKm: kmRemaining == nil ? nil : 3000,
            intervalMonths: dueDate == nil ? nil : 6,
            lastMileage: 10_000, lastDate: Date(timeIntervalSince1970: 0),
            dueMileage: kmRemaining == nil ? nil : 13_000, dueDate: dueDate,
            kmRemaining: kmRemaining, daysRemaining: daysRemaining,
            progress: progress, isOverdue: overdue)
    }

    // MARK: - remainingShort

    func testInDayByKm() {
        XCTAssertEqual(status(kmRemaining: 1_500).remainingShort, "Faltam 1.500 km")
    }

    func testOverdueByKmSaysHowFar() {
        XCTAssertEqual(status(kmRemaining: -1_200, progress: 1, overdue: true).remainingShort,
                       "1.200 km além")
    }

    func testOverdueByDateSaysHowLate() {
        let due = Date(timeIntervalSince1970: 1_000)
        XCTAssertEqual(status(daysRemaining: -87, dueDate: due, progress: 1, overdue: true).remainingShort,
                       "87 dias em atraso")
        XCTAssertEqual(status(daysRemaining: -1, dueDate: due, progress: 1, overdue: true).remainingShort,
                       "1 dia em atraso")
    }

    func testOverdueToday() {
        let due = Date(timeIntervalSince1970: 1_000)
        XCTAssertEqual(status(daysRemaining: 0, dueDate: due, progress: 1, overdue: true).remainingShort,
                       "Vence hoje")
    }

    func testKmAxisWinsWhenBothOverdue() {
        let due = Date(timeIntervalSince1970: 1_000)
        let s = status(kmRemaining: -300, daysRemaining: -10, dueDate: due, progress: 1, overdue: true)
        XCTAssertEqual(s.remainingShort, "300 km além")
    }

    func testExactKmLimitFallsBackToVencida() {
        XCTAssertEqual(status(kmRemaining: 0, progress: 1, overdue: true).remainingShort, "Vencida")
    }

    // MARK: - indicatorColor

    func testIndicatorColorOnlyColorsAttention() {
        XCTAssertEqual(status(kmRemaining: -10, progress: 1, overdue: true).indicatorColor, .red)
        XCTAssertEqual(status(kmRemaining: 400, progress: 0.85).indicatorColor, .orange)
        let ok = status(kmRemaining: 2_000, progress: 0.3).indicatorColor
        XCTAssertNotEqual(ok, .orange, "em dia não pode colidir com atenção (tema laranja)")
        XCTAssertNotEqual(ok, .red)
    }
}
