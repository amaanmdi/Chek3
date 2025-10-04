//
//  Chek3App.swift
//  Chek3
//
//  Created by Amaan Mahdi on 04/10/2025.
//

import SwiftUI

@main
struct Chek3App: App {
    private let env: AppEnvironment = {
        #if DEBUG
        return .stub()
        #else
        return .production()
        #endif
    }()

    var body: some Scene {
        WindowGroup {
            AppView()
                .environment(\.appEnv, env)
        }
    }
}