// lib/main.dart
// Stick Figure SDF Basketball - Pure Black & White Line-Animation Style with Left-Click Power & Up-Bob Boost
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
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
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

  // Left-Click Power Shot & Aiming
  bool _isAiming = false;
  Offset? _leftClickStart;
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
    _leftClickStart = null;
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

    // Left-Click Power Charge smooth rhythmic oscillation
    if (_isAiming) {
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

  // Pointer event handlers: ONLY LEFT CLICK IS USED
  void _onPointerDown(PointerDownEvent event) {
    if (_physics.isFlying || _waitingForReset) return;

    // Only respond to Primary button (Left Click or Touch)
    if (event.buttons & kPrimaryMouseButton != 0) {
      _isAiming = true;
      _leftClickStart = event.localPosition;
      _chargeDirection = 1.0;
      _player.startAiming();
      _updateAimFromCursor(event.localPosition);
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_isAiming) {
      _updateAimFromCursor(event.localPosition);

      // If user drags while holding left click, also adjust power with drag distance
      if (_leftClickStart != null) {
        final delta = _leftClickStart! - event.localPosition;
        final dragLen = delta.distance;
        if (dragLen > 14.0) {
          _player.aimPower = (dragLen / 150.0).clamp(0.25, 1.0);
        }
      }
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    if (_isAiming) {
      _isAiming = false;
      _leftClickStart = null;
      _throwBall();
    }
  }

  void _updateAimFromCursor(Offset localPos) {
    final size = MediaQuery.of(context).size;
    final scale = size.width / 16.0;
    final playerScreenX = _player.position.x * scale;
    final playerScreenY = size.height - (_player.position.y * scale) - (scale * 1.0);

    final dx = localPos.dx - playerScreenX;
    final dy = playerScreenY - localPos.dy; // Inverted in screen coordinates
    if (dx.abs() > 4.0 || dy.abs() > 4.0) {
      final angle = math.atan2(dy, dx).clamp(0.18, 1.45);
      _player.aimAngle = angle;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.space && !_physics.isFlying && !_waitingForReset) {
              _throwBall();
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
              _player.updateAim(_player.aimAngle + 0.05, _player.aimPower);
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
              _player.updateAim(_player.aimAngle - 0.05, _player.aimPower);
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.arrowRight || event.logicalKey == LogicalKeyboardKey.tab) {
              _player.nextSpot();
              _resetToCurrentSpot(changeHeight: true);
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: Stack(
          children: [
            // Interactive Outline SDF Game Canvas (Left-Click Driven)
            Positioned.fill(
              child: Listener(
                onPointerDown: _onPointerDown,
                onPointerMove: _onPointerMove,
                onPointerUp: _onPointerUp,
                child: CustomPaint(
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
              ),
            ),

            // Top HUD: Score, Streak, Highscore, and Spot
            Positioned(
              top: 16,
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
                        // Score & Best Badges
                        Row(
                          children: [
                            _buildGlassCard(
                              child: Row(
                                children: [
                                  const Icon(Icons.sports_basketball, color: Colors.white, size: 26),
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
                                          fontSize: 22,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
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
                            const SizedBox(width: 10),
                            // Dynamic Basket Height Level Badge
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

                        // Middle Streak / Fire Badge
                        if (_streak > 0)
                          _buildGlassCard(
                            borderColor: Colors.white,
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.bolt,
                                  color: Colors.white,
                                  size: 24,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _streak >= 3 ? "STREAK x$_streak [FIRE!]" : "STREAK x$_streak",
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Court Spot Switcher & Height Reroll
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
                                        fontSize: 14,
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

            // Bottom Instructions Banner highlighting LEFT-CLICK only and Up-Bob Boost
            Positioned(
              bottom: 12,
              left: 16,
              right: 16,
              child: SafeArea(
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.touch_app, size: 16, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            "HOLD LEFT-CLICK: Aim & Charge Power • Time with Upward Bob for +BOOST! • Release to Throw",
                            style: TextStyle(
                              fontSize: 12,
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
        ),
      ),
    );
  }

  Widget _buildGlassCard({required Widget child, Color? borderColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF14161C).withValues(alpha: 0.9),
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
