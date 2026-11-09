import math
from PIL import Image, ImageDraw, ImageFont

# Supersample 2x for ultra-sharp anti-aliased rendering (2400 x 1256 -> 1200 x 628)
SCALE = 2
W, H = 1200 * SCALE, 628 * SCALE

img = Image.new("RGBA", (W, H), (0, 0, 0, 255))
draw = ImageDraw.Draw(img)

# Subtle center spotlight gradient
cx, cy = int(W * 0.5), int(H * 0.45)
max_r = int(math.hypot(cx, cy))
for r in range(max_r, 0, -12):
    t = r / max_r
    # Dark vignette from center #151515 to edge #000000
    alpha = int((1.0 - t) * 28)
    draw.ellipse([cx - r, cy - int(r * 0.65), cx + r, cy + int(r * 0.65)], fill=(255, 255, 255, alpha))

# Court Ground Line
ground_y = int(H * 0.82)
draw.line([(0, ground_y), (W, ground_y)], fill=(255, 255, 255, 240), width=4 * SCALE)
# Sub-court glow/line
draw.line([(0, ground_y + 8 * SCALE), (W, ground_y + 8 * SCALE)], fill=(255, 255, 255, 60), width=1 * SCALE)

# Ground court markings
draw.line([(int(W * 0.72), ground_y), (int(W * 0.72), ground_y + 30 * SCALE)], fill=(255, 255, 255, 120), width=2 * SCALE)
draw.arc([int(W * 0.55), ground_y - int(30 * SCALE), int(W * 0.89), ground_y + int(30 * SCALE)], 180, 360, fill=(255, 255, 255, 70), width=2 * SCALE)

# Basket Hoop & Pole (Right side)
pole_x = int(W * 0.88)
rim_x = int(W * 0.82)
rim_y = int(H * 0.36)
board_w = 16 * SCALE
board_h = 130 * SCALE
board_top = rim_y - int(board_h * 0.65)
board_bottom = board_top + board_h

# Pole
draw.line([(pole_x, ground_y), (pole_x, board_top + int(board_h * 0.7))], fill=(255, 255, 255, 240), width=5 * SCALE)
# Pole support struts
draw.line([(pole_x, ground_y - int(120 * SCALE)), (pole_x + int(40 * SCALE), ground_y)], fill=(255, 255, 255, 180), width=3 * SCALE)
draw.line([(pole_x, board_top + int(board_h * 0.7)), (rim_x + int(44 * SCALE), rim_y)], fill=(255, 255, 255, 220), width=4 * SCALE)

# Backboard (hollow line-art)
draw.rectangle([pole_x - int(24 * SCALE), board_top, pole_x - int(24 * SCALE) + board_w, board_bottom], outline=(255, 255, 255, 255), width=3 * SCALE)
# Inner target box on backboard
inner_h = int(board_h * 0.38)
inner_w = int(board_w * 0.9)
inner_top = rim_y - int(inner_h * 0.7)
draw.rectangle([pole_x - int(24 * SCALE), inner_top, pole_x - int(24 * SCALE) + inner_w, inner_top + inner_h], outline=(255, 255, 255, 200), width=2 * SCALE)

# Rim bracket & Rim
draw.line([(pole_x - int(24 * SCALE), rim_y), (rim_x + int(36 * SCALE), rim_y)], fill=(255, 255, 255, 255), width=4 * SCALE)
# Rim ellipse / ring (facing left-front)
rim_r = 38 * SCALE
draw.ellipse([rim_x, rim_y - 6 * SCALE, rim_x + rim_r * 2, rim_y + 6 * SCALE], outline=(255, 255, 255, 255), width=4 * SCALE)

# Net (woven line segments)
net_top_y = rim_y + 3 * SCALE
net_bottom_y = rim_y + 54 * SCALE
net_left_x = rim_x + 3 * SCALE
net_right_x = rim_x + rim_r * 2 - 3 * SCALE
net_bottom_w = int(rim_r * 1.3)
net_bl_x = rim_x + int(rim_r * 0.35)
net_br_x = net_bl_x + net_bottom_w

