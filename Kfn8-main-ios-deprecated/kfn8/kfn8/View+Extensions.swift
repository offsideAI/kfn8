//
//  View+Extensions.swift
//  kfn8
//
//  Created by coder on 6/14/21.
//

import SwiftUI

extension View {
    @ViewBuilder func hidden(_ shouldHide: Bool) -> some View {
        switch shouldHide {
        case true: self.hidden()
        case false: self
        }
    }
}
