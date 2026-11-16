// main.dart
import 'dart:convert';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

const kGreen1 = Color(0xFF84B179);
const kGreen2 = Color(0xFFA2CB8B);
const kGreen3 = Color(0xFFC7EABB);
const kGreen4 = Color(0xFFE8F5BD);

const kOnDark = Color(0xFF16361F); // رنگ متن تیره‌ی مناسب

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // اگر جایی SystemChrome داشتی، فقط اینجا و بعد ensureInitialized اجراش کن:
  // await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  // await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  runApp(const MyApp());
}
class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const WheelPage(),
      theme: ThemeData(
        fontFamily:'myFonts2',
        fontFamilyFallback: const ['Vazir'],
        useMaterial3: true,
        colorScheme: const ColorScheme(
          brightness: Brightness.light,

          primary: kGreen1,
          onPrimary: Colors.white,

          secondary: kGreen2,
          onSecondary: kOnDark,

          tertiary: kGreen3,
          onTertiary: kOnDark,

          surface: kGreen4,
          onSurface: kOnDark,

          background: kGreen4,
          onBackground: kOnDark,

          error: Color(0xFFB00020),
          onError: Colors.white,
        ),

        appBarTheme: const AppBarTheme(
          backgroundColor: kGreen1,
          foregroundColor: Colors.white,
        ),

        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: kGreen1,
            foregroundColor: Colors.white,
          ),
        ),

        dialogTheme: const DialogThemeData(
          backgroundColor: kGreen4,
          titleTextStyle: TextStyle(color: kOnDark, fontSize: 18, fontWeight: FontWeight.w700),
          contentTextStyle: TextStyle(color: kOnDark, fontSize: 16),
        ),
      ),
    );
  }
}

class WheelPage extends StatefulWidget {
  const WheelPage({super.key});
  @override
  State<WheelPage> createState() => _WheelPageState();
}

enum _EndAction { keep, delete }