# Net strings
for i in range(8):
    t = i / 7.0
    top_x = net_left_x + t * (net_right_x - net_left_x)
    bot_x = net_bl_x + t * (net_br_x - net_bl_x)
    draw.line([(top_x, net_top_y), (bot_x, net_bottom_y)], fill=(255, 255, 255, 170), width=2 * SCALE)

# Net horizontal loops
for loop_i in range(1, 4):
    lt = loop_i / 4.0
    ly = int(net_top_y + lt * (net_bottom_y - net_top_y))
    lx1 = int(net_left_x + lt * (net_bl_x - net_left_x))
    lx2 = int(net_right_x + lt * (net_br_x - net_right_x))
    draw.ellipse([lx1, ly - 3 * SCALE, lx2, ly + 3 * SCALE], outline=(255, 255, 255, 140), width=2 * SCALE)


# Shooter: Stick figure jumping / shooting (Left side)
# Jump position: feet off ground
px = int(W * 0.22)
py = ground_y - int(70 * SCALE) # in mid-air jump!

# Shadow on ground (smaller because jumping)
draw.ellipse([px - 36 * SCALE, ground_y - 4 * SCALE, px + 36 * SCALE, ground_y + 4 * SCALE], fill=(255, 255, 255, 45))

# Hip, spine, neck, head
hip_x, hip_y = px, py - int(90 * SCALE)
neck_x, neck_y = px + int(15 * SCALE), hip_y - int(105 * SCALE)
head_x, head_y = neck_x + int(10 * SCALE), neck_y - int(36 * SCALE)
head_r = 24 * SCALE

# Spine
draw.line([(hip_x, hip_y), (neck_x, neck_y)], fill=(255, 255, 255, 255), width=5 * SCALE)

# Head (hollow circle line-art)
draw.ellipse([head_x - head_r, head_y - head_r, head_x + head_r, head_y + head_r], outline=(255, 255, 255, 255), width=4 * SCALE)

# Joint rings (Xiao-Xiao / Pivot Animator aesthetic)
def draw_joint(jx, jy, r=5*SCALE):
    draw.ellipse([jx - r, jy - r, jx + r, jy + r], outline=(255, 255, 255, 255), width=2 * SCALE)

# Left Leg (trailing back)
lknee_x, lknee_y = hip_x - int(35 * SCALE), hip_y + int(50 * SCALE)
lfoot_x, lfoot_y = lknee_x - int(25 * SCALE), lknee_y + int(45 * SCALE)
draw.line([(hip_x, hip_y), (lknee_x, lknee_y)], fill=(255, 255, 255, 255), width=4 * SCALE)
draw.line([(lknee_x, lknee_y), (lfoot_x, lfoot_y)], fill=(255, 255, 255, 255), width=4 * SCALE)
draw_joint(lknee_x, lknee_y)

# Right Leg (tucked forward/athletic)
rknee_x, rknee_y = hip_x + int(25 * SCALE), hip_y + int(40 * SCALE)
rfoot_x, rfoot_y = rknee_x + int(10 * SCALE), rknee_y + int(48 * SCALE)
draw.line([(hip_x, hip_y), (rknee_x, rknee_y)], fill=(255, 255, 255, 255), width=4 * SCALE)
draw.line([(rknee_x, rknee_y), (rfoot_x, rfoot_y)], fill=(255, 255, 255, 255), width=4 * SCALE)
draw_joint(rknee_x, rknee_y)

# Arms reaching forward-upward in release follow-through
# Left guide arm
lelbow_x, lelbow_y = neck_x + int(30 * SCALE), neck_y - int(40 * SCALE)
lhand_x, lhand_y = lelbow_x + int(35 * SCALE), lelbow_y - int(45 * SCALE)
draw.line([(neck_x, neck_y), (lelbow_x, lelbow_y)], fill=(255, 255, 255, 220), width=4 * SCALE)
draw.line([(lelbow_x, lelbow_y), (lhand_x, lhand_y)], fill=(255, 255, 255, 220), width=4 * SCALE)
draw_joint(lelbow_x, lelbow_y)

