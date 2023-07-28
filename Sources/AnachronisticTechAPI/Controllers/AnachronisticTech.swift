//
//  AnachronisticTech.swift
//  
//
//  Created by Daniel Marriner on 08/10/2022.
//

import Vapor

struct AnachronisticTech: RouteCollection {
    let pathComponent: String
    let devMode: Bool

    func boot(routes: RoutesBuilder) throws {
        routes.get(use: home)
        routes.get("archive", use: archive)
        routes.get("portfolio", use: portfolio)
        routes.get("contact", use: contact)
        routes.get("articles", ":id", use: articles)
        routes.get("postEditor", use: newPost)
        routes.get("postEditor", ":id", use: editPost)
        routes.get("portfolioEditor", use: newPortfolioItem)
        routes.get("portfolioEditor", ":id", use: editPortfolioItem)
        routes.get("upload", use: upload)
    }

    private enum Endpoint: String {
        case home, archive, portfolio, contact
        case article, editor, upload
    }

    private func pathFor(_ endpoint: Endpoint) -> String
    {
        return "\(pathComponent)/\(endpoint.rawValue)"
    }

    // MARK: - Handlers relating to views
    func home(req: Request) throws -> EventLoopFuture<View> {
        return req.view.render(pathFor(.home), [
            "devMode": "\(devMode)",
            "title": "Home"
        ])
    }

    func archive(req: Request) throws -> EventLoopFuture<View> {
        return req.view.render(pathFor(.archive), [
            "devMode": "\(devMode)",
            "title": "Archive"
        ])
    }

    func portfolio(req: Request) throws -> EventLoopFuture<View> {
        return req.view.render(pathFor(.portfolio), [
            "devMode": "\(devMode)",
            "title": "Portfolio"
        ])
    }

    func contact(req: Request) throws -> EventLoopFuture<View> {
        return req.view.render(pathFor(.contact), [
            "devMode": "\(devMode)",
            "title": "Contact"
        ])
    }

    func articles(req: Request) throws -> EventLoopFuture<View> {
        return req.view.render(pathFor(.article), [
            "devMode": "\(devMode)",
            "title": "Article",
            "id": req.parameters.get("id", as: String.self)
        ])
    }

    func newPost(req: Request) throws -> EventLoopFuture<View> {
        return req.view.render(pathFor(.editor), [
            "devMode": "\(devMode)",
            "title": "New Post",
            "editor": "posts"
        ])
    }

    func editPost(req: Request) throws -> EventLoopFuture<View> {
        return req.view.render(pathFor(.editor), [
            "devMode": "\(devMode)",
            "title": "Editing Post",
            "editor": "posts",
            "id": req.parameters.get("id", as: String.self)
        ])
    }

    func newPortfolioItem(req: Request) throws -> EventLoopFuture<View> {
        return req.view.render(pathFor(.editor), [
            "devMode": "\(devMode)",
            "title": "New Post",
            "editor": "portfolio"
        ])
    }

    func editPortfolioItem(req: Request) throws -> EventLoopFuture<View> {
        return req.view.render(pathFor(.editor), [
            "devMode": "\(devMode)",
            "title": "Editing Post",
            "editor": "portfolio",
            "id": req.parameters.get("id", as: String.self)
        ])
    }

    func upload(req: Request) throws -> EventLoopFuture<View> {
        return req.view.render(pathFor(.upload), [
            "devMode": "\(devMode)",
            "title": "File upload"
        ])
    }
}