class _WheelPageState extends State<WheelPage>
    with SingleTickerProviderStateMixin {
  static const _prefsKey = 'wheel_state_v1';

  late final AnimationController _spinCtrl;
  final GlobalKey<WheelWidgetState> _wheelKey = GlobalKey();

  late final AudioPlayer _winPlayer;
  late final AudioPlayer _tickPlayer;

  @override
  void initState() {
    super.initState();

    _spinCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadWheel();
    });
    _winPlayer = AudioPlayer()..setReleaseMode(ReleaseMode.stop);
    _tickPlayer = AudioPlayer()..setReleaseMode(ReleaseMode.stop);

  }
  @override
  void dispose() {
    _spinCtrl.dispose();
    _winPlayer.dispose();
    _tickPlayer.dispose();
    super.dispose();
  }

  Future<void> _saveWheel() async {
    final state = _wheelKey.currentState;
    if (state == null) return;

    final prefs = await SharedPreferences.getInstance();
    final map = state.exportState();
    await prefs.setString(_prefsKey, jsonEncode(map));
  }

  Future<void> _loadWheel() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_prefsKey);
    if (s == null) return;

    try {
      final map = (jsonDecode(s) as Map).cast<String, dynamic>();
      _wheelKey.currentState?.importState(map);
    } catch (_) {
      // ignore broken data
    }
  }

  Future<void> _clearSavedWheel() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }

  int _finalIndexAtPointer(double turns, int segmentCount) {
    final twoPi = 2 * math.pi;
    final rotRad = (turns * twoPi) % twoPi;
    final sweep = twoPi / segmentCount;

    var wheelAng = (-rotRad) % twoPi;
    if (wheelAng < 0) wheelAng += twoPi;

    // epsilon to avoid boundary jitter
    wheelAng = (wheelAng + 1e-6) % twoPi;

    return (wheelAng / sweep).floor().clamp(0, segmentCount - 1);
  }

  Future<void> _showResultDialog(int idx) async {
    final state = _wheelKey.currentState;
    if (!mounted || state == null) return;

    final txt = state.getTextAt(idx);
    final display = (txt == null || txt.trim().isEmpty) ? 'No Text Inserted' : txt;

    final color = state.getColorAt(idx);

    final canDelete = state.segmentCount > 2;

    final action = await showDialog<_EndAction>(
      context: context,
      builder: (_) =>  AlertDialog(
      backgroundColor: color, // ✅ هم‌رنگ با قطعه



      content: SizedBox(
        height: 150,
        width: 250,
        child: Center(
          child: Text(
            display,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),

        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context, _EndAction.keep),
                child: const Text(
                  'Continue',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),

              if (canDelete)
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color.fromRGBO(135, 38, 38, 1),
                    foregroundColor: color,
                  ),
                  onPressed: () => Navigator.pop(context, _EndAction.delete),
                  child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                ),
            ],
          ),
        ],
      ),
    );

    if (!mounted || action == null) return;

    if (action == _EndAction.delete) {
      state.removeSegmentAt(idx); // خودش onChanged -> save رو صدا می‌زنه
    }
  }
  Future<void> _safePlay(AudioPlayer p, AssetSource src) async {
    try {
      await p.stop();
      await p.play(src);
    } catch (e, st) {
      debugPrint('Audio play failed: $e');
      debugPrintStack(stackTrace: st);
    }
  }

  void _spinRandom() async{
    if (_spinCtrl.isAnimating) return; // جلوگیری از دوبار کلیک/اسپم
    final rnd = math.Random();
    final extraTurns = 2 + rnd.nextInt(4); // 2 تا 5 دور
    final end = extraTurns + rnd.nextDouble();

    await _safePlay(_tickPlayer, AssetSource('sounds/beep.mp3'));

    _spinCtrl.stop();
    _spinCtrl.reset();

    final anim = Tween<double>(begin: 0, end: end).animate(
      CurvedAnimation(parent: _spinCtrl, curve: Curves.easeOutCubic),
    );

    void listener() {
      _wheelKey.currentState?.setRotationTurns(anim.value);

      final segCount = _wheelKey.currentState?.segmentCount ?? 0;

      if (!_spinCtrl.isAnimating) {
        _spinCtrl.removeListener(listener);
      }
    }

    _spinCtrl.addListener(listener);

    // duration depends on turns
    _spinCtrl.duration = Duration(milliseconds: 3500 + (extraTurns * 400));

    _spinCtrl.forward().whenComplete(() async {
      final state = _wheelKey.currentState;
      if (!mounted || state == null) return;

      final count = state.segmentCount;
      if (count <= 0) return;

      final idx = _finalIndexAtPointer(state.rotationTurns, count);
      await _safePlay(_winPlayer,  AssetSource('sounds/win.wav'));
      await _showResultDialog(idx);

      // آخر اسپین، زاویه هم ذخیره بشه
      await _saveWheel();
    });
  }

  Future<void> _resetAll() async {
    _spinCtrl.stop();
    _spinCtrl.reset();

    _wheelKey.currentState?.resetWheel(); // onChanged -> save

    // فقط با دکمه ریست، دیتای ذخیره‌شده هم پاک/ریست بشه
    await _clearSavedWheel();
    await _saveWheel(); // تا بعد باز کردن هم همین حالت ریست بمونه
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 170,
        title: const Text('Spinnuza'),
        titleTextStyle: TextStyle(color: kOnDark, fontSize: 60, fontFamily: 'myFonts1'),
        centerTitle: true,
        backgroundColor: kGreen4,

      ),
      body: Column(
        children: [
          const SizedBox(height: 16),
          Expanded(
            child: Center(
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: kOnDark.withOpacity(0.25),
                      blurRadius: 20,
                      spreadRadius: 2,
                      offset: const Offset(0, 10), // پایین‌تر بیفته
                    ),
                  ],
                ),
                child: WheelWidget(
                  key: _wheelKey,
                  initialSegments: 2,
                  size: 320,
                  onChanged: _saveWheel,
                  onCenterPressed: _spinRandom,
                ),
              ),            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16,12,16,20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: IconButton(
                          icon: Icon(Icons.remove, fontWeight: FontWeight.bold,),
                          tooltip: 'Decrease',
                          onPressed: () => _wheelKey.currentState?.decreaseSegments(),
                        ),
                      ),
                      Expanded(
                        child: IconButton(
                          tooltip: 'Reset',
                          onPressed: _resetAll,
                          icon: const Icon(Icons.delete_outline_rounded, fontWeight: FontWeight.bold,),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: IconButton(
                          icon: Icon(Icons.add, fontWeight: FontWeight.bold,),
                          tooltip: 'Increase',
                          onPressed: () => _wheelKey.currentState?.increaseSegments(),
                        ),
                      ),
                      const SizedBox(width: 14),


                    ],
                  ),
                ),

                Center(
                  child: Text('This app is created by RD', style: TextStyle(fontSize: 10),),
                ),
              ],
            ),
          ),

        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        shape: const CircleBorder(),
        elevation: 2,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(icon),
          ),
        ),
      ),
    );
  }
}

