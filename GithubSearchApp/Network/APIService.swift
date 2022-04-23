//
//  APIService.swift
//  GithubSearchApp
//
//  Created by 박근보 on 2022/04/23.
//

import Foundation
import Moya

enum GitHubSearchAPI {
    case searchUser(query: String)
}

extension GitHubSearchAPI: TargetType {

    var baseURL: URL {
        return URL(string: APIKey.baseURL)!
    }

    var path: String {
        switch self {
        case .searchUser(let query): return "/search/users?q=\(query)"
        }
    }

    var method: Moya.Method {
        switch self {
        case .searchUser: return .get
        }
    }

    var task: Task {
        switch self {
        case .searchUser: return .requestPlain
        }
    }

    var headers: [String : String]? {
        switch self {
        case .searchUser: return [
            "Accept": "application/vnd.github.v3+json",
            "Authorization": APIKey.authorization
        ]
        }
    }
}
