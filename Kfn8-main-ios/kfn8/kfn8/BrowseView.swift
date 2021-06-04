//
//  BrowseView.swift
//  kfn8
//
//  Created by coder on 6/4/21.
//

import SwiftUI

struct BrowseView: View {
    @Binding var isBrowseShown: Bool
    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                 // Gridviews for thumbnails
            }
            .navigationBarTitle(Text("Browse"), displayMode: .large)
            .navigationBarItems(trailing:
                                    Button(action: {
                                        self.isBrowseShown.toggle()
                                    }) {
                                        Text("Done").bold()
                                    })
        }
    }
    
}
