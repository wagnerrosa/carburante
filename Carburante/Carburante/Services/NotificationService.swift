//
//  NotificationService.swift
//  Carburante
//
//  Lembretes LOCAIS de ausência (sem backend, sem push remoto). Reduz abandono
//  por esquecimento: se o piloto passa dias sem registrar abastecimento, o app
//  cutuca em 7, 14 e 21 dias após o último registro.
//
//  A cada novo abastecimento, os lembretes são recalculados (cancelados e
//  reagendados a partir da nova data). A permissão é pedida de forma contextual
//  — na primeira vez que há algo a agendar (após salvar um abastecimento), não
//  na abertura do app.
//

import Foundation
import UserNotifications

/// Marcos (em dias após o último abastecimento) dos lembretes de ausência.
/// A lógica de "quais ainda estão no futuro" é pura → testável (`pendingOffsets`).
enum AbsenceReminder {
    /// Marcos em dias. Ajustável sem tocar no resto.
    static let dayOffsets: [Int] = [7, 14, 21]

    /// Prefixo dos identificadores no centro de notificações — permite cancelar
    /// só os lembretes de ausência sem mexer em outros (ex.: troca de óleo).
    static let identifierPrefix = "absence-reminder-"

    /// Texto de cada lembrete por marco.
    static func message(forDay day: Int) -> (title: String, body: String) {
        switch day {
        case 7:
            return ("Abasteceu esta semana?",
                    "Faz 7 dias do seu último registro. Registre para manter seu consumo em dia.")
        case 14:
            return ("Seu consumo está esperando",
                    "Já são 2 semanas sem registrar abastecimento. Leva poucos segundos.")
        default:
            return ("Não perca seu histórico",
                    "Faz \(day) dias sem registro. Mantenha o acompanhamento da sua moto.")
        }
    }

    /// Dos marcos, quais ainda caem no FUTURO em relação a `now`, dado o último
    /// abastecimento em `lastFuelDate`. Retorna (dia, dataDeDisparo) ordenado.
    /// Pura e determinística (recebe `now`/`calendar`) → testável.
    static func pendingFireDates(
        lastFuelDate: Date,
        now: Date,
        calendar: Calendar = .current
    ) -> [(day: Int, fireDate: Date)] {
        dayOffsets.compactMap { day in
            guard let fire = calendar.date(byAdding: .day, value: day, to: lastFuelDate),
                  fire > now else { return nil }
            return (day, fire)
        }
    }
}

/// Wrapper fino sobre `UNUserNotificationCenter`. Isola o framework do resto do
/// app e centraliza o (re)agendamento dos lembretes de ausência.
struct NotificationService {
    static let shared = NotificationService()

    private var center: UNUserNotificationCenter { .current() }

    /// Pede permissão se ainda não decidida. Retorna se está autorizado.
    /// Não força nada se o usuário já negou (respeita a escolha).
    @discardableResult
    func requestAuthorizationIfNeeded() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        case .authorized, .provisional, .ephemeral:
            return true
        default:
            return false
        }
    }

    /// Recalcula os lembretes de ausência a partir do abastecimento mais recente.
    /// Cancela os antigos e agenda os marcos futuros. Chamar após salvar um
    /// abastecimento. Sem `lastFuelDate` (nenhum registro) só cancela.
    func rescheduleAbsenceReminders(lastFuelDate: Date?, now: Date = Date()) async {
        cancelAbsenceReminders()
        guard let lastFuelDate else { return }

        let pending = AbsenceReminder.pendingFireDates(lastFuelDate: lastFuelDate, now: now)
        guard !pending.isEmpty else { return }

        // Só pede permissão quando há de fato algo a agendar (contextual).
        guard await requestAuthorizationIfNeeded() else { return }

        for (day, fireDate) in pending {
            let content = UNMutableNotificationContent()
            let copy = AbsenceReminder.message(forDay: day)
            content.title = copy.title
            content.body = copy.body
            content.sound = .default

            let comps = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute], from: fireDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let request = UNNotificationRequest(
                identifier: "\(AbsenceReminder.identifierPrefix)\(day)",
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }
    }

    /// Remove os lembretes de ausência pendentes (sem tocar em outros).
    func cancelAbsenceReminders() {
        let ids = AbsenceReminder.dayOffsets.map { "\(AbsenceReminder.identifierPrefix)\($0)" }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }
}
