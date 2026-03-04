//
//  URL+Identifiable.swift
//  Typist
//

import Foundation

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}
