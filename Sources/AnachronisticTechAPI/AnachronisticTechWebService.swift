import Foundation
import Fluent
import Vapor
import WebServiceBuilder

public struct AnachronisticTechWebService : API, FileServer, LeafViewProvider, MigrationsProvider
{
    public var bundle: Bundle { Bundle.module }
    public let logBehaviour: LogBehaviour

    public var publicDirectoryPath: String
    public var publicDirectoryPathComponent: String

    public var resourcesDirectoryPath: String
    public var resourcesDirectoryPathComponent: String

    public var routeCollections: [RouteCollection]

    public var migrations: [Migration] = [
        CreatePost(),
        CreatePortfolio()
    ]

    public init(
        publicPath: String,
        resourcesPath: String,
        pathComponent: String,
        logBehaviour: LogBehaviour = .none,
        devMode: Bool = false
    )
    {
        publicDirectoryPath = publicPath
        resourcesDirectoryPath = resourcesPath
        publicDirectoryPathComponent = pathComponent
        resourcesDirectoryPathComponent = pathComponent
        self.logBehaviour = logBehaviour
        routeCollections = [
            AnachronisticTech(pathComponent: pathComponent, devMode: devMode),
            AnachronisticTechAPI()
        ]
    }

    internal static func validate(secret payloadSecret: String) throws
    {
        guard let secret = Environment.get("UPLOAD_SECRET"), try Bcrypt.verify(payloadSecret, created: secret) else
        {
            throw Abort(.unauthorized)
        }
    }
}
