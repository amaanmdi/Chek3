import Foundation

/// Add concrete protocol properties here as your app grows.
struct AppEnvironment {
    let auth: AuthServicing
    let store: LocalStore
    let api: APIClient
}

extension AppEnvironment {
    /// Zero-behavior stubs, safe for previews and Debug.
    static func stub() -> AppEnvironment {
        .init(auth: AuthServiceStub(),
              store: LocalStoreStub(),
              api: APIClientStub())
    }
    
    /// Production environment with real implementations
    static func production() -> AppEnvironment {
        .init(auth: AuthServiceStub(), // TODO: Replace with real AuthService
              store: LocalStoreStub(), // TODO: Replace with real LocalStore
              api: APIClientStub())    // TODO: Replace with real APIClient
    }
}
