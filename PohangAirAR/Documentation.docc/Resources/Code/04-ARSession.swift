let configuration = ARWorldTrackingConfiguration()
configuration.worldAlignment = .gravity
arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
