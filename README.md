# Zarb-Ul-Hadeed (117 SP Regt.) — Military Roster & Parade Console

A high-performance, premium Flutter administration console and personnel tracking dashboard designed for military unit deployment. Zarb-Ul-Hadeed provides real-time headcounts, movement history logging, dynamic group scheduling, customizable attributes, role-based controls, and platform-agnostic report generation (PDF and CSV).

This project has been refactored into a clean, testable **MVVM (Model-View-ViewModel)** architecture and features offline capabilities powered by `SharedPreferences`.

---

## 1. Visual Identity & Design System

The application utilizes a premium military design language featuring **Glassmorphism**, neon highlights, sleek golds, and deep regimental forest greens. 

### A. Color Palette Reference

| Palette Token | Light Mode Value | Dark Mode Value | Semantic Role |
| :--- | :--- | :--- | :--- |
| **Forest Green (Primary)** | `#0C5A32` | `#0C5A32` | Header background, primary buttons, positive labels |
| **Deep Forest (Background)**| `#E8F5EE` | `#03140A` | Scaffold background, login background, input backdrops |
| **Gold Metallic (Accent)**  | `#9E7715` | `#CD9B2D` | High-contrast borders, category titles, active states |
| **Neon Green (Highlight)** | `#0C5A32` (Muted) | `#00FF66` | Online state badges, statistics badges, focus indicator |
| **Gold Highlight (Text)**  | `#4A5D52` | `#FFF2C2` | Golden header typography gradients |
| **Body Typography (Light)**| `#042011` | `#FFFFFF` | Primary reading text |
| **Body Typography (Muted)**| `#4A5D52` | `#E5E5E5` | Labels, details, descriptions, subtitles |
| **Danger Muted (Delete)**  | `#FFD2D2` | `#FF1F1F` (Muted) | Alert cards, delete button background |
| **Danger Highlight**       | `#D32F2F` | `#FF5252` | Delete button labels, invalid warning icons |

### B. UI Styling Tokens
* **Border Radius**: Consistent `12px` to `16px` rounded corners on all cards, text inputs, and dialog boxes.
* **Glassmorphism**: App bars and bottom navigation bars use a semi-translucent backdrop filter with a blur factor of `sigmaX: 10, sigmaY: 10` and `85% opacity`.
* **Elevations & Borders**: Flat design in dark mode with thin `1px` high-contrast gold outlines (`alpha: 0.25`). Light mode utilizes soft shadows (`blurRadius: 10, offset: (0, 4)`) combined with forest green borders.

---

## 2. Directory Layout & MVVM Architecture

The codebase separates presentation (Views) from logic (ViewModels) and data structures (Models) using the Provider package for dependency injection.

```
lib/
├── main.dart                      # App entry point, MultiProvider setup & MaterialApp
├── models/                        # Core data models
│   ├── group_model.dart           # Custom dynamic groups
│   ├── movement_record.dart       # Chronological movement events
│   └── person_status.dart         # Current category/subcategory assignment status
├── services/                      # System services and persistence engine
│   ├── mock_data.dart             # Mock credentials & attributes
│   ├── personnel_data.dart        # Seed nominal roll and default hierarchy data
│   ├── personnel_data_manager.dart# Singleton database driver and storage controller
│   ├── file_saver.dart            # Platform-specific export router
│   ├── file_saver_web.dart        # Web file downloader (html anchors)
│   └── file_saver_web.dart        # Compiler stub
├── viewmodels/                    # UI state controllers (ViewModels)
│   ├── app_viewmodel.dart         # Theme, splash, and authentication state
│   ├── login_viewmodel.dart       # Credentials input and validation logic
│   ├── dashboard_viewmodel.dart   # Tab coordination, search query, FAB triggers
│   ├── nominal_roll_viewmodel.dart # Roster searching and ID dialog controls
│   ├── analysis_viewmodel.dart    # Segmented analysis filters and chip drill-downs
│   ├── edit_tab_viewmodel.dart    # Intermediate view scheduler
│   ├── edit_assignment_viewmodel.dart # Detail screen scheduler & category populators
│   ├── battery_detail_viewmodel.dart # Battery metrics, filtering, and rosters
│   ├── manage_attributes_viewmodel.dart # Trade, Rank, and Battery configuration metadata
│   └── view_all_groups_viewmodel.dart # Directory lists of credentials slots
└── views/                         # Presentation layouts (Views)
    ├── splash_screen.dart         # Force-dark military intro animation
    ├── login_screen.dart          # Secure gateway screen
    ├── dashboard_screen.dart      # Multi-tab dashboard container
    ├── edit_assignment_screen.dart# Personnel duty scheduler
    ├── battery_detail_screen.dart # Battery-specific dashboards
    ├── group_detail_screen.dart   # Personnel tracking inside custom groups
    ├── manage_attributes_screen.dart# Regimental database metadata modifiers
    ├── personnel_profile_screen.dart# Personnel movement history detail
    └── view_all_groups_screen.dart# Account authorization tables
```

