import Foundation

func withRetry<T: Sendable>(
    maxAttempts: Int = 2,
    delayNanos: UInt64 = 500_000_000,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    var lastError: Error
    do {
        return try await operation()
    } catch {
        lastError = error
    }

    for _ in 1..<maxAttempts {
        try? await Task.sleep(nanoseconds: delayNanos)
        do {
            return try await operation()
        } catch {
            lastError = error
        }
    }

    throw lastError
}
