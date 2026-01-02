import Foundation
import Network

actor LoopbackServer {
	enum ServerError: Error, LocalizedError {
		case bindFailed
		case invalidRequest
		case noAuthorizationCode
		case authorizationError(String)
		case cancelled

		var errorDescription: String? {
			switch self {
			case .bindFailed:
				return "Failed to start local server"
			case .invalidRequest:
				return "Invalid OAuth callback request"
			case .noAuthorizationCode:
				return "No authorization code received"
			case .authorizationError(let error):
				return "Authorization error: \(error)"
			case .cancelled:
				return "Authentication was cancelled"
			}
		}
	}

	private var listener: NWListener?
	private var continuation: CheckedContinuation<String, Error>?
	private var boundPort: UInt16 = 0

	var port: UInt16 {
		boundPort
	}

	var redirectURI: String {
		"http://127.0.0.1:\(boundPort)/callback"
	}

	func start() async throws -> UInt16 {
		let parameters = NWParameters.tcp
		parameters.allowLocalEndpointReuse = true

		let listener = try NWListener(using: parameters, on: .any)
		self.listener = listener

		return try await withCheckedThrowingContinuation { continuation in
			listener.stateUpdateHandler = { [weak self] state in
				switch state {
				case .ready:
					if let port = listener.port?.rawValue {
						Task { await self?.setBoundPort(port) }
						continuation.resume(returning: port)
					}
				case .failed(let error):
					continuation.resume(throwing: error)
				default:
					break
				}
			}

			listener.newConnectionHandler = { [weak self] connection in
				Task { await self?.handleConnection(connection) }
			}

			listener.start(queue: .main)
		}
	}

	private func setBoundPort(_ port: UInt16) {
		boundPort = port
	}

	func waitForCallback() async throws -> String {
		try await withCheckedThrowingContinuation { continuation in
			self.continuation = continuation
		}
	}

	func stop() {
		listener?.cancel()
		listener = nil
		continuation?.resume(throwing: ServerError.cancelled)
		continuation = nil
	}

	private func handleConnection(_ connection: NWConnection) {
		connection.start(queue: .main)
		connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) {
			[weak self] data, _, _, _ in
			guard let self = self, let data = data,
				let request = String(data: data, encoding: .utf8)
			else { return }

			Task { await self.processRequest(request, connection: connection) }
		}
	}

	private func processRequest(_ request: String, connection: NWConnection) {
		// Check for error parameter first
		if let errorRange = request.range(of: "error=") {
			let errorStart = errorRange.upperBound
			let errorEnd =
				request[errorStart...].range(of: "&")?.lowerBound
				?? request[errorStart...].range(of: " ")?.lowerBound
				?? request.endIndex
			let error =
				String(request[errorStart..<errorEnd])
				.removingPercentEncoding ?? "unknown_error"

			sendResponse(connection: connection, success: false)
			continuation?.resume(throwing: ServerError.authorizationError(error))
			continuation = nil
			return
		}

		// Parse GET request for authorization code
		guard let codeRange = request.range(of: "code=") else {
			sendResponse(connection: connection, success: false)
			continuation?.resume(throwing: ServerError.noAuthorizationCode)
			continuation = nil
			return
		}

		let codeStart = codeRange.upperBound
		let codeEnd =
			request[codeStart...].range(of: "&")?.lowerBound
			?? request[codeStart...].range(of: " ")?.lowerBound
			?? request.endIndex

		let code =
			String(request[codeStart..<codeEnd])
			.removingPercentEncoding ?? ""

		guard !code.isEmpty else {
			sendResponse(connection: connection, success: false)
			continuation?.resume(throwing: ServerError.noAuthorizationCode)
			continuation = nil
			return
		}

		sendResponse(connection: connection, success: true)
		continuation?.resume(returning: code)
		continuation = nil
		Task { await self.stopAfterDelay() }
	}

	private func stopAfterDelay() async {
		try? await Task.sleep(nanoseconds: 500_000_000)  // 0.5s delay for response to be sent
		stop()
	}

	private nonisolated func sendResponse(connection: NWConnection, success: Bool) {
		let html =
			success
			? """
			<!DOCTYPE html>
			<html>
			<head><title>Ebb - Authentication</title></head>
			<body style="font-family: -apple-system, sans-serif; text-align: center; padding-top: 50px;">
			<h1>Authentication Successful</h1>
			<p>You can close this window and return to Ebb.</p>
			</body>
			</html>
			"""
			: """
			<!DOCTYPE html>
			<html>
			<head><title>Ebb - Authentication</title></head>
			<body style="font-family: -apple-system, sans-serif; text-align: center; padding-top: 50px;">
			<h1>Authentication Failed</h1>
			<p>Please close this window and try again.</p>
			</body>
			</html>
			"""

		let response = """
			HTTP/1.1 200 OK\r
			Content-Type: text/html; charset=utf-8\r
			Content-Length: \(html.utf8.count)\r
			Connection: close\r
			\r
			\(html)
			"""

		connection.send(
			content: response.data(using: .utf8),
			completion: .contentProcessed { _ in
				connection.cancel()
			})
	}
}
