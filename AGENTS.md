## 1. Documentation

- **Platform**: [docs.swift.org/swift-book](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/) (language, concurrency, macros), [developer.apple.com/documentation/swift](https://developer.apple.com/documentation/swift/) (standard library)
- **UI**: [developer.apple.com/documentation/swiftui](https://developer.apple.com/documentation/swiftui/), [developer.apple.com/tutorials/swiftui/creating-a-macos-app](https://developer.apple.com/tutorials/swiftui/creating-a-macos-app), [developer.apple.com/design/human-interface-guidelines/designing-for-macos](https://developer.apple.com/design/human-interface-guidelines/designing-for-macos)
- **Data**: [developer.apple.com/documentation/swiftdata](https://developer.apple.com/documentation/swiftdata/)
- **APIs**: [developers.google.com/gmail/api/reference/rest](https://developers.google.com/gmail/api/reference/rest), [developers.google.com/gmail/api/guides](https://developers.google.com/gmail/api/guides), [developers.google.com/identity/protocols/oauth2/native-app](https://developers.google.com/identity/protocols/oauth2/native-app)
- **Libraries**: [SwiftSoup](https://github.com/scinfu/SwiftSoup) (HTML parsing), [OpenRouter](https://openrouter.ai/docs) (AI sanitization)
- **Resources**: [developer.apple.com/forums](https://developer.apple.com/forums/), [nonstrict.eu/wwdcindex](https://nonstrict.eu/wwdcindex/)

## 2. Repository Structure

```
.
├── Ebb/
│   ├── App/
│   ├── Core/
│   │   ├── Models/
│   │   ├── Services/
│   │   │   ├── Gmail/
│   │   │   ├── OAuth/
│   │   │   └── AI/
│   │   ├── Persistence/
│   │   ├── Utilities/
│   │   └── Sync/
│   ├── Features/
│   │   ├── Auth/
│   │   ├── Main/
│   │   ├── Threads/
│   │   ├── Conversation/
│   │   └── Settings/
│   ├── UI/
│   │   ├── Components/
│   │   └── Styles/
│   └── Resources/
├── tmp/
├── Ebb.xcodeproj
└── AGENTS.md
```

## 3. Stack

| Layer | Choice | Notes |
| ----- | ------ | ----- |
| Language | Swift 6 (strict) | @MainActor UI, async/await IO |
| UI | SwiftUI | 2-column layout, Liquid Glass (Tahoe) |
| Auth | OAuth 2.0 + PKCE | Native browser, loopback redirect |
| API | Gmail REST v1 | threads, messages, labels, history, send |
| Networking | URLSession | No external dependencies |
| Persistence | SwiftData | Offline cache for threads/messages |
| HTML Parse | SwiftSoup | Clean HTML before AI processing |
| AI | OpenRouter (BYOK) | Content sanitization to markdown |
| Target | macOS 26 (Tahoe) | Liquid Glass, no backwards compatibility |

## 4. Commands

- `bun run dev` - Build and open app
- `bun run build` / `bun run build:release` - Debug/release build
- `bun run open` - Open built app
- `bun run test` - Run tests
- `bun run format` - Format with Biome
- `bun run clean` - Remove build artifacts

## 5. Architecture

- **State**: Single `AppState` root (@MainActor Observable) owns auth, threads, UI state; `AppState.userEmail` populated from Gmail profile API after login, determines sent vs received messages
- **Services**: `GmailAPIClient` struct (Sendable) wraps URLSession for REST endpoints; `OAuthManager` handles PKCE flow with loopback server; `PlainTextSanitizer` extracts clean text from HTML via SwiftSoup; `SidebarManager` handles collapsible sidebar state; `SanitizationPipeline` actor for HTML→AI→markdown; `OpenRouterClient` for AI model access; `AIKeyManager` for Keychain storage
- **Models**: Domain models (`MailThread`, `MailMessage`) separate from SwiftData `@Model` types; transformers convert between domain and persisted representations; Keychain stores OAuth tokens securely
- **Retry**: Exponential backoff on 429/403 errors, max 8 retries, base 2^attempt seconds
- **Planned**: `SyncEngine` actor for incremental sync via history.list

## 6. Data Model

- **MailThread**: id, snippet, historyId, messages array, lastMessageDate, unreadCount
- **MailMessage**: id, threadId, from (EmailAddress), to/cc arrays, subject, date, snippet, bodyPlain, bodyHtml, sanitizedBody (AI-cleaned markdown, write-once), sanitizedAt, sanitizationModel, sanitizationVersion, labelIds, isUnread, references
- **EmailAddress**: name (optional), email
- **Persisted**: `PersistedThread` mirrors MailThread with @Relationship to messages; `PersistedMessage` uses JSON-serialized arrays for to/cc/labels; `PersistedSyncState` singleton for historyId tracking
- **User identity**: Fetch from `oauth2/v2/userinfo` after login, compare `message.from.email.lowercased()` with `appState.userEmail.lowercased()` for bubble alignment

## 7. Gmail API

- **OAuth scopes**: gmail.readonly (read), gmail.send (send), gmail.modify (mark read/unread)
- **Endpoints**: threads.list (IDs only, paginate), threads.get (full messages), labels.list (filtering), history.list (incremental sync via historyId), messages.send (base64url RFC 2822 in `raw`)
- **Compose/Reply**: Build RFC 2822 MIME message, base64url encode, POST to messages.send; for replies include threadId + In-Reply-To + References headers
- **OAuth setup**: Create Google Cloud project, enable Gmail API, configure OAuth consent screen (External, scopes: gmail.readonly/send/modify), create Desktop OAuth client ID, store client_id/client_secret in OAuthConfiguration.swift (git-ignored)
- **Entitlements**: app-sandbox (required for App Store), network.client (outbound HTTPS), keychain-access-groups (OAuth tokens and API keys)

## 8. UX

- **First launch**: Clean window with centered "Sign in with Gmail" button, click opens browser for OAuth consent, return to empty window after auth
- **Manual fetch**: Menu "Fetch Emails" (cmd+shift+F), fetches recent threads with pagination, accumulates into cache, threads appear with quote-stripped plain text
- **Sanitization**: PlainTextSanitizer extracts text from HTML automatically on fetch (removes quoted content, blockquotes, signature blocks); AI sanitization via "Sanitize Emails" (cmd+shift+U) connects to OpenRouter, un-sanitized threads show at 50% opacity, sanitized markdown stored in sanitizedBody for offline; write-once caching (never recomputed automatically), destructive transform (bodyHtml is source of truth), process messages serially within thread, cap global concurrency to 1-2 parallel tasks
- **Main view**: Two-column layout (thread list left, conversation right), Arc/DIA browser style with collapsible sidebar, Liquid Glass materials, chat bubbles (sent right, received left)
- **Compose**: Reply input at bottom of conversation (cmd+enter sends); new message via pencil icon in sidebar header opens inline compose with recipient input

## 9. Design

- **DesignTokens.swift**: All spacing (xxs=4, xs=8, sm=12, md=16, lg=24, xl=32, xxl=48), corners (sm=8, md=12, lg=16, pane=20), colors (bubbleSent, bubbleReceived, separator, inProgress=0.5 opacity) centralized; no magic numbers in views
- **Style**: macOS Tahoe Liquid Glass via `.glassEffect()`, Arc browser aesthetic (floating content pane with rounded corners), collapsible sidebar with smooth animation, native controls, clean/minimal/functional
- **Settings**: cmd+, opens Settings with provider selector (OpenRouter or None), API key input with show/hide toggle (Keychain stored), model dropdown (GPT-5 Nano, Llama 4 Scout, Gemini 2.5/3 Flash, Claude Haiku 3.5)

## 10. Conventions

- `@MainActor` for all UI code; actors for background work
- `Sendable` structs for cross-isolation data transfer
- No `any` keyword; explicit generics and protocols
- Logging via `os.log` with categories: app, sync, oauth, gmail, ai
- File naming: `[Domain][Type].swift` (e.g., MailModels.swift, GmailAPIClient.swift)
- No emojis in code, comments, commits, or docs
- All design values in DesignTokens.swift

## 11. Quality

- No automated tests; manual QA required
- **Auth tests**: Launch app, sign in via OAuth, verify token persists across restart; sign out, verify tokens cleared
- **Thread tests**: Fetch emails, verify threads appear in list; select thread, verify chat bubbles (sent right, received left); verify quote-stripped plain text displays; test offline (disconnect network, verify cached threads display)
- **Compose tests**: Verify reply input at bottom, cmd+enter sends; click pencil icon, verify compose view opens; add recipient, subject, send new message
- **Sanitization tests**: Open Settings (cmd+,), configure OpenRouter API key; select different models; run "Sanitize Emails" (cmd+shift+U), verify AI formatting; run "Reset Sanitization", verify messages return to plain text
- **Performance targets**: 60fps scrolling, thread open <200ms from cache, cold launch <2s on Apple Silicon, sanitization <3s per message
- **Menu items**: Fetch Emails (cmd+shift+F), Clear Cache (cmd+shift+K), Sanitize Emails (cmd+shift+U), Reset Sanitization, Settings (cmd+,), Sign Out, About Ebb; planned: Refresh (cmd+R) for incremental sync
- Commits: Always use Conventional Commits format `type(scope): description` with body required, format as `type(scope): description` then newline then body with `- Item` bullets explaining the "why"; if commitlint.config.js exists read allowed types/scopes from there, otherwise use logical types (feat/fix/refactor/docs/chore/test) and derive scope from the area being modified

## 12. Scope

**In scope**: Gmail only, single Google account, macOS 26 Tahoe only, OAuth login, thread list, chat-bubble conversation, AI-powered HTML→markdown sanitization (OpenRouter BYOK), inline compose (iMessage-style), reply within thread, offline reading from cache, dark mode, Liquid Glass design

**Out of scope**: Multi-provider/IMAP/SMTP, multi-account, rich text editor, inline attachments, labels management, search, filters, iOS/iPadOS, push notifications, background refresh

**Constraints**: Gmail API only (no IMAP/SMTP), one account only (no switcher), chat bubbles as primary view (no traditional email layout), AI sanitization requires OpenRouter API key, minimal dependencies (URLSession, SwiftSoup, SwiftData)

## 13. Roadmap

**Phase 1-3 (Done)**: Window layout with two-column NavigationSplitView, collapsible sidebar (Arc/DIA style), floating main pane, DesignTokens, Liquid Glass, empty states; OAuth 2.0 with PKCE + loopback, token storage in Keychain, GmailAPIClient for threads.list/get, "Fetch Emails" menu, thread list view; Thread selection state, clickable rows, ConversationView with ChatBubbleView, SwiftSoup HTML to plain text, display in bubbles

**Phase 4-5 (Done)**: Sanitization prompt, OpenRouterClient, SanitizationPipeline, Settings view (API key, model picker), "Sanitize Emails" menu; Reply input at bottom, send via messages.send, threading headers, cmd+enter, conversation header with avatars, pencil icon for new message, inline compose

**Phase 6 (Partial)**: SwiftData persistence for offline (done), incremental sync via history.list (planned), loading states and animations (done), error handling with banners (planned), window state persistence (planned)
