let configuration = ARWorldTrackingConfiguration()
configuration.worldAlignment = .gravityAndHeading
arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
