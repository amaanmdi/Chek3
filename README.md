# 🚀 iOS App Starting Ground

A **production-ready foundation** for iOS app development using SwiftUI and MVVM architecture. This template saves you hours of setup time and provides a solid, scalable foundation for all your iOS projects.

[![Swift](https://img.shields.io/badge/Swift-5.0+-orange.svg)](https://swift.org)
[![iOS](https://img.shields.io/badge/iOS-26.0+-blue.svg)](https://developer.apple.com/ios/)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-Yes-green.svg)](https://developer.apple.com/xcode/swiftui/)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

## ✨ Why Use This Foundation?

- 🏗️ **Clean Architecture**: MVVM pattern with clear separation of concerns
- 🔧 **Zero Setup**: Builds with 0 errors and 0 warnings out of the box
- 🧪 **Testing Ready**: Protocol-based services make testing easy
- 🚀 **Production Ready**: Environment switching, error handling, state management
- 📱 **Scalable**: Works for simple apps to complex enterprise solutions
- 🔄 **Reusable**: Use this foundation for all your iOS projects

## 🏗️ Architecture Overview

This project follows **MVVM (Model-View-ViewModel)** architecture with dependency injection:

```
Chek3/
├── App/           # App-level configuration and environment setup
├── Views/         # SwiftUI views (UI layer)
├── ViewModels/    # Business logic and state management
├── Services/      # External dependencies and protocols
└── Utilities/     # Helper extensions and utilities
```

### **Architecture Benefits:**
- **Testable**: Protocol-based services enable easy mocking
- **Maintainable**: Clear separation between UI and business logic
- **Scalable**: Add new features without breaking existing code
- **Flexible**: Swap implementations without changing views

## 🎯 Key Features

### **🔧 Production-Ready Infrastructure**
- **Environment Switching**: Automatic Debug/Release configuration
- **Dependency Injection**: Protocol-based services with environment injection
- **Error Handling**: Comprehensive `AppError` system with localized descriptions
- **State Management**: Built-in loading and error states in `BaseViewModel`

### **🧪 Testing & Development**
- **Protocol-Based Services**: Easy mocking and testing
- **Stub Implementations**: Ready-to-use stubs for development
- **Swift Testing**: Modern testing framework setup
- **Preview Support**: All views have SwiftUI previews

### **⚡ Developer Experience**
- **Clean Architecture**: Scalable and maintainable code structure
- **Consistent Patterns**: Same patterns across all ViewModels
- **Async Operations**: `performAsync` helper for consistent state management
- **Zero Configuration**: Works immediately after cloning

## 🚀 Quick Start

### **1. Clone and Setup**
```bash
git clone <your-repo-url>
cd Chek3
open Chek3.xcodeproj
```

### **2. Build and Run**
- Select your target device/simulator
- Press `Cmd + R` to build and run
- ✅ **Builds with 0 errors and 0 warnings**

### **3. Start Building Features**
- Add new views to `Views/` folder
- Create ViewModels that inherit from `BaseViewModel`
- Add service protocols to `Services/Protocols.swift`
- Replace stubs with real implementations in production environment

## 📁 Project Structure Deep Dive

### **App Layer** (`App/`)
- `AppEnvironment.swift` - Environment configuration with Debug/Release switching
- `EnvironmentKeys.swift` - SwiftUI environment key setup for dependency injection

### **Views Layer** (`Views/`)
- `AppView.swift` - Main app view with navigation stack
- `FirstView.swift` - Example view (replace with your content)

### **ViewModels Layer** (`ViewModels/`)
- `Base/ViewModel.swift` - Base protocol and class with state management
- `AppViewModel.swift` - App-level ViewModel inheriting from BaseViewModel

### **Services Layer** (`Services/`)
- `Protocols.swift` - Service protocols and comprehensive error handling
- `Stubs.swift` - No-op implementations for development and testing

### **Utilities Layer** (`Utilities/`)
- `Extensions/View+Extensions.swift` - SwiftUI view extensions and helpers

## 🔧 Customization Guide

### **Adding New Services**
1. **Define Protocol** in `Services/Protocols.swift`:
```swift
protocol MyNewService {
    func doSomething() async throws -> Result
}
```

2. **Add Stub Implementation** in `Services/Stubs.swift`:
```swift
struct MyNewServiceStub: MyNewService {
    func doSomething() async throws -> Result {
        // Return mock data for development
    }
}
```

3. **Update Environment** in `AppEnvironment.swift`:
```swift
struct AppEnvironment {
    let myNewService: MyNewService
    // ... other services
}
```

4. **Configure Environments**:
```swift
extension AppEnvironment {
    static func production() -> AppEnvironment {
        .init(
            myNewService: MyNewServiceImplementation(), // Real implementation
            // ... other services
        )
    }
}
```

### **Adding New Views**
1. **Create View** in `Views/` folder:
```swift
struct MyNewView: View {
    @StateObject private var viewModel = MyNewViewModel()
    
    var body: some View {
        // Your UI here
    }
}
```

2. **Create ViewModel** inheriting from `BaseViewModel`:
```swift
@MainActor
class MyNewViewModel: BaseViewModel {
    override func onAppear() {
        // Initialization logic
    }
    
    func performAction() {
        Task {
            await performAsync {
                // Your async operation
                return try await someService.doSomething()
            }
        }
    }
}
```

### **Environment Configuration**
- **Debug**: Uses stub implementations (safe for development)
- **Release**: Uses production implementations (real services)

## 🧪 Testing

The project is set up with Swift Testing framework:

```swift
import Testing
@testable import Chek3

struct MyTests {
    @Test func example() async throws {
        // Write your tests here
        #expect(true)
    }
    
    @Test func testViewModel() async throws {
        let viewModel = MyViewModel()
        // Test your ViewModel logic
    }
}
```

### **Testing Benefits:**
- **Protocol-based services** make mocking easy
- **Stub implementations** for isolated testing
- **BaseViewModel** provides consistent testing patterns

## 📱 Platform Support

- **iOS 26.0+**
- **iPhone and iPad**
- **SwiftUI**
- **Swift 5.0+**
- **Xcode 15.0+**

## 🔄 Reusing This Foundation

This foundation is designed to be **reusable across all your iOS projects**:

### **For New Projects:**
1. **Copy Structure**: Clone this repository
2. **Rename Project**: Update project name and bundle identifier
3. **Customize Services**: Add your specific service protocols
4. **Replace Views**: Replace example views with your actual content
5. **Add Features**: Build your app using the established patterns

### **Benefits of Reuse:**
- ⏱️ **Save 2-3 hours** of setup time per project
- 🎯 **Consistent architecture** across all apps
- 🧪 **Testing patterns** already established
- 📚 **Documentation** and best practices included

## 📋 Best Practices

### **✅ Do:**
- Use `BaseViewModel` for all ViewModels
- Use `performAsync` for async operations
- Add services as protocols first, then implementations
- Keep views simple and focused on UI
- Use environment injection for dependencies
- Handle errors consistently with `AppError`

### **❌ Don't:**
- Put business logic in views
- Create ViewModels without inheriting from `BaseViewModel`
- Hardcode service implementations
- Skip error handling
- Mix UI and business logic

## 🔒 Security & Privacy

- **Sensitive files** are automatically ignored via `.gitignore`
- **API keys and credentials** should be added to ignored files
- **Environment variables** recommended for sensitive configuration
- **No sensitive data** in the repository

## 🛠️ Development Workflow

### **Daily Development:**
1. **Create new features** using established patterns
2. **Add tests** for new functionality
3. **Use stubs** for development and testing
4. **Replace stubs** with real implementations when ready

### **Before Production:**
1. **Update environment** to use production services
2. **Run full test suite**
3. **Verify error handling**
4. **Test on real devices**

## 📄 License

This starting ground is free to use for personal and commercial projects. Choose the license that fits your needs:

- **MIT License**: Permissive, allows commercial use
- **Apache 2.0**: Permissive with patent protection
- **Custom License**: Define your own terms

## 🤝 Contributing

Contributions are welcome! Here's how you can help:

1. **Fork the repository**
2. **Create a feature branch**
3. **Make your changes**
4. **Add tests** for new functionality
5. **Submit a pull request**

### **Areas for Contribution:**
- Additional service protocols
- More utility extensions
- Testing improvements
- Documentation enhancements
- Architecture refinements

## 📞 Support

- **Issues**: Report bugs or request features via GitHub Issues
- **Discussions**: Ask questions in GitHub Discussions
- **Documentation**: Check this README and inline code comments

---

## 🎉 Happy Coding!

This foundation will save you hours of setup time and provide a solid, scalable architecture for all your iOS projects. 

**Start building amazing apps today!** 🚀

---

*Built with ❤️ for the iOS development community*
