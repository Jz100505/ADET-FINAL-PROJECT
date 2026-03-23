# HAUPokemon Monsters App
**6ADET Finals Skill-Based Exam — Holy Angel University, School of Computing**

---

## Project Overview

HAUPokemon Monsters is a location-based Flutter application for catching and managing virtual monsters. Originally built with a PHP/MySQL backend, it has been significantly enhanced to include full offline capabilities using local SQLite storage, an advanced authentication system, and administrative features.

## Core Features

- **Authentication System:** Comprehensive user login, registration (`register_page.dart`), and secure on-device hashed password storage using the `crypto` package.
- **Admin Dashboard:** Specific administrative functions including viewing, adding, editing, and deleting players (`players_list_page.dart`, `add_player_page.dart`, `edit_player_page.dart`) and full control over monsters.
- **Player Interaction:** Players can view caught monsters, navigate the map to catch new monsters (`catch_monster_page.dart`), and view their rankings (`display_rankings_page.dart`).
- **Location & Map Integration:** Interactive map displays using `flutter_map` and `latlong2`, paired with `geolocator` to find and catch monsters based on GPS coordinates.
- **Offline Data Storage:** The app uses `sqflite` for a robust local database (`local_db_service.dart`), allowing the application to smoothly operate without necessarily relying on an external network or backend.
- **Multimedia Experiences:** Uses `audioplayers` for alerts and sounds, `torch_light` for flashlight effects, and `image_picker` for custom monster images.

---

## Project Structure

```text
haumonsters/
├── pubspec.yaml
├── android_manifest_permissions.xml
├── lib/
│   ├── main.dart
│   ├── models/
│   │   ├── monster_model.dart            ← defines Monster properties
│   │   ├── player_model.dart             ← defines Player/User properties
│   │   └── player_ranking_model.dart
│   ├── pages/
│   │   ├── splash_page.dart
│   │   ├── login_page.dart               ← login form and routing based on role
│   │   ├── register_page.dart            ← sign up form for new users
│   │   ├── dashboard_page.dart           ← main navigation hub
│   │   ├── add_monster_page.dart
│   │   ├── edit_monster_page.dart
│   │   ├── edit_monsters_page.dart
│   │   ├── delete_monster_page.dart
│   │   ├── catch_monster_page.dart       ← real-time location and interactive map map view
│   │   ├── display_rankings_page.dart
│   │   ├── map_page.dart
│   │   ├── monster_details_page.dart
│   │   ├── players_list_page.dart        ← Admin page to list all players
│   │   ├── add_player_page.dart          ← Admin page to manually register players
│   │   └── edit_player_page.dart         ← Admin page to edit player credentials
│   └── services/
│       ├── api_service.dart              ← network API / legacy remote database
│       └── local_db_service.dart         ← primary SQLite local database management
└── api/                                  ← (Optional) legacy PHP backend deployment
    ├── schema.sql
    └── *.php scripts
```

---

## Setup & Run Instructions

### 1. Install Dependencies
```bash
flutter pub get
```

### 2. Configure Android Permissions
Ensure you have the required Android permissions (Location, Internet, Camera). Use `android_manifest_permissions.xml` as a reference if installing fresh, copying its contents inside the `<manifest>` tag, **before** the `<application>` tag in:
```text
android/app/src/main/AndroidManifest.xml
```

### 3. Build & Run
To run the app on a connected device or emulator:
```bash
flutter run
```
To build a release APK:
```bash
flutter build apk --release
```

---

## Technical & Architecture Notes

1. **Local vs API:** The application has seamlessly transitioned towards prioritizing local storage (`local_db_service.dart`) utilizing `sqflite`, making it fully functional offline. 
2. **Security:** Passwords are hashed locally using the `crypto` library (SHA-256) ensuring user credentials are not stored in plain text.
3. **Map Rendering:** The app does not rely directly on Google Maps widget, instead employing the highly customizable `flutter_map` widget with localized tiles/servers via `latlong2`.

---
