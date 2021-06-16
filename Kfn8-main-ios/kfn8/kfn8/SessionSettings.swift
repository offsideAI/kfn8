//
//  SessionSettings.swift
//  kfn8
//
//  Created by coder on 6/15/21.
//

import SwiftUI

class SessionSettings: ObservableObject {
    @Published var isPeopleOcclusionEnabled: Bool = false
    @Published var isObjectOcclusionEnabled: Bool = false
    @Published var isLidarDebugEnabled: Bool = false
    @Published var isMultiuserEnabled: Bool = false
    
    
}
