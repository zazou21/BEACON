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
