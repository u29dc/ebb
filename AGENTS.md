# Ebb

A minimal, single-account Gmail client for macOS that sanitizes email HTML into clean markdown and displays conversations as chat bubbles.

> v0 exploratory code in `./tmp` as loose reference. Reference implementations cloned to `./tmp` for local access.

## Documentation

### Apple Platform

- **Swift Language:** [docs.swift.org/swift-book](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/)
- **Swift Concurrency:** [docs.swift.org/concurrency](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/)
- **Swift Macros:** [docs.swift.org/macros](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/macros/)
- **Swift Standard Library:** [developer.apple.com/documentation/swift](https://developer.apple.com/documentation/swift/)
- **SwiftUI:** [developer.apple.com/documentation/swiftui](https://developer.apple.com/documentation/swiftui/)
- **SwiftUI macOS Tutorial:** [developer.apple.com/tutorials/swiftui/creating-a-macos-app](https://developer.apple.com/tutorials/swiftui/creating-a-macos-app)
- **SwiftData:** [developer.apple.com/documentation/swiftdata](https://developer.apple.com/documentation/swiftdata/)
- **AppKit:** [developer.apple.com/documentation/appkit](https://developer.apple.com/documentation/appkit/)
- **Foundation:** [developer.apple.com/documentation/foundation](https://developer.apple.com/documentation/foundation/)
- **Observation Framework:** [developer.apple.com/documentation/observation](https://developer.apple.com/documentation/observation/)
- **macOS HIG:** [developer.apple.com/design/human-interface-guidelines/designing-for-macos](https://developer.apple.com/design/human-interface-guidelines/designing-for-macos)
- **Accessibility:** [developer.apple.com/design/human-interface-guidelines/accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)
- **Entitlements:** [developer.apple.com/documentation/bundleresources/entitlements](https://developer.apple.com/documentation/bundleresources/entitlements)
- **WWDC Videos:** [developer.apple.com/videos](https://developer.apple.com/videos/)

### Gmail & OAuth

- **Gmail API Reference:** [developers.google.com/gmail/api/reference/rest](https://developers.google.com/gmail/api/reference/rest)
- **Gmail API Guides:** [developers.google.com/gmail/api/guides](https://developers.google.com/gmail/api/guides)
- **OAuth 2.0 for Desktop:** [developers.google.com/identity/protocols/oauth2/native-app](https://developers.google.com/identity/protocols/oauth2/native-app)
- **OAuth 2.0 Scopes:** [developers.google.com/identity/protocols/oauth2/scopes#gmail](https://developers.google.com/identity/protocols/oauth2/scopes#gmail)

### Google Cloud Console Setup

Before OAuth works, you must configure a Google Cloud project:

1. **Create Project:** [console.cloud.google.com](https://console.cloud.google.com/) > New Project > Name it "Ebb"
2. **Enable Gmail API:** APIs & Services > Library > Search "Gmail API" > Enable
3. **Configure OAuth Consent Screen:**
    - User Type: External (for testing) or Internal (Google Workspace)
    - App name: "Ebb"
    - Scopes: Add `gmail.readonly`, `gmail.send`, `gmail.modify`
    - Test users: Add your Gmail address during development
4. **Create OAuth Client ID:**
    - APIs & Services > Credentials > Create Credentials > OAuth client ID
    - Application type: Desktop app
    - Download JSON, extract `client_id` and `client_secret`
5. **Store Credentials:** Add to `OAuthConfiguration.swift` (not committed) or use environment variables

**Why required:** Gmail API requires OAuth 2.0 authentication. Without a configured Cloud project, the app cannot request user authorization or make API calls.

### Dependencies

- **SwiftSoup:** [github.com/scinfu/SwiftSoup](https://github.com/scinfu/SwiftSoup) - HTML parsing and cleanup before AI sanitization
- **OpenRouter API:** [openrouter.ai/docs](https://openrouter.ai/docs) - AI model access for content sanitization (BYOK)

### Community Resources

- **Apple Developer Forums:** [developer.apple.com/forums](https://developer.apple.com/forums/)
- **WWDC Index:** [nonstrict.eu/wwdcindex](https://nonstrict.eu/wwdcindex/)

### Reference Implementations

> These repos are cloned to `./tmp` for local exploration. Use as design reference, not as dependencies.

- **exyte/Chat:** [github.com/exyte/Chat](https://github.com/exyte/Chat) - **DO NOT use as dependency** (iOS-only, heavy deps: Giphy, MediaPicker, Kingfisher). Instead, reference for patterns:
    - `MessageView.swift` - Position-in-group logic, bubble backgrounds
    - `ChatTheme.swift` - Centralized styling (like DesignTokens)
    - Build custom ~200-line ChatBubbleView instead
- **Ora Browser:** [github.com/the-ora/browser](https://github.com/the-ora/browser) - Arc browser-style floating window with collapsible sidebar. Reference for window chrome and layout patterns.

## Recommended Repository Structure

```
.
├── Ebb/
│   ├── App/
│   │   ├── EbbApp.swift          # @main entry with SwiftData config
│   │   ├── AppState.swift        # Root @MainActor state
│   │   └── AppDelegate.swift     # Window config, menu items
│   ├── Core/
│   │   ├── Models/
│   │   │   └── MailModels.swift  # MailThread, MailMessage, etc.
│   │   ├── Services/
│   │   │   ├── Gmail/
│   │   │   │   ├── GmailAPIClient.swift
│   │   │   │   └── GmailAPIModels.swift
│   │   │   ├── OAuth/
│   │   │   │   ├── OAuthManager.swift
│   │   │   │   └── KeychainManager.swift
│   │   │   └── AI/
│   │   │       ├── SanitizationPipeline.swift
│   │   │       ├── OpenRouterClient.swift
│   │   │       └── HTMLMinifier.swift
│   │   ├── Persistence/
│   │   │   ├── PersistedModels.swift
│   │   │   └── ModelTransformers.swift
│   │   └── Sync/
│   │       └── SyncEngine.swift
│   ├── Features/
│   │   ├── Auth/
│   │   │   └── LoginView.swift
│   │   ├── Threads/
│   │   │   ├── ThreadListView.swift
│   │   │   └── ThreadRowView.swift
│   │   ├── Conversation/
│   │   │   ├── ConversationView.swift
│   │   │   └── ChatBubbleView.swift
│   │   ├── Compose/
│   │   │   └── ComposeView.swift
│   │   └── Settings/
│   │       └── SettingsView.swift
│   ├── UI/
│   │   ├── Components/
│   │   │   └── FloatingPane.swift
│   │   └── Styles/
│   │       └── DesignTokens.swift
│   └── Resources/
│       └── Assets.xcassets
├── tmp/                           # Reference implementations (git-ignored)
│   ├── ebb_v0/                    # Previous exploratory code
│   ├── exytechat/                 # exyte/chat clone
│   └── browser/                   # the-ora/browser clone
├── Ebb.xcodeproj
├── Ebb.entitlements
└── AGENTS.md
```

## Stack

| Layer       | Choice            | Notes                                    |
| ----------- | ----------------- | ---------------------------------------- |
| Language    | Swift 6 (strict)  | `@MainActor` UI, `async/await` IO        |
| UI          | SwiftUI           | 2-column layout, Liquid Glass (Tahoe)    |
| Auth        | OAuth 2.0 + PKCE  | Native browser, loopback redirect        |
| API         | Gmail REST v1     | threads, messages, labels, history, send |
| Networking  | URLSession        | No external dependencies                 |
| Persistence | SwiftData         | Offline cache for threads/messages       |
| HTML Parse  | SwiftSoup         | Clean HTML before AI processing          |
| AI          | OpenRouter (BYOK) | Content sanitization to markdown         |
| Target      | macOS 26 (Tahoe)  | Liquid Glass, no backwards compatibility |

## Architecture

- Single `AppState` root (@MainActor ObservableObject) owns auth, threads, UI state
- `SyncEngine` actor orchestrates Gmail API calls, caching, incremental sync
- `SanitizationPipeline` actor handles HTML->AI->markdown conversion
- `GmailAPIClient` struct (Sendable) wraps URLSession for REST endpoints
- `OAuthManager` handles PKCE flow with loopback server for redirect
- Domain models (`MailThread`, `MailMessage`) separate from SwiftData `@Model` types
- Transformers convert between domain and persisted representations
- Keychain stores OAuth tokens and OpenRouter API key securely
- `AppState.userEmail` populated from OAuth `userinfo` endpoint after login; used to determine sent vs received messages
- Retry policy with exponential backoff for rate limits (429/403)
- Sanitization prompt lives in code (e.g., `SanitizationPrompt.swift`), versioned as `v1`, not user-editable, not fetched remotely; version bump requires code change

## Entitlements

The app requires specific entitlements in `Ebb.entitlements`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
    <key>keychain-access-groups</key>
    <array>
        <string>$(AppIdentifierPrefix)com.yourcompany.ebb</string>
    </array>
</dict>
</plist>
```

| Entitlement              | Purpose                                           |
| ------------------------ | ------------------------------------------------- |
| `app-sandbox`            | Required for App Store; enables sandboxing        |
| `network.client`         | Allows outbound HTTPS to Gmail API and OpenRouter |
| `keychain-access-groups` | Secure storage for OAuth tokens and API keys      |

## Data Model

### Domain Models (Sendable structs)

```swift
struct MailThread: Identifiable, Sendable {
    let id: String
    var snippet: String
    var historyId: String?
    var messages: [MailMessage]
    var lastMessageDate: Date?
    var unreadCount: Int
}

struct MailMessage: Identifiable, Sendable {
    let id: String
    let threadId: String
    var from: EmailAddress
    var to: [EmailAddress]
    var cc: [EmailAddress]
    var subject: String
    var date: Date
    var snippet: String
    var bodyPlain: String?
    var bodyHtml: String?
    var sanitizedBody: String?      // AI-cleaned markdown (write-once)
    var sanitizedAt: Date?          // When sanitization occurred
    var sanitizationModel: String?  // Model used (e.g., "claude-3-haiku")
    var sanitizationVersion: Int?   // Prompt version for bulk re-sanitization
    var labelIds: [String]
    var isUnread: Bool
    var references: String?         // For threading replies
}

struct EmailAddress: Sendable {
    let name: String?
    let email: String
}
```

### User Identity

After OAuth login, fetch the user's email address to determine message direction:

```swift
// In OAuthManager, after successful token exchange:
func fetchUserEmail() async throws -> String {
    let url = URL(string: "https://www.googleapis.com/oauth2/v2/userinfo")!
    var request = URLRequest(url: url)
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    let (data, _) = try await URLSession.shared.data(for: request)
    let info = try JSONDecoder().decode(UserInfo.self, from: data)
    return info.email
}

struct UserInfo: Decodable {
    let email: String
}
```

Store in `AppState.userEmail`. Compare against `message.from.email` to determine bubble alignment:

```swift
// In ConversationView or ChatBubbleView
let isSent = message.from.email.lowercased() == appState.userEmail.lowercased()
// isSent = true -> right-aligned bubble
// isSent = false -> left-aligned bubble
```

### Persisted Models (@Model)

- `PersistedThread`: Mirrors MailThread with @Relationship to messages
- `PersistedMessage`: JSON-serialized arrays for to/cc/labels
- `PersistedSyncState`: Singleton for historyId tracking

## Gmail API Reference

### OAuth Scopes

| Scope            | Use                   | Required |
| ---------------- | --------------------- | -------- |
| `gmail.readonly` | Read threads/messages | Yes      |
| `gmail.send`     | Send messages         | Yes      |
| `gmail.modify`   | Mark read/unread      | Yes      |

### Endpoints

| Feature       | Endpoint              | Notes                       |
| ------------- | --------------------- | --------------------------- |
| Thread list   | `users.threads.list`  | Returns IDs only; paginate  |
| Thread detail | `users.threads.get`   | Full messages for thread    |
| Labels        | `users.labels.list`   | For filtering               |
| Sync          | `users.history.list`  | Incremental via historyId   |
| Send          | `users.messages.send` | base64url RFC 2822 in `raw` |

### Compose/Reply

- Build RFC 2822 MIME message, base64url encode, POST to `messages.send`
- For replies: include `threadId` + `In-Reply-To` + `References` headers

### Rate Limits

- Exponential backoff on 429/403 errors
- Max 8 retries, base 2^attempt seconds

## UX Flow

### First Launch

1. Clean window with single centered "Sign in with Gmail" button
2. No icons, no decoration - native macOS button only
3. Click opens browser for OAuth consent
4. After auth, return to empty window (no data yet)

### Manual Fetch (v1)

1. Menu item: "Fetch 10 Emails" (cmd+shift+F)
2. Fetches 10 most recent threads from Gmail API
3. Threads appear in left column (may show raw snippets initially)

### Sanitization

1. Menu item: "Clean Up Emails" (cmd+shift+S)
2. Connects to OpenRouter API using stored key
3. **Visual feedback:** Un-sanitized threads show at 50% opacity and with an in-progress indicator
4. As each completes, thread returns to full opacity
5. Sanitized content stored in `sanitizedBody` for offline access

### Sanitization Semantics

**Write-once caching:** Once `sanitizedBody` is written, it is never recomputed automatically. `SanitizationPipeline` skips messages with non-nil `sanitizedBody`. Re-sanitization is an explicit user action (future: right-click menu).

**Destructive transform:** Sanitization is lossy by design.

- `bodyHtml` = immutable source of truth (never modified)
- `sanitizedBody` = derived artifact (may lose formatting, signatures, quoted text)
- Display always uses `sanitizedBody` when available
- Replies/sends always reference original `bodyHtml` and Gmail headers, never sanitized content

**Permanence over correctness:** A flawed but stable rendering is preferred to repeated re-interpretation. "Good enough" is acceptable; 90%+ quality is the target.

**Concurrency:** Process messages serially within each thread. Cap global concurrency to 1-2 parallel sanitization tasks. Update UI after each message completes.

**Granularity:** Sanitization operates at the message level, not thread level. Threads can be partially sanitized. Progress indicators track individual message completion.

### Settings (Minimal)

1. cmd+, opens Settings
2. Two fields only: OpenRouter API key input, Model dropdown
3. Models: Claude Haiku 3.5, Gemini 2.5 Flash, GPT-4o-mini, Llama 4 Scout

### Main View

1. Two-column layout: thread list (left), conversation (right, "main pane")
2. **Arc/DIA browser style:** Collapsible sidebar, floating main pane
3. Rounded edges, proper padding, Liquid Glass materials
4. Thread list: sender, snippet, date, unread indicator
5. Conversation: chat bubbles (sent right, received left), day separators

### Compose/Reply

1. Reply input at bottom of conversation view
2. cmd+enter sends
3. New compose: cmd+n opens compose window

## Design System

### DesignTokens.swift (Centralized)

All spacing, colors, and typography MUST be defined in `DesignTokens.swift`. No magic numbers scattered across views.

```swift
enum DesignTokens {
    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }

    enum Corner {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let pane: CGFloat = 20
    }

    enum Colors {
        static let bubbleSent = Color.accentColor.opacity(0.15)
        static let bubbleReceived = Color.secondary.opacity(0.1)
        static let separator = Color.primary.opacity(0.1)
        static let inProgress = 0.5  // opacity for sanitizing threads
    }
}
```

### Visual Style

- **macOS Tahoe Liquid Glass:** Use `.glassEffect()` materials where available
- **Arc browser aesthetic:** Floating content pane with rounded corners
- **Collapsible sidebar:** Smooth animation, proximity or hover activation
- **Native controls:** Standard macOS buttons, text fields, menus
- **No over-design:** Clean, minimal, functional

## Conventions

- `@MainActor` for all UI code; actors for background work (SyncEngine, SanitizationPipeline)
- `Sendable` structs for cross-isolation data transfer
- No `any` keyword; explicit generics and protocols
- Logging via `os.log` with categories: `app`, `sync`, `oauth`, `gmail`, `ai`
- File naming: `[Domain][Type].swift` (e.g., `MailModels.swift`, `GmailAPIClient.swift`)
- Commits: See Commit Conventions section below
- No emojis in code, comments, commits, or docs
- All design values in DesignTokens.swift - no inline magic numbers

## Commit Conventions

Format: `type(scope): description`

```
type(scope): description

- Body item explaining the "why"
- Additional context if needed
```

**Types:** feat, fix, refactor, docs, style, chore, test, build, ci, perf, revert

**Scopes:** app, core, ui, api, auth, sync, ai, persistence, config, deps

**Required fields:**

- **type:** One of the allowed types above
- **scope:** Component or area being modified (required for all commits)
- **description:** Lowercase subject, imperative mood, max 72 chars
- **body:** Required for feat/fix commits - explain the "why" not "what"

**Rules:**

- Scope required for all commits
- Lowercase subject, no trailing period
- Max 100 chars header total
- Body separated by blank line
- Footer for breaking changes: `BREAKING CHANGE: description`

**Examples:**

```
feat(sync): add incremental history sync

- Reduces API calls by tracking historyId
- Falls back to full sync when history is stale
```

```
fix(auth): handle token refresh race condition

- Multiple concurrent requests could trigger duplicate refreshes
- Added mutex to serialize token refresh operations
```

```
refactor(ui): extract chat bubble into separate component
```

## Commands

```bash
# Development
bun run dev           # Build and open app
bun run build         # Debug build only
bun run build:release # Release build
bun run open          # Open built app

# Testing
bun run test          # Run tests

# Utilities
bun run format        # Format with Biome
bun run clean         # Remove build artifacts
```

## Menu Items (v1)

| Item            | Shortcut    | Action                           |
| --------------- | ----------- | -------------------------------- |
| Fetch 10 Emails | cmd+shift+F | Load recent threads from Gmail   |
| Clean Up Emails | cmd+shift+S | Sanitize all un-sanitized emails |
| Refresh         | cmd+R       | Incremental sync                 |
| New Message     | cmd+N       | Open compose window              |
| Settings        | cmd+,       | Open settings                    |

## QA

- No automated tests; manual QA required
- Launch app, sign in via OAuth, verify token persists across restart
- Fetch 10 emails, verify threads appear in list
- Run "Clean Up Emails", verify:
    - Un-sanitized threads show reduced opacity during processing
    - Threads return to full opacity when complete
    - Opening a thread shows clean markdown in bubbles
- Reply to a thread, verify message appears and sends correctly
- Test offline: disconnect network, verify cached threads display
- Check console for errors; no crashes, no uncaught exceptions

## Quality Targets

- 60fps scrolling in thread list and conversation
- Thread open <200ms from cache
- Cold launch <2s on Apple Silicon
- Sanitization <3s per message (depends on AI model)

## Scope

**In scope:**

- Gmail only, single Google account
- macOS 26 Tahoe only
- OAuth login, thread list, chat-bubble conversation
- AI-powered HTML->markdown sanitization (OpenRouter BYOK)
- Compose new message, reply within thread
- Offline reading from cache
- Dark mode, Liquid Glass design

**Out of scope:**

- Multi-provider, IMAP/SMTP
- Multi-account
- Rich text editor, inline attachments
- Labels management, search, filters
- iOS/iPadOS (future)
- Push notifications, background refresh

## Roadmap

### Phase 1: Window & Layout

- [ ] Xcode project with folder structure
- [ ] Two-column NavigationSplitView layout
- [ ] Collapsible sidebar (Arc/DIA style)
- [ ] Floating main pane with rounded corners
- [ ] DesignTokens.swift with spacing/colors
- [ ] Liquid Glass materials (macOS Tahoe)
- [ ] Empty states for each pane

### Phase 2: Auth & Fetch

- [ ] OAuth 2.0 login with PKCE + loopback
- [ ] Token storage in Keychain
- [ ] Centered "Sign in with Gmail" button (first launch)
- [ ] GmailAPIClient for threads.list and threads.get
- [ ] "Fetch 10 Emails" menu item
- [ ] Thread list view with rows

### Phase 3: Sanitization

- [ ] Define and freeze sanitization prompt (version 1)
- [ ] SwiftSoup HTML minification
- [ ] OpenRouterClient for AI API calls
- [ ] SanitizationPipeline actor
- [ ] Write-once caching (skip already-sanitized messages)
- [ ] Serial per-thread processing with 1-2 global concurrency
- [ ] Settings view (API key, model picker)
- [ ] "Clean Up Emails" menu item
- [ ] Visual feedback (opacity during processing)
- [ ] Markdown rendering in chat bubbles

### Phase 4: Conversation & Reply

- [ ] ConversationView with chat bubbles
- [ ] Sent (right) vs received (left) alignment
- [ ] Day separators
- [ ] Reply input at bottom
- [ ] Send via messages.send endpoint
- [ ] Threading headers (In-Reply-To, References)
- [ ] cmd+enter to send

### Phase 5: Polish

- [ ] Compose new message window (cmd+N)
- [ ] SwiftData persistence for offline
- [ ] Incremental sync via history.list
- [ ] Loading states and animations
- [ ] Error handling with banners
- [ ] Window state persistence

## Constraints

- Gmail API only; no IMAP/SMTP
- One account only; no switcher
- Chat bubbles as primary view; no traditional email layout
- AI sanitization requires OpenRouter API key
- Minimal dependencies: URLSession, SwiftSoup, SwiftData
