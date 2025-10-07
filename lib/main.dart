import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // listEquals
import 'dart:async';
import 'dart:convert';
import 'dart:math'; // Random, min/max/sqrt
import 'dart:io' show Platform;
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';


// BLE deps
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

/* ================= PUZZLE MODEL + LOADER ================= */

class Puzzle {
  final String imagePath;
  final List<String> answer; // e.g. ['a','po','ro']
  const Puzzle({required this.imagePath, required this.answer});
}

class PuzzleRepository {
  static Future<List<Puzzle>> loadFolder(String folder) async {
    final manifest = await rootBundle.loadString('AssetManifest.json');
    final Map<String, dynamic> files = json.decode(manifest);
    final paths = files.keys
        .where((p) => p.startsWith('$folder/') && p.endsWith('.png'))
        .toList()
      ..sort();

    return paths.map((p) {
      final base = p.split('/').last.replaceAll('.png', '');
      final parts = base.split('-'); // your naming convention
      return Puzzle(imagePath: p, answer: parts);
    }).toList();
  }

  static Set<String> syllablePool(List<Puzzle> puzzles) {
    return puzzles.fold<Set<String>>(<String>{}, (set, p) => set..addAll(p.answer));
  }

  static List<String> buildBank(Random rnd, Puzzle p, Set<String> pool, {int size = 6}) {
    final bank = <String>[...p.answer];
    final choices = pool.difference(p.answer.toSet()).toList();
    while (bank.length < size && choices.isNotEmpty) {
      final pick = choices.removeAt(rnd.nextInt(choices.length));
      bank.add(pick);
    }
    bank.shuffle(rnd);
    return bank;
  }
}

/* ================= AUDIO PUZZLE MODEL + LOADER ================= */

class AudioPuzzle {
  final String soundPath;          // e.g. assets/kaupae1/sound/a-po-ro.ogg, .mp4, or .m4a
  final List<String> answer;       // e.g. ['a','po','ro']
  const AudioPuzzle({required this.soundPath, required this.answer});
}

class AudioPuzzleRepository {
  /// Loads all audio files (.ogg, .mp4, .m4a) in [folder] from AssetManifest and creates puzzles by splitting filename on '-'.
  static Future<List<AudioPuzzle>> loadFolder(String folder) async {
    final manifest = await rootBundle.loadString('AssetManifest.json');
    final Map<String, dynamic> files = json.decode(manifest);
    final paths = files.keys
        .where((p) => p.startsWith('$folder/') && _isAudioFile(p))
        .toList()
      ..sort();

    return paths.map((p) {
      final base = p.split('/').last.replaceAll(RegExp(r'\.(ogg|mp4|m4a)$'), '');
      final parts = base.split('-');
      return AudioPuzzle(soundPath: p, answer: parts);
    }).toList();
  }

  /// Check if a file path has a supported audio extension
  static bool _isAudioFile(String path) {
    final lowerPath = path.toLowerCase();
    return lowerPath.endsWith('.ogg') ||
           lowerPath.endsWith('.mp4') ||
           lowerPath.endsWith('.m4a');
  }

  /// Build a distractor pool from all unique syllables across the audio puzzles.
  static Set<String> syllablePool(List<AudioPuzzle> puzzles) {
    return puzzles.fold<Set<String>>(<String>{}, (set, p) => set..addAll(p.answer));
  }

  /// Create a mixed bank (correct syllables + distractors), shuffled.
  static List<String> buildBank(Random rnd, AudioPuzzle p, Set<String> pool, {int size = 6}) {
    final bank = <String>[...p.answer];
    final choices = pool.difference(p.answer.toSet()).toList();
    while (bank.length < size && choices.isNotEmpty) {
      final pick = choices.removeAt(rnd.nextInt(choices.length));
      bank.add(pick);
    }
    bank.shuffle(rnd);
    return bank;
  }
}


/* ========================== APP ========================== */

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Taiao Hihiko',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

/* ========================= HOME ========================= */

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  static const bgNavy = Color(0xFF1F4A78);
  static const kaupae1Color = Color(0xFF3A78C6);
  static const kaupae2Color = Color(0xFF8A02FF);
  static const kaupae3Color = Color(0xFF6BA24D);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgNavy,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) {
            final h = c.maxHeight;
            final w = c.maxWidth;

            final buttonHeight = (h * 0.14).clamp(64.0, 100.0);
            final gap = (h * 0.03).clamp(12.0, 28.0);
            final fontSize = (buttonHeight * 0.44).clamp(24.0, 42.0);
            final maxContentWidth = w.clamp(0.0, 720.0);

            final content = ConstrainedBox(
              constraints: BoxConstraints.tightFor(width: maxContentWidth),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _BigNavButton(
                    label: 'Kaupae 1',
                    color: kaupae1Color,
                    height: buttonHeight,
                    fontSize: fontSize,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => KaupaePage(
                          title: 'Kaupae 1',
                          headerColor: kaupae1Color,
                          onTapTiles: [
                            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RobotPage())),
                            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const Kaupae1RandomWordsPage())),
                            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const Kaupae1RandomListenPage())),
                            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const Kaupae1MovePage())),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: gap),
                  _BigNavButton(
                    label: 'Kaupae 2',
                    color: kaupae2Color,
                    height: buttonHeight,
                    fontSize: fontSize,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => KaupaePage(
                          title: 'Kaupae 2',
                          headerColor: kaupae2Color,
                          onTapTiles: [
                            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RobotPage())),
                            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const Kaupae2RandomWordsPage())),
                            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const Kaupae2RandomListenPage())),
                            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const Kaupae2MovePage())),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: gap),
                  _BigNavButton(
                    label: 'Kaupae 3',
                    color: kaupae3Color,
                    height: buttonHeight,
                    fontSize: fontSize,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => KaupaePage(
                          title: 'Kaupae 3',
                          headerColor: kaupae3Color,
                          onTapTiles: [
                            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RobotPage())),
                            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const Kaupae3RandomWordsPage())),
                            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const Kaupae3RandomListenPage())),
                            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const Kaupae3MovePage())),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );

            return (3 * buttonHeight + 2 * gap + 48) > h
                ? SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                    child: Align(alignment: Alignment.topCenter, child: content),
                  )
                : Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                      child: content,
                    ),
                  );
          },
        ),
      ),
    );
  }
}

