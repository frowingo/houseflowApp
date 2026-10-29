import Foundation

/// `multipart/form-data` body for `NetworkService`. The boundary is generated
/// here and always travels in `contentType`; callers never set Content-Type.
struct MultipartFormData: Sendable {
    private enum Part: Sendable {
        case field(name: String, value: String)
        case file(name: String, fileName: String, mimeType: String, data: Data)
    }

    let boundary: String
    private var parts: [Part] = []

    init(boundary: String = "FausCrew-\(UUID().uuidString)") {
        self.boundary = boundary
    }

    var contentType: String {
        "multipart/form-data; boundary=\(boundary)"
    }

    mutating func append(name: String, value: String) {
        parts.append(.field(name: name, value: value))
    }

    mutating func append(name: String, fileName: String, mimeType: String, data: Data) {
        parts.append(.file(name: name, fileName: fileName, mimeType: mimeType, data: data))
    }

    func encoded() -> Data {
        var body = Data()
        for part in parts {
            body.append("--\(boundary)\r\n")
            switch part {
            case .field(let name, let value):
                body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
                body.append(value)
            case .file(let name, let fileName, let mimeType, let data):
                body.append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(fileName)\"\r\n")
                body.append("Content-Type: \(mimeType)\r\n\r\n")
                body.append(data)
            }
            body.append("\r\n")
        }
        body.append("--\(boundary)--\r\n")
        return body
    }
}

private extension Data {
    mutating func append(_ string: String) {
        append(Data(string.utf8))
    }
}
