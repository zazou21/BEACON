# BEACON  
**Broadcast Emergency Alerts – Community Offline Network**  
🛰️ Milestone 1: UI Prototype

---

## 🚀 What is BEACON?  
In disaster scenarios where cellular/internet connectivity fails, BEACON enables a peer-to-peer emergency communication network—helping survivors, responders and communities stay connected and exchange vital alerts and resources offline.

This release (Milestone 1) focuses **solely on the UI layer**: the screens, navigation, theming and UX design of the app (no backend / offline-mesh logic yet).

---

## 🎯 Key Features Implemented (UI Only)  
- Landing page with two main actions: **Join an existing communication** or **Start a new emergency scenario**  
- Dashboard screen showing nearby connected devices (mock list / UI)  
- Chat screen UI for private messaging between users  
- Resource-sharing screen UI (medical supplies, food, shelter)  
- User Profile & Emergency Contact setup screen  
- Bottom Navigation Bar for smooth navigation between major sections  
- Light / Dark theme toggle & responsive layouts for portrait/landscape on phones and tablets  

---

## 🧩 Project Structure (UI Layer)  
```

lib/
├── main.dart           ← App entry point & theming
├── theme.dart          ← App-wide theme & style definitions
├── screens/            ← UI screens (Landing, Dashboard, Chat, Resources, Profile)
└────── chat_page.dart
 ────── dashboard_page.dart
 ────── profile_page.dart
 ────── resource_page.dart

````
> *Note: Backend, service integrations, offline mesh networking and persistence will be in later milestones.*

---

## 🧠 ViewModels (Business Logic)

This project uses a simple MVVM-style approach where **Screens** render UI and delegate state + actions to **ViewModels**. ViewModels are responsible for:
- Holding screen state (loading flags, selected tabs, discovered devices/clusters, chat messages, etc.)
- Coordinating async flows (initialization, DB reads/writes, Nearby messaging)
- Exposing a clean API to the UI via `ChangeNotifier` (so widgets can rebuild via `Provider`/`Consumer`)

In the UI layer, ViewModels are typically wired using `ChangeNotifierProvider` and `Consumer` (see the screen implementations in `lib/screens/`).

### ViewModel responsibilities (by file)

- `lib/viewmodels/dashboard_view_model.dart` (**DashboardViewModel**)
   - Orchestrates **Nearby Connections** in either `initiator` or `joiner` mode.
   - Initiator flow: creates/loads the current cluster, tracks available devices, and invites devices to join.
   - Joiner flow: tracks discovered clusters, joins a selected cluster, accepts/rejects invites, and loads cluster members.
   - Convenience actions: quick-message sending, broadcast messaging, navigation helpers to chat, and a `stopAll()` reset.

- `lib/viewmodels/chat_view_model.dart` (**ChatViewModel**)
   - Supports **private chats** (device-to-device) and **group chats** (cluster chat).
   - Loads chat + participants from the local DB (repositories) and keeps UI updated.
   - Sends messages through Nearby (`sendChatMessage` / `broadcastChatMessage`) and persists messages to the DB.
   - Refresh strategy:
      - Reacts to Nearby state updates (device presence / cluster membership)
      - Periodically refreshes messages from the DB (polling)

- `lib/viewmodels/resource_viewmodel.dart` (**ResourceViewModel**)
   - Drives the Resources screen state (selected category tab, loading flag, recent activity list).
   - Initializes Nearby (initiator/joiner) based on the persisted `dashboard_mode` and loads current resources/devices.
   - Posts/requests resources, persists them via the repository, and broadcasts resource updates to connected devices.
   - Listens for resource updates via `Resource.resourceUpdateStream` and refreshes UI when the stream emits.

- `lib/viewmodels/profile_view_model.dart` (**ProfileViewModel**)
   - Loads and saves the user profile via `ProfileRepository`.
   - Exposes `currentProfile`, `isSaved`, and a `savedData` map for display.
   - Used by the Profile screen to persist onboarding/profile changes.

### Dependency injection (testability)

Most ViewModels support injecting repositories/services (or create sensible defaults). This makes unit/integration testing easier because tests can provide fakes/mocks:
- `ChatViewModel(...)` accepts repositories + an optional Nearby implementation.
- `ResourceViewModel(...)` accepts an optional `ResourceRepository`, `DBService`, and `NearbyConnectionsBase`.
- `DashboardViewModel(...)` is constructed with repositories and chooses the correct Nearby implementation based on mode.
- `ProfileViewModel(...)` is constructed with a `ProfileRepository` (the screen may inject a real implementation).

---

## 🛠️ How to Run (for UI test)  
1. Clone the repository:  
   ```bash
   git clone https://github.com/zazou21/BEACON.git  
   cd BEACON  
   ```
2. Make sure you have Flutter installed & configured:
   ```bash
   flutter doctor  
   ```
3. Launch the app on an emulator or physical device:
   ```bash
   flutter run  
   ```
4. Explore the UI flows and theme toggle. (All data is mocked in this milestone.)
---

## 🙌 Why this Matters

In real-world disasters, networks collapse—but community communication becomes *more* essential, not less. BEACON’s UI is the first step toward empowering local networks of responders and citizens to share alerts, chat and coordinate **even offline**. This prototype lays the groundwork for intelligence, resource sharing and peer resilience.

---

## 📌 What’s Next (Upcoming Milestones)

TBA
---

---

## 📄 License

This project is licensed under the MIT License – see the [LICENSE](LICENSE) file for details.

---

Thank you for checking out BEACON! 💡
