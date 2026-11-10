// lib/main.dart
// Stick Figure SDF Basketball - Pure Black & White Line-Animation Style
// Fully responsive across Desktop & Mobile (Horizontal Landscape & Vertical Portrait) with Touch Events
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'sdf_math.dart';
import 'physics.dart';
import 'stick_man.dart';
import 'game_painter.dart';
import 'audio.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Support all orientations on mobile devices
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const StickBasketballApp());
}

class StickBasketballApp extends StatelessWidget {
  const StickBasketballApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stick Figure Basketball',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0C0E12),
        colorScheme: const ColorScheme.dark(
          primary: Colors.white,
          secondary: Colors.white70,
        ),
      ),
      home: const BasketballGameScreen(),
    );
  }
}

class BasketballGameScreen extends StatefulWidget {
  const BasketballGameScreen({super.key});

  @override
  State<BasketballGameScreen> createState() => _BasketballGameScreenState();
}

class _BasketballGameScreenState extends State<BasketballGameScreen>
    with SingleTickerProviderStateMixin {
  ui.FragmentShader? _shader;

  late final AnimationController _ticker;
  final PhysicsEngine _physics = PhysicsEngine();
  final StickManController _player = StickManController();

  double _gameTime = 0.0;
  double _lastFrameTime = 0.0;

  // Game stats
  int _score = 0;
  int _highScore = 0;
  int _streak = 0;
  double _scoreFlash = 0.0;

  // Touch & Pointer state (Left-Click or Mobile Finger Touch)
  bool _isAiming = false;
  bool _isDragging = false;
  int? _activePointerId;
  Offset? _touchStart;
  double _chargeDirection = 1.0;

  final List<Particle> _particles = [];
  final List<FloatingText> _floatingTexts = [];

  // Reset timer after shot finishes
  double _postShotTimer = 0.0;
  bool _waitingForReset = false;

  @override
  void initState() {
    super.initState();
    _loadShader();
    _resetToCurrentSpot(changeHeight: false);

    _ticker = AnimationController.unbounded(vsync: this)
      ..addListener(_onTick);
    _ticker.repeat(min: 0, max: 1, period: const Duration(milliseconds: 16));
  }

  Future<void> _loadShader() async {
    try {
      final program = await ui.FragmentProgram.fromAsset('shaders/sdf_scene.frag');
      setState(() {
        _shader = program.fragmentShader();
      });
    } catch (e) {
      debugPrint("Fragment shader load note: $e");
    }
  }

  // Adjust basket height for every turn!
  void _resetToCurrentSpot({bool changeHeight = true}) {
    _player.returnToIdle();
    if (changeHeight) {
      _physics.randomizeHoopHeight();
    }
    final ballStart = _player.getBallHoldPosition();
    _physics.resetBall(ballStart);
    _waitingForReset = false;
    _postShotTimer = 0.0;
    _isAiming = false;
    _isDragging = false;
    _activePointerId = null;
    _touchStart = null;
  }

  void _onTick() {
    final now = DateTime.now().millisecondsSinceEpoch / 1000.0;
    if (_lastFrameTime == 0.0) _lastFrameTime = now;
    final dt = (now - _lastFrameTime).clamp(0.001, 0.033);
    _lastFrameTime = now;
    _gameTime += dt;

    // Decay score flash
    if (_scoreFlash > 0.0) {
      _scoreFlash = math.max(0.0, _scoreFlash - dt * 2.0);
    }

    // Smooth rhythmic power charging when holding without dragging
    if (_isAiming && !_isDragging) {
      _player.aimPower += _chargeDirection * dt * 0.95;
      if (_player.aimPower >= 1.0) {
        _player.aimPower = 1.0;
        _chargeDirection = -1.0;
      } else if (_player.aimPower <= 0.25) {
        _player.aimPower = 0.25;
        _chargeDirection = 1.0;
      }
    }

    // Update player animation (includes continuous bobbing!)
    _player.update(dt);

    // If ball not in flight, keep it in player's shooting pocket (following the bob!)
    if (!_physics.isFlying && !_waitingForReset) {
      _physics.ballPos = _player.getBallHoldPosition();
    }

    // Update Physics simulation
    _physics.update(dt, onSound: (type, intensity) {
      GameAudio.play(type, intensity);
      if (type == 'rim' || type == 'backboard') {
        _spawnSparks(_physics.ballPos, 6, Colors.white);
      }
    });

    // Check shot outcome
    if (_physics.isFlying && !_waitingForReset) {
      if (_physics.lastResult == ShotResult.scored) {
        _onScore();
      } else if (_physics.lastResult == ShotResult.missed) {
        _onMiss();
      } else if (_physics.flightTime > 3.0) {
        // Safety anti-stuck check: force miss if ball is flying > 3.0 seconds
        _onMiss();
      }
    }

    // Handle post-shot reset delay (triggers new basket height for the next turn!)
    if (_waitingForReset) {
      _postShotTimer += dt;
      if (_postShotTimer > 1.2) {
        _resetToCurrentSpot(changeHeight: true);
      }
    }

    // Update particles
    _particles.removeWhere((p) => !p.update(dt));
    _floatingTexts.removeWhere((ft) => !ft.update(dt));

    setState(() {});
  }

  void _onScore() {
    _waitingForReset = true;
    _postShotTimer = 0.0;
    _streak++;
    _scoreFlash = 1.0;

    // Calculate score
    final spotPoints = _player.currentSpot.points;
    final isSwish = _physics.scoreType.contains("SWISH");
    final bonus = isSwish ? 3 : (_physics.scoreType.contains("BANK") ? 2 : 1);
    final multiplier = _streak >= 3 ? 2 : 1;
    final earned = (spotPoints + bonus) * multiplier;

    _score += earned;
    if (_score > _highScore) _highScore = _score;

    GameAudio.play('score', 1.0);
    _player.celebrate();

    // Spawn floating score banner
    final bannerText = _streak >= 3 ? "${_physics.scoreType} [FIRE x2!]" : _physics.scoreType;
    _floatingTexts.add(FloatingText(
      pos: Vec2(12.8, _physics.hoopY + 0.55),
      text: bannerText,
      color: Colors.white,
    ));

    // Spawn white victory sparks around rim
    _spawnSparks(Vec2(12.8, _physics.hoopY), 24, Colors.white);
  }

  void _onMiss() {
    _waitingForReset = true;
    _postShotTimer = 0.0;
    _streak = 0;
    _player.miss();

    _floatingTexts.add(FloatingText(
      pos: _physics.ballPos + const Vec2(0, 0.4),
      text: "MISSED!",
      color: const Color(0xFFE0E0E0),
    ));
  }

  void _spawnSparks(Vec2 pos, int count, Color color) {
    final rand = math.Random();
    for (int i = 0; i < count; i++) {
      final angle = rand.nextDouble() * math.pi * 2;
      final speed = 1.5 + rand.nextDouble() * 4.5;
      _particles.add(Particle(
        pos: pos,
        vel: Vec2(math.cos(angle) * speed, math.sin(angle) * speed),
        color: color,
        maxLife: 0.5 + rand.nextDouble() * 0.6,
        size: 2.0 + rand.nextDouble() * 3.5,
      ));
    }
  }

  // ---------------------------------------------------------------------------
  // Touch & Pointer event handlers (Universal for Mouse, Touch Screens & Stylus)
  // ---------------------------------------------------------------------------
  void _onPointerDown(PointerDownEvent event, Size courtSize) {
    if (_physics.isFlying || _waitingForReset) return;

    // Accept touch devices, stylus, or primary mouse button
    final isPrimary = event.kind == PointerDeviceKind.touch ||
        event.kind == PointerDeviceKind.stylus ||
        (event.buttons & kPrimaryMouseButton != 0) ||
        event.buttons == 0;
    if (!isPrimary) return;

    _activePointerId = event.pointer;
    _isAiming = true;
    _isDragging = false;
    _touchStart = event.localPosition;
    _chargeDirection = 1.0;
    _player.startAiming();
    _updateAimFromCursor(event.localPosition, courtSize);
  }

  void _onPointerMove(PointerMoveEvent event, Size courtSize) {
    if (_isAiming && event.pointer == _activePointerId) {
      _updateAimFromCursor(event.localPosition, courtSize);

      // If user drags while holding, adjust power with drag distance
      if (_touchStart != null) {
        final delta = _touchStart! - event.localPosition;
        final dragLen = delta.distance;
        if (dragLen > 10.0) {
          _isDragging = true;
          final scale = courtSize.width / 16.0;
          _player.aimPower = (dragLen / (scale * 3.6)).clamp(0.25, 1.0);
        }
      }
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    if (_isAiming && event.pointer == _activePointerId) {
      _isAiming = false;
      _isDragging = false;
      _activePointerId = null;
      _touchStart = null;
      _throwBall();
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (_isAiming && event.pointer == _activePointerId) {
      _isAiming = false;
      _isDragging = false;
      _activePointerId = null;
      _touchStart = null;
      _player.returnToIdle();
    }
  }

  void _updateAimFromCursor(Offset localPos, Size courtSize) {
    final scale = courtSize.width / 16.0;
    final playerScreenX = _player.position.x * scale;
    final playerScreenY = (9.0 - (_player.position.y + 1.15)) * scale;

    final dx = localPos.dx - playerScreenX;
    final dy = playerScreenY - localPos.dy; // Inverted in screen coordinates

    if (dx.abs() > 4.0 || dy.abs() > 4.0) {
      double angle;
      if (dx >= 0) {
        // Aiming forward towards the basket
        angle = math.atan2(dy, dx);
      } else {
        // Pulling backward (slingshot style drag)
        angle = math.atan2(-dy, -dx);
      }
      _player.aimAngle = angle.clamp(0.18, 1.48);
    }
  }

  void _throwBall() {
    _player.releaseThrow();
    final startPos = _player.getBallHoldPosition();
    _physics.ballPos = startPos;

    // Up-bob boost adds extra launch speed if released while bobbing up!
    final boost = _player.currentUpBobBoost;
    if (boost > 0.8) {
      _floatingTexts.add(FloatingText(
        pos: _player.position + const Vec2(0.3, 2.2),
        text: "▲ BOOST!",
        color: const Color(0xFFFFD54F),
        maxLife: 0.9,
      ));
    }

    _physics.launch(_player.aimAngle, _player.aimPower, boost);
    GameAudio.play('throw', _player.aimPower);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Responsive Build: Automatically adapts to Horizontal (Landscape) or Vertical (Portrait)
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isPortrait = media.size.height > media.size.width;

    return Scaffold(
      backgroundColor: const Color(0xFF0C0E12),
      body: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.space &&
                !_physics.isFlying &&
                !_waitingForReset) {
              _throwBall();
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
              _player.updateAim(_player.aimAngle + 0.05, _player.aimPower);
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
              _player.updateAim(_player.aimAngle - 0.05, _player.aimPower);
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
                event.logicalKey == LogicalKeyboardKey.tab) {
              _player.nextSpot();
              _resetToCurrentSpot(changeHeight: true);
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.keyR) {
              _resetToCurrentSpot(changeHeight: true);
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: isPortrait ? _buildPortraitLayout(context) : _buildLandscapeLayout(context),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 1. HORIZONTAL (LANDSCAPE) VIEW
  // ---------------------------------------------------------------------------
  Widget _buildLandscapeLayout(BuildContext context) {
    return Stack(
      children: [
        // Center the 16:9 Basketball Court
        Center(
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final courtSize = Size(constraints.maxWidth, constraints.maxHeight);
                return Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (e) => _onPointerDown(e, courtSize),
                  onPointerMove: (e) => _onPointerMove(e, courtSize),
                  onPointerUp: _onPointerUp,
                  onPointerCancel: _onPointerCancel,
                  child: CustomPaint(
                    size: courtSize,
                    painter: GamePainter(
                      shader: _shader,
                      physics: _physics,
                      player: _player,
                      time: _gameTime,
                      streak: _streak,
                      scoreFlash: _scoreFlash,
                      isAiming: _isAiming,
                      particles: _particles,
                      floatingTexts: _floatingTexts,
                    ),
                  ),
                );
              },
            ),
          ),
        ),

        // Top Floating HUD
        Positioned(
          top: 12,
          left: 16,
          right: 16,
          child: SafeArea(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: math.max(720.0, MediaQuery.of(context).size.width - 32.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Score, Best, Hoop Height
                    Row(
                      children: [
                        _buildGlassCard(
                          child: Row(
                            children: [
                              const Icon(Icons.sports_basketball, color: Colors.white, size: 24),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    "SCORE",
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white60,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  Text(
                                    "$_score",
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildGlassCard(
                          child: Row(
                            children: [
                              const Icon(Icons.emoji_events, color: Colors.white70, size: 20),
                              const SizedBox(width: 6),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    "BEST",
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white54,
                                    ),
                                  ),
                                  Text(
                                    "$_highScore",
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildGlassCard(
                          child: Row(
                            children: [
                              const Icon(Icons.height, color: Colors.white, size: 20),
                              const SizedBox(width: 6),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    "HOOP HEIGHT",
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white54,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                  Text(
                                    "${(_physics.hoopY / 5.85 * 10.0).toStringAsFixed(1)} FT",
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // Streak Badge
                    if (_streak > 0)
                      _buildGlassCard(
                        borderColor: Colors.white,
                        child: Row(
                          children: [
                            const Icon(Icons.bolt, color: Colors.white, size: 22),
                            const SizedBox(width: 6),
                            Text(
                              _streak >= 3 ? "STREAK x$_streak [FIRE!]" : "STREAK x$_streak",
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Controls: Spot, Reroll, Reset
                    Row(
                      children: [
                        PopupMenuButton<int>(
                          tooltip: "Change Spot",
                          initialValue: _player.currentSpotIndex,
                          onSelected: (idx) {
                            _player.setSpotIndex(idx);
                            _resetToCurrentSpot(changeHeight: true);
                          },
                          itemBuilder: (ctx) => [
                            for (int i = 0; i < StickManController.spots.length; i++)
                              PopupMenuItem(
                                value: i,
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.place,
                                      size: 18,
                                      color: i == _player.currentSpotIndex
                                          ? Colors.white
                                          : Colors.grey,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      "${StickManController.spots[i].name} (${StickManController.spots[i].points} pts)",
                                      style: TextStyle(
                                        fontWeight: i == _player.currentSpotIndex
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                          child: _buildGlassCard(
                            child: Row(
                              children: [
                                const Icon(Icons.my_location, color: Colors.white, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  _player.currentSpot.name,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const Icon(Icons.arrow_drop_down, color: Colors.white70),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: "Reroll Hoop Height & Reset",
                          icon: const Icon(Icons.refresh, color: Colors.white),
                          onPressed: () => _resetToCurrentSpot(changeHeight: true),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Bottom Touch Instructions
        Positioned(
          bottom: 10,
          left: 16,
          right: 16,
          child: SafeArea(
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.touch_app, size: 16, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        "TOUCH / CLICK & HOLD: Charge Power • Time with Upward Bob for +BOOST! • Release to Throw",
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 2. VERTICAL (PORTRAIT) VIEW: Mobile-Optimized with Arcade Touch Console
  // ---------------------------------------------------------------------------
  Widget _buildPortraitLayout(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          // 1. Compact Top Stats Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Score & Best
                Row(
                  children: [
                    _buildGlassCard(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      child: Row(
                        children: [
                          const Icon(Icons.sports_basketball, color: Colors.white, size: 20),
                          const SizedBox(width: 6),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                "SCORE",
                                style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white60),
                              ),
                              Text(
                                "$_score",
                                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Colors.white),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    _buildGlassCard(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            "BEST",
                            style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white54),
                          ),
                          Text(
                            "$_highScore",
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Streak Fire (if active)
                if (_streak > 0)
                  _buildGlassCard(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    borderColor: Colors.white,
                    child: Row(
                      children: [
                        const Icon(Icons.bolt, color: Colors.white, size: 16),
                        Text(
                          "x$_streak",
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white),
                        ),
                      ],
                    ),
                  ),

                // Hoop Height & Sound Toggle
                Row(
                  children: [
                    _buildGlassCard(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            "HOOP HEIGHT",
                            style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white54),
                          ),
                          Text(
                            "${(_physics.hoopY / 5.85 * 10.0).toStringAsFixed(1)} FT",
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      iconSize: 20,
                      icon: Icon(
                        GameAudio.soundEnabled ? Icons.volume_up : Icons.volume_off,
                        color: Colors.white70,
                      ),
                      onPressed: () {
                        setState(() {
                          GameAudio.toggleSound();
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 2. 16:9 Basketball Court (Direct Touch Enabled)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white30, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.8),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final courtSize = Size(constraints.maxWidth, constraints.maxHeight);
                  return Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: (e) => _onPointerDown(e, courtSize),
                    onPointerMove: (e) => _onPointerMove(e, courtSize),
                    onPointerUp: _onPointerUp,
                    onPointerCancel: _onPointerCancel,
                    child: CustomPaint(
                      size: courtSize,
                      painter: GamePainter(
                        shader: _shader,
                        physics: _physics,
                        player: _player,
                        time: _gameTime,
                        streak: _streak,
                        scoreFlash: _scoreFlash,
                        isAiming: _isAiming,
                        particles: _particles,
                        floatingTexts: _floatingTexts,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // 3. Mobile Arcade Touch Console (Fills lower screen comfortably)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Spot Quick Selector Pills (Horizontally scrollable for any screen width)
                  SizedBox(
                    height: 48,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: StickManController.spots.length,
                      separatorBuilder: (context, index) => const SizedBox(width: 8),
                      itemBuilder: (ctx, i) {
                        final spot = StickManController.spots[i];
                        final isSelected = i == _player.currentSpotIndex;
                        return InkWell(
                          onTap: () {
                            _player.setSpotIndex(i);
                            _resetToCurrentSpot(changeHeight: true);
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.white : const Color(0xFF14161C),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected ? Colors.white : Colors.white24,
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  spot.name.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                    color: isSelected ? Colors.black : Colors.white,
                                  ),
                                ),
                                Text(
                                  "${spot.points} PTS",
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? Colors.black54 : Colors.white54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Large Thumb-Friendly Mobile Aim & Shoot Touchpad
                  _buildMobileTouchPad(),

                  // Quick Action Buttons & Rotation Tip
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Reroll Height Button
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white24),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => _resetToCurrentSpot(changeHeight: true),
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text("REROLL HEIGHT", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 12),
                        // Reset Shot Turn
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white24),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => _resetToCurrentSpot(changeHeight: false),
                          icon: const Icon(Icons.replay, size: 16),
                          label: const Text("RESET TURN", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),

                  // Rotation Tip
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.screen_rotation, size: 14, color: Colors.white54),
                          SizedBox(width: 6),
                          Text(
                            "Rotate phone sideways for stadium view",
                            style: TextStyle(fontSize: 10, color: Colors.white54, letterSpacing: 0.4),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Large Interactive Mobile Aim & Shoot Touchpad for Portrait mode
  Widget _buildMobileTouchPad() {
    final isUp = _player.isBobbingUp;
    final boost = _player.currentUpBobBoost;

    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (event) {
        if (_physics.isFlying || _waitingForReset) return;
        _activePointerId = event.pointer;
        _isAiming = true;
        _isDragging = false;
        _touchStart = event.localPosition;
        _chargeDirection = 1.0;
        _player.startAiming();
      },
      onPointerMove: (event) {
        if (_isAiming && event.pointer == _activePointerId && _touchStart != null) {
          final delta = event.localPosition - _touchStart!;
          final dist = delta.distance;
          if (dist > 8.0) {
            _isDragging = true;
            // Up/down drag changes angle
            final angleDelta = -delta.dy * 0.006;
            _player.aimAngle = (_player.aimAngle + angleDelta).clamp(0.18, 1.48);
            // Distance changes power
            _player.aimPower = (dist / 110.0).clamp(0.25, 1.0);
          }
        }
      },
      onPointerUp: (event) {
        if (_isAiming && event.pointer == _activePointerId) {
          _isAiming = false;
          _isDragging = false;
          _activePointerId = null;
          _touchStart = null;
          _throwBall();
        }
      },
      onPointerCancel: (event) {
        if (_isAiming && event.pointer == _activePointerId) {
          _isAiming = false;
          _isDragging = false;
          _activePointerId = null;
          _touchStart = null;
          _player.returnToIdle();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: double.infinity,
        height: 125,
        decoration: BoxDecoration(
          color: _isAiming
              ? Colors.white.withValues(alpha: 0.12)
              : const Color(0xFF14161C),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _isAiming
                ? (isUp ? const Color(0xFFFFD54F) : Colors.white)
                : Colors.white24,
            width: _isAiming ? 2.5 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: _isAiming
                  ? (isUp
                      ? const Color(0xFFFFD54F).withValues(alpha: 0.3)
                      : Colors.white.withValues(alpha: 0.2))
                  : Colors.black.withValues(alpha: 0.5),
              blurRadius: _isAiming ? 18 : 8,
              spreadRadius: _isAiming ? 2 : 0,
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Power progress background bar
            if (_isAiming)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: MediaQuery.of(context).size.width * _player.aimPower,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
              ),

            // Content
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.touch_app,
                          size: 26,
                          color: _isAiming
                              ? (isUp ? const Color(0xFFFFD54F) : Colors.white)
                              : Colors.white70,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isAiming
                              ? "POWER: ${(_player.aimPower * 100).toInt()}% • ANGLE: ${(_player.aimAngle * 180 / math.pi).toInt()}°"
                              : "HOLD TO CHARGE • RELEASE TO SHOOT",
                          style: TextStyle(
                            fontSize: _isAiming ? 14 : 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                            color: _isAiming
                                ? (isUp ? const Color(0xFFFFD54F) : Colors.white)
                                : Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                // Up-Bob Boost Alert
                if (isUp && boost > 0.8)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD54F),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      "▲ UP-BOOST READY! RELEASE NOW",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                        letterSpacing: 0.8,
                      ),
                    ),
                  )
                else
                  Text(
                    _isAiming
                        ? "Drag up/down to adjust angle • Drag distance adjusts power"
                        : "Tap court directly or hold this pad to charge your shot",
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.white54,
                      letterSpacing: 0.2,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassCard({
    required Widget child,
    Color? borderColor,
    EdgeInsetsGeometry? padding,
  }) {
    return Container(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF14161C).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: borderColor ?? Colors.white.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}
