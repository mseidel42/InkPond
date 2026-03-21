//
//  URL+Identifiable.swift
//  InkPond
//

import Foundation

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}