/// ----------------------
/// Data model per segment
/// ----------------------
class WheelSegmentData {
  String? text;
  final Color color;
  WheelSegmentData({this.text, required this.color});
}

/// ----------------------
/// Wheel Widget
/// ----------------------
class WheelWidget extends StatefulWidget {
  const WheelWidget({
    super.key,
    this.initialSegments = 2,
    this.size = 280,
    this.onChanged,
    this.onCenterPressed,
    this.rotation,
  });

  final int initialSegments;
  final double size;
  final VoidCallback? onChanged;
  final VoidCallback? onCenterPressed;
  final Animation<double>? rotation;

  @override
  State<WheelWidget> createState() => WheelWidgetState();
}

enum _SegmentAction { editText, delete }

class WheelWidgetState extends State<WheelWidget> {

  late List<WheelSegmentData> _segments;
  double _rotationTurns = 0.0; // 0..n (turns)


  static const Color _baseGreen = Color(0xFF84B179);
  int get segmentCount => _segments.length;
  double get rotationTurns => _rotationTurns;

  @override
  void initState() {
    super.initState();
    final count = math.max(2, widget.initialSegments);
    _segments = _buildSegments(count);
  }
// بازه‌ی Hue سبزها: (تقریباً) 78° تا 140°
// 78 نزدیک لیمویی-سبز، 140 نزدیک سبز سرد/جنگلی
  Color _varietyGreen(int i, int n) {
    final t = (n <= 1) ? 0.5 : (i / (n - 1)); // 0..1

    // ✅ انواع سبز: Hue در بازه‌ی سبزها حرکت می‌کنه
    // برای اینکه کنار هم خیلی شبیه نشه، ترتیب رو زیگزاگ می‌کنیم
    final zigzag = (i % 2 == 0) ? (i ~/ 2) : (n - 1 - (i ~/ 2));
    final tz = (n <= 1) ? 0.5 : (zigzag / (n - 1));

    final hue = 78.0 + (140.0 - 78.0) * tz; // 78..140

    // ✅ مینیمال ولی زنده: اکثراً ملایم، بعضی‌ها کمی پررنگ‌تر
    final bool isBold = (i % 4 == 0); // هر 4 تا یکی یه ذره پررنگ‌تر

    final saturation = isBold ? 0.55 : 0.38;  // ملایم/پررنگ
    final lightness  = isBold
        ? (0.52 + 0.10 * t)               // پررنگ‌ها کمی تیره‌تر
        : (0.68 + 0.12 * (1.0 - t));      // ملایم‌ها روشن‌تر

    return HSLColor.fromAHSL(1.0, hue, saturation, lightness).toColor();
  }

