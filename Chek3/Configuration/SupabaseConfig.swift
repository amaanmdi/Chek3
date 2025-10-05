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
            fatalError("Missing SUPABASE_PROJECT_URL in configuration. Please add it to Info.plist or environment variables.\n\nFor local development, add to Info.plist:\n<key>SUPABASE_PROJECT_URL</key>\n<string>https://your-project.supabase.co</string>\n\nFor production, set environment variable:\nexport SUPABASE_PROJECT_URL=https://your-project.supabase.co\n\nNote: Hardcoded values are available in DEBUG builds for development convenience.")
        }
        return url
    }()
    
    static let anonKey: String = {
        guard let key = getConfigurationValue(for: anonKeyKey) else {
            fatalError("Missing SUPABASE_ANON_KEY in configuration. Please add it to Info.plist or environment variables.\n\nFor local development, add to Info.plist:\n<key>SUPABASE_ANON_KEY</key>\n<string>your-anon-key-here</string>\n\nFor production, set environment variable:\nexport SUPABASE_ANON_KEY=your-anon-key-here\n\nNote: Hardcoded values are available in DEBUG builds for development convenience.")
        }
        return key
    }()
    
    // MARK: - Private Methods
    private static func getConfigurationValue(for key: String) -> String? {
        // First try environment variables (for CI/CD and production)
        if let envValue = ProcessInfo.processInfo.environment[key], !envValue.isEmpty {
            return envValue
        }
        
        // Then try Info.plist (for local development)
        if let plistValue = Bundle.main.object(forInfoDictionaryKey: key) as? String, !plistValue.isEmpty {
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
    
    // MARK: - Validation
    static func validateConfiguration() -> Bool {
        let url = getConfigurationValue(for: projectURLKey)
        let key = getConfigurationValue(for: anonKeyKey)
        
        guard let urlString = url, !urlString.isEmpty else {
            print("❌ SupabaseConfig: Missing or empty SUPABASE_PROJECT_URL")
            return false
        }
        
        guard let keyString = key, !keyString.isEmpty else {
            print("❌ SupabaseConfig: Missing or empty SUPABASE_ANON_KEY")
            return false
        }
        
        // Basic validation
        guard URL(string: urlString) != nil else {
            print("❌ SupabaseConfig: Invalid SUPABASE_PROJECT_URL format")
            return false
        }
        
        print("✅ SupabaseConfig: Configuration validated successfully")
        return true
    }
}