# Right shooting arm (fully extended with wrist flick)
relbow_x, relbow_y = neck_x + int(45 * SCALE), neck_y - int(55 * SCALE)
rhand_x, rhand_y = relbow_x + int(45 * SCALE), relbow_y - int(55 * SCALE)
draw.line([(neck_x, neck_y), (relbow_x, relbow_y)], fill=(255, 255, 255, 255), width=5 * SCALE)
draw.line([(relbow_x, relbow_y), (rhand_x, rhand_y)], fill=(255, 255, 255, 255), width=5 * SCALE)
draw_joint(relbow_x, relbow_y)
# Wrist snap / hand
draw.line([(rhand_x, rhand_y), (rhand_x + int(12 * SCALE), rhand_y + int(14 * SCALE))], fill=(255, 255, 255, 255), width=4 * SCALE)

# Parabolic Dotted Trajectory Arc
start_arc_x = rhand_x + int(15 * SCALE)
start_arc_y = rhand_y - int(10 * SCALE)
target_arc_x = rim_x + rim_r
target_arc_y = rim_y

# Apex between start and target
apex_x = int((start_arc_x * 0.45 + target_arc_x * 0.55))
apex_y = int(H * 0.16)

# Sample quadratic Bezier curve
num_dots = 42
trajectory_points = []
for i in range(num_dots + 1):
    t = i / num_dots
    # Quad bezier
    bx = (1 - t)**2 * start_arc_x + 2 * (1 - t) * t * apex_x + t**2 * target_arc_x
    by = (1 - t)**2 * start_arc_y + 2 * (1 - t) * t * apex_y + t**2 * target_arc_y
    trajectory_points.append((bx, by))

# Draw dotted trajectory arc
for i in range(0, len(trajectory_points), 2):
    pt = trajectory_points[i]
    dot_r = 3 * SCALE
    draw.ellipse([pt[0] - dot_r, pt[1] - dot_r, pt[0] + dot_r, pt[1] + dot_r], fill=(255, 255, 255, 190))

# Basketball (near apex of flight curve, heading towards hoop)
ball_idx = int(num_dots * 0.62)
ball_x, ball_y = trajectory_points[ball_idx]
ball_r = 26 * SCALE

def draw_basketball(bx, by, br, rotation_deg=28):
    # Black core with crisp white border
    draw.ellipse([bx - br, by - br, bx + br, by + br], fill=(10, 10, 10, 255), outline=(255, 255, 255, 255), width=3 * SCALE)
    
    # Seams: horizontal & vertical & twin arcs
    # Horizontal center seam
    draw.line([(bx - br + 2*SCALE, by), (bx + br - 2*SCALE, by)], fill=(255, 255, 255, 255), width=2 * SCALE)
    # Vertical curved seam
    draw.arc([bx - br*0.35, by - br + 2*SCALE, bx + br*0.35, by + br - 2*SCALE], -90, 90, fill=(255, 255, 255, 255), width=2 * SCALE)
    # Left curved seam
    draw.arc([bx - br*1.15, by - br + 2*SCALE, bx - br*0.1, by + br - 2*SCALE], -80, 80, fill=(255, 255, 255, 200), width=2 * SCALE)
    # Right curved seam
    draw.arc([bx + br*0.1, by - br + 2*SCALE, bx + br*1.15, by + br - 2*SCALE], 100, 260, fill=(255, 255, 255, 200), width=2 * SCALE)

draw_basketball(ball_x, ball_y, ball_r)

