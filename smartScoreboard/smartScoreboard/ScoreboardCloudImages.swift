import Foundation

nonisolated struct ScoreboardCloudImageReference: Sendable, Equatable {
    var slot: String
    var id: String
    var path: String
}

extension ScoreboardWebAPIState {
    nonisolated var cloudImageReferences: [ScoreboardCloudImageReference] {
        var images: [ScoreboardCloudImageReference] = []
        if let logo = teams.home.logo { images.append(.init(slot: "home", id: logo.id, path: logo.path)) }
        if let logo = teams.guest.logo { images.append(.init(slot: "guest", id: logo.id, path: logo.path)) }
        if let logo = display?.eventLogo { images.append(.init(slot: "event", id: logo.id, path: logo.path)) }
        if let background = display?.backgroundImage { images.append(.init(slot: "background", id: background.id, path: background.path)) }
        return images
    }
}
