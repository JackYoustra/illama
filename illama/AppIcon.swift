//
//  AppIcon.swift
//  illama
//
//  Created by Jack Youstra on 9/10/23.
//

import Foundation

enum AppIcon: String, CaseIterable, Identifiable, CustomStringConvertible {
    case primary = "AppIcon"
    case smaller = "AppIcon-smaller"
    case full = "AppIcon-full"
    
    var id: String {
        rawValue
    }
    
    var iconName: String? {
            switch self {
            case .primary:
                /// `nil` is used to reset the app icon back to its primary icon.
                return nil
            default:
                return rawValue
            }
        }
    
    var description: String {
        switch self {
        case .primary:
            return "Head"
        case .smaller:
            return "Portrait"
        case .full:
            return "Full"
        }
    }
    
    var preview: String {
        switch self {
        case .primary:
            return "headshot-preview"
        case .smaller:
            return "smaller-preview"
        case .full:
            return "full-preview"
        }
    }
}
