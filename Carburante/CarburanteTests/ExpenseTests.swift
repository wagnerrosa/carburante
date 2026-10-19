//
//  ExpenseTests.swift
//  CarburanteTests
//
//  Outras despesas (`Expense`, Custos v2): título da linha, exclusão lógica em
//  cascata com a moto, entrada nos custos e no texto de exclusão da moto.
//

import XCTest
import SwiftData
@testable import Carburante

@MainActor
final class ExpenseTests: XCTestCase {

    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Motorcycle.self, FuelLog.self, MaintenanceLog.self,
                                           Expense.self, configurations: config)
        return ModelContext(container)
    }

    func testTitleIsCategoryUnlessOtherWithNotes() {
        XCTAssertEqual(Expense(amount: 10, category: .toll, notes: "Ponte").displayTitle, "Pedágio")
        XCTAssertEqual(Expense(amount: 10, category: .other).displayTitle, "Outra")
        XCTAssertEqual(Expense(amount: 10, category: .other, notes: "  Capa de chuva\nna loja X ").displayTitle,
                       "Capa de chuva")
    }

    func testSoftDeleteIsIdempotentAndBumpsUpdatedAt() {
        let expense = Expense(amount: 10, category: .parking, createdAt: Date(timeIntervalSince1970: 0))
        let first = Date(timeIntervalSince1970: 100)
        expense.softDelete(now: first)
        expense.softDelete(now: Date(timeIntervalSince1970: 200))
        XCTAssertEqual(expense.deletedAt, first)
        XCTAssertEqual(expense.updatedAt, first)
    }

    func testMotorcycleSoftDeleteCascadesToExpenses() throws {
        let ctx = try makeContext()
        let moto = Motorcycle(make: "Honda", model: "CG 160", year: 2024, country: "Brasil")
        ctx.insert(moto)
        let expense = Expense(amount: 300, category: .ipva, motorcycle: moto)
        ctx.insert(expense)
        try ctx.save()

        moto.softDelete()
        XCTAssertNotNil(expense.deletedAt, "o push precisa levar a exclusão da despesa junto")
        XCTAssertTrue(moto.activeExpenses.isEmpty)
    }

    func testActiveExpensesFeedCostsAndTotal() throws {
        let ctx = try makeContext()
        let moto = Motorcycle(make: "Honda", model: "CG 160", year: 2024, country: "Brasil")
        ctx.insert(moto)
        let ipva = Expense(amount: 300, category: .ipva, motorcycle: moto)
        let gone = Expense(amount: 50, category: .wash, motorcycle: moto)
        ctx.insert(ipva)
        ctx.insert(gone)
        ctx.insert(MaintenanceLog(mileage: 1000, cost: 120, type: .oleo, motorcycle: moto))
        ctx.insert(FuelLog(odometer: 1000, liters: 10, totalCost: 60, fuelType: .gasolinaComum, motorcycle: moto))
        gone.softDelete()
        try ctx.save()

        XCTAssertEqual(moto.otherCosts.map(\.label), ["IPVA"])
        XCTAssertEqual(moto.totalSpentEver, 60 + 120 + 300)
    }

    func testDeletionTextListsExpensesWithCommaAndE() throws {
        let ctx = try makeContext()
        let moto = Motorcycle(make: "Honda", model: "CG 160", year: 2024, country: "Brasil")
        ctx.insert(moto)
        ctx.insert(FuelLog(odometer: 1000, liters: 10, totalCost: 60, fuelType: .gasolinaComum, motorcycle: moto))
        ctx.insert(MaintenanceLog(mileage: 1000, type: .oleo, motorcycle: moto))
        ctx.insert(Expense(amount: 300, category: .ipva, motorcycle: moto))
        ctx.insert(Expense(amount: 20, category: .toll, motorcycle: moto))
        try ctx.save()

        XCTAssertEqual(moto.deletionConfirmationText,
                       "Excluir Honda CG 160 (2024) e 1 abastecimento, 1 manutenção e 2 despesas? Esta ação não pode ser desfeita.")
    }
}