  List<WheelSegmentData> _buildSegments(int count) {
    return List.generate(
      count,
          (i) => WheelSegmentData(color: _varietyGreen(i, count)),
    );
  }

  Color _greenMix(int i, int n) {
    final base = HSLColor.fromColor(_baseGreen);

    // زیگزاگ برای پخش روشن/تیره
    final zigzag = (i % 2 == 0) ? (i ~/ 2) : (n - 1 - (i ~/ 2));
    final t = (n <= 1) ? 0.5 : zigzag / (n - 1); // 0..1

    // 1) بعضی قطعه‌ها پررنگ‌تر
    final isBold = (i % 3 == 0);

    // 2) بعضی قطعه‌ها زردی‌تر (yellow-green)
    // هر 4 تا یکی به سمت زرد میره
    final isYellowish = (i % 4 == 1);

    // پاستلی
    const softS = 0.30;
    const softMinL = 0.72;
    const softMaxL = 0.88;

    // پررنگ‌تر
    const boldS = 0.58;
    const boldMinL = 0.46;
    const boldMaxL = 0.70;

    final s = isBold ? boldS : softS;
    final minL = isBold ? boldMinL : softMinL;
    final maxL = isBold ? boldMaxL : softMaxL;

    final lightness = minL + (maxL - minL) * t;

    // ✅ شیفت Hue به سمت زرد (درجه)
    // سبزتر: 0..6 درجه
    // زردی‌تر: 10..18 درجه
    final hueShift = isYellowish
        ? (10.0 + 8.0 * t)  // زردی‌تر
        : (2.0 + 4.0 * t);  // خیلی کم

    // Hue wrap
    var newHue = base.hue - hueShift; // کم کردن hue => نزدیک‌تر به زرد (60°)
    if (newHue < 0) newHue += 360;

    return base
        .withHue(newHue)
        .withSaturation(s)
        .withLightness(lightness)
        .toColor();
  }
  Color _pastelGreen(int i, int n) {
    final hsl = HSLColor.fromColor(_baseGreen);

    // ✅ پاستلی = saturation کمتر
    const pastelS = 0.28;

    // ✅ ملایم = بازه روشنایی نزدیک به هم (کنتراست کم)
    const minL = 0.72;
    const maxL = 0.86;

    // ترتیب زیگزاگی برای اینکه کنار هم خیلی شبیه نشوند
    // 0, n-1, 1, n-2, ...
    final zigzag = (i % 2 == 0) ? (i ~/ 2) : (n - 1 - (i ~/ 2));
    final t = (n <= 1) ? 0.5 : zigzag / (n - 1);

    final lightness = minL + (maxL - minL) * t;

    return hsl.withSaturation(pastelS).withLightness(lightness).toColor();
  }

  Color getColorAt(int index) {
    if (index < 0 || index >= _segments.length) {
      return Colors.white;
    }
    return _segments[index].color;
  }


  // IMPORTANT: اینجا onChanged صدا نزن (وگرنه وسط انیمیشن زیاد ذخیره میشه)
  void setRotationTurns(double turns) {
    if (!mounted) return;
    setState(() => _rotationTurns = turns);
  }

  void increaseSegments() {
    setState(() {
      _segments.add(WheelSegmentData(color: Colors.transparent));
      for (int i = 0; i < _segments.length; i++) {
        _segments[i] = WheelSegmentData(
          text: _segments[i].text,
          color: _varietyGreen(i, _segments.length),
        );
      }
    });
    widget.onChanged?.call();
  }
  void decreaseSegments() {
    if (_segments.length <= 2) return;
    setState(() {
      _segments.removeLast();
      for (int i = 0; i < _segments.length; i++) {
        _segments[i] = WheelSegmentData(
          text: _segments[i].text,
          color: _varietyGreen(i, _segments.length),
        );
      }
    });
    widget.onChanged?.call();
  }
  void resetWheel() {
    setState(() {
      _rotationTurns = 0.0;
      _segments = _buildSegments(2);
    });
    widget.onChanged?.call();
  }
  String? getTextAt(int index) {
    if (index < 0 || index >= _segments.length) return null;
    return _segments[index].text;
  }

