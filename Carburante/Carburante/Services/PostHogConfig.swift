//
//  PostHogConfig.swift
//  Carburante
//
//  Project API key + host do PostHog. A project API key é client-side por
//  design (igual a publishable key do Supabase): segura no app, só permite
//  ingestão de eventos. Region US → host us.i.posthog.com.
//
//  Nome PostHogSettings (não PostHogConfig) p/ evitar colisão com o tipo
//  PostHogConfig do SDK.
//

import Foundation

enum PostHogSettings {
    static let apiKey = "phc_oG2P2J8HqjakFg9G7MwQykuAcuwwATfrCuZ9rWLgHMr4"
    static let host = "https://us.i.posthog.com"
}
