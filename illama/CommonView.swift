//
//  CommonView.swift
//  illama
//
//  Created by Jack Youstra on 8/29/23.
//

import SwiftUI

struct CommonView: View {
    var body: some View {
        Group {
            if #available(iOS 17.0, *) {
                ContentView()
            } else {
                OldContentView()
            }
        }.toolbar {
            ToolbarItem(placement: .topBarLeading) {
                NavigationLink {
                    
                } label: {
                    Image(systemName: "gear")
                }
            }
        }
    }
}

#Preview {
    CommonView()
}
