# Taiao Hihiko - Project Documentation

## Overview

Taiao Hihiko is a Flutter-based educational app for learning te reo Māori (the Māori language). The app features interactive puzzle games that teach syllables and words through visual, auditory, and kinesthetic learning modes. It also includes Bluetooth connectivity to control an mBot robot for hands-on learning activities.

## Architecture

The entire application is contained in a single file: [lib/main.dart](lib/main.dart). The app follows a modular structure with distinct sections for different functionality:

### Core Components

1. **Data Models** (lines 18-97)
2. **App Entry & Navigation** (lines 102-453)
3. **Bluetooth Robot Controller** (lines 455-748)
4. **Game Pages** (lines 750-2839)

---

## 1. Data Models

### Puzzle Model (lines 18-54)

```dart
class Puzzle {
  final String imagePath;
  final List<String> answer;
}
```

**Purpose:** Represents image-based puzzles where users match syllables to pictures.

**PuzzleRepository** provides:
- `loadFolder(String folder)`: Scans assets for PNG images and extracts syllable answers from filenames (e.g., `a-po-ro.png` → `['a', 'po', 'ro']`)
- `syllablePool(List<Puzzle>)`: Extracts all unique syllables for creating distractors
- `buildBank()`: Creates a shuffled bank of correct syllables + random distractors

### AudioPuzzle Model (lines 58-97)

```dart
class AudioPuzzle {
  final String soundPath;
  final List<String> answer;
}
```

**Purpose:** Represents audio-based puzzles where users listen to sounds and match syllables.

**AudioPuzzleRepository** provides similar functionality to PuzzleRepository but for `.ogg` audio files.

---

## 2. App Navigation Structure

### Main App (lines 102-120)

```dart
void main() {
  runApp(const MyApp());
}
```

Entry point that launches the MaterialApp with "Taiao Hihiko" theme.

### HomePage (lines 124-211)

**Navigation Hub** featuring three levels (Kaupae):
- **Kaupae 1** (Blue, enabled) - Basic syllable learning
- **Kaupae 2** (Purple, disabled) - Future content
- **Kaupae 3** (Green, disabled) - Future content

**Responsive Design:**
- Uses `LayoutBuilder` to adapt button sizes
- Switches between centered and scrollable layouts based on screen height
- Maximum content width clamped to 720px

### KaupaePage (lines 274-407)

**4-Tile Activity Selector** for each Kaupae level:
- **Robot Tile** (Red) → `RobotPage` - Bluetooth robot control
- **Words Tile** (Purple) → `Kaupae1RandomWordsPage` - Image-syllable matching
- **Ear Tile** (Yellow) → `Kaupae1RandomListenPage` - Audio-syllable matching
- **Move Tile** (Green) → `Kaupae1MovePage` - Listen and choose from images

**Layout Features:**
- 2x2 grid of colorful tiles
- Responsive sizing with scroll fallback
- Header banner with Kaupae title

---

## 3. Bluetooth Robot Controller (mBot)

### MbotBleController (lines 496-748)

**Purpose:** Manages Bluetooth Low Energy (BLE) connection to Makeblock mBot robot for physical movement activities.

#### Key Features:

**Connection Management:**
- Auto-scanning for mBot devices (searches for "Makeblock_LE")
- Automatic reconnection with exponential backoff
- Heartbeat monitoring every 3 seconds
- Handles BLE throttling and platform exceptions

**Motor Control:**
- `setWheels(leftFrac, rightFrac)`: Sets differential drive (-1.0 to 1.0)
- `stopMotors()`: Emergency stop
- `rawBoth(speed)`: Raw speed control for calibration

**Calibration System:**
- First-time connection triggers calibration dialog
- User runs test spin and selects observed behavior (forward/backward/spin left/spin right)
- Settings saved to SharedPreferences via `MotorMapping`
- Handles motor port mapping (0x09, 0x0A) and directional signs

**BLE Protocol:**
- Uses custom UUIDs for RX/TX characteristics
- Encodes signed speeds into byte arrays
- 10ms delay between motor commands

### RobotPage (lines 752-1137)

**Joystick Control Interface** for mBot:

**Features:**
- Custom-painted circular joystick (lines 1068-1137)
- Real-time wheel mixing (arcade drive)
- Deadzone handling (5%)
- Visual feedback with vector line and knob
- Connection status indicator
- Calibration button in app bar

**Math Implementation:**
- Constrains knob position to circular boundary
- Converts XY position to left/right wheel speeds
- Inner-wheel reduction for turning
- Throttles redundant BLE commands

