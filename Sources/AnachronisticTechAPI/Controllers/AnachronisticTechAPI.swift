//
//  AnachronisticTechAPI.swift
//  
//
//  Created by Daniel Marriner on 08/10/2022.
//

import Fluent
import Vapor
import Files
import Ink

public struct AnachronisticTechAPI: RouteCollection {
    public init() {}

    public func boot(routes: RoutesBuilder) throws {
        let api = routes.grouped("at-api")
        api.get("images", use: getAllImages)
        api.post("upload", use: postImage)
        api.get("tag", ":n", use: getPostsByTag)

        let posts = api.grouped("posts")
        posts.get(use: getAllPosts)
        posts.post(use: createNewPost)
        posts.get(":id", use: getPost)
        posts.post(":id", use: updatePost)
        posts.get("articles", use: getPostArticles)
        posts.get("articles", ":n", use: getPostArticles)
        posts.get("projects", use: getPostProjects)
        posts.get("projects", ":n", use: getPostProjects)

        let portfolio = api.grouped("portfolio")
        portfolio.get(use: getAllPortfolioItems)
        portfolio.post(use: createNewPortfolioItem)
        portfolio.get(":id", use: getPortfolioItem)
        portfolio.post(":id", use: updatePortfolioItem)
        portfolio.get("interests", use: getPortfolioInterestItems)
        portfolio.get("interests", ":n", use: getPortfolioInterestItems)
        portfolio.get("projects", use: getPortfolioProjectItems)
        portfolio.get("projects", ":n", use: getPortfolioProjectItems)
    }

    func getPostsByTag(req: Request) throws -> EventLoopFuture<[Post.Output]> {
        guard let tag = req.parameters.get("n", as: String.self) else {
            throw Abort(.badRequest)
        }

        return Post
            .query(on: req.db)
            .sort(\.$date, .ascending)
            .filter(\.$tags ~~ tag)
            .all()
            .mapEach { $0.toOutput(with: req) }
    }

    // MARK: - Handlers relating to images
    func getAllImages(req: Request) throws -> [String] {
        return (try? Folder(path: "\(req.application.directory.publicDirectory)/AnachronisticTech/content/images")
            .files
            .map { $0.name }
            .filter { $0.split(separator: ".").last != "txt" }
        ) ?? []
    }

    func postImage(req: Request) throws -> Response {
        struct PostData: Content {
            var file: Vapor.File
            var secret: String
        }

        guard let payload = try? req.content.decode(PostData.self) else {
            throw Abort(.custom(code: 47, reasonPhrase: "couldn't decode data"))
        }

        try AnachronisticTechWebService.validate(secret: payload.secret)

        let data = Data(buffer: payload.file.data)

        guard FileManager.default.createFile(
            atPath: "\(req.application.directory.publicDirectory)/AnachronisticTech/content/images/\(payload.file.filename)",
            contents: data,
            attributes: [.posixPermissions: 0o544]
        ) else {
            throw Abort(.custom(code: 47, reasonPhrase: "error saving file"))
        }

        return Response(
            status: .ok,
            body: Response.Body(string: "file uploaded")
        )
    }

    // MARK: - Handlers relating to Posts
    func getAllPosts(req: Request) throws -> EventLoopFuture<[Post.Output]> {
        return Post
            .query(on: req.db)
            .sort(\.$date, .descending)
            .all()
            .mapEach { $0.toOutput(with: req) }
    }

    func createNewPost(req: Request) throws -> EventLoopFuture<HTTPStatus> {
        guard let payload = try? req.content.decode(Post.Input.self), let data = payload.data else {
            throw Abort(.custom(code: 47, reasonPhrase: "error decoding payload"))
        }

        try AnachronisticTechWebService.validate(secret: payload.secret)

        let markdown = String(data: data, encoding: .utf8)!
            .replacingOccurrences(of: "\r\n", with: "\n")
        let parser = MarkdownParser()
        let result = parser.parse(markdown)

        guard let dateString = result.metadata["date"], let date = Post.dateFormatter.date(from: dateString) else {
            throw Abort(.custom(code: 47, reasonPhrase: "bad date value"))
        }

        let post = Post(
            icon: payload.icon,
            type: result.metadata["type"] == "project" ? 1 : 0,
            date: date,
            tags: result.metadata["tags"] ?? ""
        )
        return post
            .save(on: req.db)
            .map {
                do {
                    let _ = try Folder(path: "\(req.application.directory.publicDirectory)/AnachronisticTech/content/posts")
                        .createFile(at: "\(post.id!).md", contents: data)
                } catch {
                    let _ = Post
                        .find(post.id!, on: req.db)
                        .unwrap(or: Abort(.notFound))
                        .flatMap({ $0.delete(on: req.db) })
                    return .custom(code: 47, reasonPhrase: "error saving file")
                }
                return .ok
            }
    }

