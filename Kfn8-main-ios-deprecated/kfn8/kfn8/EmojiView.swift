//
//  EmojiView.swift
//  kfn8
//
//  Created by coder on 6/18/21.
//

import SwiftUI


struct EmojiView: View {
    let item: String
    var body: some View {
        Text(item)
            .font(.system(size: 40))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.pink)
        
    }
    
}

#if DEBUG

struct EmojiView_Previews: PreviewProvider {
    static var previews: some View {
        EmojiView(item: "🍅")
    }
}

#endif



