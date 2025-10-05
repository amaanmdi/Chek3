//
//  StringExtensions.swift
//  Chek3
//
//  Created by Amaan Mahdi on 04/10/2025.
//

import Foundation

extension String {
    var isNilOrEmpty: Bool {
        return self.isEmpty
    }
}

extension Optional where Wrapped == String {
    var isNilOrEmpty: Bool {
        return self?.isEmpty ?? true
    }
}
