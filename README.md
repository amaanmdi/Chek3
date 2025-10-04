# iOS App Starting Ground

A clean, scalable, and production-ready foundation for iOS app development using SwiftUI and MVVM architecture.

## 🏗️ Architecture

This project follows **MVVM (Model-View-ViewModel)** architecture with the following structure:

```
Chek3/
├── App/           # App-level configuration and environment
├── Views/         # SwiftUI views
├── ViewModels/    # Business logic and state management
├── Services/      # External dependencies and protocols
└── Utilities/     # Helper extensions and utilities
```

## ✨ Features

### 🎯 **Production-Ready Foundation**
- **Environment Switching**: Automatic Debug/Release environment configuration
- **Dependency Injection**: Protocol-based services with environment injection
- **Error Handling**: Comprehensive `AppError` system with localized descriptions
- **State Management**: Built-in loading and error states in `BaseViewModel`

### 🧪 **Testing Infrastructure**
- **Protocol-Based Services**: Easy mocking and testing
- **Stub Implementations**: Ready-to-use stubs for development
- **Swift Testing**: Modern testing framework setup

### 🚀 **Developer Experience**
- **Clean Architecture**: Scalable and maintainable code structure
- **Consistent Patterns**: Same patterns across all ViewModels
- **Async Operations**: `performAsync` helper for consistent state management
- **Preview Support**: All views have SwiftUI previews

## 🛠️ Getting Started

### 1. Clone and Setup
```bash
git clone <your-repo-url>
cd Chek3
open Chek3.xcodeproj
```

### 2. Build and Run
- Select your target device/simulator
- Press `Cmd + R` to build and run
- The app will build with **0 errors and 0 warnings**

### 3. Start Building Features
- Add new views to `Views/` folder
- Create ViewModels that inherit from `BaseViewModel`
- Add service protocols to `Services/Protocols.swift`
- Replace stubs with real implementations in production environment

## 📁 Project Structure

### **App Layer**
- `AppEnvironment.swift` - Environment configuration with Debug/Release switching
- `EnvironmentKeys.swift` - SwiftUI environment key setup

### **Views Layer**
- `AppView.swift` - Main app view with navigation
- `FirstView.swift` - Example view (replace with your content)

### **ViewModels Layer**
- `Base/ViewModel.swift` - Base protocol and class with state management
- `AppViewModel.swift` - App-level ViewModel

### **Services Layer**
- `Protocols.swift` - Service protocols and error handling
- `Stubs.swift` - No-op implementations for development

### **Utilities Layer**
- `Extensions/View+Extensions.swift` - SwiftUI view extensions

## 🔧 Customization

### **Adding New Services**
1. Add protocol to `Services/Protocols.swift`
2. Add stub implementation to `Services/Stubs.swift`
3. Add to `AppEnvironment` struct
4. Update environment configurations

### **Adding New Views**
1. Create view in `Views/` folder
2. Create corresponding ViewModel inheriting from `BaseViewModel`
3. Use `performAsync` for async operations
4. Add SwiftUI preview

### **Environment Configuration**
- **Debug**: Uses stub implementations
- **Release**: Uses production implementations (replace stubs with real services)

## 🧪 Testing

The project is set up with Swift Testing framework:

```swift
import Testing
@testable import Chek3

struct MyTests {
    @Test func example() async throws {
        // Write your tests here
    }
}
```

## 📱 Supported Platforms

- **iOS 26.0+**
- **iPhone and iPad**
- **SwiftUI**
- **Swift 5.0+**

## 🚀 Reusing This Foundation

This foundation is designed to be reusable across all your iOS projects:

1. **Copy the entire structure** to your new project
2. **Update project name** and bundle identifier
3. **Add your specific services** and business logic
4. **Replace example views** with your actual content

## 📋 Best Practices

- ✅ Use `BaseViewModel` for all ViewModels
- ✅ Use `performAsync` for async operations
- ✅ Add services as protocols first, then implementations
- ✅ Keep views simple and focused on UI
- ✅ Use environment injection for dependencies
- ✅ Handle errors consistently with `AppError`

## 🔒 Security

- Sensitive files are automatically ignored via `.gitignore`
- Add API keys and credentials to ignored files
- Use environment variables for sensitive configuration

## 📄 License

This starting ground is free to use for personal and commercial projects.

---

**Happy Coding!** 🎉

This foundation will save you hours of setup time and provide a solid, scalable architecture for all your iOS projects.
