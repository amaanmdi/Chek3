//
//  NetworkMonitorService.swift
//  Chek3
//
//  Created by Amaan Mahdi on 04/10/2025.
//

import Foundation
import Network
import Combine

@MainActor
class NetworkMonitorService: ObservableObject {
    static let shared = NetworkMonitorService()
    
    @Published var isOnline: Bool = true
    
    private let networkMonitor = NWPathMonitor()
    private let networkQueue = DispatchQueue(label: "NetworkMonitor")
    private var connectivityCallback: ((Bool) -> Void)?
    
    private init() {
        setupNetworkMonitoring()
    }
    
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                let wasOnline = self.isOnline
                self.isOnline = path.status == .satisfied
                
                #if DEBUG
                print("🌐 Network status changed: \(wasOnline ? "Online" : "Offline") → \(self.isOnline ? "Online" : "Offline")")
                #endif
                
                // Notify callback if connectivity changed
                if wasOnline != self.isOnline {
                    self.connectivityCallback?(self.isOnline)
                }
            }
        }
        networkMonitor.start(queue: networkQueue)
    }
    
    func setConnectivityCallback(_ callback: @escaping (Bool) -> Void) {
        connectivityCallback = callback
    }
    
    deinit {
        networkMonitor.cancel()
    }
}
