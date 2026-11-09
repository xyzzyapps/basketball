# Stick Figure Basketball

A minimalist black & white stick figure line-art basketball shooting game with signed distance field (SDF) rendering and real-time physics simulation, built in Flutter and Dart.

## Features

- **Classic Line-Art Animation**: Clean black and white aesthetic inspired by stick figure animator line styles.
- **Continuous Rhythm Bobbing & Boost**: The shooter bobs continuously up and down; timing your release with the upward bob grants a launch boost (`▲ BOOST!`).
- **Dynamic Basket Heights**: Random hoop heights every turn with solved parabolic trajectory physics ensuring every target is mathematically reachable.
- **SDF Shader & Vector Fallback**: Custom GLSL fragment shader rendering the court, pole, backboard, rim, woven net, and stick figure, with Canvas vector fallback.
- **Left-Click Controls**: Aim with the mouse and hold left-click to charge power, then release to shoot.
- **Twitter / X Player Card Ready**: Configured for seamless iframe embedding in Twitter/X Player Cards with touch-action optimizations and overscroll prevention.

## Controls

- **Left-Click Hold**: Charge shot power.
- **Left-Click Release**: Fire the basketball.
- **Mouse Move**: Aim trajectory.
- **Space**: Switch shooter distance / spot.
- **R**: Reset current turn.

## Web & Twitter / X Player Card

The web distribution is pre-configured with Twitter Player Card meta tags and full-viewport iframe styling:

- **Card Type**: `player` (640x360)
- **Hosted Target**: `https://xyzzyapps.github.io/basketball/`

## Running Locally

```bash
flutter pub get
flutter run -d chrome
```

## Running Tests

```bash
flutter test
```

## License

Copyright (c) 2026 Xyzzy Apps <xyzzyapps@gmail.com>. All rights reserved.
