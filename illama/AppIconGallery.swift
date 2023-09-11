//
//  AppIconGallery.swift
//  illama
//
//  Created by Jack Youstra on 9/10/23.
//

import SwiftUI

// Add as needed, too many blows up compile times
public func unwrap<T>(_ v: T???) -> T? {
    v as? T
}

extension Binding where Value: Equatable {
    func equalsNoUnset(_ value: Value) -> Binding<Bool> {
        Binding<Bool> {
            wrappedValue == value
        } set: { _ in
            wrappedValue = value
        }
    }
}

struct AppIconGallery: View {
    @State private var selectedIcon = AppIcon(string: UIApplication.shared.alternateIconName)
    
    var body: some View {
        if UIApplication.shared.supportsAlternateIcons && false {
            VStack {
            ScrollView {
                VStack(spacing: 11) {
                    ForEach(AppIcon.allCases) { appIcon in
                        Toggle(isOn: $selectedIcon.equalsNoUnset(appIcon)) {
                            HStack(spacing: 16) {
                                Image(appIcon.preview)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 60, height: 60)
                                    .cornerRadius(12)
                                Text(appIcon.description)
                                    .font(.body)
                            }
                        }
                        .padding(EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16))
                        .background(Color.init(uiColor: UIColor.systemGroupedBackground))
                        .cornerRadius(20)
                    }
                }.padding(.horizontal)
                .padding(.vertical, 40)
            }.bounceModifierIfWeCan()
        }
            // propagate changes
            .task(id: selectedIcon) {
                let icon = selectedIcon
                guard UIApplication.shared.alternateIconName != icon.iconName else {
                            /// No need to update since we're already using this icon.
                            return
                        }

                        do {
                            try await UIApplication.shared.setAlternateIconName(icon.iconName)
                        } catch {
                            /// We're only logging the error here and not actively handling the app icon failure
                            /// since it's very unlikely to fail.
                            print("Updating icon to \(String(describing: icon.iconName)) failed.")

                            /// Restore previous app icon
                            selectedIcon = AppIcon(string: UIApplication.shared.alternateIconName)
                        }
            }
            // ensure accurate
            .task {
        let stream = UIApplication.shared
            .publisher(for: \.alternateIconName)
            .map(AppIcon.init(string:))
            .values
                do {
                    for try await icon in stream {
                        if selectedIcon != icon {
                            selectedIcon = icon
                        }
                    }
                } catch {
                    print("No longer listening to icon updates")
                }
            }
        } else {
            VStack {
                Spacer()
                Text("For some reason, I can't set alternate icons. Strange!")
                Spacer()
            }
        }
    }
}

extension AppIcon {
    init(string: String?) {
        self = unwrap(string.map(AppIcon.init(rawValue:))) ?? .primary
    }
}

extension View {
    func bounceModifierIfWeCan() -> some View {
        if #available(iOS 16.4, *) {
            return self
                .scrollBounceBehavior(.basedOnSize)
        } else {
            return self
        }
    }
}

#Preview {
    NavigationView {
        SettingsView()
    }
}