    func getPost(req: Request) throws -> EventLoopFuture<Post.Output> {
        return Post
            .find(req.parameters.get("id"), on: req.db)
            .unwrap(or: Abort(.notFound))
            .map { $0.toOutput(with: req) }
    }

    func updatePost(req: Request) throws -> EventLoopFuture<HTTPStatus> {
        guard let payload = try? req.content.decode(Post.Input.self), let id = req.parameters.get("id", as: Int.self) else {
            throw Abort(.custom(code: 47, reasonPhrase: "error getting id or decoding payload"))
        }

        try AnachronisticTechWebService.validate(secret: payload.secret)

        return Post
            .find(id, on: req.db)
            .unwrap(or: Abort(.notFound))
            .map { $0.toOutput(with: req) }
            .flatMap { post in
                let date: Date
                let type: Int
                let tags: String
                if let data = payload.data, data.count > 10 {
                    let markdown = String(data: data, encoding: .utf8)!
                        .replacingOccurrences(of: "\r\n", with: "\n")
                    let parser = MarkdownParser()
                    let result = parser.parse(markdown)

                    date = Post.dateFormatter.date(from: result.metadata["date"]!)!
                    type = result.metadata["type"] == "project" ? 1 : 0
                    tags = result.metadata["tags"] ?? ""
                } else {
                    date = post.date
                    type = post.type
                    tags = post.tags.joined(separator: ";")
                }
                let revertDate = post.date
                let revertType = post.type
                let revertIcon = post.icon
                let revertTags = post.tags.joined(separator: ";")

                return Post.query(on: req.db)
                    .filter(\.$id == id)
                    .set(\.$type, to: type)
                    .set(\.$icon, to: payload.icon)
                    .set(\.$date, to: date)
                    .set(\.$tags, to: tags)
                    .update()
                    .map {
                        if let data = payload.data, data.count > 10 {
                            do {
                                let _ = try Folder(path: "\(req.application.directory.publicDirectory)/posts")
                                    .createFile(at: "\(id).md", contents: data)
                            } catch {
                                let _ = Post.query(on: req.db)
                                    .filter(\.$id == id)
                                    .set(\.$type, to: revertType)
                                    .set(\.$icon, to: revertIcon)
                                    .set(\.$date, to: revertDate)
                                    .set(\.$tags, to: revertTags)
                                    .update()
                                return .custom(code: 47, reasonPhrase: "error saving file")
                            }
                        }
                        return .ok
                    }
            }
    }

    func getPostArticles(req: Request) throws -> EventLoopFuture<[Post.Output]> {
        if let id = req.parameters.get("n", as: Int.self) {
            return Post
                .query(on: req.db)
                .filter(\.$type == 0)
                .sort(\.$date, .descending)
                .range(0..<id)
                .all()
                .mapEach { $0.toOutput(with: req) }
        } else {
            return Post
                .query(on: req.db)
                .filter(\.$type == 0)
                .sort(\.$date, .descending)
                .all()
                .mapEach { $0.toOutput(with: req) }
        }
    }

    func getPostProjects(req: Request) throws -> EventLoopFuture<[Post.Output]> {
        if let id = req.parameters.get("n", as: Int.self) {
            return Post
                .query(on: req.db)
                .filter(\.$type == 1)
                .sort(\.$date, .descending)
                .range(0..<id)
                .all()
                .mapEach { $0.toOutput(with: req) }
        } else {
            return Post
                .query(on: req.db)
                .filter(\.$type == 1)
                .sort(\.$date, .descending)
                .all()
                .mapEach { $0.toOutput(with: req) }
        }
    }

    // MARK: - Handlers relating to Portfolio
    func getAllPortfolioItems(req: Request) throws -> EventLoopFuture<[PortfolioItem.Output]> {
        return PortfolioItem
            .query(on: req.db)
            .sort(\.$id, .descending)
            .all()
            .mapEach { $0.toOutput(with: req) }
    }

