//
//  Analytics.swift
//  Carburante
//
//  Camada fina e type-safe sobre o PostHog. Razão de existir:
//   - Nomes de evento como CONSTANTES (uma fonte) — sem string solta no app.
//   - Toda propriedade sensível passa por um BUCKET aqui (custo/litros/tempo
//     viram faixa; GPS/odômetro/data exata NUNCA saem). Privacidade por design.
//   - Um ponto único para super properties, opt-out e um futuro kill-switch.
//
//  Taxonomia: ver o plano de Product Analytics (Analytics v1). CRUD para
//  entidades (`*_created/_updated/_deleted`); verbo descritivo para estado/erro.
//
//  Cada evento é um método estático — o call-site fica em 1 linha e o
//  compilador garante que as propriedades certas (em bucket) foram passadas.
//

import Foundation
import PostHog

enum Analytics {

    // MARK: - Infra

    /// Configura super properties derivadas no device. Chamado no launch e a
    /// cada foreground (account_age_days muda por dia → precisa re-registrar,
    /// senão congela no valor do 1º setup).
    static func refreshSuperProperties(activeBikeCount: Int) {
        PostHogSDK.shared.register([
            "active_bike_count": activeBikeCount,
            "app_locale": Locale.current.identifier,
            "account_age_days": accountAgeDays(),
        ])
    }

    /// Dispara um evento. Wrapper único — facilita opt-out/kill-switch no futuro.
    private static func capture(_ event: String, _ props: [String: Any] = [:]) {
        PostHogSDK.shared.capture(event, properties: props)
    }

    /// Opt-out de telemetria (Configurações → "Compartilhar dados de uso").
    static func setEnabled(_ enabled: Bool) {
        if enabled { PostHogSDK.shared.optIn() } else { PostHogSDK.shared.optOut() }
    }

    // MARK: - Lifecycle

    static func appVersionUpdated(from: String, to: String) {
        capture("app_version_updated", ["from_version": from, "to_version": to])
    }

    // MARK: - Onboarding

    static func onboardingStarted() {
        capture("onboarding_started")
    }

    static func onboardingStepViewed(stepIndex: Int, stepName: String) {
        capture("onboarding_step_viewed", ["step_index": stepIndex, "step_name": stepName])
    }

    /// exit: skipped | added_bike | explored.
    static func onboardingCompleted(exit: String, lastStepIndex: Int) {
        capture("onboarding_completed", ["exit": exit, "last_step_index": lastStepIndex])
    }

    static func activationStepCompleted(step: String) {
        capture("activation_step_completed", ["step": step])
    }

    // MARK: - Motorcycle

    static func motorcycleCreated(_ moto: Motorcycle, isFirstBike: Bool,
                                  makeFromCatalog: Bool, filledOptionalDetails: Bool) {
        capture("motorcycle_created", [
            "make": moto.make,
            "category": moto.category as Any,
            "displacement_band": displacementBand(moto.displacementCC),
            "country": moto.country,
            "is_first_bike": isFirstBike,
            "make_from_catalog": makeFromCatalog,
            "filled_optional_details": filledOptionalDetails,
        ])
    }

    static func motorcycleSwitched(bikeCount: Int, toCategory: String?) {
        capture("motorcycle_switched", [
            "bike_count": bikeCount,
            "switched_to_category": toCategory as Any,
        ])
    }

    static func motorcycleDeleted(hadFuelLogs: Bool, fuelLogCount: Int, remainingBikeCount: Int) {
        capture("motorcycle_deleted", [
            "had_fuel_logs": hadFuelLogs,
            "fuel_log_count_band": countBand(fuelLogCount),
            "remaining_bike_count": remainingBikeCount,
        ])
    }

    // MARK: - Fuel

    static func fuelEntryStarted(entryPoint: String) {
        capture("fuel_entry_started", ["entry_point": entryPoint])
    }

    static func fuelCreated(fuelType: FuelType, isFullTank: Bool, ocrOutcome: OCROutcome,
                            hasLocation: Bool, logNumber: Int, liters: Double, cost: Double,
                            unlocksConsumption: Bool, currency: String) {
        capture("fuel_created", [
            "fuel_type": fuelType.rawValue,
            "is_full_tank": isFullTank,
            "ocr_outcome": ocrOutcome.rawValue,
            "has_location": hasLocation,
            "log_number": logNumber,
            "liters_band": litersBand(liters),
            "cost_band": costBand(cost),
            "currency": currency,
            "unlocks_consumption": unlocksConsumption,
        ])
    }

    static func fuelUpdated(fieldsChanged: [String], wasOcrFilled: Bool, timeSinceCreate: TimeInterval) {
        capture("fuel_updated", [
            "field_changed": fieldsChanged,
            "was_ocr_filled": wasOcrFilled,
            "time_since_create_band": timeSinceCreateBand(timeSinceCreate),
        ])
    }

