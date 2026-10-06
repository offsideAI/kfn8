//
//  DetailViewOne.swift
//  kfn8
//
//  Created by coder on 6/17/21.
//

import Foundation
import SwiftUI


struct DetailViewOne: View {
    let items: [String] = ["🤩", "🦊", "☘️", "🎃", "🐐"]
    var body: some View {
        List(items, id: \.self) { item in
            NavigationLink(
                destination: EmojiView(item: item), label: {
                    Text(item)
                }
            )
        }
    }
    
}

#if DEBUG

struct DetailViewOne_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            DetailViewOne()
        }
    }
}

#endif