  void removeSegmentAt(int index) {
    if (_segments.length <= 2) return;
    if (index < 0 || index >= _segments.length) return;

    setState(() {
      _segments.removeAt(index);
      for (int i = 0; i < _segments.length; i++) {
        _segments[i] = WheelSegmentData(
          text: _segments[i].text,
          color: _varietyGreen(i, _segments.length),
        );
      }
    });
    widget.onChanged?.call();
  }
  Map<String, dynamic> exportState() => {
    'turns': _rotationTurns,
    'texts': _segments.map((s) => s.text ?? '').toList(),
    'colors': _segments.map((s) => s.color.value).toList(),
  };

  void importState(Map<String, dynamic> data) {
    final turns = (data['turns'] as num?)?.toDouble() ?? 0.0;
    final texts = (data['texts'] as List?)?.cast<dynamic>() ?? const [];
    final colors = (data['colors'] as List?)?.cast<dynamic>() ?? const [];

    final colorInts = colors.map((e) => (e as num).toInt()).toList();
    if (colorInts.length < 2) return;

    setState(() {
      _rotationTurns = turns;

      _segments = List.generate(colorInts.length, (i) {
        final c = Color(colorInts[i]);

        final raw = (i < texts.length) ? (texts[i]?.toString() ?? '') : '';
        final t = raw.trim();
        return WheelSegmentData(text: t.isEmpty ? null : t, color: c);
      });
    });
  }
  // ---------------------------------------