    static func fuelDeleted(wasMostRecent: Bool) {
        capture("fuel_deleted", ["was_most_recent": wasMostRecent])
    }

    // MARK: - Maintenance

    static func maintenanceCreated(type: MaintenanceType, isFirst: Bool, fromScheduledPrompt: Bool,
                                   customInterval: Bool, revisaoItemCount: Int?) {
        capture("maintenance_created", [
            "type": type.rawValue,
            "is_first_maintenance": isFirst,
            "from_scheduled_prompt": fromScheduledPrompt,
            "custom_interval": customInterval,
            "revisao_item_count": revisaoItemCount as Any,
        ])
    }

    /// App agendou lembrete(s) de manutenção. Mede a cobertura do motor de
    /// re-engajamento (% da base alcançável fora do app).
    static func maintenanceReminderScheduled(planCount: Int, hasOverdue: Bool) {
        capture("maintenance_reminder_scheduled", [
            "plan_count": planCount,
            "has_overdue": hasOverdue,
        ])
    }

    static func maintenanceDeleted(type: MaintenanceType, wasRevisao: Bool) {
        capture("maintenance_deleted", ["type": type.rawValue, "was_revisao": wasRevisao])
    }

    /// Transição de estado (não-clique): a troca de óleo passou a vencida.
    /// Disparar UMA vez por transição — ver guarda em `OilOverdueTracker`.
    private static func oilChangeOverdue(axis: String, attentionCount: Int) {
        capture("oil_change_overdue", ["overdue_axis": axis, "attention_count": attentionCount])
    }

    /// Avalia os status de manutenção de uma moto e emite `oil_change_overdue`
    /// só quando o óleo passa de em-dia para vencido (guarda por moto). Chamado
    /// nos pontos que recalculam status (save/delete de abastecimento, save de
    /// manutenção). `MaintenanceStatus` é Equatable/leve → cálculo no main actor.
    static func evaluateOilOverdue(statuses: [MaintenanceStatus], bikeID: UUID) {
        guard let oil = statuses.first(where: { $0.type == .oleo }) else { return }
        guard OilOverdueTracker.transitionedToOverdue(bikeID: bikeID, isOverdue: oil.isOverdue) else { return }
        // Eixo do atraso: km (kmRemaining<0), data (daysRemaining<0), ou ambos.
        let kmOver = (oil.kmRemaining ?? 1) < 0
        let dateOver = (oil.daysRemaining ?? 1) < 0
        let axis = kmOver && dateOver ? "both" : (kmOver ? "km" : "date")
        let attention = statuses.filter(\.isOverdue).count
        oilChangeOverdue(axis: axis, attentionCount: attention)
    }

    // MARK: - Dashboard

    /// Resumo mostrou o estado "faltam N tanques cheios para o 1º km/l".
    static func consumptionWaitingShown(tanksRemaining: Int) {
        capture("consumption_waiting_shown", ["tanks_remaining": tanksRemaining])
    }

    // MARK: - Statistics

    static func consumptionChartViewed(hasData: Bool, segmentCount: Int, vsCategory: String) {
        capture("consumption_chart_viewed", [
            "has_data": hasData,
            "segment_count_band": countBand(segmentCount),
            "vs_category": vsCategory,
        ])
    }

    // MARK: - Value (entrega de valor)

    /// 1º uso real de uma feature. Dispara UMA vez por feature/usuário (guarda
    /// em `AdoptionTracker`). `account_age_days` (super property) dá o "tempo até
    /// adotar" automaticamente — não repetir aqui.
    static func featureAdopted(_ feature: Feature) {
        capture("feature_adopted", ["feature": feature.rawValue])
    }

    // MARK: - Errors / Permissions

    /// OCR rodou mas não entregou (sem texto / baixa confiança / sem campos).
    /// reason: no_text | low_confidence | no_fields. target: odometer | receipt.
    static func ocrFailed(target: String, reason: String, fieldsParsed: Int, confidence: Double?) {
        capture("ocr_failed", [
            "target": target,
            "reason": reason,
            "fields_parsed": fieldsParsed,
            "confidence_band": confidenceBand(confidence),
        ])
    }

    static func syncFailed(stage: String, errorCode: String) {
        capture("sync_failed", ["stage": stage, "error_code": errorCode])
    }

    static func permissionResponded(permission: String, result: String, context: String) {
        capture("permission_responded", [
            "permission": permission, "result": result, "context": context,
        ])
    }

    static func validationBlockedSave(error: String, screen: String) {
        capture("validation_blocked_save", ["error": error, "screen": screen])
    }
}

// MARK: - Tipos de apoio

extension Analytics {
    /// Resultado do uso de OCR num abastecimento. Substitui o antigo bool
    /// `used_ocr`: `edited` = OCR rodou mas o usuário corrigiu antes de salvar.
    enum OCROutcome: String {
        case notUsed = "not_used"
        case accepted
        case edited
    }

