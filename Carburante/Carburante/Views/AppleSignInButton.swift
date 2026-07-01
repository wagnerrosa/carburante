//
//  AppleSignInButton.swift
//  Carburante
//
//  Botão "Entrar com a Apple" reutilizável — encapsula todo o fluxo de link:
//  gera o nonce (CRU + SHA256), pede o token à Apple e chama
//  SyncService.linkApple (PROMOVE a sessão anônima, mantém o user_id). Usado em
//  AccountView (Ajustes) e no CTA do onboarding, sem duplicar a lógica.
//
//  Atrás da flag `appleSignInEnabled` + só faz sentido quando a sessão é
//  anônima → o próprio componente decide se aparece (retorna vazio caso
//  contrário). Quem chama não precisa repetir essas condições.
//

import SwiftUI
import AuthenticationServices
import SwiftData

struct AppleSignInButton: View {
    /// Chamado após o link bem-sucedido (ex.: fechar um sheet, seguir o fluxo).
    var onSuccess: () -> Void = {}

    @Environment(\.modelContext) private var modelContext
    /// Liga o botão. OFF some o componente inteiro (mesma flag do AccountView).
    @AppStorage("appleSignInEnabled") private var appleSignInEnabled = true

    private var sync: SyncService { .shared }
    /// Nonce CRU da tentativa em curso — gerado antes do request, enviado ao
    /// Supabase com o idToken. Mantido só durante o fluxo.
    @State private var currentNonce: String?
    @State private var isLinking = false
    /// Erro exposto a quem usa (a tela decide como mostrar). nil = sem erro.
    @Binding var errorMessage: String?

    /// Inicializador que dispensa o binding de erro quando a tela não exibe um.
    init(errorMessage: Binding<String?> = .constant(nil), onSuccess: @escaping () -> Void = {}) {
        self._errorMessage = errorMessage
        self.onSuccess = onSuccess
    }

    var body: some View {
        // Só faz sentido quando há sessão anônima a promover; flag desliga tudo.
        if appleSignInEnabled && sync.isAnonymous {
            SignInWithAppleButton(.signIn) { request in
                let nonce = AppleSignInNonce.random()
                currentNonce = nonce
                request.requestedScopes = [.fullName, .email]
                request.nonce = AppleSignInNonce.sha256(nonce)
            } onCompletion: { result in
                handleCompletion(result)
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 44)
            .disabled(isLinking)
        }
    }

    private func handleCompletion(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard
                let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                let tokenData = credential.identityToken,
                let idToken = String(data: tokenData, encoding: .utf8),
                let nonce = currentNonce
            else {
                errorMessage = "Não foi possível ler as credenciais da Apple."
                return
            }
            isLinking = true
            errorMessage = nil
            Task {
                let ok = await sync.linkApple(idToken: idToken, nonce: nonce, context: modelContext)
                isLinking = false
                currentNonce = nil
                if ok {
                    Haptics.success()
                    onSuccess()
                } else {
                    errorMessage = sync.lastError ?? "Falha ao entrar com a Apple."
                }
            }
        case .failure(let error):
            // Cancelamento do usuário não é erro a exibir.
            if (error as? ASAuthorizationError)?.code == .canceled { return }
            errorMessage = "Erro no login Apple: \(error.localizedDescription)"
        }
    }
}
