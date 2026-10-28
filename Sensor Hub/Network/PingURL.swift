//
//  PingURL.swift
//  Sensor Hub
//
//  Created by Chris Riddick on 7/18/26.
//  code by Duck.ai
//

import Foundation

enum URLPingError: Error {
    case invalidURL
    case requestFailed(String)
    case nonHTTPResponse
}

func pingURLActiveGET(
    _ urlString: String,
    timeout: TimeInterval = 5,
    completion: @escaping (Result<Bool, Error>) -> Void
) {
    guard let url = URL(string: urlString) else {
        completion(.failure(URLPingError.invalidURL))
        return
    }

    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.timeoutInterval = timeout
    request.cachePolicy = .reloadIgnoringLocalCacheData

    let task = URLSession.shared.dataTask(with: request) { _, response, error in
        if let error = error {
            completion(.failure(URLPingError.requestFailed(error.localizedDescription)))
            return
        }

        guard let http = response as? HTTPURLResponse else {
            completion(.failure(URLPingError.nonHTTPResponse))
            return
        }

        // Active includes any response that indicates the server is reachable and responding:
        // 2xx/3xx/4xx (including 401/403). Only treat 5xx as inactive (or network failure as error).
        let isActive = (200...499).contains(http.statusCode)
        completion(.success(isActive))
    }

    task.resume()
}

// USAGE
//pingURLActiveGET("https://example.com") { result in
//    switch result {
//    case .success(let active):
//        print("Active:", active)
//    case .failure(let error):
//        print("Ping failed:", error)
//    }
//}