  Future<void> _onTapSegment(int index) async {
    final canDelete = segmentCount > 2;
    final action = await showModalBottomSheet<_SegmentAction>(
      context: context,
      showDragHandle: true,
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,

            children: [
              ListTile(
                title: Center(
                  child: const Text(
                    '+ Add/Edit Text',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                onTap: () => Navigator.pop(context, _SegmentAction.editText),
              ),

              if (canDelete)
                ListTile(
                  title: Center(
                    child: const Text(
                      'Delete This Segment',
                      style: TextStyle(
                        color: Color.fromRGBO(135, 38, 38, 1),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  onTap: () => Navigator.pop(context, _SegmentAction.delete),
                ),

              const SizedBox(height: 20),
            ],          ),
        );
      },
    );

    if (!mounted || action == null) return;

    if (action == _SegmentAction.delete) {
      removeSegmentAt(index);
      return;
    }

    final text = await _showTextDialog(initial: _segments[index].text);
    if (!mounted || text == null) return;

    setState(() {
      final t = text.trim();
      _segments[index].text = t.isEmpty ? null : t;
    });
    widget.onChanged?.call();
  }

  Future<String?> _showTextDialog({String? initial}) async {
    final ctrl = TextEditingController(text: initial ?? '');
    return showDialog<String?>(
      context: context,
      builder: (ctx) {
        return AlertDialog(

          content: SizedBox(
            width: 300,
            height: 100,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
              child: TextField(
                controller: ctrl,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Enter The Fated Phrase...',
                  hintStyle: TextStyle(fontSize: 12),
                  border: OutlineInputBorder(),
                ),
                minLines: 1,
                maxLines: 3,
              ),
            ),
          ),
          actions: [

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, null),
                  child: const Text('Never mind'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, ctrl.text),
                  child: const Text('Done'),
                ),
              ],
            ),


          ],
        );
      },
    );
  }

  int? _hitTestSegment(Offset localPos, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final v = localPos - center;
    final r = v.distance;
    final radius = math.min(size.width, size.height) / 2;

    if (r > radius) return null;

    final innerRadius = radius * 0.18;
    if (r < innerRadius) return null;

    var ang = math.atan2(v.dy, v.dx);
    if (ang < 0) ang += 2 * math.pi;

    // align to painter start (-pi/2 => top)
    ang = (ang + math.pi / 2) % (2 * math.pi);

    final rotRad = (_rotationTurns * 2 * math.pi) % (2 * math.pi);
    var wheelAng = ang - rotRad;
    if (wheelAng < 0) wheelAng += 2 * math.pi;

    final sweep = 2 * math.pi / _segments.length;
    return (wheelAng / sweep).floor().clamp(0, _segments.length - 1);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: LayoutBuilder(
        builder: (ctx, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);

          return GestureDetector(
            onTapDown: (details) {
              final idx = _hitTestSegment(details.localPosition, size);
              if (idx != null) _onTapSegment(idx);
            },
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Transform.rotate(
                  angle: _rotationTurns * 2 * math.pi,
                  child: CustomPaint(
                    size: size,
                    painter: WheelPainter(segments: _segments),
                  ),
                ),
                Container(
                  width: widget.size * 0.18,
                  height: widget.size * 0.18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context).colorScheme.surface,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                    boxShadow: const [
                      BoxShadow(blurRadius: 5, offset: Offset(0, 3)),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Tooltip(
                    message: 'Spin',
                    showDuration: const Duration(seconds: 3),
                    child: IconButton(
                        onPressed: widget.onCenterPressed,
                        icon: Icon(Icons.favorite),
                    ),
                  )
                ),
                Positioned(
                  top: -(widget.size * 0.10),
                  child: const SizedBox(
                    width: 28,
                    height: 28,
                    child: CustomPaint(painter: _PointerPainter()),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// ----------------------
/// Wheel painter
/// ----------------------
class WheelPainter extends CustomPainter {
  WheelPainter({required this.segments});
  final List<WheelSegmentData> segments;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;

    final bgPaint = Paint()..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = const Color(0xFF16361F).withOpacity(0.65); // مشکی با شفافیت کم

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    final sweep = 2 * math.pi / segments.length;
    var start = -math.pi / 2;

    for (var i = 0; i < segments.length; i++) {
      bgPaint.color = segments[i].color;

      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..arcTo(
          Rect.fromCircle(center: center, radius: radius),
          start,
          sweep,
          false,
        )
        ..close();

      canvas.drawPath(path, bgPaint);
      canvas.drawPath(path, borderPaint);

      canvas.save();
      canvas.clipPath(path);

      final seg = segments[i];
      if (seg.text != null && seg.text!.isNotEmpty) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: seg.text!,
            style: const TextStyle(
              fontFamily: 'myFonts2',
              fontFamilyFallback: const ['Vazir'],
              fontSize: 16,
              height: 1.1,
              fontWeight: FontWeight.w600,
              color: kOnDark,
            ),
          ),
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
          maxLines: 3,
          ellipsis: '…',
        )..layout(maxWidth: radius * 0.9);

        final midAng = start + sweep / 2;
        final pos =
            center + Offset(math.cos(midAng), math.sin(midAng)) * (radius * 0.55);

        canvas.save();
        canvas.translate(pos.dx, pos.dy);
        // زاویه متن رو دست نزدیم (همون قبلی شما)
        canvas.rotate(midAng + math.pi / 2);
        canvas.translate(-textPainter.width / 2, -textPainter.height / 2);
        textPainter.paint(canvas, Offset.zero);
        canvas.restore();
      }

      canvas.restore();
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant WheelPainter oldDelegate) {
    if (oldDelegate.segments.length != segments.length) return true;
    for (var i = 0; i < segments.length; i++) {
      final a = oldDelegate.segments[i];
      final b = segments[i];
      if (a.text != b.text) return true;
      if (a.color.value != b.color.value) return true;
    }
    return false;
  }
}

/// Pointer painter (TIP -> DOWN, towards wheel)
class _PointerPainter extends CustomPainter {
  const _PointerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final p = Path()
      ..moveTo(size.width / 2, size.height) // TIP پایین (به سمت دایره)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..close();

    canvas.drawPath(p, Paint()..color = kOnDark);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}