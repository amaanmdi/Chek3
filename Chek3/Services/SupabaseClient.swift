//
//  SupabaseClient.swift
//  Chek3
//
//  Created by Amaan Mahdi on 04/10/2025.
//

import Foundation
import Supabase

class SupabaseClient {
    static let shared = SupabaseClient()
    
    let client: Supabase.SupabaseClient
    
    private init() {
        self.client = Supabase.SupabaseClient(
            supabaseURL: URL(string: SupabaseConfig.projectURL)!,
            supabaseKey: SupabaseConfig.anonKey
        )
    }
}
