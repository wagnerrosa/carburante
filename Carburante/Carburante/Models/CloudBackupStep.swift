//
//  CloudBackupStep.swift
//  Carburante
//
//  Passo "Guarde seu histórico" dos primeiros passos: convida a entrar com a
//  Apple para o histórico não se perder ao trocar ou perder o iPhone.
//
//  O checklist é por moto, mas a conta é do usuário. Regra:
//  - sessão anônima → passo pendente (em qualquer moto);
//  - entrou com a Apple DEPOIS que a moto foi cadastrada → passo concluído
//    (fez pelo guia desta moto: o ✓ é o retorno);
//  - já tinha conta quando a moto nasceu (ou data desconhecida) → o passo não
//    aparece. Moto nova de quem já entrou não pede de novo.
//  Derivado (sessão + data do vínculo + `createdAt` da moto), nada gravado.
//

import Foundation

enum CloudBackupStep {

    enum State: Equatable {
        case pending
        case done
    }

    /// Estado do passo para uma moto, ou nil quando ele não deve aparecer.
    static func state(isAnonymous: Bool, appleLinkedAt: Date?, bikeCreatedAt: Date) -> State? {
        if isAnonymous { return .pending }
        if let linkedAt = appleLinkedAt, bikeCreatedAt < linkedAt { return .done }
        return nil
    }
}
