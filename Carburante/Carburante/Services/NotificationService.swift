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
//  Quem cadastra a moto e nunca registra também recebe os 3 marcos, contados do
//  cadastro (`neverLoggedFireDates`), depois de aceitar a pergunta do app
//  (`FirstFuelReminderOffer`). Os identificadores são os mesmos: o 1º
//  abastecimento salvo substitui esses lembretes pelos normais.
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

    // MARK: - Moto cadastrada, nenhum abastecimento ainda

    /// Hora fixa dos lembretes de quem nunca registrou. O cadastro costuma ser
    /// em casa, a qualquer hora: repetir a hora dele mandaria aviso às 23h.
    static let neverLoggedHour = 18

    /// Texto por marco para quem ainda não registrou nada. Aceita abastecimento
    /// de dias atrás de propósito: até 7 dias ainda conta como "na hora"
    /// (`EventProvenance`), e o fluxo deixa escolher o dia.
    static func neverLoggedMessage(forDay day: Int, bikeName: String) -> (title: String, body: String) {
        switch day {
        case 7:
            return ("Já abasteceu a \(bikeName)?",
                    "Registre mesmo que tenha sido há alguns dias: no app dá para escolher o dia.")
        case 14:
            return ("Quantos km/l a \(bikeName) faz?",
                    "Registre dois tanques cheios e o Carburante mostra o consumo de verdade.")
        default:
            return ("Abasteceu nos últimos dias?",
                    "Registre em poucos segundos. O histórico da sua moto começa no 1º registro.")
        }
    }

    /// Mesmos marcos, contados do dia do cadastro da moto, sempre às
    /// `neverLoggedHour`. Só os que ainda caem no futuro. Pura → testável.
    static func neverLoggedFireDates(
        bikeCreatedAt: Date,
        now: Date,
        calendar: Calendar = .current
    ) -> [(day: Int, fireDate: Date)] {
        let start = calendar.startOfDay(for: bikeCreatedAt)
        return dayOffsets.compactMap { day in
            guard let dayDate = calendar.date(byAdding: .day, value: day, to: start),
                  let fire = calendar.date(bySettingHour: neverLoggedHour, minute: 0, second: 0, of: dayDate),
                  fire > now else { return nil }
            return (day, fire)
        }
    }
}

/// Pergunta do app ("Lembrar do próximo abastecimento?") feita uma vez, depois
/// de cadastrar uma moto. Vem antes do pedido do iOS, que só pode ser feito uma
/// vez: com "Agora não", o pedido do sistema fica para o 1º abastecimento salvo,
/// como sempre foi.
enum FirstFuelReminderOffer: String {
    /// Nunca houve moto nova desde que a regra existe.
    case none = ""
    /// Moto acabou de ser cadastrada; a raiz do app resolve assim que o
    /// cadastro fecha.
    case pending
    /// Já resolvida (perguntou, agendou ou não se aplicava). Não volta.
    case done

    /// Chave do `@AppStorage` (form da moto marca `pending`, a raiz resolve).
    static let storageKey = "firstFuelReminderOffer"

    enum Action: Equatable {
        /// Mostrar a pergunta do app.
        case ask
        /// Permissão já dada: agenda sem perguntar.
        case scheduleSilently
        /// Nada a fazer (já registra abastecimento, ou negou notificações).
        case skip
    }

    /// O que fazer quando o cadastro fecha. Quem já tem abastecimento tem os
    /// lembretes normais; quem negou notificações não é perguntado de novo.
    static func action(hasAnyFuelLog: Bool, authorization: UNAuthorizationStatus) -> Action {
        guard !hasAnyFuelLog else { return .skip }
        switch authorization {
        case .notDetermined:
            return .ask
        case .authorized, .provisional, .ephemeral:
            return .scheduleSilently
        default:
            return .skip
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
    func requestAuthorizationIfNeeded(context: String = "reminder_scheduling") async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
            // Analytics: só na 1ª decisão. Contexto = algo a agendar (save de
            // abastecimento ou manutenção, ou "Lembrar" depois do cadastro da
            // moto) — pedido contextual, não no launch.
            Analytics.permissionResponded(permission: "notifications",
                                          result: granted ? "granted" : "denied",
                                          context: context)
            return granted
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
            await addAbsenceReminder(day: day, fireDate: fireDate,
                                     copy: AbsenceReminder.message(forDay: day))
        }
    }

