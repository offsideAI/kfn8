//
//  CustomARView.swift
//  FocusEntity-Example
//
//

import RealityKit
import FocusEntity
import Combine
import ARKit
import SwiftUI

class CustomARView: ARView {
    
  enum FocusStyleChoices {
    case classic
    case material
    case color
  }

  /// Style to be displayed in the example
  let focusStyle: FocusStyleChoices = .classic
  var focusEntity: FocusEntity?
  var sessionSettings: SessionSettings
  
  required init(frame frameRect: CGRect, sessionSettings: SessionSettings) {
    self.sessionSettings = sessionSettings
    super.init(frame: frameRect)
    self.setupConfig()

    switch self.focusStyle {
    case .color:
      self.focusEntity = FocusEntity(on: self, focus: .plane)
    case .material:
      do {
        let onColor: MaterialColorParameter = try .texture(.load(named: "Add"))
        let offColor: MaterialColorParameter = try .texture(.load(named: "Open"))
        self.focusEntity = FocusEntity(
          on: self,
          style: .colored(
            onColor: onColor, offColor: offColor,
            nonTrackingColor: offColor
          )
        )
      } catch {
        self.focusEntity = FocusEntity(on: self, focus: .classic)
        print("Unable to load plane textures")
        print(error.localizedDescription)
      }
    default:
      self.focusEntity = FocusEntity(on: self, focus: .classic)
    }
    
  }
  required init(frame frameRect: CGRect) {
    fatalError("init(frame:) has not been implemented")
  }

  func setupConfig() {
    let config = ARWorldTrackingConfiguration()
    config.planeDetection = [.horizontal, .vertical]
    session.run(config, options: [])
  }

  @objc required dynamic init?(coder decoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

extension CustomARView: FocusEntityDelegate {
  func toTrackingState() {
    print("tracking")
  }
  func toInitializingState() {
    print("initializing")
  }
}
