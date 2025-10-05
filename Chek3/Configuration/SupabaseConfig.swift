//
//  SupabaseConfig.swift
//  Chek3
//
//  Created by Amaan Mahdi on 04/10/2025.
//

import Foundation

struct SupabaseConfig {
    // MARK: - Configuration Keys
    private static let projectURLKey = "SUPABASE_PROJECT_URL"
    private static let anonKeyKey = "SUPABASE_ANON_KEY"
    
    // MARK: - Configuration Values
    static let projectURL: String = {
        guard let url = getConfigurationValue(for: projectURLKey) else {
            fatalError("Missing SUPABASE_PROJECT_URL in configuration")
        }
        return url
    }()
    
    static let anonKey: String = {
        guard let key = getConfigurationValue(for: anonKeyKey) else {
            fatalError("Missing SUPABASE_ANON_KEY in configuration")
        }
        return key
    }()
    
    // MARK: - Private Methods
    private static func getConfigurationValue(for key: String) -> String? {
        // First try environment variables (for CI/CD)
        if let envValue = ProcessInfo.processInfo.environment[key] {
            return envValue
        }
        
        // Then try Info.plist (for local development)
        if let plistValue = Bundle.main.object(forInfoDictionaryKey: key) as? String {
            return plistValue
        }
        
        // Fallback to hardcoded values for development only
        #if DEBUG
        switch key {
        case projectURLKey:
            return "https://gbcsriyfsdiynbqrleru.supabase.co"
        case anonKeyKey:
            return "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdiY3NyaXlmc2RpeW5icXJsZXJ1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTkzNTQwMDcsImV4cCI6MjA3NDkzMDAwN30.d-iNDWAtPyrbFp-sUN7kkIuAaADjW5cpdy1M2TpN7ZA"
        default:
            return nil
        }
        #else
        return nil
        #endif
    }
}