---

## 4. Game Pages

### Words Puzzle Game

#### Kaupae1RandomWordsPage (lines 1142-1235)

**Wrapper component** that:
- Loads all puzzles from `assets/kaupae1/tiles/`
- Implements bag randomization (shuffle without immediate repeats)
- Dynamically calculates bank size (answer syllables + 2-4 distractors, max 6 tiles)
- Passes puzzle data to `WordsPuzzlePage`

#### WordsPuzzlePage (lines 1337-1758)

**Interactive drag-and-drop puzzle interface:**

**Game Mechanics:**
- Drag syllable tiles from bank to answer slots
- Swap tiles between slots
- Drag from slots back to bank
- Check button validates answer
- Auto-advance on correct answer
- Shake/reset on incorrect answer

**Visual Feedback:**
- Status icons (help/check/cancel)
- Colored status text (amber/green/red)
- Glow effect during drag
- Haptic feedback on drag start

**Responsive Layout:**
- Scales tiles to fit screen
- Maintains aspect ratios
- Scrollable if needed
- Bottom navigation bar with undo + submit buttons

### Listen Puzzle Game

#### Kaupae1RandomListenPage (lines 1239-1332)

Similar wrapper to WordsPuzzlePage but loads `.ogg` files from `assets/kaupae1/sound/`.

#### ListenPuzzlePage (lines 1838-2282)

**Audio-based puzzle interface:**

**Key Differences from Words:**
- Replaces image with audio playback button
- Uses `AudioPlayer` from `audioplayers` package
- Shows animated equalizer icon during playback
- Same drag-and-drop mechanics for syllables
- Scale animation on button tap

**Audio Handling:**
- Strips "assets/" prefix for `AssetSource`
- Stops previous playback before starting new
- Updates `_playing` state on completion
- Error handling with snackbar messages

### Move/Listen-Choose Game

#### Kaupae1MovePage (lines 2377-2755)

**Multiple-choice image selection game:**

**Game Flow:**
1. Load matching tile/sound pairs from assets
2. Play random word audio
3. Display 4 image options (1 correct + 3 distractors)
4. User selects an image
5. Submit validates choice
6. Auto-advance on correct, reset on incorrect

**Asset Loading:**
- Parses AssetManifest.json
- Finds intersection of .png and .ogg files with matching basenames
- Validates pairs before starting game

**UI Layout:**
- Top status bar
- Large centered play button
- 2x2 grid of selectable image tiles
- Selection indicated by amber border + elevation
- Bottom undo/submit buttons

---

## 5. UI Components

### Custom Buttons

**_BigNavButton** (lines 213-270)
- Large rounded buttons for home page
- Disabled state with grayed-out appearance
- Elevation and Material ripple effects

**_IconButtonSquare** (lines 2287-2309)
- 72x72px square buttons
- Used for undo actions
- Navy background with elevation

**_OtiButton** (lines 2311-2341)
- White submit button with green checkmark
- Text label (typically "oti" - finished)
- Horizontal padding for text + icon

### Drag and Drop Components

**_SlotTarget** (lines 1767-1819)
- Brown wooden-style slot containers
- Accepts both String (from bank) and _FromSlot (from other slots)
- Hover state changes background color

**_BankDragTarget** (lines 1821-1834)
- Invisible drop zone covering bank area
- Returns tiles from slots to bank

### Visual Chips

**_chip** widget (lines 1737-1757, 2261-2281)
- White rounded containers for syllables
- Supports dim state (semi-transparent)
- Optional glow shadow during drag
- Responsive font sizing

### Joystick Painter

**_JoystickPainter** (lines 1068-1137)
- Custom painter for robot control interface
- Draws concentric circles, crosshairs, movement vector
- Knob with shadow and accent ring
- Updates on position change

---

## 6. Asset Structure

### Expected Asset Organization:

```
assets/
├── kaupae1/
│   ├── tiles/
│   │   ├── a-po-ro.png
│   │   ├── ka-ka.png
│   │   └── ... (more syllable images)
│   └── sound/
│       ├── a-po-ro.ogg
│       ├── ka-ka.ogg
│       ├── listeningButton.png
│       └── ... (more audio files)
└── tiles/
    ├── robot.png
    ├── words.png
    ├── ear.png
    └── move.png
```

**Naming Convention:**
- Syllables separated by hyphens: `syllable1-syllable2-syllable3.png/ogg`
- Parser splits on `-` to extract answer array

---

## 7. State Management

The app uses **StatefulWidget** with local state management:

