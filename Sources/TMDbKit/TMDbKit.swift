import Foundation

public struct Actor: Codable, Hashable {
    public var popularity: Double
    public var name: String
    public var id: Int
    public var profile_path: String?
}

public struct MovieService {
    public var fetchActors: (String) async throws -> Set<Actor>
}

extension MovieService {
    public static var live: MovieService {
        let client = MovieClient()
        return MovieService(fetchActors: client.fetchActors(apiKey:))
    }
}

struct Movie: Codable, Hashable {
    var id: Int
    var original_title: String?
}

struct Movies: Codable {
    var results: [Movie]
}

struct Credits: Codable, Hashable {
    var cast: [Actor]
}

actor Store {
    var actors = Set<Actor>()
    var movies = 0

    func addActors(_ newActors: [Actor]) async {
        actors.formUnion(newActors)
    }
}

class MovieClient {
    let store = Store()

    func fetchActors(apiKey: String) async throws -> Set<Actor> {
        let movies = try await requestMovies(apiKey: apiKey)
        for movie in movies.results {
            let credits = try await creditsForMovie(apiKey: apiKey, movie: movie)
            await store.addActors(credits)
        }

        return await store.actors
    }

    func requestMovies(apiKey: String) async throws -> Movies {
        guard
            var URL = URL(string: "https://api.themoviedb.org/3/discover/movie")
        else {
            fatalError("wrong URL")
        }
        let URLParams = [
            "api_key": apiKey,
            "sort": "popularity.desc",
            "page": "2"
        ]
        URL = URL.appendingQueryParameters(URLParams)
        var request = URLRequest(url: URL)
        request.httpMethod = "GET"

        let (data, _) = try await URLSession.shared.data(for: request)

        let decoder = JSONDecoder()
        let movies = try decoder.decode(Movies.self, from: data)
        return movies
    }

    func creditsForMovie(apiKey: String, movie: Movie) async throws -> [Actor] {
        guard
            var URL = URL(string: "https://api.themoviedb.org/3/movie/\(movie.id)/credits")
        else {
            fatalError("wrong URL")
        }
        let URLParams = [
            "api_key": apiKey,
        ]
        URL = URL.appendingQueryParameters(URLParams)
        var request = URLRequest(url: URL)
        request.httpMethod = "GET"
        let (data, _) = try await URLSession.shared.data(for: request)

        let decoder = JSONDecoder()
        let credits = try decoder.decode(Credits.self, from: data)
        return credits.cast
    }
}


protocol URLQueryParameterStringConvertible {
    var queryParameters: String {get}
}

extension Dictionary : URLQueryParameterStringConvertible {
    /**
     This computed property returns a query parameters string from the given NSDictionary. For
     example, if the input is @{@"day":@"Tuesday", @"month":@"January"}, the output
     string will be @"day=Tuesday&month=January".
     @return The computed parameters string.
    */
    var queryParameters: String {
        var parts: [String] = []
        for (key, value) in self {
            let part = String(format: "%@=%@",
                String(describing: key).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!,
                String(describing: value).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)
            parts.append(part as String)
        }
        return parts.joined(separator: "&")
    }

}

extension URL {
    /**
     Creates a new URL by adding the given query parameters.
     @param parametersDictionary The query parameter dictionary to add.
     @return A new URL.
    */
    func appendingQueryParameters(_ parametersDictionary : Dictionary<String, String>) -> URL {
        let URLString : String = String(format: "%@?%@", self.absoluteString, parametersDictionary.queryParameters)
        return URL(string: URLString)!
    }
}