    /// Moto cadastrada e nenhum abastecimento: agenda os marcos a partir do
    /// cadastro. Chamar só depois do "Lembrar" (ou com a permissão já dada) —
    /// aqui é onde o iOS pede a permissão, se ainda não decidida.
    func scheduleNeverLoggedReminders(bikeCreatedAt: Date, bikeName: String, now: Date = Date()) async {
        cancelAbsenceReminders()
        let pending = AbsenceReminder.neverLoggedFireDates(bikeCreatedAt: bikeCreatedAt, now: now)
        guard !pending.isEmpty else { return }
        guard await requestAuthorizationIfNeeded(context: "first_fuel_reminder") else { return }

        for (day, fireDate) in pending {
            await addAbsenceReminder(day: day, fireDate: fireDate,
                                     copy: AbsenceReminder.neverLoggedMessage(forDay: day, bikeName: bikeName))
        }
    }

    /// Mesmo identificador nos dois casos: um novo agendamento sempre
    /// substitui o anterior (o 1º abastecimento troca "nunca registrou" pelos
    /// lembretes de ausência).
    private func addAbsenceReminder(day: Int, fireDate: Date, copy: (title: String, body: String)) async {
        let content = UNMutableNotificationContent()
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

    /// Estado atual da permissão (para decidir se a pergunta do app aparece).
    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    /// Remove os lembretes de ausência pendentes (sem tocar em outros).
    func cancelAbsenceReminders() {
        let ids = AbsenceReminder.dayOffsets.map { "\(AbsenceReminder.identifierPrefix)\($0)" }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    // MARK: - Manutenção programada

    /// (Re)agenda os lembretes de manutenção a partir dos status de todos os
    /// tipos. Chamar ao salvar um abastecimento (muda km/progresso) ou uma
    /// manutenção (reinicia o intervalo do tipo). `statuses` são valores puros.
    /// A coalescência em `MaintenanceReminder.plans` evita excesso de notificação.
    func rescheduleMaintenance(statuses: [MaintenanceStatus], now: Date = Date()) async {
        await cancelMaintenanceReminders()
        let plans = MaintenanceReminder.plans(for: statuses, now: now)
        guard !plans.isEmpty else { return }
        guard await requestAuthorizationIfNeeded() else { return }

        await MainActor.run {
            Analytics.maintenanceReminderScheduled(
                planCount: plans.count,
                hasOverdue: statuses.contains(where: \.isOverdue)
            )
        }

        for plan in plans {
            let content = UNMutableNotificationContent()
            content.title = plan.title
            content.body = plan.body
            content.sound = .default

            let comps = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute], from: plan.fireDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let request = UNNotificationRequest(
                identifier: "\(MaintenanceReminder.identifierPrefix)\(plan.idSuffix)",
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }
    }

    /// Remove os lembretes de manutenção pendentes (sem tocar em outros, ex.:
    /// ausência). Como o conjunto de identificadores é dinâmico (por tipo),
    /// busca os pendentes e filtra pelo prefixo. Também limpa os lembretes
    /// legados só-óleo (`oil-change-*`) na migração.
    func cancelMaintenanceReminders() async {
        let pending = await center.pendingNotificationRequests()
        let ids = pending.map(\.identifier).filter {
            $0.hasPrefix(MaintenanceReminder.identifierPrefix)
                || $0.hasPrefix(MaintenanceReminder.legacyOilPrefix)
        }
        if !ids.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }
}
