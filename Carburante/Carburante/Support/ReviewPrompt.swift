//
//  ReviewPrompt.swift
//  Carburante
//
//  Quando pedir avaliação na App Store. Regra pura (testada); a chamada ao
//  `requestReview` fica na view. Momento de valor = o abastecimento que acaba
//  de fechar um trecho de consumo (o usuário ganha um km/l). Uma vez por
//  versão do app — o iOS ainda limita a 3 exibições por ano e decide sozinho
//  se mostra (no TestFlight nunca mostra).
//

import Foundation

enum ReviewPrompt {
    /// Chave do `@AppStorage` com a versão (`CFBundleShortVersionString`) em
    /// que o pedido já foi feito.
    static let askedVersionKey = "reviewPromptAskedVersion"

    /// Registro histórico (`EventProvenance`) não é uso na hora — fechar um
    /// trecho digitando o passado não é o momento de valor.
    static func shouldAsk(closedConsumptionSegment: Bool, isHistorical: Bool,
                          askedVersion: String, currentVersion: String) -> Bool {
        closedConsumptionSegment && !isHistorical && askedVersion != currentVersion
    }

    static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }
}