    func createNewPortfolioItem(req: Request) throws -> EventLoopFuture<HTTPStatus> {
        guard let payload = try? req.content.decode(PortfolioItem.Input.self), let data = payload.data else {
            throw Abort(.custom(code: 47, reasonPhrase: "error decoding payload"))
        }

        try AnachronisticTechWebService.validate(secret: payload.secret)

        let markdown = String(data: data, encoding: .utf8)!
            .replacingOccurrences(of: "\r\n", with: "\n")
        let parser = MarkdownParser()
        let result = parser.parse(markdown)

        guard let tag = result.metadata["tag"] else {
            throw Abort(.custom(code: 47, reasonPhrase: "bad tag value"))
        }

        let item = PortfolioItem(
            icon: payload.icon,
            type: result.metadata["type"] == "project" ? 1 : 0,
            tag: tag
        )
        return item
            .save(on: req.db)
            .map {
                do {
                    let _ = try Folder(path: "\(req.application.directory.publicDirectory)/AnachronisticTech/content/portfolio")
                        .createFile(at: "\(item.id!).md", contents: data)
                } catch {
                    let _ = PortfolioItem
                        .find(item.id!, on: req.db)
                        .unwrap(or: Abort(.notFound))
                        .flatMap({ $0.delete(on: req.db) })
                    return .custom(code: 47, reasonPhrase: "error saving file")
                }
                return .ok
            }
    }

    func getPortfolioItem(req: Request) throws -> EventLoopFuture<PortfolioItem.Output> {
        return PortfolioItem
            .find(req.parameters.get("id"), on: req.db)
            .unwrap(or: Abort(.notFound))
            .map { $0.toOutput(with: req) }
    }

    func updatePortfolioItem(req: Request) throws -> EventLoopFuture<HTTPStatus> {
        guard let payload = try? req.content.decode(PortfolioItem.Input.self), let id = req.parameters.get("id", as: Int.self) else {
            throw Abort(.custom(code: 47, reasonPhrase: "error getting id or decoding payload"))
        }

        try AnachronisticTechWebService.validate(secret: payload.secret)

        return PortfolioItem
            .find(id, on: req.db)
            .unwrap(or: Abort(.notFound))
            .map { $0.toOutput(with: req) }
            .flatMap { item in
                let tag: String
                let type: Int
                if let data = payload.data, data.count > 10 {
                    let markdown = String(data: data, encoding: .utf8)!
                        .replacingOccurrences(of: "\r\n", with: "\n")
                    let parser = MarkdownParser()
                    let result = parser.parse(markdown)

                    tag = result.metadata["tag"]!
                    type = result.metadata["type"] == "project" ? 1 : 0
                } else {
                    tag = item.tag
                    type = item.type
                }
                let revertType = item.type
                let revertIcon = item.icon
                let revertTag = item.tag

                return PortfolioItem.query(on: req.db)
                    .filter(\.$id == id)
                    .set(\.$type, to: type)
                    .set(\.$icon, to: payload.icon)
                    .set(\.$tag, to: tag)
                    .update()
                    .map {
                        if let data = payload.data, data.count > 10 {
                            do {
                                let _ = try Folder(path: "\(req.application.directory.publicDirectory)/portfolio")
                                    .createFile(at: "\(id).md", contents: data)
                            } catch {
                                let _ = PortfolioItem.query(on: req.db)
                                    .filter(\.$id == id)
                                    .set(\.$type, to: revertType)
                                    .set(\.$icon, to: revertIcon)
                                    .set(\.$tag, to: revertTag)
                                    .update()
                                return .custom(code: 47, reasonPhrase: "error saving file")
                            }
                        }
                        return .ok
                    }
            }
    }

    func getPortfolioInterestItems(req: Request) throws -> EventLoopFuture<[PortfolioItem.Output]> {
        if let id = req.parameters.get("n", as: Int.self) {
            return PortfolioItem
                .query(on: req.db)
                .filter(\.$type == 0)
                .sort(\.$id, .descending)
                .range(0..<id)
                .all()
                .mapEach { $0.toOutput(with: req) }
        } else {
            return PortfolioItem
                .query(on: req.db)
                .filter(\.$type == 0)
                .sort(\.$id, .descending)
                .all()
                .mapEach { $0.toOutput(with: req) }
        }
    }

    func getPortfolioProjectItems(req: Request) throws -> EventLoopFuture<[PortfolioItem.Output]> {
        if let id = req.parameters.get("n", as: Int.self) {
            return PortfolioItem
                .query(on: req.db)
                .filter(\.$type == 1)
                .sort(\.$id, .descending)
                .range(0..<id)
                .all()
                .mapEach { $0.toOutput(with: req) }
        } else {
            return PortfolioItem
                .query(on: req.db)
                .filter(\.$type == 1)
                .sort(\.$id, .descending)
                .all()
                .mapEach { $0.toOutput(with: req) }
        }
    }
}
