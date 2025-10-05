# 🚀 Chek3 - iOS Budget Management App

A **production-ready iOS app** built with SwiftUI and Supabase. Features user authentication, category management with local-first sync, and offline support with clean MVVM architecture.

[![Swift](https://img.shields.io/badge/Swift-5.0+-orange.svg)](https://swift.org)
[![iOS](https://img.shields.io/badge/iOS-26.0+-blue.svg)](https://developer.apple.com/ios/)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-Yes-green.svg)](https://developer.apple.com/xcode/swiftui/)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

## ✨ Key Features

- 🔐 **Supabase Authentication**: Complete user registration and login system
- 📊 **Category Management**: Full CRUD operations for budget categories
- 🔄 **Local-First Sync**: Offline support with automatic sync when online
- 📱 **Real-time Sync Status**: Visual indicators for sync state and connectivity
- 👤 **User Display Name**: Shows current user's name and email above sync status
- 🎨 **Customizable Categories**: Color-coded categories with income/expense types
- 🏗️ **Clean Architecture**: MVVM pattern with clear separation of concerns
- 🔧 **Production Ready**: Error handling, validation, and state management
- 📱 **Modern UI**: Beautiful SwiftUI interface with smooth animations

## 🏗️ Architecture Overview

This project follows **MVVM (Model-View-ViewModel)** architecture with dependency injection:

```
Chek3/
├── Configuration/ # Supabase configuration and setup
├── Models/        # Data models (Category, etc.)
├── Views/         # SwiftUI views (AuthView, AppView, FirstView, CategoryEditSheet)
├── ViewModels/    # Business logic and state management
├── Services/      # Authentication service, CategoryService, and Supabase client
└── Utilities/     # Validation, error handling, and extensions
```

### **Architecture Benefits:**
- **Testable**: Protocol-based services enable easy mocking
- **Maintainable**: Clear separation between UI and business logic
- **Scalable**: Add new features without breaking existing code
- **Flexible**: Swap implementations without changing views

## 🎯 Key Features

### **🔐 Authentication Features**
- **User Registration**: Email/password signup with first name and last name
- **User Login**: Secure authentication with Supabase
- **Display Name Management**: Automatic combination of first and last names
- **Session Management**: Automatic token refresh and session handling
- **Email Verification**: Built-in email confirmation flow

### **📊 Category Management Features**
- **Create Categories**: Add new budget categories with custom colors
- **Edit Categories**: Modify category properties (name, color, type, default status)
- **Delete Categories**: Remove categories with swipe-to-delete
- **Category Types**: Distinguish between income and expense categories
- **Default Categories**: Mark categories as default for quick access
- **Color Coding**: Visual category identification with custom colors

### **🛡️ Security & Validation**
- **Input Validation**: Email format and password strength validation
- **Rate Limiting**: Protection against brute force attacks
- **Error Sanitization**: User-friendly error messages
- **Secure Storage**: Token management handled by Supabase SDK

### **🔄 Sync & Offline Features**
- **Local-First Architecture**: All operations work offline
- **Automatic Sync**: Changes sync to Supabase when online
- **Conflict Resolution**: Last-edited timestamp determines sync priority
- **Pending Operations Queue**: Offline changes queued for later sync
- **Network Monitoring**: Real-time connectivity status
- **Sync Status Indicators**: Visual feedback for sync state

### **📱 User Experience**
- **User Display Name**: Shows current user's full name and email above sync status
- **Dynamic UI**: Real-time updates for categories and sync status
- **Smooth Animations**: Elegant transitions between states
- **Loading States**: Visual feedback during operations
- **Error Handling**: Clear, actionable error messages
- **Offline Support**: Full functionality without internet connection

## 🚀 Quick Start

### **1. Setup Supabase**
- Create a new Supabase project at [supabase.com](https://supabase.com)
- Copy your project URL and anon key
- Update `Configuration/SupabaseConfig.swift` with your credentials

### **2. Clone and Build**
```bash
git clone <your-repo-url>
cd Chek3
open Chek3.xcodeproj
```

### **3. Run the App**
- Select your target device/simulator
- Press `Cmd + R` to build and run
- ✅ **Ready to test authentication features**

### **4. Test Features**
- **Sign Up**: Create a new account with first name and last name
- **Sign In**: Login with existing credentials
- **Manage Categories**: Create, edit, and delete budget categories
- **Test Offline**: Turn off internet and verify offline functionality
- **Sync Status**: Monitor sync indicators and connectivity status

## 📁 Project Structure Deep Dive

### **Configuration Layer** (`Configuration/`)
- `SupabaseConfig.swift` - Supabase client configuration and credentials

### **Models Layer** (`Models/`)
- `Category.swift` - Category data model with Supabase schema alignment

### **Views Layer** (`Views/`)
- `AppView.swift` - Main app view with authentication state management
- `AuthView.swift` - Complete authentication interface (signup/signin)
- `FirstView.swift` - Category management dashboard with sync status
- `CategoryEditSheet.swift` - Category creation and editing interface
- `CategoryRowView.swift` - Individual category list item component

### **ViewModels Layer** (`ViewModels/`)
- `AppViewModel.swift` - App-level state management and navigation

### **Services Layer** (`Services/`)
- `AuthService.swift` - Complete authentication service with Supabase integration
- `CategoryService.swift` - Category CRUD operations with local-first sync
- `SupabaseClient.swift` - Supabase client singleton setup

### **Utilities Layer** (`Utilities/`)
- `ValidationUtils.swift` - Email and password validation with rate limiting
- `ErrorSanitizer.swift` - User-friendly error message handling
- `StringExtensions.swift` - String utility extensions

## 🔧 How It Works

### **Authentication Flow**
1. **Sign Up Process**:
   - User enters email, password, first name, and last name
   - First name and last name are combined into a display name
   - Display name is stored as user metadata in Supabase
   - Email verification is sent (if configured)

2. **Sign In Process**:
   - User enters email and password
   - Supabase validates credentials
   - Session is established with automatic token refresh

3. **User Display**:
   - `FirstView` observes `AuthService.currentUser`
   - Category management interface is shown when user is authenticated
   - Updates automatically when authentication state changes

### **Category Management Flow**
1. **Category Creation**:
   - User taps "+" button to create new category
   - `CategoryEditSheet` opens with form fields
   - Category is created locally and queued for sync

2. **Category Editing**:
   - User taps on existing category in list
   - `CategoryEditSheet` opens with pre-filled data
   - Changes are saved locally and synced to Supabase

3. **Category Deletion**:
   - User swipes to delete category
   - Category is removed locally and deletion is queued for sync

4. **Sync Process**:
   - Local changes are immediately applied to UI
   - When online, changes sync to Supabase
   - Conflict resolution uses `lastEdited` timestamp
   - Offline changes are queued and synced when connection restored

### **Key Components**

#### **AuthService** (`Services/AuthService.swift`)
- Singleton service managing authentication state
- Handles signup, signin, signout, and session management
- Publishes authentication state for UI updates
- Includes rate limiting and validation

#### **AuthView** (`Views/AuthView.swift`)
- Complete authentication interface
- Toggle between signup and signin modes
- Name fields appear only during signup
- Real-time validation and error handling

#### **CategoryService** (`Services/CategoryService.swift`)
- Singleton service managing category CRUD operations
- Handles local-first sync with Supabase
- Manages offline queue and network monitoring
- Publishes category updates and sync status

#### **FirstView** (`Views/FirstView.swift`)
- Category management dashboard
- Displays sync status and connectivity indicators
- Shows category list with create/edit/delete functionality
- Updates automatically when categories change

#### **CategoryEditSheet** (`Views/CategoryEditSheet.swift`)
- Modal sheet for creating and editing categories
- Form validation and color picker
- Handles both new category creation and existing category updates

### **Supabase Integration**
- **User Metadata**: First and last names stored as `full_name`
- **Category Storage**: Categories stored in `categories` table with user isolation
- **Session Management**: Automatic token refresh
- **Error Handling**: User-friendly error messages
- **Security**: Rate limiting and input validation
- **Local-First Sync**: Offline support with automatic conflict resolution

## 🧪 Testing the App

### **Manual Testing Steps**
1. **Test Sign Up**:
   - Enter valid email, password, first name, and last name
   - Verify display name is created correctly
   - Check email verification flow (if enabled)

2. **Test Sign In**:
   - Use existing credentials to sign in
   - Verify session persistence across app restarts

3. **Test Category Management**:
   - Create new categories with different colors and types
   - Edit existing categories and verify changes persist
   - Delete categories using swipe gesture
   - Verify sync status indicators work correctly

4. **Test Offline Functionality**:
   - Turn off internet connection
   - Create, edit, and delete categories offline
   - Turn internet back on and verify sync occurs
   - Check that pending operations are processed

### **Automated Testing**
The project includes Swift Testing framework setup for future test implementation:

```swift
import Testing
@testable import Chek3

struct AuthTests {
    @Test func testCategoryCreation() async throws {
        // Test category creation functionality
    }
    
    @Test func testOfflineSync() async throws {
        // Test offline operations and sync
    }
    
    @Test func testNameCombination() async throws {
        // Test firstName + lastName combination
    }
}
```

## 📱 Platform Support

- **iOS 26.0+**
- **iPhone and iPad**
- **SwiftUI**
- **Swift 5.0+**
- **Xcode 15.0+**

## 🔄 Extending the App

### **Adding New Features:**
1. **Budget Management**:
   - Add budget creation and tracking
   - Implement transaction management
   - Add budget vs actual comparisons

2. **Enhanced Categories**:
   - Add category icons and emojis
   - Implement category hierarchies
   - Add category templates

3. **Advanced Sync**:
   - Add selective sync options
   - Implement data export/import
   - Add sync conflict resolution UI

4. **User Profile Management**:
   - Add profile editing capabilities
   - Display user's full name from metadata
   - Add profile picture upload

### **Database Integration:**
- Extend Supabase with budgets and transactions tables
- Add user preferences and settings
- Implement advanced data synchronization

## 📋 Best Practices

### **✅ Do:**
- Keep authentication logic in `AuthService`
- Keep category logic in `CategoryService`
- Use `@StateObject` for service singletons
- Handle state changes reactively
- Validate user input before API calls
- Provide clear error messages to users
- Use SwiftUI's declarative syntax
- Implement local-first architecture
- Handle offline scenarios gracefully

### **❌ Don't:**
- Put business logic directly in views
- Hardcode Supabase credentials in code
- Skip input validation
- Ignore error states in UI
- Mix different concerns in single services
- Store sensitive data in UserDefaults
- Block UI during sync operations
- Ignore offline scenarios

## 🔒 Security & Privacy

- **Supabase credentials** stored in `SupabaseConfig.swift`
- **API keys** should be added to ignored files for production
- **User data** handled securely through Supabase
- **No sensitive data** committed to repository
- **Rate limiting** prevents brute force attacks

## 🛠️ Development Workflow

### **Daily Development:**
1. **Test authentication flows** on simulator
2. **Test category management** functionality
3. **Verify offline sync** behavior
4. **Check error handling** with invalid inputs
5. **Test session persistence** across app restarts

### **Before Production:**
1. **Update Supabase config** with production credentials
2. **Test on real devices**
3. **Verify email verification** works correctly
4. **Test offline scenarios** thoroughly
5. **Check rate limiting** and security measures
6. **Verify sync conflict resolution**

## 📄 License

This project is free to use for personal and commercial projects. Choose the license that fits your needs:

- **MIT License**: Permissive, allows commercial use
- **Apache 2.0**: Permissive with patent protection
- **Custom License**: Define your own terms

## 🤝 Contributing

Contributions are welcome! Here's how you can help:

1. **Fork the repository**
2. **Create a feature branch**
3. **Make your changes**
4. **Test authentication flows**
5. **Submit a pull request**

### **Areas for Contribution:**
- Additional authentication methods
- Enhanced category management features
- Budget and transaction management
- Advanced sync features
- UI/UX improvements
- Testing enhancements
- Documentation improvements

## 📞 Support

- **Issues**: Report bugs or request features via GitHub Issues
- **Discussions**: Ask questions in GitHub Discussions
- **Documentation**: Check this README and inline code comments

---

## 🎉 Ready to Use!

This budget management app provides a solid foundation for iOS apps requiring user authentication and data management with offline support.

**Start building your budget management iOS app today!** 🚀

---

*Built with ❤️ using SwiftUI and Supabase*
