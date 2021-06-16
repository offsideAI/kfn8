//
//  ItemButton.swift
//  kfn8
//
//  Created by coder on 6/16/21.
//

import SwiftUI

struct ItemButton: View {
    let model: Model
    let height: CGFloat?
    let action: () -> Void
    var body: some View {
        Button(action: {
            self.action()
        }) {
            Image(uiImage: self.model.image)
                .resizable()
                .frame(height: height)
                .aspectRatio(1/1, contentMode: .fit)
                .background(Color(UIColor.secondarySystemFill))
                .cornerRadius(8.0)
        }
    }
}
