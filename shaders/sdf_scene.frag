#version 460 core

#include <flutter/runtime_effect.glsl>

// Uniforms mapped linearly in Flutter:
// index 0,1: uResolution (vec2)
// index 2:   uTime (float)
// index 3,4: uBallPos (vec2)
// index 5:   uBallRadius (float)
// index 6:   uBallRot (float)
// index 7,8: uCharPos (vec2)
// index 9:   uAimAngle (float)
// index 10:  uAimPower (float)
// index 11:  uCharState (float) 0=idle, 1=aim, 2=throw, 3=celebrate, 4=miss
// index 12:  uThrowProgress (float)
// index 13,14: uNetFlex (vec2)
// index 15:  uStreak (float)
// index 16:  uScoreFlash (float)
// index 17:  uHoopY (float) - dynamic height for every turn!

uniform vec2 uResolution;
uniform float uTime;
uniform vec2 uBallPos;
uniform float uBallRadius;
uniform float uBallRot;
uniform vec2 uCharPos;
uniform float uAimAngle;
uniform float uAimPower;
uniform float uCharState;
uniform float uThrowProgress;
uniform vec2 uNetFlex;
uniform float uStreak;
uniform float uScoreFlash;
uniform float uHoopY;

out vec4 fragColor;

// -----------------------------------------------------------------------------
// SDF PRIMITIVES & OPERATORS
// -----------------------------------------------------------------------------

float sdCircle(vec2 p, float r) {
    return length(p) - r;
}

