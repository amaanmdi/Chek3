//
//  ViewModel.swift
//  Chek3
//
//  Created by Amaan Mahdi on 04/10/2025.
//

import Foundation
import Combine

/// Base protocol for all ViewModels in the MVVM architecture
protocol ViewModel: ObservableObject {
    /// Called when the view appears
    func onAppear()
    
    /// Called when the view disappears
    func onDisappear()
}

/// Base ViewModel with common state management
@MainActor
class BaseViewModel: ObservableObject, ViewModel {
    @Published var isLoading = false
    @Published var error: AppError?
    
    func onAppear() {
        // Override in subclasses
    }
    
    func onDisappear() {
        // Override in subclasses
    }
    
    /// Helper to handle async operations with loading and error states
    func performAsync<T>(_ operation: @escaping () async throws -> T) async -> T? {
        isLoading = true
        error = nil
        
        do {
            let result = try await operation()
            isLoading = false
            return result
        } catch {
            isLoading = false
            self.error = error as? AppError ?? .unknown(error.localizedDescription)
            return nil
        }
    }
}
