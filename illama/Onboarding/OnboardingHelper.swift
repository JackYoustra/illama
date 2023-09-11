//
//  OnboardingHelper.swift
//  illama
//
//  Created by Jack Youstra on 9/10/23.
//

import UIKit
import UIOnboarding
import SwiftUI

struct UIOnboardingHelper {
    static func setUpIcon() -> UIImage {
        return Bundle.main.appIcon ?? .init(named: "onboarding-icon") ?? .init()
    }
    
    // First Title Line
    // Welcome Text
    static func setUpFirstTitleLine() -> NSMutableAttributedString {
        .init(string: "Welcome to", attributes: [.foregroundColor: UIColor.label])
    }
    
    // Second Title Line
    // App Name
    static func setUpSecondTitleLine() -> NSMutableAttributedString {
        .init(string: Bundle.main.displayName ?? "illama", attributes: [
            .foregroundColor: primaryColor
        ])
    }

    static func setUpFeatures() -> Array<UIOnboardingFeature> {
        return .init([
            .init(icon: UIImage(systemName: "lock.shield") ?? UIImage(),
                  title: "Private and Secure",
                  description: "Your chats are privately and securely stored on your phone."),
            .init(icon: UIImage(systemName: "bolt.badge.clock") ?? UIImage(),
                  title: "Fast",
                  description: "Faster than equivalently accurate language models on same hardware."),
            .init(icon: UIImage(systemName: "party.popper") ?? UIImage(),
                  title: "Free",
                  description: "No usage limits. No speed caps. No IP rights issues.")
        ])
    }
    
    static func setUpNotice() -> UIOnboardingTextViewConfiguration {
        return .init(icon: .init(named: "onboarding-notice-icon"),
                     text: "Developed and designed as a side project by NanoFlick.",
                     linkTitle: "Learn more...",
                     link: "https://www.nanoflick.com",
                     tint: primaryColor)
    }
    
    static func setUpButton() -> UIOnboardingButtonConfiguration {
        return .init(title: "Continue",
                     backgroundColor: primaryColor)
    }
    
    static let primaryColor: UIColor = .init(named: "camou") ?? .init(red: 0.654, green: 0.618, blue: 0.494, alpha: 1.0)
}

extension UIOnboardingViewConfiguration {
    static func setUp() -> UIOnboardingViewConfiguration {
        return .init(appIcon: UIOnboardingHelper.setUpIcon(),
                     firstTitleLine: UIOnboardingHelper.setUpFirstTitleLine(),
                     secondTitleLine: UIOnboardingHelper.setUpSecondTitleLine(),
                     features: UIOnboardingHelper.setUpFeatures(),
                     textViewConfiguration: UIOnboardingHelper.setUpNotice(),
                     buttonConfiguration: UIOnboardingHelper.setUpButton())
    }
}

#if swift(>=5.9)
#Preview {
    OnboardingView()
        .ignoresSafeArea()
}
#endif
