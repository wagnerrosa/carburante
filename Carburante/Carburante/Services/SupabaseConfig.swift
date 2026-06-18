//
//  SupabaseConfig.swift
//  Carburante
//
//  URL + publishable key do Supabase. A publishable key é client-side por
//  design (igual NEXT_PUBLIC_*): segura no app porque o RLS protege os dados.
//  A secret key NUNCA entra aqui.
//

import Foundation

enum SupabaseConfig {
    static let url = URL(string: "https://ptcjnqnueazqpkinvgwr.supabase.co")!
    static let publishableKey = "sb_publishable_lCNiiJISB86c6UuASkT1ig_SWdwu2yL"
}
