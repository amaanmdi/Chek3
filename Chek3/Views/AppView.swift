//
//  AppView.swift
//  Chek3
//
//  Created by Amaan Mahdi on 04/10/2025.
//

import SwiftUI

struct AppView: View {
    @StateObject private var viewModel = AppViewModel()
    
    var body: some View {
        NavigationStack {
            FirstView()
        }
        .onAppear {
            viewModel.onAppear()
        }
    }
}

#Preview {
    AppView()
}