class _BigNavButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  final double height;
  final double fontSize;

  const _BigNavButton({
    super.key,
    required this.label,
    required this.color,
    required this.onTap,
    required this.height,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: true,
      child: Material(
        elevation: 6,
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(28),
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: onTap,
          child: Ink(
            height: height,
            width: double.infinity,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: fontSize,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/* ====================== KAUPAE PAGE ===================== */

class KaupaePage extends StatelessWidget {
  final String title;
  final Color headerColor;
  final List<VoidCallback> onTapTiles;

  const KaupaePage({
    super.key,
    required this.title,
    required this.headerColor,
    required this.onTapTiles,
  }) : assert(onTapTiles.length == 4, 'Provide 4 tile callbacks');

  static const bgNavy = Color(0xFF1F4A78);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgNavy,
      appBar: AppBar(
        backgroundColor: bgNavy,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) {
            final h = c.maxHeight;
            final w = c.maxWidth;

            const sidePad = 16.0;
            const topPad = 12.0;
            const betweenHeaderAndGrid = 16.0;
            const rowGap = 16.0;
            const colGap = 16.0;
            const bottomPad = 12.0;

            final headerHeight = (h * 0.18).clamp(72.0, 120.0);
            final headerFont = (headerHeight * 0.45).clamp(28.0, 56.0);

            final availForGrid = h - topPad - headerHeight - betweenHeaderAndGrid - rowGap - bottomPad;

            var tileHeight = (availForGrid * 0.98) / 2;
            tileHeight = tileHeight.clamp(72.0, 220.0);

            final maxContentWidth = w.clamp(0.0, 900.0);
            final tileWidth = ((maxContentWidth - sidePad * 2 - colGap) / 2).clamp(120.0, 420.0);

            final minNeeded = topPad + headerHeight + betweenHeaderAndGrid + 2 * 72.0 + rowGap + bottomPad;
            final needsScroll = h < minNeeded;

            final content = ConstrainedBox(
              constraints: BoxConstraints.tightFor(width: maxContentWidth),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Material(
                    elevation: 6,
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      height: headerHeight,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: headerColor,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: headerFont,
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: betweenHeaderAndGrid),
                  Row(
                    children: [
                      _Tile(
                        w: tileWidth,
                        h: tileHeight,
                        color: const Color(0xFFE53935),
                        image: 'assets/tiles/robot.png',
                        onTap: onTapTiles[0],
                      ),
                      const SizedBox(width: colGap),
                      _Tile(
                        w: tileWidth,
                        h: tileHeight,
                        color: const Color(0xFF7E57C2),
                        image: 'assets/tiles/words.png',
                        onTap: onTapTiles[1],
                      ),
                    ],
                  ),
                  const SizedBox(height: rowGap),
                  Row(
                    children: [
                      _Tile(
                        w: tileWidth,
                        h: tileHeight,
                        color: const Color(0xFFFFEB3B),
                        image: 'assets/tiles/ear.png',
                        onTap: onTapTiles[2],
                      ),
                      const SizedBox(width: colGap),
                      _Tile(
                        w: tileWidth,
                        h: tileHeight,
                        color: const Color(0xFF00E676),
                        image: 'assets/tiles/move.png',
                        onTap: onTapTiles[3],
                      ),
                    ],
                  ),
                  const SizedBox(height: bottomPad),
                ],
              ),
            );

            final inner = Padding(
              padding: const EdgeInsets.fromLTRB(sidePad, topPad, sidePad, 0),
              child: Align(alignment: Alignment.topCenter, child: content),
            );

            return needsScroll ? SingleChildScrollView(child: inner) : Center(child: inner);
          },
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final double w, h;
  final Color color;
  final String image;
  final VoidCallback onTap;

  const _Tile({
    super.key,
    required this.w,
    required this.h,
    required this.color,
    required this.image,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const radius = 24.0;
    return SizedBox(
      width: w,
      height: h,
      child: Material(
        color: Colors.transparent,
        elevation: 6,
        borderRadius: BorderRadius.circular(radius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          child: Ink(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(radius),
            ),
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(h * 0.16),
                child: Image.asset(image, fit: BoxFit.contain),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/* ============ MBOT BLE (Flutter) ============ */

const _mbotName = "Makeblock_LE";
const List<List<String>> _uuidPairs = [
  ["0000ffe3-0000-1000-8000-00805f9b34fb", "0000ffe2-0000-1000-8000-00805f9b34fb"],
  ["0000ffe2-0000-1000-8000-00805f9b34fb", "0000ffe3-0000-1000-8000-00805f9b34fb"],
];

const _maxSpeed = 200;
const _heartbeatS = 3;
const _calibKey = "mbot_calibration_json";

class MotorMapping {
  int leftPort;
  int rightPort;
  int leftSign; // +1 forward, -1 backward
  int rightSign;

  MotorMapping({
    this.leftPort = 0x09,
    this.rightPort = 0x0A,
    this.leftSign = -1,
    this.rightSign = 1,
  });

  Map<String, dynamic> toJson() => {
        "leftPort": leftPort,
        "rightPort": rightPort,
        "leftSign": leftSign,
        "rightSign": rightSign,
      };

  // Robust parser (keeps your version)
  static MotorMapping fromJson(Map<String, dynamic> j) => MotorMapping(
        leftPort: j["leftPort"] ?? 0x09,
        rightPort: j["rightPort"] ?? 0x0A,
        leftSign: (j["leftSign"] ?? -1) is int ? (j["leftSign"] ?? -1) : int.tryParse("${j["leftSign"]}") ?? -1,
        rightSign: (j["rightSign"] ?? 1) is int ? (j["rightSign"] ?? 1) : int.tryParse("${j["rightSign"]}") ?? 1,
      );
}

class MbotBleController {
  final ValueNotifier<bool> connected = ValueNotifier<bool>(false);
  final ValueNotifier<String> status =
      ValueNotifier<String>("BLE: searching for mBot...");

  BluetoothDevice? _device;
  BluetoothCharacteristic? _rx;
  BluetoothCharacteristic? _tx;
  StreamSubscription<List<int>>? _notifSub;
  Timer? _hbTimer;
  bool _disposed = false;

  MotorMapping mapping = MotorMapping();

  Future<void> start() async {
    _disposed = false;
    await _loadCalibration();
    _connectLoop(); // fire and forget
  }

  Future<void> shutdown() async {
    _disposed = true;
    _cancelHeartbeat();
    await _notifSub?.cancel();
    if (_device != null) {
      try { await _device!.disconnect(); } catch (_) {}
    }
    connected.value = false;
  }

  // ---- single-session scan with cooldown/backoff (prevents “scanning too frequently”) ----
  Future<BluetoothDevice?> _scanForMbot({Duration timeout = const Duration(seconds: 7)}) async {
    BluetoothDevice? found;
    StreamSubscription<List<ScanResult>>? sub;
    bool started = false;

    try {
      await FlutterBluePlus.startScan(
        timeout: timeout,
        androidScanMode: AndroidScanMode.lowLatency,
      );
      started = true;

      sub = FlutterBluePlus.scanResults.listen((results) {
        for (final r in results) {
          final adv = r.advertisementData;
          final advName = adv.advName;
          final name = (advName.isNotEmpty ? advName : r.device.platformName).toLowerCase();
          final matchesName = name.contains('makeblock') ||
                              name.contains('mbot') ||
                              name.contains(_mbotName.toLowerCase());
          final services = adv.serviceUuids.map((g) => g.toString().toLowerCase()).toList();
          final matchesService = services.any((s) => s.contains('ffe0') || s.contains('ffe2') || s.contains('ffe3'));

          if (matchesName || matchesService) {
            found ??= r.device; // keep the first match
          }
        }
      });

      // Let the scan actually run for the full timeout
      await Future.delayed(timeout);
    } finally {
      await sub?.cancel();
      if (started) { try { await FlutterBluePlus.stopScan(); } catch (_) {} }
    }
    return found;
  }

  Future<void> _connectLoop() async {
    int backoff = 0; // grows a bit on failures, resets on success

    while (!_disposed) {
      try {
        status.value = "BLE: scanning…";
        final found = await _scanForMbot(timeout: const Duration(seconds: 7));

        if (found == null) {
          status.value = "BLE: mBot not found; retrying…";
          await Future.delayed(Duration(seconds: 5 + backoff)); // cooldown to avoid throttle
          backoff = (backoff + 3).clamp(0, 15);
          continue;
        }

        _device = found;
        status.value = "BLE: connecting…";
        await _device!.connect(timeout: const Duration(seconds: 8));
        status.value = "BLE: discovering services…";
        final services = await _device!.discoverServices();

        _rx = null;
        _tx = null;
        for (final pair in _uuidPairs) {
          final rx = _findChar(services, pair[0]);
          final tx = _findChar(services, pair[1]);
          if (rx != null && tx != null) {
            try {
              await rx.write([0xFF, 0x55, 2, 0, 2], withoutResponse: true);
              _rx = rx;
              _tx = tx;
              break;
            } catch (_) { /* try next pair */ }
          }
        }
        if (_rx == null || _tx == null) {
          status.value = "BLE: RX/TX not found; retrying…";
          try { await _device!.disconnect(); } catch (_) {}
          await Future.delayed(Duration(seconds: 5 + backoff));
          backoff = (backoff + 3).clamp(0, 15);
          continue;
        }

        try { await _tx!.setNotifyValue(true); } catch (_) {}
        await _notifSub?.cancel();
        _notifSub = _tx!.lastValueStream.listen((_) {});

        connected.value = true;
        status.value = "BLE: connected";
        _startHeartbeat();
        backoff = 0; // success

        // wait until disconnect
        await for (final s in _device!.connectionState) {
          if (s == BluetoothConnectionState.disconnected) break;
        }
      } on PlatformException catch (e) {
        final msg = e.message ?? "";
        if (msg.contains("too frequently") ||
            msg.contains("already_scanning") ||
            msg.contains("application registration failed")) {
          status.value = "BLE: scan throttled, cooling down…";
          await Future.delayed(const Duration(seconds: 12));
        } else {
          status.value = "BLE: error; retrying…";
          await Future.delayed(const Duration(seconds: 5));
        }
      } catch (_) {
        status.value = "BLE: error; retrying…";
        await Future.delayed(const Duration(seconds: 5));
      } finally {
        _cancelHeartbeat();
        await _notifSub?.cancel();
        _notifSub = null;
        if (_device != null) { try { await _device!.disconnect(); } catch (_) {} }
        connected.value = false;
      }
    }
  }

  BluetoothCharacteristic? _findChar(List<BluetoothService> services, String uuid) {
    final target = Guid.fromString(uuid.toLowerCase());
    for (final s in services) {
      for (final c in s.characteristics) {
        if (c.uuid == target) return c;
      }
    }
    return null;
  }

  void _startHeartbeat() {
    _cancelHeartbeat();
    _hbTimer = Timer.periodic(const Duration(seconds: _heartbeatS), (_) async {
      final ok = await _heartbeatCheck();
      if (!ok) { try { await _device?.disconnect(); } catch (_) {} }
    });
  }

  void _cancelHeartbeat() {
    _hbTimer?.cancel();
    _hbTimer = null;
  }

  Future<bool> _heartbeatCheck() async {
    try {
      if (_rx == null) return false;
      await _rx!.write([0xFF, 0x55, 2, 0, 2], withoutResponse: true);
      return true;
    } catch (_) {
      return false;
    }
  }

  // ---------- Calibration ----------
  Future<void> applyCalibrationFromOutcome(String outcome) async {
    switch (outcome) {
      case "forward":    mapping.leftSign = 1;  mapping.rightSign = 1;  break;
      case "backward":   mapping.leftSign = -1; mapping.rightSign = -1; break;
      case "spin_right": mapping.leftSign = 1;  mapping.rightSign = -1; break;
      case "spin_left":  mapping.leftSign = -1; mapping.rightSign = 1;  break;
      default: return;
    }
    await _saveCalibration();
  }

  Future<void> _saveCalibration() async {
    final sp = await SharedPreferences.getInstance();
    sp.setString(_calibKey, mapping.toJson().toString());
  }

  Future<void> _loadCalibration() async {
    final sp = await SharedPreferences.getInstance();
    final s = sp.getString(_calibKey);
    if (s != null) {
      try {
        final m = <String, dynamic>{};
        for (final kv in s.substring(1, s.length - 1).split(",")) {
          final parts = kv.split(":");
          if (parts.length >= 2) {
            final k = parts[0].trim();
            final v = int.tryParse(parts.sublist(1).join(":").trim()) ?? 0;
            m[k] = v;
          }
        }
        mapping = MotorMapping.fromJson(m);
      } catch (_) {}
    }
  }

  // ---------- Motor IO ----------
  List<int> _encodeSpeed(int v) {
    v = v.clamp(-255, 255);
    if (v >= 0) return [v & 0xFF, 0x00];
    final mag = (-v) & 0xFF;
    return [(256 - mag) & 0xFF, 0xFF];
  }

  Future<void> _rawSetMotor(int portByte, int signedSpeed) async {
    if (_rx == null) return;
    final enc = _encodeSpeed(signedSpeed);
    final bytes = [0xFF, 0x55, 6, 0, 2, 0x0A, portByte, enc[0], enc[1]];
    try { await _rx!.write(bytes, withoutResponse: true); } catch (_) {}
  }

  Future<void> rawBoth(int signedSpeed) async {
    await _rawSetMotor(mapping.leftPort, signedSpeed);
    await Future.delayed(const Duration(milliseconds: 10));
    await _rawSetMotor(mapping.rightPort, signedSpeed);
  }

  Future<void> stopAll() async => rawBoth(0);

  Future<void> setWheels(double leftFrac, double rightFrac, {int maxSpeed = _maxSpeed}) async {
    leftFrac  = leftFrac.clamp(-1.0, 1.0);
    rightFrac = rightFrac.clamp(-1.0, 1.0);
    final leftRaw  = (leftFrac * maxSpeed).toInt()  * mapping.leftSign;
    final rightRaw = (rightFrac * maxSpeed).toInt() * mapping.rightSign;
    await _rawSetMotor(mapping.leftPort, leftRaw);
    await Future.delayed(const Duration(milliseconds: 10));
    await _rawSetMotor(mapping.rightPort, rightRaw);
  }

  Future<void> stopMotors() => setWheels(0, 0);
}

/* ==================== Robot Page (styled) ==================== */

class RobotPage extends StatefulWidget {
  const RobotPage({super.key});
  @override
  State<RobotPage> createState() => _RobotPageState();
}

class _RobotPageState extends State<RobotPage> {
  final MbotBleController ctrl = MbotBleController();

  // knob position in pixels within current canvas
  double _bx = 0, _by = 0;
  double? _lastCanvasSize;

  // last wheel mix we sent (to throttle)
  double _lastL = 9, _lastR = 9; // out-of-range → force first send
  bool _wasConnected = false;

  static const double _dead = 0.05;

  @override
  void initState() {
    super.initState();
    ctrl.start();
    ctrl.connected.addListener(() {
      final c = ctrl.connected.value;
      if (c && !_wasConnected) {
        _wasConnected = true;
        _openCalibrationDialog();
      } else if (!c) {
        _wasConnected = false;
      }
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    ctrl.shutdown();
    super.dispose();
  }

  // ---------- math helpers that use the live canvas geometry ----------
  Offset _clampToCircle(double cx, double cy, double R, Offset p) {
    final dx = p.dx - cx, dy = p.dy - cy;
    final d = sqrt(dx * dx + dy * dy);
    if (d <= R) return p;
    final s = R / d;
    return Offset(cx + dx * s, cy + dy * s);
  }

  Offset _mixToWheels(double cx, double cy, double R, double xPx, double yPx) {
    final dx = (xPx - cx) / R;
    final dy = (yPx - cy) / R;
    var x = dx.clamp(-1.0, 1.0);
    var y = (-dy).clamp(-1.0, 1.0); // up is +y
    final m = min(1.0, sqrt(x * x + y * y));

    // inner-wheel reduction
    final leftScale = 1.0 - max(0.0, -x);
    final rightScale = 1.0 - max(0.0, x);

    final forward = (y >= -_dead);
    double lGui, rGui;
    if (forward) {
      lGui = -m * leftScale; // GUI: left forward is negative
      rGui = m * rightScale;
    } else {
      lGui = m * leftScale;
      rGui = -m * rightScale;
    }
    return Offset(lGui, rGui);
  }

  Future<void> _maybeSend(double lGui, double rGui) async {
    if ((lGui - _lastL).abs() < 0.05 && (rGui - _lastR).abs() < 0.05) return;
    _lastL = lGui;
    _lastR = rGui;

    // GUI → semantic (+ = forward)
    final lSem = -lGui;
    final rSem = rGui;
    await ctrl.setWheels(lSem, rSem);
  }

  void _onPress(Offset p, double cx, double cy, double R) {
    final clamped = _clampToCircle(cx, cy, R, p);
    setState(() {
      _bx = clamped.dx;
      _by = clamped.dy;
    });
    final lr = _mixToWheels(cx, cy, R, clamped.dx, clamped.dy);
    _maybeSend(lr.dx, lr.dy);
  }

  void _onDrag(Offset p, double cx, double cy, double R) => _onPress(p, cx, cy, R);

  void _onRelease(double cx, double cy) {
    setState(() {
      _bx = cx;
      _by = cy;
    });
    _lastL = 9;
    _lastR = 9; // force next send
    ctrl.stopMotors();
  }

  // ---------- Calibration dialog (unchanged) ----------
  void _openCalibrationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        bool spinning = false;
        String text = "Place the mBot safely.\n"
            "Tap Start to spin BOTH wheels at +MAX for 3 seconds,\n"
            "then choose what it did.";

        Future<void> startSpin(StateSetter setD) async {
          setD(() {
            spinning = true;
            text = "Spinning both wheels…";
          });
          await ctrl.rawBoth(_maxSpeed);
          await Future.delayed(const Duration(seconds: 3));
          await ctrl.stopAll();
          setD(() {
            spinning = false;
            text = "What did it do?";
          });
        }

        Future<void> choose(String outcome) async {
          await ctrl.applyCalibrationFromOutcome(outcome);
          if (mounted) Navigator.of(ctx).pop();
        }

        return StatefulBuilder(
          builder: (ctx, setD) => AlertDialog(
            title: const Text("mBot Calibration"),
            content: Text(text),
            actions: [
              if (!spinning)
                TextButton(
                    onPressed: () => startSpin(setD),
                    child: const Text("Start calibration")),
              if (text == "What did it do?") ...[
                TextButton(onPressed: () => choose("forward"), child: const Text("Forward")),
                TextButton(onPressed: () => choose("backward"), child: const Text("Backward")),
                TextButton(onPressed: () => choose("spin_right"), child: const Text("Spin Right")),
                TextButton(onPressed: () => choose("spin_left"), child: const Text("Spin Left")),
                TextButton(onPressed: () => startSpin(setD), child: const Text("Redo test")),
              ],
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const bgNavy = Color(0xFF1F4A78);
    const accent = Color(0xFF3A78C6); // matches Kaupae 1
    const cardNavy = Color(0xFF244C7F);

    return Scaffold(
      backgroundColor: bgNavy,
      appBar: AppBar(
        backgroundColor: bgNavy,
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text("Robot"),
        actions: [
          IconButton(
            tooltip: "Redo calibration",
            onPressed: ctrl.connected.value ? _openCalibrationDialog : null,
            icon: const Icon(Icons.tune),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) {
            // responsive square size, then compute geometry
            final size = min(c.maxWidth, c.maxHeight) * 0.58;
            final canvasSize = size.clamp(260.0, 380.0);
            final cx = canvasSize / 2;
            final cy = canvasSize / 2;
            final R = canvasSize * 0.375;

            // when size changes (rotation / window), recenter knob
            if (_lastCanvasSize == null || (_lastCanvasSize! - canvasSize).abs() > 1) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                setState(() {
                  _lastCanvasSize = canvasSize;
                  _bx = cx;
                  _by = cy;
                  _lastL = 9;
                  _lastR = 9;
                });
              });
            }

            return Column(
              children: [
                const SizedBox(height: 8),
                // connection chip
                ValueListenableBuilder(
                  valueListenable: ctrl.status,
                  builder: (_, s, __) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Align(
                      alignment: Alignment.center,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: ctrl.connected.value ? Colors.green.withOpacity(.15) : Colors.black12,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: ctrl.connected.value ? Colors.greenAccent : Colors.white24,
                            width: 1.2,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                ctrl.connected.value ? Icons.bluetooth_connected : Icons.bluetooth_searching,
                                color: ctrl.connected.value ? Colors.greenAccent : Colors.white70,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                s,
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const Spacer(),

                // centered joystick card
                Center(
                  child: Material(
                    color: Colors.transparent,
                    elevation: 8,
                    borderRadius: BorderRadius.circular(28),
                    child: Container(
                      width: canvasSize + 40,
                      height: canvasSize + 40,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: const [cardNavy, bgNavy],
                        ),
                        boxShadow: const [
                          BoxShadow(color: Colors.black45, blurRadius: 16, offset: Offset(0, 8)),
                        ],
                        border: Border.all(color: Colors.white12, width: 1),
                      ),
                      child: Center(
                        child: GestureDetector(
                          onPanStart: (d) => _onPress(d.localPosition, cx, cy, R),
                          onPanUpdate: (d) => _onDrag(d.localPosition, cx, cy, R),
                          onPanEnd: (_) => _onRelease(cx, cy),
                          child: CustomPaint(
                            painter: _JoystickPainter(
                              cx: cx,
                              cy: cy,
                              r: R,
                              bx: _bx,
                              by: _by,
                              accent: accent,
                            ),
                            size: Size(canvasSize, canvasSize),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const Spacer(),

                // bottom STOP button centered
                Padding(
                  padding: const EdgeInsets.only(bottom: 18.0),
                  child: FilledButton.tonal(
                    style: FilledButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.red.shade400,
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                      textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => ctrl.stopMotors(),
                    child: const Text("STOP"),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _JoystickPainter extends CustomPainter {
  final double cx, cy, r, bx, by;
  final Color accent;
  const _JoystickPainter({
    required this.cx,
    required this.cy,
    required this.r,
    required this.bx,
    required this.by,
    required this.accent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // background plate
    final bg = Paint()..color = const Color(0xFFE7EEF7).withOpacity(0.06);
    final plateR = r + 20;
    canvas.drawCircle(Offset(cx, cy), plateR, bg);

    // outer glow ring
    final ringOuter = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..color = accent.withOpacity(0.18);
    canvas.drawCircle(Offset(cx, cy), r + 6, ringOuter);

    // main ring
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 6
      ..color = accent.withOpacity(0.85);
    canvas.drawCircle(Offset(cx, cy), r, ring);

    // crosshair (subtle)
    final cross = Paint()
      ..strokeWidth = 2
      ..color = Colors.white.withOpacity(0.22);
    canvas.drawLine(Offset(cx - r, cy), Offset(cx + r, cy), cross);
    canvas.drawLine(Offset(cx, cy - r), Offset(cx, cy + r), cross);

    // movement vector
    final vec = Paint()
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..color = accent.withOpacity(0.9);
    canvas.drawLine(Offset(cx, cy), Offset(bx, by), vec);

    // center dot
    final centerDot = Paint()..color = Colors.white.withOpacity(0.8);
    canvas.drawCircle(Offset(cx, cy), 5, centerDot);

    // knob with shadow
    final shadow = Paint()..color = Colors.black.withOpacity(0.25);
    canvas.drawCircle(Offset(bx + 2, by + 4), 16, shadow);

    final knob = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(bx, by), 16, knob);

    final knobRing = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = accent.withOpacity(0.9);
    canvas.drawCircle(Offset(bx, by), 16, knobRing);
  }

  @override
  bool shouldRepaint(covariant _JoystickPainter old) =>
      old.bx != bx || old.by != by || old.cx != cx || old.cy != cy || old.r != r || old.accent != accent;
}


/* ===================== GAME WRAPPER ====================== */

class Kaupae1RandomWordsPage extends StatefulWidget {
  const Kaupae1RandomWordsPage({super.key});
  @override
  State<Kaupae1RandomWordsPage> createState() => _Kaupae1RandomWordsPageState();
}

class _Kaupae1RandomWordsPageState extends State<Kaupae1RandomWordsPage> {
  static const folder = 'assets/kaupae1/tiles';
  final rnd = Random();

  List<Puzzle>? _all;
  late Set<String> _pool;

  Puzzle? _current;
  List<String>? _bank;

  List<int> _bag = [];
  int? _lastIndex;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final puzzles = await PuzzleRepository.loadFolder(folder);
    if (puzzles.isEmpty) {
      setState(() {
        _all = [];
        _pool = {};
      });
      return;
    }
    _all = puzzles;
    _pool = PuzzleRepository.syllablePool(puzzles);
    _makeNext();
  }

  void _refillBag() {
    if (_all == null || _all!.isEmpty) return;
    _bag = List<int>.generate(_all!.length, (i) => i)..shuffle(rnd);
    if (_lastIndex != null && _bag.length > 1 && _bag.first == _lastIndex) {
      final swapWith = 1 + rnd.nextInt(_bag.length - 1);
      final tmp = _bag[0];
      _bag[0] = _bag[swapWith];
      _bag[swapWith] = tmp;
    }
  }

  int _dynamicBankSize(Puzzle p) {
    final uniqueDistractors = _pool.difference(p.answer.toSet()).length;
    const bankCols = 3, maxRows = 2, maxTiles = bankCols * maxRows; // 6
    final minTiles = (p.answer.length + 2 <= maxTiles) ? p.answer.length + 2 : maxTiles;
    final desired = p.answer.length +
        (uniqueDistractors < (maxTiles - p.answer.length)
            ? uniqueDistractors
            : (maxTiles - p.answer.length));
    return desired.clamp(minTiles, maxTiles);
  }

  void _makeNext() {
    if (_all == null || _all!.isEmpty) return;
    if (_bag.isEmpty) _refillBag();

    final nextIndex = _bag.removeAt(0);
    final p = _all![nextIndex];

    final size = _dynamicBankSize(p);
    final bank = PuzzleRepository.buildBank(rnd, p, _pool, size: size);

    setState(() {
      _current = p;
      _bank = bank;
      _lastIndex = nextIndex;
    });
  }

  @override
  Widget build(BuildContext context) {
    const bgNavy = Color(0xFF1F4A78);

    if (_all == null) {
      return const Scaffold(
        backgroundColor: bgNavy,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (_all!.isEmpty) {
      return Scaffold(
        backgroundColor: bgNavy,
        appBar: AppBar(
          backgroundColor: bgNavy,
          elevation: 0,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Text(
              'Kāore anō kia tāpirihia ngā mahi kupu.',
              style: TextStyle(color: Colors.white, fontSize: 20),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    if (_current == null || _bank == null) {
      return const Scaffold(
        backgroundColor: bgNavy,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return WordsPuzzlePage(
      key: ValueKey(_current!.imagePath),
      imagePath: _current!.imagePath,
      answer: _current!.answer,
      bankStart: _bank!,
      onNext: _makeNext,
    );
  }
}

/* ========== KAUPAE 1 — RANDOM LISTEN PUZZLE WRAPPER ========== */

class Kaupae1RandomListenPage extends StatefulWidget {
  const Kaupae1RandomListenPage({super.key});
  @override
  State<Kaupae1RandomListenPage> createState() => _Kaupae1RandomListenPageState();
}

class _Kaupae1RandomListenPageState extends State<Kaupae1RandomListenPage> {
  static const folder = 'assets/kaupae1/sound';
  final rnd = Random();

  List<AudioPuzzle>? _all;
  late Set<String> _pool;

  AudioPuzzle? _current;
  List<String>? _bank;

  List<int> _bag = [];
  int? _lastIndex;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final puzzles = await AudioPuzzleRepository.loadFolder(folder);
    if (puzzles.isEmpty) {
      setState(() {
        _all = [];
        _pool = {};
      });
      return;
    }
    _all = puzzles;
    _pool = AudioPuzzleRepository.syllablePool(puzzles);
    _makeNext();
  }

  void _refillBag() {
    if (_all == null || _all!.isEmpty) return;
    _bag = List<int>.generate(_all!.length, (i) => i)..shuffle(rnd);
    if (_lastIndex != null && _bag.length > 1 && _bag.first == _lastIndex) {
      final swapWith = 1 + rnd.nextInt(_bag.length - 1);
      final tmp = _bag[0]; _bag[0] = _bag[swapWith]; _bag[swapWith] = tmp;
    }
  }

  int _dynamicBankSize(AudioPuzzle p) {
    final uniqueDistractors = _pool.difference(p.answer.toSet()).length;
    const bankCols = 3;
    const maxRows = 2;
    const maxTiles = bankCols * maxRows; // 6
    final minTiles = p.answer.length + 2 <= maxTiles ? p.answer.length + 2 : maxTiles;
    final desired = p.answer.length +
        (uniqueDistractors < (maxTiles - p.answer.length)
            ? uniqueDistractors
            : (maxTiles - p.answer.length));
    return desired.clamp(minTiles, maxTiles);
  }

  void _makeNext() {
    if (_all == null || _all!.isEmpty) return;
    if (_bag.isEmpty) _refillBag();

    final nextIndex = _bag.removeAt(0);
    final p = _all![nextIndex];

    final size = _dynamicBankSize(p);
    final bank = AudioPuzzleRepository.buildBank(rnd, p, _pool, size: size);

    setState(() {
      _current = p;
      _bank = bank;
      _lastIndex = nextIndex;
    });
  }

  @override
  Widget build(BuildContext context) {
    const bgNavy = Color(0xFF1F4A78);

    if (_all == null) {
      return const Scaffold(
        backgroundColor: bgNavy,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (_all!.isEmpty) {
      return Scaffold(
        backgroundColor: bgNavy,
        appBar: AppBar(
          backgroundColor: bgNavy,
          elevation: 0,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Text(
              'Kāore anō kia tāpirihia ngā mahi whakarongo.',
              style: TextStyle(color: Colors.white, fontSize: 20),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    if (_current == null || _bank == null) {
      return const Scaffold(
        backgroundColor: bgNavy,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return ListenPuzzlePage(
      key: ValueKey(_current!.soundPath),
      soundPath: _current!.soundPath,
      answer: _current!.answer,
      bankStart: _bank!,
      onNext: _makeNext,
    );
  }
}

/* ========== KAUPAE 2 — RANDOM WORDS PUZZLE WRAPPER ========== */

class Kaupae2RandomWordsPage extends StatefulWidget {
  const Kaupae2RandomWordsPage({super.key});
  @override
  State<Kaupae2RandomWordsPage> createState() => _Kaupae2RandomWordsPageState();
}

class _Kaupae2RandomWordsPageState extends State<Kaupae2RandomWordsPage> {
  static const folder = 'assets/kaupae2/tiles';
  final rnd = Random();

  List<Puzzle>? _all;
  late Set<String> _pool;

  Puzzle? _current;
  List<String>? _bank;

  List<int> _bag = [];
  int? _lastIndex;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final puzzles = await PuzzleRepository.loadFolder(folder);
    if (puzzles.isEmpty) {
      setState(() {
        _all = [];
        _pool = {};
      });
      return;
    }
    _all = puzzles;
    _pool = PuzzleRepository.syllablePool(puzzles);
    _makeNext();
  }

  void _refillBag() {
    if (_all == null || _all!.isEmpty) return;
    _bag = List<int>.generate(_all!.length, (i) => i)..shuffle(rnd);
    if (_lastIndex != null && _bag.length > 1 && _bag.first == _lastIndex) {
      final swapWith = 1 + rnd.nextInt(_bag.length - 1);
      final tmp = _bag[0];
      _bag[0] = _bag[swapWith];
      _bag[swapWith] = tmp;
    }
  }

  int _dynamicBankSize(Puzzle p) {
    final uniqueDistractors = _pool.difference(p.answer.toSet()).length;
    const bankCols = 3, maxRows = 2, maxTiles = bankCols * maxRows; // 6
    final minTiles = (p.answer.length + 2 <= maxTiles) ? p.answer.length + 2 : maxTiles;
    final desired = p.answer.length +
        (uniqueDistractors < (maxTiles - p.answer.length)
            ? uniqueDistractors
            : (maxTiles - p.answer.length));
    return desired.clamp(minTiles, maxTiles);
  }

  void _makeNext() {
    if (_all == null || _all!.isEmpty) return;
    if (_bag.isEmpty) _refillBag();

    final nextIndex = _bag.removeAt(0);
    final p = _all![nextIndex];

    final size = _dynamicBankSize(p);
    final bank = PuzzleRepository.buildBank(rnd, p, _pool, size: size);

    setState(() {
      _current = p;
      _bank = bank;
      _lastIndex = nextIndex;
    });
  }

  @override
  Widget build(BuildContext context) {
    const bgNavy = Color(0xFF1F4A78);

    if (_all == null) {
      return const Scaffold(
        backgroundColor: bgNavy,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (_all!.isEmpty) {
      return Scaffold(
        backgroundColor: bgNavy,
        appBar: AppBar(
          backgroundColor: bgNavy,
          elevation: 0,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Text(
              'Kāore anō kia tāpirihia ngā mahi kupu.',
              style: TextStyle(color: Colors.white, fontSize: 20),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    if (_current == null || _bank == null) {
      return const Scaffold(
        backgroundColor: bgNavy,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return WordsPuzzlePage(
      key: ValueKey(_current!.imagePath),
      imagePath: _current!.imagePath,
      answer: _current!.answer,
      bankStart: _bank!,
      onNext: _makeNext,
    );
  }
}

/* ========== KAUPAE 2 — RANDOM LISTEN PUZZLE WRAPPER ========== */

class Kaupae2RandomListenPage extends StatefulWidget {
  const Kaupae2RandomListenPage({super.key});
  @override
  State<Kaupae2RandomListenPage> createState() => _Kaupae2RandomListenPageState();
}

class _Kaupae2RandomListenPageState extends State<Kaupae2RandomListenPage> {
  static const folder = 'assets/kaupae2/sound';
  final rnd = Random();

  List<AudioPuzzle>? _all;
  late Set<String> _pool;

  AudioPuzzle? _current;
  List<String>? _bank;

  List<int> _bag = [];
  int? _lastIndex;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final puzzles = await AudioPuzzleRepository.loadFolder(folder);
    if (puzzles.isEmpty) {
      setState(() {
        _all = [];
        _pool = {};
      });
      return;
    }
    _all = puzzles;
    _pool = AudioPuzzleRepository.syllablePool(puzzles);
    _makeNext();
  }

  void _refillBag() {
    if (_all == null || _all!.isEmpty) return;
    _bag = List<int>.generate(_all!.length, (i) => i)..shuffle(rnd);
    if (_lastIndex != null && _bag.length > 1 && _bag.first == _lastIndex) {
      final swapWith = 1 + rnd.nextInt(_bag.length - 1);
      final tmp = _bag[0]; _bag[0] = _bag[swapWith]; _bag[swapWith] = tmp;
    }
  }

  int _dynamicBankSize(AudioPuzzle p) {
    final uniqueDistractors = _pool.difference(p.answer.toSet()).length;
    const bankCols = 3;
    const maxRows = 2;
    const maxTiles = bankCols * maxRows; // 6
    final minTiles = p.answer.length + 2 <= maxTiles ? p.answer.length + 2 : maxTiles;
    final desired = p.answer.length +
        (uniqueDistractors < (maxTiles - p.answer.length)
            ? uniqueDistractors
            : (maxTiles - p.answer.length));
    return desired.clamp(minTiles, maxTiles);
  }

  void _makeNext() {
    if (_all == null || _all!.isEmpty) return;
    if (_bag.isEmpty) _refillBag();

    final nextIndex = _bag.removeAt(0);
    final p = _all![nextIndex];

    final size = _dynamicBankSize(p);
    final bank = AudioPuzzleRepository.buildBank(rnd, p, _pool, size: size);

    setState(() {
      _current = p;
      _bank = bank;
      _lastIndex = nextIndex;
    });
  }

  @override
  Widget build(BuildContext context) {
    const bgNavy = Color(0xFF1F4A78);

    if (_all == null) {
      return const Scaffold(
        backgroundColor: bgNavy,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (_all!.isEmpty) {
      return Scaffold(
        backgroundColor: bgNavy,
        appBar: AppBar(
          backgroundColor: bgNavy,
          elevation: 0,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Text(
              'Kāore anō kia tāpirihia ngā mahi whakarongo.',
              style: TextStyle(color: Colors.white, fontSize: 20),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    if (_current == null || _bank == null) {
      return const Scaffold(
        backgroundColor: bgNavy,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return ListenPuzzlePage(
      key: ValueKey(_current!.soundPath),
      soundPath: _current!.soundPath,
      answer: _current!.answer,
      bankStart: _bank!,
      onNext: _makeNext,
    );
  }
}

/* ========== KAUPAE 2 — MOVE PAGE WRAPPER ========== */

class Kaupae2MovePage extends StatefulWidget {
  const Kaupae2MovePage({super.key});
  @override
  State<Kaupae2MovePage> createState() => _Kaupae2MovePageState();
}

class _Kaupae2MovePageState extends State<Kaupae2MovePage> with SingleTickerProviderStateMixin {
  static const bgNavy = Color(0xFF1F4A78);

  final String _tilesFolder = 'assets/kaupae2/tiles';
  final String _soundsFolder = 'assets/kaupae2/sound';

  final _player = AudioPlayer();
  bool _playing = false;
  late final AnimationController _tapScale =
      AnimationController(vsync: this, lowerBound: .95, upperBound: 1.0, duration: const Duration(milliseconds: 120))
        ..value = 1.0;

  Map<String, String> _tilePathByName = {};
  Map<String, String> _soundPathByName = {};
  List<String> _validNames = [];

  String? _targetName;
  String? _targetSoundPath;
  List<String> _optionImagePaths = [];

  int? _selectedIndex;
  bool? _isCorrect;

  final List<int> _bag = [];
  int? _lastIndex;

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _player.onPlayerComplete.listen((_) => setState(() => _playing = false));
    _loadAssets();
  }

  @override
  void dispose() {
    _tapScale.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _loadAssets() async {
    try {
      final manifestStr = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> files = json.decode(manifestStr);

      final tilePngs = files.keys
          .where((p) => p.startsWith('$_tilesFolder/') && p.toLowerCase().endsWith('.png'))
          .toList();

      final soundOggs = files.keys
          .where((p) => p.startsWith('$_soundsFolder/') && AudioPuzzleRepository._isAudioFile(p))
          .toList();

      String baseFrom(String path) {
        final file = path.split('/').last;
        return file.replaceAll(RegExp(r'\.(png|ogg|mp4|m4a)$', caseSensitive: false), '');
      }

      _tilePathByName = { for (final p in tilePngs) baseFrom(p): p };
      _soundPathByName = { for (final p in soundOggs) baseFrom(p): p };

      _validNames = _tilePathByName.keys
          .toSet()
          .intersection(_soundPathByName.keys.toSet())
          .toList()
        ..sort();

      if (_validNames.isNotEmpty) {
        _makeNext();
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _refillBag() {
    _bag
      ..clear()
      ..addAll(List<int>.generate(_validNames.length, (i) => i)..shuffle(Random()));
    if (_lastIndex != null && _bag.length > 1 && _bag.first == _lastIndex) {
      final swapWith = 1 + Random().nextInt(_bag.length - 1);
      final t = _bag[0]; _bag[0] = _bag[swapWith]; _bag[swapWith] = t;
    }
  }

  void _makeNext() {
    if (_validNames.isEmpty) return;
    if (_bag.isEmpty) _refillBag();

    final idx = _bag.removeAt(0);
    _lastIndex = idx;

    final name = _validNames[idx];
    final correctImg = _tilePathByName[name]!;
    final correctSnd = _soundPathByName[name]!;

    final others = _tilePathByName.keys.where((n) => n != name).toList()..shuffle(Random());
    final distractors = others.take(3).map((n) => _tilePathByName[n]!).toList();
    final options = <String>[correctImg, ...distractors]..shuffle(Random());

    setState(() {
      _targetName = name;
      _targetSoundPath = correctSnd;
      _optionImagePaths = options;
      _selectedIndex = null;
      _isCorrect = null;
      _playing = false;
    });
  }

  Future<void> _play() async {
    if (_targetSoundPath == null) return;
    try {
      setState(() => _playing = true);
      await _player.stop();
      final rel = _targetSoundPath!.startsWith('assets/') ? _targetSoundPath!.substring(7) : _targetSoundPath!;
      await _player.play(AssetSource(rel));
    } catch (_) {
      setState(() => _playing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kāore i taea te purei i te oro')),
        );
      }
    }
  }

  void _submit() {
    if (_selectedIndex == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kōwhiria tētahi pikitia')),
      );
      return;
    }
    final chosenPath = _optionImagePaths[_selectedIndex!];
    final chosenName = chosenPath.split('/').last.replaceAll('.png', '');
    final ok = (chosenName == _targetName);

    setState(() => _isCorrect = ok);

    if (ok) {
      Future.delayed(const Duration(milliseconds: 450), () {
        if (!mounted) return;
        _makeNext();
      });
    } else {
      Future.delayed(const Duration(milliseconds: 600), () {
        if (!mounted) return;
        setState(() {
          _selectedIndex = null;
          _isCorrect = null;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: bgNavy,
        body: SafeArea(child: Center(child: CircularProgressIndicator(color: Colors.white))),
      );
    }

    if (_validNames.isEmpty) {
      return const Scaffold(
        backgroundColor: bgNavy,
        body: SafeArea(
          child: Center(
            child: Text(
              'Kāore he oro me ngā pikitia ōrite i kitea.',
              style: TextStyle(color: Colors.white, fontSize: 18),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    if (_optionImagePaths.length < 4 || _targetSoundPath == null) {
      return const Scaffold(
        backgroundColor: bgNavy,
        body: SafeArea(child: Center(child: CircularProgressIndicator(color: Colors.white))),
      );
    }

    final statusText = switch (_isCorrect) {
      null => 'Whakarongo — kōwhiria te pikitia tika',
      true => 'Tika!',
      false => 'Ngana anō',
    };
    final statusIcon = switch (_isCorrect) {
      null => Icons.help,
      true => Icons.check_circle,
      false => Icons.cancel,
    };
    final statusColor = switch (_isCorrect) {
      null => Colors.amber,
      true => Colors.greenAccent,
      false => Colors.redAccent,
    };

    return Scaffold(
      backgroundColor: bgNavy,
      appBar: AppBar(
        backgroundColor: bgNavy,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                _IconButtonSquare(
                  icon: Icons.undo_rounded,
                  onTap: () => setState(() { _selectedIndex = null; _isCorrect = null; }),
                ),
                const Spacer(),
                _OtiButton(label: 'oti', onTap: _submit),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) {
            final h = c.maxHeight;
            final w = c.maxWidth;

            const sidePad = 16.0;
            const g = 12.0;
            const colGap = 12.0;

            final maxBodyW = (w - sidePad * 2).clamp(0.0, 900.0);
            final titleSize = (h * 0.043).clamp(20.0, 30.0);
            final statusH = titleSize + 10.0;

            final gridTileW = ((maxBodyW - colGap) / 2).clamp(110.0, 260.0);
            final gridTileH = gridTileW;
            final gridHeight = gridTileH * 2 + g;

            final minButtonH = 110.0;
            final spaceForButton =
                h - statusH - g - gridHeight - g - (64.0 + 12.0) - MediaQuery.of(context).viewPadding.bottom - 24.0;
            final buttonH = spaceForButton.clamp(minButtonH, h * 0.4);

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: sidePad),
              child: Column(
                children: [
                  SizedBox(
                    height: statusH,
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              statusText,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: titleSize,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(statusIcon, color: statusColor, size: titleSize + 6),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: g),

                  SizedBox(
                    height: buttonH,
                    width: maxBodyW,
                    child: Center(
                      child: GestureDetector(
                        onTapDown: (_) => _tapScale.reverse(),
                        onTapCancel: () => _tapScale.forward(),
                        onTapUp: (_) => _tapScale.forward(),
                        onTap: _play,
                        child: ScaleTransition(
                          scale: _tapScale,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.asset(
                                  'assets/kaupae1/sound/listeningButton.png',
                                  height: buttonH,
                                  fit: BoxFit.contain,
                                ),
                              ),
                              if (_playing)
                                const Positioned(
                                  bottom: 10,
                                  child: Icon(Icons.graphic_eq, color: Colors.white, size: 40),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: g),

                  SizedBox(
                    width: maxBodyW,
                    height: gridHeight,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            _ChoiceTile(
                              path: _optionImagePaths[0],
                              selected: _selectedIndex == 0,
                              size: Size(gridTileW, gridTileH),
                              onTap: () => setState(() { _selectedIndex = 0; _isCorrect = null; }),
                            ),
                            SizedBox(width: colGap),
                            _ChoiceTile(
                              path: _optionImagePaths[1],
                              selected: _selectedIndex == 1,
                              size: Size(gridTileW, gridTileH),
                              onTap: () => setState(() { _selectedIndex = 1; _isCorrect = null; }),
                            ),
                          ],
                        ),
                        SizedBox(height: g),
                        Row(
                          children: [
                            _ChoiceTile(
                              path: _optionImagePaths[2],
                              selected: _selectedIndex == 2,
                              size: Size(gridTileW, gridTileH),
                              onTap: () => setState(() { _selectedIndex = 2; _isCorrect = null; }),
                            ),
                            SizedBox(width: colGap),
                            _ChoiceTile(
                              path: _optionImagePaths[3],
                              selected: _selectedIndex == 3,
                              size: Size(gridTileW, gridTileH),
                              onTap: () => setState(() { _selectedIndex = 3; _isCorrect = null; }),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/* ========== KAUPAE 3 — RANDOM WORDS PUZZLE WRAPPER ========== */

class Kaupae3RandomWordsPage extends StatefulWidget {
  const Kaupae3RandomWordsPage({super.key});
  @override
  State<Kaupae3RandomWordsPage> createState() => _Kaupae3RandomWordsPageState();
}

class _Kaupae3RandomWordsPageState extends State<Kaupae3RandomWordsPage> {
  static const folder = 'assets/kaupae3/tiles';
  final rnd = Random();

  List<Puzzle>? _all;
  late Set<String> _pool;

  Puzzle? _current;
  List<String>? _bank;

  List<int> _bag = [];
  int? _lastIndex;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final puzzles = await PuzzleRepository.loadFolder(folder);
    if (puzzles.isEmpty) {
      setState(() {
        _all = [];
        _pool = {};
      });
      return;
    }
    _all = puzzles;
    _pool = PuzzleRepository.syllablePool(puzzles);
    _makeNext();
  }

  void _refillBag() {
    if (_all == null || _all!.isEmpty) return;
    _bag = List<int>.generate(_all!.length, (i) => i)..shuffle(rnd);
    if (_lastIndex != null && _bag.length > 1 && _bag.first == _lastIndex) {
      final swapWith = 1 + rnd.nextInt(_bag.length - 1);
      final tmp = _bag[0];
      _bag[0] = _bag[swapWith];
      _bag[swapWith] = tmp;
    }
  }

  int _dynamicBankSize(Puzzle p) {
    final uniqueDistractors = _pool.difference(p.answer.toSet()).length;
    const bankCols = 3, maxRows = 2, maxTiles = bankCols * maxRows; // 6
    final minTiles = (p.answer.length + 2 <= maxTiles) ? p.answer.length + 2 : maxTiles;
    final desired = p.answer.length +
        (uniqueDistractors < (maxTiles - p.answer.length)
            ? uniqueDistractors
            : (maxTiles - p.answer.length));
    return desired.clamp(minTiles, maxTiles);
  }

  void _makeNext() {
    if (_all == null || _all!.isEmpty) return;
    if (_bag.isEmpty) _refillBag();

    final nextIndex = _bag.removeAt(0);
    final p = _all![nextIndex];

    final size = _dynamicBankSize(p);
    final bank = PuzzleRepository.buildBank(rnd, p, _pool, size: size);

    setState(() {
      _current = p;
      _bank = bank;
      _lastIndex = nextIndex;
    });
  }

  @override
  Widget build(BuildContext context) {
    const bgNavy = Color(0xFF1F4A78);

    if (_all == null) {
      return const Scaffold(
        backgroundColor: bgNavy,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (_all!.isEmpty) {
      return Scaffold(
        backgroundColor: bgNavy,
        appBar: AppBar(
          backgroundColor: bgNavy,
          elevation: 0,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Text(
              'Kāore anō kia tāpirihia ngā mahi kupu.',
              style: TextStyle(color: Colors.white, fontSize: 20),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    if (_current == null || _bank == null) {
      return const Scaffold(
        backgroundColor: bgNavy,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return WordsPuzzlePage(
      key: ValueKey(_current!.imagePath),
      imagePath: _current!.imagePath,
      answer: _current!.answer,
      bankStart: _bank!,
      onNext: _makeNext,
    );
  }
}

/* ========== KAUPAE 3 — RANDOM LISTEN PUZZLE WRAPPER ========== */

class Kaupae3RandomListenPage extends StatefulWidget {
  const Kaupae3RandomListenPage({super.key});
  @override
  State<Kaupae3RandomListenPage> createState() => _Kaupae3RandomListenPageState();
}

class _Kaupae3RandomListenPageState extends State<Kaupae3RandomListenPage> {
  static const folder = 'assets/kaupae3/sound';
  final rnd = Random();

  List<AudioPuzzle>? _all;
  late Set<String> _pool;

  AudioPuzzle? _current;
  List<String>? _bank;

  List<int> _bag = [];
  int? _lastIndex;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final puzzles = await AudioPuzzleRepository.loadFolder(folder);
    if (puzzles.isEmpty) {
      setState(() {
        _all = [];
        _pool = {};
      });
      return;
    }
    _all = puzzles;
    _pool = AudioPuzzleRepository.syllablePool(puzzles);
    _makeNext();
  }

  void _refillBag() {
    if (_all == null || _all!.isEmpty) return;
    _bag = List<int>.generate(_all!.length, (i) => i)..shuffle(rnd);
    if (_lastIndex != null && _bag.length > 1 && _bag.first == _lastIndex) {
      final swapWith = 1 + rnd.nextInt(_bag.length - 1);
      final tmp = _bag[0]; _bag[0] = _bag[swapWith]; _bag[swapWith] = tmp;
    }
  }

  int _dynamicBankSize(AudioPuzzle p) {
    final uniqueDistractors = _pool.difference(p.answer.toSet()).length;
    const bankCols = 3;
    const maxRows = 2;
    const maxTiles = bankCols * maxRows; // 6
    final minTiles = p.answer.length + 2 <= maxTiles ? p.answer.length + 2 : maxTiles;
    final desired = p.answer.length +
        (uniqueDistractors < (maxTiles - p.answer.length)
            ? uniqueDistractors
            : (maxTiles - p.answer.length));
    return desired.clamp(minTiles, maxTiles);
  }

  void _makeNext() {
    if (_all == null || _all!.isEmpty) return;
    if (_bag.isEmpty) _refillBag();

    final nextIndex = _bag.removeAt(0);
    final p = _all![nextIndex];

    final size = _dynamicBankSize(p);
    final bank = AudioPuzzleRepository.buildBank(rnd, p, _pool, size: size);

    setState(() {
      _current = p;
      _bank = bank;
      _lastIndex = nextIndex;
    });
  }

  @override
  Widget build(BuildContext context) {
    const bgNavy = Color(0xFF1F4A78);

    if (_all == null) {
      return const Scaffold(
        backgroundColor: bgNavy,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (_all!.isEmpty) {
      return Scaffold(
        backgroundColor: bgNavy,
        appBar: AppBar(
          backgroundColor: bgNavy,
          elevation: 0,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Text(
              'Kāore anō kia tāpirihia ngā mahi whakarongo.',
              style: TextStyle(color: Colors.white, fontSize: 20),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    if (_current == null || _bank == null) {
      return const Scaffold(
        backgroundColor: bgNavy,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return ListenPuzzlePage(
      key: ValueKey(_current!.soundPath),
      soundPath: _current!.soundPath,
      answer: _current!.answer,
      bankStart: _bank!,
      onNext: _makeNext,
    );
  }
}

/* ========== KAUPAE 3 — MOVE PAGE WRAPPER ========== */

class Kaupae3MovePage extends StatefulWidget {
  const Kaupae3MovePage({super.key});
  @override
  State<Kaupae3MovePage> createState() => _Kaupae3MovePageState();
}

class _Kaupae3MovePageState extends State<Kaupae3MovePage> with SingleTickerProviderStateMixin {
  static const bgNavy = Color(0xFF1F4A78);

  final String _tilesFolder = 'assets/kaupae3/tiles';
  final String _soundsFolder = 'assets/kaupae3/sound';

  final _player = AudioPlayer();
  bool _playing = false;
  late final AnimationController _tapScale =
      AnimationController(vsync: this, lowerBound: .95, upperBound: 1.0, duration: const Duration(milliseconds: 120))
        ..value = 1.0;

  Map<String, String> _tilePathByName = {};
  Map<String, String> _soundPathByName = {};
  List<String> _validNames = [];

  String? _targetName;
  String? _targetSoundPath;
  List<String> _optionImagePaths = [];

  int? _selectedIndex;
  bool? _isCorrect;

  final List<int> _bag = [];
  int? _lastIndex;

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _player.onPlayerComplete.listen((_) => setState(() => _playing = false));
    _loadAssets();
  }

  @override
  void dispose() {
    _tapScale.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _loadAssets() async {
    try {
      final manifestStr = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> files = json.decode(manifestStr);

      final tilePngs = files.keys
          .where((p) => p.startsWith('$_tilesFolder/') && p.toLowerCase().endsWith('.png'))
          .toList();

      final soundOggs = files.keys
          .where((p) => p.startsWith('$_soundsFolder/') && AudioPuzzleRepository._isAudioFile(p))
          .toList();

      String baseFrom(String path) {
        final file = path.split('/').last;
        return file.replaceAll(RegExp(r'\.(png|ogg|mp4|m4a)$', caseSensitive: false), '');
      }

      _tilePathByName = { for (final p in tilePngs) baseFrom(p): p };
      _soundPathByName = { for (final p in soundOggs) baseFrom(p): p };

      _validNames = _tilePathByName.keys
          .toSet()
          .intersection(_soundPathByName.keys.toSet())
          .toList()
        ..sort();

      if (_validNames.isNotEmpty) {
        _makeNext();
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _refillBag() {
    _bag
      ..clear()
      ..addAll(List<int>.generate(_validNames.length, (i) => i)..shuffle(Random()));
    if (_lastIndex != null && _bag.length > 1 && _bag.first == _lastIndex) {
      final swapWith = 1 + Random().nextInt(_bag.length - 1);
      final t = _bag[0]; _bag[0] = _bag[swapWith]; _bag[swapWith] = t;
    }
  }

  void _makeNext() {
    if (_validNames.isEmpty) return;
    if (_bag.isEmpty) _refillBag();

    final idx = _bag.removeAt(0);
    _lastIndex = idx;

    final name = _validNames[idx];
    final correctImg = _tilePathByName[name]!;
    final correctSnd = _soundPathByName[name]!;

    final others = _tilePathByName.keys.where((n) => n != name).toList()..shuffle(Random());
    final distractors = others.take(3).map((n) => _tilePathByName[n]!).toList();
    final options = <String>[correctImg, ...distractors]..shuffle(Random());

    setState(() {
      _targetName = name;
      _targetSoundPath = correctSnd;
      _optionImagePaths = options;
      _selectedIndex = null;
      _isCorrect = null;
      _playing = false;
    });
  }

  Future<void> _play() async {
    if (_targetSoundPath == null) return;
    try {
      setState(() => _playing = true);
      await _player.stop();
      final rel = _targetSoundPath!.startsWith('assets/') ? _targetSoundPath!.substring(7) : _targetSoundPath!;
      await _player.play(AssetSource(rel));
    } catch (_) {
      setState(() => _playing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kāore i taea te purei i te oro')),
        );
      }
    }
  }

  void _submit() {
    if (_selectedIndex == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kōwhiria tētahi pikitia')),
      );
      return;
    }
    final chosenPath = _optionImagePaths[_selectedIndex!];
    final chosenName = chosenPath.split('/').last.replaceAll('.png', '');
    final ok = (chosenName == _targetName);

    setState(() => _isCorrect = ok);

    if (ok) {
      Future.delayed(const Duration(milliseconds: 450), () {
        if (!mounted) return;
        _makeNext();
      });
    } else {
      Future.delayed(const Duration(milliseconds: 600), () {
        if (!mounted) return;
        setState(() {
          _selectedIndex = null;
          _isCorrect = null;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: bgNavy,
        body: SafeArea(child: Center(child: CircularProgressIndicator(color: Colors.white))),
      );
    }

    if (_validNames.isEmpty) {
      return const Scaffold(
        backgroundColor: bgNavy,
        body: SafeArea(
          child: Center(
            child: Text(
              'Kāore he oro me ngā pikitia ōrite i kitea.',
              style: TextStyle(color: Colors.white, fontSize: 18),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    if (_optionImagePaths.length < 4 || _targetSoundPath == null) {
      return const Scaffold(
        backgroundColor: bgNavy,
        body: SafeArea(child: Center(child: CircularProgressIndicator(color: Colors.white))),
      );
    }

    final statusText = switch (_isCorrect) {
      null => 'Whakarongo — kōwhiria te pikitia tika',
      true => 'Tika!',
      false => 'Ngana anō',
    };
    final statusIcon = switch (_isCorrect) {
      null => Icons.help,
      true => Icons.check_circle,
      false => Icons.cancel,
    };
    final statusColor = switch (_isCorrect) {
      null => Colors.amber,
      true => Colors.greenAccent,
      false => Colors.redAccent,
    };

    return Scaffold(
      backgroundColor: bgNavy,
      appBar: AppBar(
        backgroundColor: bgNavy,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                _IconButtonSquare(
                  icon: Icons.undo_rounded,
                  onTap: () => setState(() { _selectedIndex = null; _isCorrect = null; }),
                ),
                const Spacer(),
                _OtiButton(label: 'oti', onTap: _submit),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) {
            final h = c.maxHeight;
            final w = c.maxWidth;

            const sidePad = 16.0;
            const g = 12.0;
            const colGap = 12.0;

            final maxBodyW = (w - sidePad * 2).clamp(0.0, 900.0);
            final titleSize = (h * 0.043).clamp(20.0, 30.0);
            final statusH = titleSize + 10.0;

            final gridTileW = ((maxBodyW - colGap) / 2).clamp(110.0, 260.0);
            final gridTileH = gridTileW;
            final gridHeight = gridTileH * 2 + g;

            final minButtonH = 110.0;
            final spaceForButton =
                h - statusH - g - gridHeight - g - (64.0 + 12.0) - MediaQuery.of(context).viewPadding.bottom - 24.0;
            final buttonH = spaceForButton.clamp(minButtonH, h * 0.4);

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: sidePad),
              child: Column(
                children: [
                  SizedBox(
                    height: statusH,
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              statusText,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: titleSize,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(statusIcon, color: statusColor, size: titleSize + 6),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: g),

                  SizedBox(
                    height: buttonH,
                    width: maxBodyW,
                    child: Center(
                      child: GestureDetector(
                        onTapDown: (_) => _tapScale.reverse(),
                        onTapCancel: () => _tapScale.forward(),
                        onTapUp: (_) => _tapScale.forward(),
                        onTap: _play,
                        child: ScaleTransition(
                          scale: _tapScale,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.asset(
                                  'assets/kaupae1/sound/listeningButton.png',
                                  height: buttonH,
                                  fit: BoxFit.contain,
                                ),
                              ),
                              if (_playing)
                                const Positioned(
                                  bottom: 10,
                                  child: Icon(Icons.graphic_eq, color: Colors.white, size: 40),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: g),

                  SizedBox(
                    width: maxBodyW,
                    height: gridHeight,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            _ChoiceTile(
                              path: _optionImagePaths[0],
                              selected: _selectedIndex == 0,
                              size: Size(gridTileW, gridTileH),
                              onTap: () => setState(() { _selectedIndex = 0; _isCorrect = null; }),
                            ),
                            SizedBox(width: colGap),
                            _ChoiceTile(
                              path: _optionImagePaths[1],
                              selected: _selectedIndex == 1,
                              size: Size(gridTileW, gridTileH),
                              onTap: () => setState(() { _selectedIndex = 1; _isCorrect = null; }),
                            ),
                          ],
                        ),
                        SizedBox(height: g),
                        Row(
                          children: [
                            _ChoiceTile(
                              path: _optionImagePaths[2],
                              selected: _selectedIndex == 2,
                              size: Size(gridTileW, gridTileH),
                              onTap: () => setState(() { _selectedIndex = 2; _isCorrect = null; }),
                            ),
                            SizedBox(width: colGap),
                            _ChoiceTile(
                              path: _optionImagePaths[3],
                              selected: _selectedIndex == 3,
                              size: Size(gridTileW, gridTileH),
                              onTap: () => setState(() { _selectedIndex = 3; _isCorrect = null; }),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}


/* ===================== PUZZLE PAGE ====================== */

class WordsPuzzlePage extends StatefulWidget {
  final String imagePath;
  final List<String> answer;
  final List<String> bankStart;
  final VoidCallback? onNext;

  const WordsPuzzlePage({
    super.key,
    required this.imagePath,
    required this.answer,
    required this.bankStart,
    this.onNext,
  });

  @override
  State<WordsPuzzlePage> createState() => _WordsPuzzlePageState();
}

class _WordsPuzzlePageState extends State<WordsPuzzlePage> {
  late List<String?> slots;
  late List<String> bank;
  bool? isCorrect;
  bool _busy = false;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    slots = List<String?>.filled(widget.answer.length, null);
    bank = List<String>.from(widget.bankStart);
  }

  @override
  void didUpdateWidget(covariant WordsPuzzlePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.answer, widget.answer)) {
      slots = List<String?>.filled(widget.answer.length, null);
      isCorrect = null;
    }
    if (!listEquals(oldWidget.bankStart, widget.bankStart)) {
      bank = List<String>.from(widget.bankStart);
    }
    _busy = false;
    _dragging = false;
  }

  void _check() {
    if (_busy) return;
    _busy = true;
    final built = slots.map((s) => s ?? '').toList();
    final correct = listEquals(built, widget.answer);

    if (correct) {
      setState(() => isCorrect = true);
      Future.delayed(const Duration(milliseconds: 400), () {
        if (!mounted) return;
        _busy = false;
        widget.onNext?.call();
      });
    } else {
      setState(() => isCorrect = false);
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        setState(() {
          bank.addAll(slots.whereType<String>());
          slots = List<String?>.filled(widget.answer.length, null);
          isCorrect = null;
        });
        _busy = false;
      });
    }
  }

  void _clearStatus() {
    if (isCorrect != null) setState(() => isCorrect = null);
  }

  void _placeFromBankToSlot(String tile, int slotIndex) {
    setState(() {
      _clearStatus();
      final prev = slots[slotIndex];
      if (prev != null) bank.add(prev);
      bank.remove(tile);
      slots[slotIndex] = tile;
    });
  }

  void _slotToSlot(int from, int to) {
    setState(() {
      _clearStatus();
      final a = slots[from];
      final b = slots[to];
      slots[to] = a;
      slots[from] = b;
    });
  }

  void _slotToBank(int from) {
    final tile = slots[from];
    if (tile == null) return;
    setState(() {
      _clearStatus();
      slots[from] = null;
      bank.add(tile);
    });
  }

  @override
  Widget build(BuildContext context) {
    const bgNavy = Color(0xFF1F4A78);

    return Scaffold(
      backgroundColor: bgNavy,
      appBar: AppBar(
        backgroundColor: bgNavy,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
          child: IgnorePointer(
            ignoring: _dragging,
            child: SizedBox(
              height: 64,
              child: Row(
                children: [
                  _IconButtonSquare(
                    icon: Icons.undo_rounded,
                    onTap: () {
                      setState(() {
                        bank.addAll(slots.whereType<String>());
                        slots = List<String?>.filled(widget.answer.length, null);
                        isCorrect = null;
                      });
                    },
                  ),
                  const Spacer(),
                  _OtiButton(label: 'oti', onTap: _check),
                ],
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) {
            final h = c.maxHeight;
            final w = c.maxWidth;

            const sidePad = 16.0;
            const g = 12.0;
            const colGap = 12.0;
            const slotH0 = 86.0;
            const minImg = 110.0;
            final maxBodyW = (w - sidePad * 2).clamp(0.0, 900.0);

            final titleSize = (h * 0.043).clamp(20.0, 30.0);
            final statusH = titleSize + 10.0;

            final slotsCount = widget.answer.length.clamp(1, 6);
            final slotW = ((maxBodyW - colGap * (slotsCount - 1))).clamp(0.0, double.infinity) / slotsCount;

            double slotH = slotH0.clamp(56.0, 220.0);
            slotH = slotH.clamp(56.0, slotW * 0.66);
            double tileH = slotH;

            const bankCols = 3;
            final bankTileW = ((maxBodyW - colGap * (bankCols - 1))).clamp(0.0, double.infinity) / bankCols;

            final int bankRows = ((bank.length / bankCols).ceil()).clamp(1, 3);
            final bankHeight = bankRows * tileH + (bankRows - 1) * g;

            final fixedTop = statusH + g;
            final fixedGaps = g + g + g;

            const navHeight = 64.0;
            const navPad = 12.0;
            final spacerH = navHeight + navPad + MediaQuery.of(context).viewPadding.bottom;

            final bottomGap = spacerH;

            final availableForImageAndTiles = h - (fixedTop + fixedGaps + bottomGap) - 24;
            final tilesNeeded = slotH + tileH + tileH;

            double scale = 1.0;
            if ((tilesNeeded + minImg) > availableForImageAndTiles) {
              final denom = tilesNeeded;
              if (denom > 0) {
                scale = ((availableForImageAndTiles - minImg) / denom).clamp(0.55, 1.0);
              }
            }
            slotH *= scale;
            tileH *= scale;

            final imageH = (availableForImageAndTiles - (slotH + tileH + tileH)).clamp(minImg, h * 0.5);
            final tileFont = (tileH * 0.42).clamp(18.0, 28.0);

            final statusText = switch (isCorrect) {
              null => 'Tuhia tenei ki te reo!',
              true => 'Tika!',
              false => 'Ngana ano',
            };
            final statusIcon = switch (isCorrect) {
              null => Icons.help,
              true => Icons.check_circle,
              false => Icons.cancel,
            };
            final statusColor = switch (isCorrect) {
              null => Colors.amber,
              true => Colors.greenAccent,
              false => Colors.redAccent,
            };

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: sidePad),
              child: Column(
                children: [
                  SizedBox(
                    height: statusH,
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              statusText,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: titleSize,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(statusIcon, color: statusColor, size: titleSize + 6),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: g),

                  Expanded(
                    child: Column(
                      children: [
                        // Image
                        SizedBox(
                          height: imageH,
                          width: maxBodyW,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: FittedBox(
                              fit: BoxFit.contain,
                              alignment: Alignment.center,
                              child: Image.asset(
                                widget.imagePath,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.broken_image,
                                  size: 48,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: g),

                        // Slots
                        SizedBox(
                          width: maxBodyW,
                          height: slotH,
                          child: Row(
                            children: List.generate(widget.answer.length, (i) {
                              final filled = slots[i];
                              return SizedBox(
                                width: slotW,
                                height: slotH,
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    right: i < widget.answer.length - 1 ? colGap : 0,
                                  ),
                                  child: _SlotTarget(
                                    height: slotH,
                                    child: filled == null
                                        ? null
                                        : Draggable<_FromSlot>(
                                            data: _FromSlot(i),
                                            dragAnchorStrategy: childDragAnchorStrategy, // keep finger at same spot
                                            onDragStarted: () {
                                              HapticFeedback.selectionClick();
                                              setState(() => _dragging = true);
                                            },
                                            onDragEnd: (_) => setState(() => _dragging = false),
                                            feedback: Transform.scale(
                                              scale: 1.08,
                                              child: Material(
                                                type: MaterialType.transparency,
                                                child: _chip(
                                                  filled,
                                                  slotH,
                                                  tileFont,
                                                  opacity: 1,
                                                  width: slotW,
                                                  glow: true,
                                                ),
                                              ),
                                            ),
                                            childWhenDragging: _chip(
                                              '',
                                              slotH,
                                              tileFont,
                                              dim: true,
                                              width: slotW,
                                            ),
                                            child: _chip(
                                              filled,
                                              slotH,
                                              tileFont,
                                              width: slotW,
                                            ),
                                          ),
                                    onAcceptFromBank: (tile) => _placeFromBankToSlot(tile, i),
                                    onAcceptFromSlot: (from) => _slotToSlot(from, i),
                                    slotIndex: i,
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                        const SizedBox(height: g),

                        // Bank — drop zone behind tiles
                        SizedBox(
                          width: maxBodyW,
                          height: bankHeight,
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: _BankDragTarget(
                                  onAcceptFromSlot: (from) => _slotToBank(from),
                                  child: const SizedBox.expand(),
                                ),
                              ),
                              Align(
                                alignment: Alignment.topLeft,
                                child: Wrap(
                                  spacing: colGap,
                                  runSpacing: g,
                                  children: [
                                    for (final t in bank)
                                      Draggable<String>(
                                        data: t,
                                        dragAnchorStrategy: childDragAnchorStrategy, // keep center under finger
                                        onDragStarted: () {
                                          HapticFeedback.selectionClick();
                                          setState(() => _dragging = true);
                                        },
                                        onDragEnd: (_) => setState(() => _dragging = false),
                                        feedback: Transform.scale(
                                          scale: 1.08,
                                          child: Material(
                                            type: MaterialType.transparency,
                                            child: _chip(
                                              t,
                                              tileH,
                                              tileFont,
                                              opacity: 1,
                                              width: bankTileW,
                                              glow: true,
                                            ),
                                          ),
                                        ),
                                        childWhenDragging: _chip('', tileH, tileFont, dim: true, width: bankTileW),
                                        child: _chip(t, tileH, tileFont, width: bankTileW),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: spacerH),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // Visual chip
  Widget _chip(String text, double h, double fs,
      {bool dim = false, double opacity = 1, double? width, bool glow = false}) {
    return Opacity(
      opacity: opacity,
      child: Container(
        width: width,
        height: h,
        decoration: BoxDecoration(
          color: dim ? Colors.white38 : Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            if (glow) BoxShadow(color: Colors.white.withOpacity(0.85), blurRadius: 14, spreadRadius: 1),
            const BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
          ],
        ),
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(horizontal: (width ?? h) * 0.08),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            text,
            style: TextStyle(fontSize: fs, color: Colors.black87, fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.visible,
          ),
        ),
      ),
    );
  }
}

/* ================= DragTargets & helpers ================= */

class _FromSlot {
  final int index;
  const _FromSlot(this.index);
}

class _SlotTarget extends StatelessWidget {
  final double height;
  final Widget? child; // chip if slot filled
  final void Function(String tile) onAcceptFromBank;
  final void Function(int fromSlotIndex) onAcceptFromSlot;
  final int slotIndex;

  const _SlotTarget({
    required this.height,
    required this.child,
    required this.onAcceptFromBank,
    required this.onAcceptFromSlot,
    required this.slotIndex,
  });

  @override
  Widget build(BuildContext context) {
    const radius = 12.0;
    return DragTarget<Object>(
      builder: (context, candidateData, rejectedData) {
        final isHover = candidateData.isNotEmpty;
        return Container(
          height: height,
          decoration: BoxDecoration(
            color: const Color(0xFF7A5555),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: const Color(0xFF5A3D3D), width: 3),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
          ),
          padding: const EdgeInsets.all(6),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              color: isHover ? const Color(0xFF8D6E63) : const Color(0xFF6D4C41),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
      onWillAcceptWithDetails: (details) => details.data is String || details.data is _FromSlot,
      onAcceptWithDetails: (details) {
        final d = details.data;
        if (d is String) {
          onAcceptFromBank(d); // bank → slot
        } else if (d is _FromSlot) {
          onAcceptFromSlot(d.index); // slot → slot
        }
      },
    );
  }
}

class _BankDragTarget extends StatelessWidget {
  final Widget child;
  final void Function(int fromSlotIndex) onAcceptFromSlot;
  const _BankDragTarget({required this.child, required this.onAcceptFromSlot});

  @override
  Widget build(BuildContext context) {
    return DragTarget<_FromSlot>(
      builder: (context, candidate, rejected) => child,
      onWillAcceptWithDetails: (details) => details.data is _FromSlot,
      onAcceptWithDetails: (details) => onAcceptFromSlot(details.data.index),
    );
  }
}

/* ===================== LISTEN PUZZLE PAGE ====================== */

class ListenPuzzlePage extends StatefulWidget {
  final String soundPath;          // asset path to audio file: .ogg, .mp4, or .m4a (likely starts with "assets/")
  final List<String> answer;       // syllables in order
  final List<String> bankStart;
  final VoidCallback? onNext;

  const ListenPuzzlePage({
    super.key,
    required this.soundPath,
    required this.answer,
    required this.bankStart,
    this.onNext,
  });

  @override
  State<ListenPuzzlePage> createState() => _ListenPuzzlePageState();
}

class _ListenPuzzlePageState extends State<ListenPuzzlePage> with SingleTickerProviderStateMixin {
  late List<String?> slots;
  late List<String> bank;
  bool? isCorrect;
  bool _busy = false;
  bool _dragging = false;

  final _player = AudioPlayer();
  bool _playing = false;
  late final AnimationController _tapScale =
      AnimationController(vsync: this, lowerBound: .95, upperBound: 1.0, duration: const Duration(milliseconds: 120))
        ..value = 1.0;

  @override
  void initState() {
    super.initState();
    slots = List<String?>.filled(widget.answer.length, null);
    bank = List<String>.from(widget.bankStart);
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playing = false);
    });
  }

  @override
  void didUpdateWidget(covariant ListenPuzzlePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.answer, widget.answer)) {
      slots = List<String?>.filled(widget.answer.length, null);
      isCorrect = null;
    }
    if (!listEquals(oldWidget.bankStart, widget.bankStart)) {
      bank = List<String>.from(widget.bankStart);
    }
    _busy = false;
    _dragging = false;
  }

  @override
  void dispose() {
    _tapScale.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _play() async {
    try {
      setState(() => _playing = true);
      await _player.stop();
      // ---- Only change: strip leading "assets/" for AssetSource ----
      final rel = widget.soundPath.startsWith('assets/')
          ? widget.soundPath.substring(7)
          : widget.soundPath;
      await _player.play(AssetSource(rel));
    } catch (_) {
      setState(() => _playing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kāore i taea te purei i te oro')),
      );
    }
  }

  void _check() {
    if (_busy) return;
    _busy = true;
    final built = slots.map((s) => s ?? '').toList();
    final correct = listEquals(built, widget.answer);

    if (correct) {
      setState(() => isCorrect = true);
      Future.delayed(const Duration(milliseconds: 400), () {
        if (!mounted) return;
        _busy = false;
        widget.onNext?.call();
      });
    } else {
      setState(() => isCorrect = false);
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        setState(() {
          bank.addAll(slots.whereType<String>());
          slots = List<String?>.filled(widget.answer.length, null);
          isCorrect = null;
        });
        _busy = false;
      });
    }
  }

  void _clearStatus() {
    if (isCorrect != null) setState(() => isCorrect = null);
  }

  void _placeFromBankToSlot(String tile, int slotIndex) {
    setState(() {
      _clearStatus();
      final prev = slots[slotIndex];
      if (prev != null) bank.add(prev);
      bank.remove(tile);
      slots[slotIndex] = tile;
    });
  }

  void _slotToSlot(int from, int to) {
    setState(() {
      _clearStatus();
      final a = slots[from];
      final b = slots[to];
      slots[to] = a;
      slots[from] = b;
    });
  }

  void _slotToBank(int from) {
    final tile = slots[from];
    if (tile == null) return;
    setState(() {
      _clearStatus();
      slots[from] = null;
      bank.add(tile);
    });
  }

  @override
  Widget build(BuildContext context) {
    const bgNavy = Color(0xFF1F4A78);

    return Scaffold(
      backgroundColor: bgNavy,
      appBar: AppBar(
        backgroundColor: bgNavy,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
          child: IgnorePointer(
            ignoring: _dragging,
            child: SizedBox(
              height: 64,
              child: Row(
                children: [
                  _IconButtonSquare(
                    icon: Icons.undo_rounded,
                    onTap: () {
                      setState(() {
                        bank.addAll(slots.whereType<String>());
                        slots = List<String?>.filled(widget.answer.length, null);
                        isCorrect = null;
                      });
                    },
                  ),
                  const Spacer(),
                  _OtiButton(label: 'oti', onTap: _check),
                ],
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) {
            final h = c.maxHeight;
            final w = c.maxWidth;

            const sidePad = 16.0;
            const g = 12.0;
            const colGap = 12.0;
            const slotH0 = 86.0;
            const minImg = 110.0;
            final maxBodyW = (w - sidePad * 2).clamp(0.0, 900.0);

            final titleSize = (h * 0.043).clamp(20.0, 30.0);
            final statusH = titleSize + 10.0;

            final slotsCount = widget.answer.length.clamp(1, 6);
            final slotW = ((maxBodyW - colGap * (slotsCount - 1))).clamp(0.0, double.infinity) / slotsCount;

            double slotH = slotH0.clamp(56.0, 220.0);
            slotH = slotH.clamp(56.0, slotW * 0.66);
            double tileH = slotH;

            const bankCols = 3;
            final bankTileW = ((maxBodyW - colGap * (bankCols - 1))).clamp(0.0, double.infinity) / bankCols;

            final bankRows = (bank.length / bankCols).ceil().clamp(1, 3);
            final bankHeight = bankRows * tileH + (bankRows - 1) * g;

            final fixedTop = statusH + g;
            final fixedGaps = g + g + g;

            const navHeight = 64.0;
            const navPad = 12.0;
            final spacerH = navHeight + navPad + MediaQuery.of(context).viewPadding.bottom;

            final bottomGap = spacerH;

            final availableForImageAndTiles = h - (fixedTop + fixedGaps + bottomGap) - 24;
            final tilesNeeded = slotH + tileH + tileH;

            double scale = 1.0;
            if ((tilesNeeded + minImg) > availableForImageAndTiles) {
              final denom = tilesNeeded;
              if (denom > 0) {
                scale = ((availableForImageAndTiles - minImg) / denom).clamp(0.55, 1.0);
              }
            }
            slotH *= scale;
            tileH *= scale;

            final imageH = 0.8*(availableForImageAndTiles - (slotH + tileH + tileH)).clamp(minImg, h * 0.5);
            final tileFont = (tileH * 0.42).clamp(18.0, 28.0);

            // Header text + icon colors like words page
            final statusText = switch (isCorrect) {
              null => 'He aha te kupu e rongo ana koe?',
              true => 'Tika!',
              false => 'Ngana anō',
            };
            final statusIcon = switch (isCorrect) {
              null => Icons.hearing,
              true => Icons.check_circle,
              false => Icons.cancel,
            };
            final statusColor = switch (isCorrect) {
              null => Colors.amber,
              true => Colors.greenAccent,
              false => Colors.redAccent,
            };

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: sidePad),
              child: Column(
                children: [
                  SizedBox(
                    height: statusH,
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              statusText,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: titleSize,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(statusIcon, color: statusColor, size: titleSize + 6),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: g),

                  // Big center "play" button area (reuses the image slot from words page)
                  SizedBox(
                    height: imageH,
                    width: maxBodyW,
                    child: Center(
                      child: GestureDetector(
                        onTapDown: (_) => _tapScale.reverse(),
                        onTapCancel: () => _tapScale.forward(),
                        onTapUp: (_) => _tapScale.forward(),
                        onTap: _play,
                        child: ScaleTransition(
                          scale: _tapScale,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: const [
                                BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))
                              ],
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.asset(
                                    'assets/kaupae1/sound/listeningButton.png',
                                    height: imageH,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                                if (_playing)
                                  const Positioned(
                                    bottom: 10,
                                    child: Icon(Icons.graphic_eq, color: Colors.white, size: 40),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: g),

                  // Slots
                  SizedBox(
                    width: maxBodyW,
                    height: slotH,
                    child: Row(
                      children: List.generate(widget.answer.length, (i) {
                        final filled = slots[i];
                        return SizedBox(
                          width: slotW,
                          height: slotH,
                          child: Padding(
                            padding: EdgeInsets.only(right: i < widget.answer.length - 1 ? colGap : 0),
                            child: _SlotTarget(
                              height: slotH,
                              child: filled == null
                                  ? null
                                  : Draggable<_FromSlot>(
                                      data: _FromSlot(i),
                                      dragAnchorStrategy: childDragAnchorStrategy, // keep finger at same spot
                                      onDragStarted: () {
                                        HapticFeedback.selectionClick();
                                        setState(() => _dragging = true);
                                      },
                                      onDragEnd: (_) => setState(() => _dragging = false),
                                      feedback: Transform.scale(
                                        scale: 1.08,
                                        child: Material(
                                          type: MaterialType.transparency,
                                          child: _chip(filled, slotH, tileFont, opacity: 1, width: slotW, glow: true),
                                        ),
                                      ),
                                      childWhenDragging: _chip('', slotH, tileFont, dim: true, width: slotW),
                                      child: _chip(filled, slotH, tileFont, width: slotW),
                                    ),
                              onAcceptFromBank: (tile) => _placeFromBankToSlot(tile, i),
                              onAcceptFromSlot: (from) => _slotToSlot(from, i),
                              slotIndex: i,
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: g),

                  // Bank & drop zone
                  SizedBox(
                    width: maxBodyW,
                    height: bankHeight,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: _BankDragTarget(
                            onAcceptFromSlot: (from) => _slotToBank(from),
                            child: const SizedBox.expand(),
                          ),
                        ),
                        Align(
                          alignment: Alignment.topLeft,
                          child: Wrap(
                            spacing: colGap,
                            runSpacing: g,
                            children: [
                              for (final t in bank)
                                Draggable<String>(
                                  data: t,
                                  dragAnchorStrategy: childDragAnchorStrategy, // keep center under finger
                                  onDragStarted: () {
                                    HapticFeedback.selectionClick();
                                    setState(() => _dragging = true);
                                  },
                                  onDragEnd: (_) => setState(() => _dragging = false),
                                  feedback: Transform.scale(
                                    scale: 1.08,
                                    child: Material(
                                      type: MaterialType.transparency,
                                      child: _chip(t, tileH, tileFont, opacity: 1, width: bankTileW, glow: true),
                                    ),
                                  ),
                                  childWhenDragging: _chip('', tileH, tileFont, dim: true, width: bankTileW),
                                  child: _chip(t, tileH, tileFont, width: bankTileW),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: spacerH),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // Reuse the same visual chip from Words page
  Widget _chip(String text, double h, double fs,
      {bool dim = false, double opacity = 1, double? width, bool glow = false}) {
    return Opacity(
      opacity: opacity,
      child: Container(
        width: width,
        height: h,
        decoration: BoxDecoration(
          color: dim ? Colors.white38 : Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            if (glow) BoxShadow(color: Colors.white.withOpacity(0.85), blurRadius: 14, spreadRadius: 1),
            const BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
          ],
        ),
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(horizontal: (width ?? h) * 0.08),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            text,
            style: TextStyle(fontSize: fs, color: Colors.black87, fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.visible,
          ),
        ),
      ),
    );
  }
}


/* ===================== BUTTONS ======================= */

class _IconButtonSquare extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconButtonSquare({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF476277),
      borderRadius: BorderRadius.circular(16),
      elevation: 3,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: SizedBox(
          width: 72,
          height: 72,
          child: Icon(icon, size: 36, color: Colors.black87),
        ),
      ),
    );
  }
}

class _OtiButton extends StatelessWidget {
  final String label; // e.g. 'oti'
  final VoidCallback onTap;
  final IconData? icon;

  const _OtiButton({required this.label, required this.onTap, this.icon});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 3,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: const TextStyle(fontSize: 22, color: Colors.black)),
              const SizedBox(width: 8),
              Icon(icon ?? Icons.check_circle, color: Colors.green, size: 26),
            ],
          ),
        ),
      ),
    );
  }
}

/* ===================== STUB PAGES ======================= */

class WordsPage2 extends StatelessWidget {
  const WordsPage2({super.key});
  @override
  Widget build(BuildContext context) => const _SimplePage(title: 'Syllables');
}

class WordsPage3 extends StatelessWidget {
  const WordsPage3({super.key});
  @override
  Widget build(BuildContext context) => const _SimplePage(title: 'Syllables');
}

class ListenPage1 extends StatelessWidget {
  const ListenPage1({super.key});
  @override
  Widget build(BuildContext context) => const _SimplePage(title: 'Listen');
}

class ListenPage2 extends StatelessWidget {
  const ListenPage2({super.key});
  @override
  Widget build(BuildContext context) => const _SimplePage(title: 'Listen');
}

class ListenPage3 extends StatelessWidget {
  const ListenPage3({super.key});
  @override
  Widget build(BuildContext context) => const _SimplePage(title: 'Listen');
}

/* ===================== MOVE — LISTEN & CHOOSE (fixed init) ====================== */

class Kaupae1MovePage extends StatefulWidget {
  const Kaupae1MovePage({super.key});
  @override
  State<Kaupae1MovePage> createState() => _Kaupae1MovePageState();
}

class _Kaupae1MovePageState extends State<Kaupae1MovePage> with SingleTickerProviderStateMixin {
  static const bgNavy = Color(0xFF1F4A78);

  final String _tilesFolder = 'assets/kaupae1/tiles';
  final String _soundsFolder = 'assets/kaupae1/sound';

  final _player = AudioPlayer();
  bool _playing = false;
  late final AnimationController _tapScale =
      AnimationController(vsync: this, lowerBound: .95, upperBound: 1.0, duration: const Duration(milliseconds: 120))
        ..value = 1.0;

  Map<String, String> _tilePathByName = {};
  Map<String, String> _soundPathByName = {};
  List<String> _validNames = [];                 // ← not late; starts empty

  String? _targetName;
  String? _targetSoundPath;
  List<String> _optionImagePaths = [];

  int? _selectedIndex;
  bool? _isCorrect;

  final List<int> _bag = [];
  int? _lastIndex;

  bool _loading = true;                          // ← loading gate

  @override
  void initState() {
    super.initState();
    _player.onPlayerComplete.listen((_) => setState(() => _playing = false));
    _loadAssets();
  }

  @override
  void dispose() {
    _tapScale.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _loadAssets() async {
    try {
      final manifestStr = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> files = json.decode(manifestStr);

      final tilePngs = files.keys
          .where((p) => p.startsWith('$_tilesFolder/') && p.toLowerCase().endsWith('.png'))
          .toList();

      final soundOggs = files.keys
          .where((p) => p.startsWith('$_soundsFolder/') && AudioPuzzleRepository._isAudioFile(p))
          .toList();

      String baseFrom(String path) {
        final file = path.split('/').last;
        return file.replaceAll(RegExp(r'\.(png|ogg|mp4|m4a)$', caseSensitive: false), '');
      }

      _tilePathByName = { for (final p in tilePngs) baseFrom(p): p };
      _soundPathByName = { for (final p in soundOggs) baseFrom(p): p };

      _validNames = _tilePathByName.keys
          .toSet()
          .intersection(_soundPathByName.keys.toSet())
          .toList()
        ..sort();

      if (_validNames.isNotEmpty) {
        _makeNext();
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _refillBag() {
    _bag
      ..clear()
      ..addAll(List<int>.generate(_validNames.length, (i) => i)..shuffle(Random()));
    if (_lastIndex != null && _bag.length > 1 && _bag.first == _lastIndex) {
      final swapWith = 1 + Random().nextInt(_bag.length - 1);
      final t = _bag[0]; _bag[0] = _bag[swapWith]; _bag[swapWith] = t;
    }
  }

  void _makeNext() {
    if (_validNames.isEmpty) return;
    if (_bag.isEmpty) _refillBag();

    final idx = _bag.removeAt(0);
    _lastIndex = idx;

    final name = _validNames[idx];
    final correctImg = _tilePathByName[name]!;
    final correctSnd = _soundPathByName[name]!;

    final others = _tilePathByName.keys.where((n) => n != name).toList()..shuffle(Random());
    final distractors = others.take(3).map((n) => _tilePathByName[n]!).toList();
    final options = <String>[correctImg, ...distractors]..shuffle(Random());

    setState(() {
      _targetName = name;
      _targetSoundPath = correctSnd;
      _optionImagePaths = options;
      _selectedIndex = null;
      _isCorrect = null;
      _playing = false;
    });
  }

  Future<void> _play() async {
    if (_targetSoundPath == null) return;
    try {
      setState(() => _playing = true);
      await _player.stop();
      final rel = _targetSoundPath!.startsWith('assets/') ? _targetSoundPath!.substring(7) : _targetSoundPath!;
      await _player.play(AssetSource(rel));
    } catch (_) {
      setState(() => _playing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kāore i taea te purei i te oro')),
        );
      }
    }
  }

  void _submit() {
    if (_selectedIndex == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kōwhiria tētahi pikitia')),
      );
      return;
    }
    final chosenPath = _optionImagePaths[_selectedIndex!];
    final chosenName = chosenPath.split('/').last.replaceAll('.png', '');
    final ok = (chosenName == _targetName);

    setState(() => _isCorrect = ok);

    if (ok) {
      Future.delayed(const Duration(milliseconds: 450), () {
        if (!mounted) return;
        _makeNext();
      });
    } else {
      Future.delayed(const Duration(milliseconds: 600), () {
        if (!mounted) return;
        setState(() {
          _selectedIndex = null;
          _isCorrect = null;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Loading state
    if (_loading) {
      return const Scaffold(
        backgroundColor: bgNavy,
        body: SafeArea(child: Center(child: CircularProgressIndicator(color: Colors.white))),
      );
    }

    // No valid pairs found
    if (_validNames.isEmpty) {
      return const Scaffold(
        backgroundColor: bgNavy,
        body: SafeArea(
          child: Center(
            child: Text(
              'Kāore he oro me ngā pikitia ōrite i kitea.',
              style: TextStyle(color: Colors.white, fontSize: 18),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    // Guard: options not ready yet
    if (_optionImagePaths.length < 4 || _targetSoundPath == null) {
      return const Scaffold(
        backgroundColor: bgNavy,
        body: SafeArea(child: Center(child: CircularProgressIndicator(color: Colors.white))),
      );
    }

    final statusText = switch (_isCorrect) {
      null => 'Whakarongo — kōwhiria te pikitia tika',
      true => 'Tika!',
      false => 'Ngana anō',
    };
    final statusIcon = switch (_isCorrect) {
      null => Icons.help,
      true => Icons.check_circle,
      false => Icons.cancel,
    };
    final statusColor = switch (_isCorrect) {
      null => Colors.amber,
      true => Colors.greenAccent,
      false => Colors.redAccent,
    };

    return Scaffold(
      backgroundColor: bgNavy,
      appBar: AppBar(
        backgroundColor: bgNavy,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                _IconButtonSquare(
                  icon: Icons.undo_rounded,
                  onTap: () => setState(() { _selectedIndex = null; _isCorrect = null; }),
                ),
                const Spacer(),
                _OtiButton(label: 'oti', onTap: _submit),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) {
            final h = c.maxHeight;
            final w = c.maxWidth;

            const sidePad = 16.0;
            const g = 12.0;
            const colGap = 12.0;

            final maxBodyW = (w - sidePad * 2).clamp(0.0, 900.0);
            final titleSize = (h * 0.043).clamp(20.0, 30.0);
            final statusH = titleSize + 10.0;

            final gridTileW = ((maxBodyW - colGap) / 2).clamp(110.0, 260.0);
            final gridTileH = gridTileW;
            final gridHeight = gridTileH * 2 + g;

            final minButtonH = 110.0;
            final spaceForButton =
                h - statusH - g - gridHeight - g - (64.0 + 12.0) - MediaQuery.of(context).viewPadding.bottom - 24.0;
            final buttonH = spaceForButton.clamp(minButtonH, h * 0.4);

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: sidePad),
              child: Column(
                children: [
                  SizedBox(
                    height: statusH,
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              statusText,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: titleSize,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(statusIcon, color: statusColor, size: titleSize + 6),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: g),

                  SizedBox(
                    height: buttonH,
                    width: maxBodyW,
                    child: Center(
                      child: GestureDetector(
                        onTapDown: (_) => _tapScale.reverse(),
                        onTapCancel: () => _tapScale.forward(),
                        onTapUp: (_) => _tapScale.forward(),
                        onTap: _play,
                        child: ScaleTransition(
                          scale: _tapScale,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.asset(
                                  'assets/kaupae1/sound/listeningButton.png',
                                  height: buttonH,
                                  fit: BoxFit.contain,
                                ),
                              ),
                              if (_playing)
                                const Positioned(
                                  bottom: 10,
                                  child: Icon(Icons.graphic_eq, color: Colors.white, size: 40),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: g),

                  SizedBox(
                    width: maxBodyW,
                    height: gridHeight,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            _ChoiceTile(
                              path: _optionImagePaths[0],
                              selected: _selectedIndex == 0,
                              size: Size(gridTileW, gridTileH),
                              onTap: () => setState(() { _selectedIndex = 0; _isCorrect = null; }),
                            ),
                            SizedBox(width: colGap),
                            _ChoiceTile(
                              path: _optionImagePaths[1],
                              selected: _selectedIndex == 1,
                              size: Size(gridTileW, gridTileH),
                              onTap: () => setState(() { _selectedIndex = 1; _isCorrect = null; }),
                            ),
                          ],
                        ),
                        SizedBox(height: g),
                        Row(
                          children: [
                            _ChoiceTile(
                              path: _optionImagePaths[2],
                              selected: _selectedIndex == 2,
                              size: Size(gridTileW, gridTileH),
                              onTap: () => setState(() { _selectedIndex = 2; _isCorrect = null; }),
                            ),
                            SizedBox(width: colGap),
                            _ChoiceTile(
                              path: _optionImagePaths[3],
                              selected: _selectedIndex == 3,
                              size: Size(gridTileW, gridTileH),
                              onTap: () => setState(() { _selectedIndex = 3; _isCorrect = null; }),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  final String path;
  final bool selected;
  final Size size;
  final VoidCallback onTap;

  const _ChoiceTile({
    super.key,
    required this.path,
    required this.selected,
    required this.size,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size.width,
      height: size.height,
      child: Material(
        color: Colors.transparent,
        elevation: selected ? 8 : 4,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            decoration: BoxDecoration(
              color: const Color(0xFF244C7F),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? Colors.amber : const Color(0xFF1B3555),
                width: selected ? 4 : 2,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: FittedBox(
                  fit: BoxFit.contain,
                  alignment: Alignment.center,
                  child: Image.asset(
                    path,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.broken_image, color: Colors.white70, size: 48),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}


class MovePage2 extends StatelessWidget {
  const MovePage2({super.key});
  @override
  Widget build(BuildContext context) => const _SimplePage(title: 'Move');
}

class MovePage3 extends StatelessWidget {
  const MovePage3({super.key});
  @override
  Widget build(BuildContext context) => const _SimplePage(title: 'Move');
}

class _SimplePage extends StatelessWidget {
  final String title;
  const _SimplePage({required this.title, super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Text(title, style: const TextStyle(fontSize: 28)),
      ),
    );
  }
}