# Motion blur / speed lines behind ball
for offset in [int(18 * SCALE), int(34 * SCALE), int(50 * SCALE)]:
    prev_idx = max(0, ball_idx - offset // (6 * SCALE))
    px_t, py_t = trajectory_points[prev_idx]
    op = max(20, 140 - offset * 2)
    draw.ellipse([px_t - 4*SCALE, py_t - 4*SCALE, px_t + 4*SCALE, py_t + 4*SCALE], fill=(255, 255, 255, op))

# HUD Badges & Overlays
# 1. Top Left Title Card: "STICK FIGURE BASKETBALL"
# We draw crisp vector typography and stylized HUD panels
badge_x, badge_y = int(W * 0.06), int(H * 0.08)

# Title box backdrop
draw.rectangle([badge_x, badge_y, badge_x + int(420 * SCALE), badge_y + int(76 * SCALE)], fill=(12, 12, 12, 230), outline=(255, 255, 255, 140), width=2 * SCALE)
# Subtitle box
draw.rectangle([badge_x, badge_y + int(84 * SCALE), badge_x + int(340 * SCALE), badge_y + int(118 * SCALE)], fill=(0, 0, 0, 200), outline=(255, 255, 255, 80), width=1 * SCALE)

# 2. Top Right: Live HUD - "HOOP HEIGHT: 6.8m" & "SCORE: 7"
hud_r_w = int(260 * SCALE)
hud_r_x = int(W * 0.94) - hud_r_w
hud_r_y = int(H * 0.08)
draw.rectangle([hud_r_x, hud_r_y, hud_r_x + hud_r_w, hud_r_y + int(50 * SCALE)], fill=(12, 12, 12, 230), outline=(255, 255, 255, 140), width=2 * SCALE)

# 3. Boost Badge: "▲ BOOST! +3.5" near the shooter
boost_x = px - int(50 * SCALE)
boost_y = py - int(240 * SCALE)
draw.rectangle([boost_x, boost_y, boost_x + int(120 * SCALE), boost_y + int(36 * SCALE)], fill=(255, 255, 255, 240), outline=(0, 0, 0, 255), width=2 * SCALE)

# 4. Power Meter charging bar
meter_x = px - int(60 * SCALE)
meter_y = ground_y - int(20 * SCALE)
meter_w = int(140 * SCALE)
meter_h = int(14 * SCALE)
draw.rectangle([meter_x, meter_y, meter_x + meter_w, meter_y + meter_h], fill=(15, 15, 15, 255), outline=(255, 255, 255, 180), width=2 * SCALE)
draw.rectangle([meter_x + 2*SCALE, meter_y + 2*SCALE, meter_x + int(meter_w * 0.82), meter_y + meter_h - 2*SCALE], fill=(255, 255, 255, 255))

# Render clean text using PIL default or standard font
try:
    font_large = ImageFont.truetype("arial.ttf", 36 * SCALE)
    font_med = ImageFont.truetype("arial.ttf", 20 * SCALE)
    font_small = ImageFont.truetype("arial.ttf", 15 * SCALE)
    font_bold = ImageFont.truetype("arialbd.ttf", 22 * SCALE)
    font_boost = ImageFont.truetype("arialbd.ttf", 18 * SCALE)
except Exception:
    font_large = ImageFont.load_default()
    font_med = ImageFont.load_default()
    font_small = ImageFont.load_default()
    font_bold = ImageFont.load_default()
    font_boost = ImageFont.load_default()

draw.text((badge_x + int(20 * SCALE), badge_y + int(16 * SCALE)), "STICK FIGURE BASKETBALL", fill=(255, 255, 255, 255), font=font_large)
draw.text((badge_x + int(16 * SCALE), badge_y + int(90 * SCALE)), "SDF PHYSICS • LINE-ART ARCADE", fill=(200, 200, 200, 255), font=font_small)

draw.text((hud_r_x + int(16 * SCALE), hud_r_y + int(13 * SCALE)), "HOOP: 6.8m  |  SCORE: 7", fill=(255, 255, 255, 255), font=font_bold)

draw.text((boost_x + int(12 * SCALE), boost_y + int(7 * SCALE)), "▲ BOOST!", fill=(0, 0, 0, 255), font=font_boost)

# Controls footer badge (bottom center)
foot_w = int(460 * SCALE)
foot_x = (W - foot_w) // 2
foot_y = int(H * 0.92)
draw.rectangle([foot_x, foot_y, foot_x + foot_w, foot_y + int(32 * SCALE)], fill=(12, 12, 12, 220), outline=(255, 255, 255, 80), width=1 * SCALE)
draw.text((foot_x + int(24 * SCALE), foot_y + int(7 * SCALE)), "HOLD LEFT-CLICK TO CHARGE • RELEASE TO SHOOT", fill=(220, 220, 220, 255), font=font_small)

# Downscale with high quality Lanczos filter for perfectly smooth lines
preview_final = img.resize((1200, 628), Image.Resampling.LANCZOS)
preview_final.save("web/preview.png", "PNG", optimize=True)
preview_final.save("preview.png", "PNG", optimize=True)
print("Preview image created successfully: 1200x628")

# Now generate favicon.png (64x64) and icons
fav_size = 64 * SCALE
fav_img = Image.new("RGBA", (fav_size, fav_size), (0, 0, 0, 0))
fav_draw = ImageDraw.Draw(fav_img)

fcx, fcy = fav_size // 2, fav_size // 2
fr = int(fav_size * 0.44)

# Circular dark base with crisp white outline
fav_draw.ellipse([fcx - fr, fcy - fr, fcx + fr, fcy + fr], fill=(12, 12, 12, 255), outline=(255, 255, 255, 255), width=3 * SCALE)
# Horizontal center seam
fav_draw.line([(fcx - fr + 2*SCALE, fcy), (fcx + fr - 2*SCALE, fcy)], fill=(255, 255, 255, 255), width=2 * SCALE)
# Vertical seam
fav_draw.line([(fcx, fcy - fr + 2*SCALE), (fcx, fcy + fr - 2*SCALE)], fill=(255, 255, 255, 255), width=2 * SCALE)
# Curved left seam
fav_draw.arc([fcx - fr*1.15, fcy - fr + 2*SCALE, fcx - fr*0.1, fcy + fr - 2*SCALE], -80, 80, fill=(255, 255, 255, 220), width=2 * SCALE)
# Curved right seam
fav_draw.arc([fcx + fr*0.1, fcy - fr + 2*SCALE, fcx + fr*1.15, fcy + fr - 2*SCALE], 100, 260, fill=(255, 255, 255, 220), width=2 * SCALE)

fav_final = fav_img.resize((64, 64), Image.Resampling.LANCZOS)
fav_final.save("web/favicon.png", "PNG")
fav_final.save("favicon.png", "PNG")

# Also generate 192x192 and 512x512 app icons
for size in [192, 512]:
    icon_s = size * SCALE
    icon_img = Image.new("RGBA", (icon_s, icon_s), (0, 0, 0, 255))
    icon_draw = ImageDraw.Draw(icon_img)
    icx, icy = icon_s // 2, icon_s // 2
    ir = int(icon_s * 0.42)
    icon_draw.ellipse([icx - ir, icy - ir, icx + ir, icy + ir], fill=(10, 10, 10, 255), outline=(255, 255, 255, 255), width=int(size * 0.02 * SCALE))
    icon_draw.line([(icx - ir + 4*SCALE, icy), (icx + ir - 4*SCALE, icy)], fill=(255, 255, 255, 255), width=int(size * 0.015 * SCALE))
    icon_draw.line([(icx, icy - ir + 4*SCALE), (icx, icy + ir - 4*SCALE)], fill=(255, 255, 255, 255), width=int(size * 0.015 * SCALE))
    icon_draw.arc([icx - ir*1.12, icy - ir + 4*SCALE, icx - ir*0.1, icy + ir - 4*SCALE], -80, 80, fill=(255, 255, 255, 220), width=int(size * 0.015 * SCALE))
    icon_draw.arc([icx + ir*0.1, icy - ir + 4*SCALE, icx + ir*1.12, icy + ir - 4*SCALE], 100, 260, fill=(255, 255, 255, 220), width=int(size * 0.015 * SCALE))
    
    icon_resized = icon_img.resize((size, size), Image.Resampling.LANCZOS)
    icon_resized.save(f"web/icons/Icon-{size}.png", "PNG")
    icon_resized.save(f"web/icons/Icon-maskable-{size}.png", "PNG")

print("Favicon and App Icons created successfully!")
