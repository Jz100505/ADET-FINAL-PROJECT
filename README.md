# HAUPokemon Monsters App
**6ADET Finals Skill-Based Exam — Holy Angel University, School of Computing**

---

## Project Structure

```
haumonsters/
├── pubspec.yaml
├── android_manifest_permissions.xml     ← paste into AndroidManifest.xml
├── lib/
│   ├── main.dart
│   ├── models/
│   │   ├── monster_model.dart
│   │   └── player_ranking_model.dart
│   ├── pages/
│   │   ├── dashboard_page.dart
│   │   ├── add_monster_page.dart
│   │   ├── edit_monster_page.dart       ← single monster edit form
│   │   ├── edit_monsters_page.dart      ← list + navigate to edit
│   │   ├── delete_monster_page.dart
│   │   ├── catch_monster_page.dart      ← placeholder (future)
│   │   ├── display_rankings_page.dart   ← placeholder (future)
│   │   ├── map_page.dart                ← placeholder (future)
│   │   └── monster_details_page.dart    ← placeholder (future)
│   └── services/
│       └── api_service.dart
└── api/                                 ← deploy to your PHP server
    ├── hauconnect.php
    ├── add_monster.php
    ├── get_monsters.php
    ├── update_monster.php
    ├── delete_monster.php
    ├── upload_monster_image.php
    └── schema.sql
```

---

## Flutter Setup

### 1. Install dependencies
```bash
flutter pub get
```

### 2. Add Android permissions
Copy the contents of `android_manifest_permissions.xml` into:
```
android/app/src/main/AndroidManifest.xml
```
Paste inside the `<manifest>` tag, **before** `<application>`.

### 3. Update server IP
Open `lib/services/api_service.dart` and change `baseUrl`:
```dart
static const String baseUrl = "http://YOUR_SERVER_IP";
```

---

## PHP Backend Setup

### 1. Import the database
```bash
mysql -u root -p < api/schema.sql
```

### 2. Update credentials in `hauconnect.php`
```php
$host     = "localhost";
$dbname   = "haumonstersDB";
$username = "YOUR_DB_USER";
$password = "YOUR_DB_PASSWORD";
```

### 3. Deploy API files
Upload all files inside `api/` to your web server root (e.g. `/var/www/html/`).

### 4. Create the uploads folder (for image upload)
```bash
mkdir -p /var/www/html/uploads
chmod 777 /var/www/html/uploads
```

### 5. Update the image URL in `upload_monster_image.php`
```php
$imageUrl = "http://YOUR_SERVER_IP/uploads/" . $newFileName;
```

---

## API Endpoints

| Endpoint                   | Method | Description             |
|----------------------------|--------|-------------------------|
| `/add_monster.php`         | POST   | Create a new monster    |
| `/get_monsters.php`        | GET    | Fetch all monsters      |
| `/update_monster.php`      | POST   | Update monster by ID    |
| `/delete_monster.php`      | POST   | Delete monster by ID    |
| `/upload_monster_image.php`| POST   | Upload monster image    |

---

## Database

**Name:** `haumonstersDB`  
**Server (exam default):** `http://3.0.90.110`

### `monsterstbl` columns

| Column               | Type             | Notes              |
|----------------------|------------------|--------------------|
| `monster_id`         | INT UNSIGNED     | PK, Auto Increment |
| `monster_name`       | VARCHAR(100)     | Required           |
| `monster_type`       | VARCHAR(100)     | Required           |
| `spawn_latitude`     | DECIMAL(10,7)    | Required           |
| `spawn_longitude`    | DECIMAL(10,7)    | Required           |
| `spawn_radius_meters`| DECIMAL(10,2)    | Default: 100.00    |
| `picture_url`        | VARCHAR(500)     | Nullable           |

---

## Completed / Missing Code Notes

The exam PDF had two **"INPUT THE MISSING CODES HERE"** gaps:

### 1. `edit_monsters_page.dart` — `_openEdit()`
```dart
Future<void> _openEdit(Monster monster) async {
  final updated = await Navigator.push<bool>(
    context,
    MaterialPageRoute(builder: (_) => EditMonsterPage(monster: monster)),
  );
  if (updated == true) {
    _refresh();
  }
}
```

### 2. `delete_monster_page.dart` — `_deleteMonster()` confirmation dialog
```dart
final confirmed = await showDialog<bool>(
  context: context,
  builder: (context) => AlertDialog(
    title: const Text("Delete Monster"),
    content: Text("Are you sure you want to delete ${monster.monsterName}?"),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text("Cancel"),
      ),
      ElevatedButton(
        onPressed: () => Navigator.pop(context, true),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
        child: const Text("Delete", style: TextStyle(color: Colors.white)),
      ),
    ],
  ),
);
```

---

## Submission Requirements (per exam rubric)
- Screen record demo video working on a mobile device
- APK file
- Full source code
- Wireframes / initial design draft