float sdBox(vec2 p, vec2 b) {
    vec2 d = abs(p) - b;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

float sdRoundedBox(vec2 p, vec2 b, vec4 r) {
    r.xy = (p.x > 0.0) ? r.xy : r.zw;
    r.x  = (p.y > 0.0) ? r.x  : r.y;
    vec2 q = abs(p) - b + r.x;
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r.x;
}

float sdSegment(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

float sdCapsule(vec2 p, vec2 a, vec2 b, float r) {
    return sdSegment(p, a, b) - r;
}

// Hollow outline of an SDF shape
float opOnion(float d, float thickness) {
    return abs(d) - thickness;
}

mat2 rotate2D(float angle) {
    float c = cos(angle), s = sin(angle);
    return mat2(c, -s, s, c);
}

// -----------------------------------------------------------------------------
// AUTHENTIC BLACK & WHITE LINE ANIMATION SHADER (Xiao Xiao / Pivot Style)
// -----------------------------------------------------------------------------

void main() {
    vec2 fragCoord = FlutterFragCoord().xy;
    // World coordinates: X: [0.0, 16.0], Y: [0.0, 9.0]
    float scale = uResolution.x / 16.0;
    vec2 p = vec2(fragCoord.x / scale, (uResolution.y - fragCoord.y) / scale);
    float px = 1.0 / scale; // Screen pixel size for anti-aliasing

    // Deep chalkboard black canvas
    vec3 col = vec3(0.04, 0.04, 0.05);

    // Stroke width for line animation
    float lineStroke = 0.022;

    // 1. COURT GROUND LINE (Clean White Line Art)
    float floorY = 2.0;
    float dGroundLine = abs(p.y - floorY) - lineStroke;
    // Dashed lines for court key & marks
    float dTick1 = opOnion(sdSegment(p, vec2(5.2, floorY), vec2(5.2, floorY + 0.12)), 0.014);
    float dTick2 = opOnion(sdSegment(p, vec2(3.6, floorY), vec2(3.6, floorY + 0.12)), 0.014);
    float dTick3 = opOnion(sdSegment(p, vec2(1.8, floorY), vec2(1.8, floorY + 0.12)), 0.014);
    float dCourt = min(dGroundLine, min(dTick1, min(dTick2, dTick3)));
    col = mix(col, vec3(0.95), smoothstep(px, -px, dCourt));

    // 2. BASKETBALL HOOP & STAND (Hollow White Line Outlines, Dynamic Height uHoopY)
    float hoopY = (uHoopY > 3.0 && uHoopY < 8.5) ? uHoopY : 5.85;

    // Wireframe Stand Pole (Dual parallel lines)
    float dPoleL = abs(p.x - 14.50) - 0.012;
    float dPoleR = abs(p.x - 14.70) - 0.012;
    float dPole = max(min(dPoleL, dPoleR), p.y - 8.2);
    // Cross braces on pole
    float crossY = mod(p.y - 2.0, 0.8) - 0.4;
    float dPoleCross = sdSegment(vec2(p.x, crossY), vec2(14.50, -0.4), vec2(14.70, 0.4)) - 0.010;
    dPole = min(dPole, dPoleCross);

    // Cantilever Support Bracket to Backboard
    float dOverhang = opOnion(sdSegment(p, vec2(14.60, hoopY + 0.40), vec2(13.55, hoopY + 0.40)), 0.018);
    float dSupportBrace = opOnion(sdSegment(p, vec2(14.60, hoopY - 0.45), vec2(13.65, hoopY + 0.35)), 0.014);
    float dStand = min(dPole, min(dOverhang, dSupportBrace));
    col = mix(col, vec3(0.75), smoothstep(px, -px, dStand));

    // Backboard Outline (Hollow Rectangle)
    vec2 bbCenter = vec2(13.55, hoopY + 0.40);
    vec2 bbHalf = vec2(0.08, 0.85);
    float dBackboardOutline = opOnion(sdRoundedBox(p - bbCenter, bbHalf, vec4(0.02)), lineStroke);
    // Inner Target Box Outline (Hollow Rectangle)
    vec2 targetCenter = vec2(13.48, hoopY + 0.28);
    vec2 targetHalf = vec2(0.015, 0.26);
    float dTargetOutline = opOnion(sdBox(p - targetCenter, targetHalf), 0.016);
    float dBoard = min(dBackboardOutline, dTargetOutline);
    col = mix(col, vec3(1.0), smoothstep(px, -px, dBoard));

    // Rim Outline (Clean White Line Oval/Capsule from 12.20 to 13.45)
    vec2 rimFront = vec2(12.20, hoopY);
    vec2 rimBack  = vec2(13.45, hoopY);
    float dRimLine = opOnion(sdCapsule(p, rimFront, rimBack, 0.038), 0.018);
    float dRimLipF = opOnion(sdCircle(p - rimFront, 0.055), 0.018);
    float dRimLipB = opOnion(sdCircle(p - rimBack, 0.055), 0.018);
    float dRim = min(dRimLine, min(dRimLipF, dRimLipB));
    col = mix(col, vec3(1.0), smoothstep(px, -px, dRim));

    // Woven Net (Wireframe diamond line mesh with dynamic flex)
    vec2 flex = uNetFlex;
    float netTop = hoopY;
    float netBottom = hoopY - 1.1;
    if (p.y < netTop && p.y > netBottom && p.x > 12.0 && p.x < 13.6) {
        float netT = (netTop - p.y) / 1.1;
        float leftX  = mix(12.22, 12.58, netT) + flex.x * netT;
        float rightX = mix(13.43, 13.07, netT) + flex.x * netT;
        if (p.x >= leftX && p.x <= rightX) {
            float diagA = fract((p.x * 6.5 + p.y * 6.5) + flex.x * 0.5);
            float diagB = fract((p.x * 6.5 - p.y * 6.5) - flex.x * 0.5);
            float strand = min(abs(diagA - 0.5), abs(diagB - 0.5));
            float netLine = smoothstep(0.12, 0.03, strand);
            col = mix(col, vec3(0.92), netLine * 0.95);
        }
    }

    // 3. STICK FIGURE BASKETBALL PLAYER (Classic Animation Hollow Line Style)
    vec2 root = uCharPos;
    float state = uCharState; // 0=idle, 1=aim, 2=throw, 3=celebrate, 4=miss
    float throwT = uThrowProgress;

    // Crouch & Jump kinematics
    float crouch = 0.0;
    if (state == 1.0) {
        crouch = 0.16 * uAimPower;
    } else if (state == 2.0) {
        crouch = -0.12 * (1.0 - throwT);
    } else if (state == 3.0) {
        crouch = -0.22 * abs(sin(uTime * 6.0));
    }

    vec2 hips = root + vec2(0.0, 1.05 - crouch);
    vec2 footL = root + vec2(-0.25, 0.04);
    vec2 footR = root + vec2(0.22, 0.04);
    if (crouch < -0.05) {
        footL.y += (-crouch) * 0.6;
        footR.y += (-crouch) * 0.6;
    }

    vec2 kneeL = (hips + footL) * 0.5 + vec2(crouch * 0.8 + 0.08, 0.0);
    vec2 kneeR = (hips + footR) * 0.5 + vec2(crouch * 0.8 + 0.10, 0.0);

    vec2 shoulders = hips + vec2(0.04 + crouch * 0.4, 0.95);
    vec2 neck = shoulders + vec2(0.02, 0.14);
    vec2 head = neck + vec2(0.04, 0.28);
    float headRadius = 0.20;

    // Arms & Shooting Kinematics
    vec2 elbowR, wristR;
    vec2 elbowL, wristL;

    if (state == 0.0) {
        // Idle
        elbowR = shoulders + vec2(0.24, -0.32);
        wristR = elbowR + vec2(0.22, 0.18 + sin(uTime * 3.5) * 0.05);

        elbowL = shoulders + vec2(-0.22, -0.28);
        wristL = elbowL + vec2(0.18, 0.12);
    } else if (state == 1.0) {
        // Aiming: shooting pocket, right elbow under ball
        float angle = uAimAngle;
        elbowR = shoulders + vec2(cos(angle - 1.1) * 0.32, sin(angle - 1.1) * 0.32);
        wristR = elbowR + vec2(cos(angle + 0.35) * 0.35, sin(angle + 0.35) * 0.35);

        // Guide hand on side of the ball
        elbowL = shoulders + vec2(0.08, 0.24);
        wristL = wristR + vec2(-0.16, 0.12);
    } else if (state == 2.0) {
        // Throw follow-through: Goose neck flick
        float t = throwT;
        float throwAngle = uAimAngle;
        vec2 throwDir = vec2(cos(throwAngle), sin(throwAngle));
        elbowR = shoulders + throwDir * 0.38;
        wristR = elbowR + mix(throwDir * 0.38, vec2(throwDir.x * 0.35, throwDir.y * 0.35 - 0.14), smoothstep(0.0, 0.4, t));

        elbowL = shoulders + vec2(0.05, 0.25 - t * 0.2);
        wristL = elbowL + vec2(0.15, 0.15 - t * 0.1);
    } else if (state == 3.0) {
        // Celebrate: Both arms raised in victory
        float cheerWave = sin(uTime * 8.0) * 0.1;
        elbowR = shoulders + vec2(0.26, 0.38 + cheerWave);
        wristR = elbowR + vec2(0.12, 0.32);

        elbowL = shoulders + vec2(-0.26, 0.38 - cheerWave);
        wristL = elbowL + vec2(-0.12, 0.32);
    } else {
        // Miss: Shrug
        elbowR = shoulders + vec2(0.28, 0.05);
        wristR = elbowR + vec2(0.20, 0.22);

        elbowL = shoulders + vec2(-0.28, 0.05);
        wristL = elbowL + vec2(-0.20, 0.22);
    }

    // Stick Figure OUTLINES (Hollow Head, Line Segments, Joint Rings)
    // Head: Hollow circle outline
    float dHeadOutline = opOnion(sdCircle(p - head, headRadius), lineStroke);
    // Eye dot
    float dEye = sdCircle(p - (head + vec2(0.06, 0.04)), 0.024);

    // Spine & Neck lines
    float dSpineLine = sdSegment(p, shoulders, hips) - lineStroke;
    float dNeckLine = sdSegment(p, shoulders, neck) - lineStroke;

    // Legs lines
    float dThighL = sdSegment(p, hips, kneeL) - lineStroke;
    float dShinL = sdSegment(p, kneeL, footL) - lineStroke;
    float dThighR = sdSegment(p, hips, kneeR) - lineStroke;
    float dShinR = sdSegment(p, kneeR, footR) - lineStroke;
    float dFootLineL = sdSegment(p, footL, footL + vec2(0.15, 0.0)) - (lineStroke + 0.006);
    float dFootLineR = sdSegment(p, footR, footR + vec2(0.15, 0.0)) - (lineStroke + 0.006);

    // Arms lines
    float dUpArmR = sdSegment(p, shoulders, elbowR) - lineStroke;
    float dForeArmR = sdSegment(p, elbowR, wristR) - lineStroke;
    float dUpArmL = sdSegment(p, shoulders, elbowL) - lineStroke;
    float dForeArmL = sdSegment(p, elbowL, wristL) - lineStroke;

    // Joint Rings (Pivot animator style circle joints)
    float dJointKneeL = opOnion(sdCircle(p - kneeL, 0.038), 0.012);
    float dJointKneeR = opOnion(sdCircle(p - kneeR, 0.038), 0.012);
    float dJointElbowR = opOnion(sdCircle(p - elbowR, 0.035), 0.012);
    float dJointWristR = opOnion(sdCircle(p - wristR, 0.035), 0.012);
    float dJoints = min(min(dJointKneeL, dJointKneeR), min(dJointElbowR, dJointWristR));

    float dStickLines = min(min(dHeadOutline, dEye),
                        min(min(dSpineLine, dNeckLine),
                        min(min(dThighL, min(dShinL, min(dThighR, dShinR))),
                        min(min(dFootLineL, dFootLineR),
                        min(min(dUpArmR, dForeArmR), min(dUpArmL, dForeArmL))))));
    dStickLines = min(dStickLines, dJoints);

    // Render Stick Figure White Outline
    col = mix(col, vec3(1.0), smoothstep(px, -px, dStickLines));

    // 4. BASKETBALL (Hollow Outline Circle with Curved Line Seams)
    vec2 bPos = uBallPos;
    float bRadius = uBallRadius;
    float dBallRaw = sdCircle(p - bPos, bRadius);

    if (dBallRaw < 0.1) {
        // Outer perimeter outline
        float dBallPerimeter = opOnion(dBallRaw, lineStroke);

        // Internal rotating seam lines
        vec2 ballLocal = rotate2D(-uBallRot) * (p - bPos);
        float seam1 = sdSegment(ballLocal, vec2(-bRadius, 0.0), vec2(bRadius, 0.0)) - 0.016;
        float seam2 = sdSegment(ballLocal, vec2(0.0, -bRadius), vec2(0.0, bRadius)) - 0.016;
        float seam3 = opOnion(sdCircle(ballLocal - vec2(0.0, bRadius * 0.9), bRadius * 0.85), 0.016);
        float seam4 = opOnion(sdCircle(ballLocal + vec2(0.0, bRadius * 0.9), bRadius * 0.85), 0.016);
        float dBallSeams = min(min(seam1, seam2), min(seam3, seam4));

        // Clip seams to inside ball
        float dBallInside = max(dBallSeams, dBallRaw);
        float dBallAll = min(dBallPerimeter, dBallInside);

        // Subtle dark translucent fill inside the ball so it reads as an object
        if (dBallRaw < 0.0) {
            col = mix(col, vec3(0.08), 0.65);
        }

        col = mix(col, vec3(1.0), smoothstep(px, -px, dBallAll));
    }

    // ON-FIRE ENERGY OUTLINE (Pulsing Wireframe Aura on streak >= 3)
    if (uStreak >= 3.0) {
        float dFire = opOnion(length(p - bPos) - bRadius * 1.45, 0.018);
        float fireWave = sin(p.x * 24.0 + uTime * 30.0) * sin(p.y * 24.0 - uTime * 30.0);
        dFire += fireWave * 0.05;
        col = mix(col, vec3(1.0), smoothstep(px, -px, dFire) * 0.85);
    }

    // Score celebration flash
    if (uScoreFlash > 0.01) {
        col += vec3(1.0) * uScoreFlash * 0.4;
    }

    fragColor = vec4(col, 1.0);
}
