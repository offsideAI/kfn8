//
//  MoreView.swift
//  kfn8
//
//  Created by coder on 6/9/21.
//

import SwiftUI

struct MoreView: View {
    @Binding var isMyCollectionShown: Bool
    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                 // Gridviews for thumbnails
            }
            .navigationBarTitle(Text("History"), displayMode: .large)
            .navigationBarItems(trailing:
                                    Button(action: {
                                        self.isMyCollectionShown.toggle()
                                    }) {
                                        Text("Done").bold()
                                    })
        }
    }
    
}