### Key Architectural Layers

#### A. Models Layer
* **[GroupModel](file:///c:/flutter/Projects/Frukh/parade/lib/models/group_model.dart)**: Contains custom groups deployed for transient missions (e.g. Sports, Working Parties). Includes group metadata (Leader, Category, Expiration Date) and references to assigned personnel.
* **[PersonStatus](file:///c:/flutter/Projects/Frukh/parade/lib/models/person_status.dart)**: Maps a soldier's active category, optional subcategory, and optional sub-subcategory, alongside a start date, end date (indefinite or finite), and destination details. Contains path generator helper properties (e.g., `displayPath`).
* **[MovementRecord](file:///c:/flutter/Projects/Frukh/parade/lib/models/movement_record.dart)**: Stores chronological movement paths for timelines.

#### B. ViewModels Layer (State Management)
* **[AppViewModel](file:///c:/flutter/Projects/Frukh/parade/lib/viewmodels/app_viewmodel.dart)**: Coordinates high-level application states (Splash dismissal, Login sessions, Global theme toggles) and persists user theme preferences.
* **[DashboardViewModel](file:///c:/flutter/Projects/Frukh/parade/lib/viewmodels/dashboard_viewmodel.dart)**: Manages tab indices, expandable parade tree hierarchies, and Floating Action Buttons (FAB) states.
* **[AnalysisViewModel](file:///c:/flutter/Projects/Frukh/parade/lib/viewmodels/analysis_viewmodel.dart)**: Dictates filter states (Rank, Battery, Trade) for the Analysis panel and facilitates drilling down into customized personnel collections.
* **[EditAssignmentViewModel](file:///c:/flutter/Projects/Frukh/parade/lib/viewmodels/edit_assignment_viewmodel.dart)**: Manages dynamic hierarchy list population and writes updated location structures back to the storage singleton.
* **[ManageAttributesViewModel](file:///c:/flutter/Projects/Frukh/parade/lib/viewmodels/manage_attributes_viewmodel.dart)**: Administers configuration constraints.

#### C. Services Layer
* **[PersonnelDataManager](file:///c:/flutter/Projects/Frukh/parade/lib/services/personnel_data_manager.dart)**: A central data controller. Initializes, parses, reads, and writes records, customized structures, histories, and metadata limits. It coordinates serialization cycles into `SharedPreferences`.
* **[FileSaver Engine](file:///c:/flutter/Projects/Frukh/parade/lib/services/file_saver.dart)**: Routes byte arrays into local file generators. The engine splits between:
  - **[file_saver_web.dart](file:///c:/flutter/Projects/Frukh/parade/lib/services/file_saver_web.dart)**: Triggers download anchors in standard HTML5 frameworks.
  - **[file_saver_io.dart](file:///c:/flutter/Projects/Frukh/parade/lib/services/file_saver_io.dart)**: Generates output files, handles storage permissions on Android/iOS, and opens the results using system-native application triggers (`open_file`).

---

## 3. Screen Specifications, Modules & Functionalities

This section documents each UI screen within the application, listing their specific sub-modules, components, and the operational functionalities they provide.

### A. Splash Screen ([splash_screen.dart](file:///c:/flutter/Projects/Frukh/parade/lib/views/splash_screen.dart))
* **Purpose**: Creates the initial immersive visual experience and launches setup configurations.
* **Key Components & Modules**:
  * *Animated Topographic Background*: Uses a custom `TopographicPainter` displaying moving, organic contour lines that breathing-drift slowly.
  * *Unit Emblem*: Centered circular card showcasing `army_crest.png` with a gold metallic outer boundary shadow.
  * *ShaderMask Branding Titles*: Draws gradients across the typography tags `117 SP` and `REGT.`.
  * *Sweep Spinner Loader*: Uses `SpinnerPainter` to build a glowing neon-green circular loading indicator with back-blur filters.
* **Functionality**: Performs a 5-second automatic initialization flow before routing the execution context into either the Login or Dashboard screens.

### B. Login Screen ([login_screen.dart](file:///c:/flutter/Projects/Frukh/parade/lib/views/login_screen.dart))
* **Purpose**: Restricts system entry, verifying credentials and distributing role permissions.
* **Key Components & Modules**:
  * *Spotlight Glow*: The top of the form contains radial overlays drawing a subtle gold highlight.
  * *Glowing Fields*: Implements `GlowingTextField` showing border glows on focus, suffix toggle visibility icons, and case-insensitive validators.
  * *Login Submitter*: Large green action button triggering authentication via [LoginViewModel](file:///c:/flutter/Projects/Frukh/parade/lib/viewmodels/login_viewmodel.dart).
* **Functionality**: Validates roles (`superadmin`, `admin`, `user`) and restricts login screen access to a forced dark theme.

### C. Dashboard Screen ([dashboard_screen.dart](file:///c:/flutter/Projects/Frukh/parade/lib/views/dashboard_screen.dart))
* **Purpose**: The main console containing the tab views, search inputs, and dynamic action buttons.
* **Key Components & Modules (Tabbed Sections)**:
  * **1. Dashboard (Tab 1)**: Renders the *Parade Tree* (collapsible hierarchy accordions with dynamic counts).
    * *Roster List*: Lists soldiers active inside the selected node. Double-tapping an individual launches their *Military ID Card Modal*.
    * *Speed Dial FAB*: Provides buttons to add, rename, or delete category/subcategory nodes.
    * *Movement History*: Inline chronological logs tracking a soldier's movement details.
  * **2. Analysis (Tab 2)**: Metrics screen sorting data by Rank, Trade, and Battery.
    * *Filter Header*: Mode-aware dropdown enabling coordinators to filter data sheets.
    * *Smart Grid*: Cards indicating active strength counts, officers, JCOs, soldiers breakdown, and fighting/non-fighting ratios.
    * *Drill-down Chips*: Expandable chips. Tapping a category chip (e.g. `Present: 4`) opens the personnel lists, pre-configuring filters.
  * **3. Nominal Roll (Tab 3)**: Master index listing all personnel.
    * *Registry Search*: Keyword search (Army Number, Name, Class) combined with division filters.
    * *Action FAB*: Enables adding new soldier profiles or toggling edit/delete mode highlights.
  * **4. Filter (Tab 4)**: Advanced query filtering panel.
    * *Search Modifiers*: Allows filtering active rosters by category, subcategory list selections, travel start/end dates, and destination names.
  * **5. Settings Center (Tab 5)**: Global controls layout.
    * *Cards Roster*: Features toggles for theme configurations, instructions dialogs, admin promoters, attributes configs, and logout buttons.

### D. Edit Personnel Assignment Screen ([edit_assignment_screen.dart](file:///c:/flutter/Projects/Frukh/parade/lib/views/edit_assignment_screen.dart))
* **Purpose**: Coordinates scheduling and movement reassignments for a selected soldier.
* **Key Components & Modules**:
  * *Soldier Card*: Summarizes rank, name, and army number metadata.
  * *Dynamic Selector Dropdowns*: Three nested selector boxes populating categories, subcategories, and sub-subcategories on the fly.
  * *Calendar Calendars*: Custom range selectors displaying start and end date calendars.
  * *Infinite Toggle*: Shortcut text button (`Set Infinite`) that resets expiration limits to indefinite status.
  * *Destination Field*: Capture box for specific travel destinations.

### E. Battery Detail Screen ([battery_detail_screen.dart](file:///c:/flutter/Projects/Frukh/parade/lib/views/battery_detail_screen.dart))
* **Purpose**: Displays detailed personnel distribution and metrics for a specific battery unit (HQ Bty, P Bty, Q Bty, R Bty).
* **Key Components & Modules**:
  * *Colored Header*: Features theme backdrops reflecting battery-specific colors.
  * *Strength Metrics*: Renders breakdowns of active personnel counts, fighting statistics, and rank categories.
  * *Search Roster*: Renders cards matching search inputs and filter chip options (Officers, JCOs, Soldiers).

### F. Group Detail Screen ([group_detail_screen.dart](file:///c:/flutter/Projects/Frukh/parade/lib/views/group_detail_screen.dart))
* **Purpose**: Renders deployment schedules and personnel rosters for custom transient groups.
* **Key Components & Modules**:
  * *Status Indicators*: Chips indicating details for leader profiles, locations, and timeline targets.
  * *Spread Metrics*: Bar summarizing total counts and active subcategory distribution.
  * *Personnel Cards*: Scrollable lists displaying soldier details, remarks, and serial numbers.

### G. Manage Attributes Screen ([manage_attributes_screen.dart](file:///c:/flutter/Projects/Frukh/parade/lib/views/manage_attributes_screen.dart))
* **Purpose**: Allows modifying database lists such as Trades, Ranks, and Batteries.
* **Key Components & Modules**:
  * *Tabbed Attributes*: Segmented views representing Trades, Ranks, and Batteries lists.
  * *Registry Table*: Lists active tags with indicators to edit or remove database records.
  * *CRUD Form Modals*: Input text boxes collecting names, subcategory relations, and parent categories.

### H. View All Groups Screen ([view_all_groups_screen.dart](file:///c:/flutter/Projects/Frukh/parade/lib/views/view_all_groups_screen.dart))
* **Purpose**: Provides lists of active dynamic custom groups and accounts directories.
* **Key Components & Modules**:
  * *Category Filters*: Choices (Travel, Training, Sports, Working Party) adjusting group list outputs.
  * *Group Cards*: Summary widgets mapping group details and assigned personnel limits.
  * *Access Slot Directories*: Lists of active credentials grouped by permission level.

### I. Personnel Profile Screen ([personnel_profile_screen.dart](file:///c:/flutter/Projects/Frukh/parade/lib/views/personnel_profile_screen.dart))
* **Purpose**: Displays metadata details and movement history records for a single soldier.
* **Key Components & Modules**:
  * *Profile Header*: Circular avatar showing `profile_avatar.jpg` and personal labels.
  * *Timeline Tracker*: Movement log records showing previous locations, transfer dates, and durations.

---

## 4. Authentication & Role-Based Access Control (RBAC)

Authentication operates via three standard security roles validated by `MockDataManager`.

```
┌─────────────────┐     Logs In     ┌───────────────────────────┐
│     User Type   ├────────────────►│      Assigned Access      │
│─────────────────│                 │───────────────────────────│
│ [superadmin]    │ ──────────────► │ Full Admin CRUD + Settings│
│ [admin / Roster]│ ──────────────► │ Read + Edit Locations     │
│ [user]          │ ──────────────► │ View-Only (4 Tabs)        │
└─────────────────┘                 └───────────────────────────┘
```

### Roles and Permissions Mapping

1. **`superadmin`** (System Administrator)
   * Default Username: `superadmin`
   * Default Password: `123456`
   * Access: Full access to all 5 navigation tabs. Can add/rename/delete categories. Can run CRUD operations on personnel records. Accesses settings to promote custom admins, configure Trades/Ranks/Batteries, and view active login credentials directories.
2. **`admin`** (Data Entry Administrator)
   * Default Username: `admin`
   * Default Password: `123456`
   * Access: Access to all 5 navigation tabs. Can assign new locations and schedulers for personnel. Restriced from speed dial FABs (no authority to create or remove categories/personnel) and cannot view the custom admins directory list.
3. **`user`** (View-Only User)
   * Default Username: `user`
   * Default Password: `123456`
   * Access: Restricted to **4 tabs** (Dashboard, Analysis, Nominal Roll, Settings) — the "Edit" tab is completely hidden. Read-only access to roster counts and stats cards. Settings are restricted to theme selections and instruction manuals.

---

## 5. Key Functional Modules

### A. Collapsible Parade State Tree (Tab 1)
Renders a nested multi-layered hierarchy representing active military divisions (e.g. *Present*, *Leave*, *Courses*, *Att*). Headcounts bubble up dynamically:
* Main categories collapse and expand to show nested Subcategories (e.g., *Leave* -> *Casual Leave*) and Sub-Subcategories (e.g., *Casual Leave* -> *In Station*).
* Long-pressing a personnel record launches the **Military ID Card Modal**.
* Interactive FAB speed-dial menus allow `superadmin` accounts to customize layout structures in real-time.

### B. Analytical Breakdown & Drill-Down (Tab 2)
Provides visual matrices for regimental strength:
* Segmented control splits analysis into **Rank**, **Trade**, and **Battery** modes.
* An interactive context-aware dropdown filters the active dataset.
* Summarizes fighting ratio calculations.
* Tapping a chip launches `CategoryPersonnelListScreen` pre-configured to lock down secondary filters based on the selected metrics, preventing invalid search combinations.

### C. Master Nominal Roll (Tab 3)
A search registry showing all soldiers:
* Combines full-text search fields (Army Number, Name, Class) with category filters (Battery, Division type).
* Floating Speed Dial menu enables adding new recruits, toggling edit toggles on cards, or triggering quick-removal warnings.
* Tapping a soldier opens their profile. A timeline tracks movements, with days-based filters (e.g., last 7, 30, 90, or 365 days).

### D. Dynamic Scheduler (Tab 4)
Allows schedulers to modify active allocations:
* Roster search fields retrieve soldiers instantly.
* Dropdown fields populate dynamically, pulling active layouts from storage.
* Dates allow setting explicit duty ranges. The calendar provides a `Set Infinite` reset utility to switch the schedule back to indefinite duration.

### E. Attributes & Custom Groups Manager (Tab 5)
* **Custom Dynamic Groups**: Allows assembling soldiers under temporary classifications (e.g., "Cricket Tournament", "Working Party A") and managing leaders, destinations, and duration limits.
* **Database Metadata Configuration**: Provides tools to append, adjust, or retire Trades, Ranks, and Batteries.
* **Credentials Registry**: Superadmin overview showing system accounts sorted by permission level.

### F. Reports Export System (PDF/CSV)
Generates platform-optimized reports accessible on desktop, web, and mobile devices:
* **Parade State PDF Report**: Creates custom multi-page documents listing unit strength summaries (officers, JCOs, soldiers count and percentages), main category breakdowns, and tables mapping each active individual. Renders using built-in system fonts for cross-platform compatibility.
* **Movement History Excel (CSV)**: Serializes nominal records, active status categories, and movement history tracks into a CSV formatted file.

---

## 6. Storage & Persistence Engine

State variables are serialized to and from JSON format, matching keys in the local system database configuration:

```
┌────────────────────────┐      Serializes      ┌─────────────────────────┐
│     In-Memory State    ├─────────────────────►│  SharedPreferences Key  │
│────────────────────────│                      │─────────────────────────│
│ categoryHierarchy      │ ──[JSON String]────► │ "categoryHierarchy"     │
│ nominalRollList        │ ──[JSON List]──────► │ "nominalRollList"       │
│ _statuses (Map)        │ ──[JSON Map]───────► │ "personnelStatuses"     │
│ _history (Map)         │ ──[JSON Map]───────► │ "personnelHistory"      │
│ _customGroups (Map)    │ ──[JSON Map]───────► │ "customGroups"          │
│ customAdminAccounts    │ ──[JSON Map]───────► │ "customAdminAccounts"   │
│ isDarkMode (bool)      │ ───────────────────► │ "isDarkMode"            │
└────────────────────────┘                      └─────────────────────────┘
```

---

## 7. How to Run the Project

### Prerequisites
* Flutter SDK (version `^3.12.2`)
* Dart SDK

### Installation
1. Clone the repository and navigate to the project directory:
   ```bash
   cd parade
   ```
2. Retrieve dependencies:
   ```bash
   flutter pub get
   ```
3. Run the application:
   ```bash
   flutter run
   ```
   *(For desktop clients, ensure Windows, macOS, or Linux compilation environments are active. For web deployment, run `flutter run -d chrome`)*.
