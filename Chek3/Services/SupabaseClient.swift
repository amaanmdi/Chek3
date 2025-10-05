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
        // Validate configuration before creating client
        guard SupabaseConfig.validateConfiguration() else {
            fatalError("Supabase configuration validation failed. Please check your Info.plist or environment variables.")
        }
        
        self.client = Supabase.SupabaseClient(
            supabaseURL: URL(string: SupabaseConfig.projectURL)!,
            supabaseKey: SupabaseConfig.anonKey
        )
    }
}