- `ValueNotifier` for BLE connection status
- `setState()` for UI updates
- `AnimationController` for button animations
- `StreamSubscription` for BLE notifications

**No external state management libraries** (no Provider, Riverpod, Bloc, etc.)

---

## 8. Dependencies

Key packages used:

- **flutter_blue_plus**: BLE communication with mBot
- **shared_preferences**: Persisting robot calibration
- **permission_handler**: Bluetooth permissions
- **audioplayers**: Playing .ogg sound files

---

## 9. Key Design Patterns

### Bag Randomization
```dart
List<int> _bag = [];
void _refillBag() {
  _bag = List<int>.generate(_all!.length, (i) => i)..shuffle(rnd);
  // Prevent immediate repeat of last puzzle
  if (_lastIndex != null && _bag.first == _lastIndex) {
    // Swap with random position
  }
}
```

Used in all game modes to ensure varied puzzle order without immediate repeats.

### Dynamic Bank Sizing
```dart
int _dynamicBankSize(Puzzle p) {
  final uniqueDistractors = _pool.difference(p.answer.toSet()).length;
  const maxTiles = 6;
  final minTiles = (p.answer.length + 2).clamp(0, maxTiles);
  return (p.answer.length + min(uniqueDistractors, maxTiles - p.answer.length))
      .clamp(minTiles, maxTiles);
}
```

Adapts difficulty based on available distractors.

### Responsive Layout
All pages use `LayoutBuilder` to compute sizes:
```dart
LayoutBuilder(
  builder: (context, constraints) {
    final h = constraints.maxHeight;
    final w = constraints.maxWidth;
    // Calculate responsive sizes...
  }
)
```

### Asset Manifest Scanning
```dart
final manifest = await rootBundle.loadString('AssetManifest.json');
final Map<String, dynamic> files = json.decode(manifest);
final paths = files.keys.where((p) => p.startsWith('folder/')).toList();
```

Runtime discovery of assets without hardcoding file lists.

---

## 10. Color Scheme

**Navy Theme:**
- Background: `#1F4A78` (bgNavy)
- Card: `#244C7F` (cardNavy)

**Kaupae Colors:**
- Kaupae 1: `#3A78C6` (blue)
- Kaupae 2: `#8A02FF` (purple)
- Kaupae 3: `#6BA24D` (green)

**Tile Colors:**
- Robot: `#E53935` (red)
- Words: `#7E57C2` (purple)
- Listen: `#FFEB3B` (yellow)
- Move: `#00E676` (green)

**Status Colors:**
- Neutral: Amber
- Correct: Green accent
- Incorrect: Red accent

---

## 11. Future Extensions

Placeholder stub pages exist for:
- `WordsPage2`, `WordsPage3`
- `ListenPage2`, `ListenPage3`
- `MovePage2`, `MovePage3`

These render a simple `_SimplePage` scaffold and can be implemented for Kaupae 2 & 3.

---

## 12. Platform Considerations

**Android:**
- Requires Bluetooth permissions (handled by permission_handler)
- BLE scanning throttling handled with backoff delays
- Uses `AndroidScanMode.lowLatency`

**iOS:**
- Uses platform name fallback for BLE advertising
- Handles different BLE behavior

**Windows (current platform):**
- May require additional BLE setup
- Robot features may not work without BLE hardware

---

## 13. Error Handling

**BLE Errors:**
- Scan throttling → 12s cooldown
- Connection failures → 5s retry with exponential backoff
- Heartbeat failures → auto-disconnect and reconnect

**Asset Errors:**
- Missing images → broken image icon
- Audio playback failure → Māori language snackbar message
- No valid puzzles → error message display

**User Input:**
- Submit without selection → warning snackbar
- All drag operations cancel safely on error

---

## File Statistics

- **Total Lines:** 2,839
- **Single File Architecture:** All code in `lib/main.dart`
- **Classes:** 30+ widgets and models
- **Lines of Code by Section:**
  - Models: ~80 lines
  - Navigation: ~350 lines
  - BLE Controller: ~300 lines
  - Robot UI: ~400 lines
  - Words Game: ~500 lines
  - Listen Game: ~450 lines
  - Move Game: ~380 lines
  - UI Components: ~200 lines

---

## Getting Started

1. Ensure Flutter SDK is installed
2. Run `flutter pub get` to install dependencies
3. Add image/audio assets following naming convention
4. For robot features, pair mBot via Bluetooth
5. Run with `flutter run`

The app will auto-detect available puzzles from assets and generate game content dynamically.
