//
//  AppConstants.swift
//  Chek3
//
//  Created by Amaan Mahdi on 04/10/2025.
//

import Foundation

struct AppConstants {
    
    // MARK: - Authentication
    struct Auth {
        static let sessionRefreshInterval: TimeInterval = 3000 // 50 minutes
    }
    
    // MARK: - Validation
    struct Validation {
        static let emailMinLength = 5
        static let emailMaxLength = 254
        static let passwordMinLength = 6
        static let passwordMaxLength = 128
        static let emailCacheLimit = 100
        static let emailCacheTrimSize = 50
    }
    
    // MARK: - UI
    struct UI {
        static let smallHorizontalPadding: CGFloat = 6
        static let progressViewScale: CGFloat = 0.8
    }
}