    /// Features rastreadas para adoção (1 evento, N features via esta prop).
    /// Adicionar uma feature futura = só um case novo (zero evento novo).
    enum Feature: String {
        case ocr
        case consumptionChart = "consumption_chart"
        case scheduledMaintenance = "scheduled_maintenance"
        case categoryComparison = "category_comparison"
        case export
    }
}

// MARK: - Buckets (conversão de valor sensível → faixa, no device)

extension Analytics {
    /// Custo → faixa semântica (currency-agnostic). Cortes em BRL no MVP;
    /// quando virar multi-país, trocar a tabela de cortes por `currency` — o
    /// nome do bucket não muda, a taxonomia não refatora. Sempre acompanhar de
    /// `currency` (ISO 4217) no evento.
    static func costBand(_ cost: Double) -> String {
        switch cost {
        case ..<50:   return "very_low"
        case ..<100:  return "low"
        case ..<200:  return "mid"
        case ..<300:  return "high"
        default:      return "very_high"
        }
    }

    /// Litros → faixa. Volume é universal (não localiza), não precisa de currency.
    static func litersBand(_ liters: Double) -> String {
        switch liters {
        case ..<5:   return "0-5"
        case ..<10:  return "5-10"
        case ..<15:  return "10-15"
        case ..<20:  return "15-20"
        default:     return "20+"
        }
    }

    /// Cilindrada → faixa (espelha `DisplacementBand` da Fase 2). nil → "unknown".
    static func displacementBand(_ cc: Int?) -> String {
        guard let cc else { return "unknown" }
        switch cc {
        case ..<150:  return "up_to_150"
        case ..<300:  return "150_300"
        case ..<500:  return "300_500"
        case ..<800:  return "500_800"
        default:      return "above_800"
        }
    }

    /// Confiança do OCR (0…1) → faixa. nil → "none".
    static func confidenceBand(_ c: Double?) -> String {
        guard let c else { return "none" }
        switch c {
        case ..<0.5:  return "low"
        case ..<0.8:  return "mid"
        default:      return "high"
        }
    }

    /// Contagem → faixa (evita cardinalidade alta; alinhado à meta >3).
    static func countBand(_ n: Int) -> String {
        switch n {
        case 0:        return "0"
        case 1...3:    return "1-3"
        case 4...10:   return "4-10"
        default:       return "10+"
        }
    }

    /// Tempo entre criação e edição → faixa. Separa correção imediata (input
    /// ruim) de tardia (histórico editável). Delta relativo, não revela datas.
    static func timeSinceCreateBand(_ seconds: TimeInterval) -> String {
        switch seconds {
        case ..<300:     return "0-5min"        // 5 min
        case ..<1800:    return "5-30min"       // 30 min
        case ..<86400:   return "30min-24h"     // 24 h
        default:         return "1d+"
        }
    }

    /// Dias desde a 1ª abertura do app (super property). Delta relativo — não
    /// expõe a data de instalação. `firstLaunchDate` salvo em UserDefaults.
    static func accountAgeDays() -> Int {
        let key = "firstLaunchDate"
        let now = Date()
        let first: Date
        if let saved = UserDefaults.standard.object(forKey: key) as? Date {
            first = saved
        } else {
            UserDefaults.standard.set(now, forKey: key)
            first = now
        }
        return max(0, Calendar.current.dateComponents([.day], from: first, to: now).day ?? 0)
    }
}

// MARK: - Guardas de "uma vez" (transições de estado / 1ª adoção)

/// Garante que um evento de adoção dispare só na 1ª vez, por feature.
enum AdoptionTracker {
    static func markAndCheck(_ feature: Analytics.Feature) -> Bool {
        let key = "adopted_\(feature.rawValue)"
        if UserDefaults.standard.bool(forKey: key) { return false }
        UserDefaults.standard.set(true, forKey: key)
        return true
    }
}

/// Emite `activation_step_completed` uma vez por passo, por moto. Recebe o
/// estado atual dos passos derivados e dispara só os que viraram concluídos.
enum ActivationTracker {
    static func sync(bikeID: UUID, fuel: Bool, maintenance: Bool, consumption: Bool) {
        let steps: [(String, Bool)] = [
            ("fuel", fuel), ("maintenance", maintenance), ("consumption", consumption),
        ]
        for (name, done) in steps where done {
            let key = "activation_\(bikeID.uuidString)_\(name)"
            if !UserDefaults.standard.bool(forKey: key) {
                UserDefaults.standard.set(true, forKey: key)
                Analytics.activationStepCompleted(step: name)
            }
        }
    }
}

/// Garante que `oil_change_overdue` dispare só na transição não→sim, por moto.
enum OilOverdueTracker {
    static func transitionedToOverdue(bikeID: UUID, isOverdue: Bool) -> Bool {
        let key = "oil_overdue_\(bikeID.uuidString)"
        let was = UserDefaults.standard.bool(forKey: key)
        UserDefaults.standard.set(isOverdue, forKey: key)
        return isOverdue && !was   // só quando vira vencida
    }
}
