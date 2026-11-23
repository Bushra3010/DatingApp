#!/usr/bin/env python3
"""
Generate ultra-high-resolution, custom marketing screenshots for Google Play Store.
Dimensions: 1080 x 1920 (Standard FHD portrait 9:16).
Uses real photo assets and Everlane's signature aesthetic.
"""

import os
import math
from PIL import Image, ImageDraw, ImageFont, ImageFilter

OUTPUT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), 'screenshots'))
ASSETS_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), '../mobile/assets/images'))

os.makedirs(OUTPUT_DIR, exist_ok=True)

# Fonts
FONT_PATH = '/System/Library/Fonts/Avenir Next.ttc'

def get_font(size, bold=False, heavy=False):
    index = 0
    if heavy:
        index = 4  # Heavy
    elif bold:
        index = 2  # Demi Bold / Bold
    else:
        index = 0  # Regular
    try:
        return ImageFont.truetype(FONT_PATH, size, index=index)
    except Exception:
        return ImageFont.load_default()

FONT_PILL = get_font(24, bold=True)
FONT_HEAD = get_font(64, heavy=True)
FONT_SUB = get_font(30, bold=False)
FONT_MOCK_TITLE = get_font(38, bold=True)
FONT_MOCK_BODY = get_font(26, bold=False)
FONT_MOCK_SMALL = get_font(22, bold=False)
FONT_MOCK_TINY = get_font(18, bold=True)

# Everlane Theme Colors
BG_TOP = (14, 7, 26)       # #0E071A
BG_BOTTOM = (34, 15, 54)   # #220F36
ROSE_ACCENT = (236, 72, 153) # #EC4899
PURPLE_ACCENT = (168, 85, 247) # #A855F7
VERIFIED_BLUE = (56, 189, 248) # #38BDF8
TEXT_WHITE = (255, 255, 255)
TEXT_MUTED = (203, 213, 225)
DEVICE_FRAME = (38, 22, 58)
DEVICE_BORDER = (75, 45, 115)
CARD_BG = (28, 16, 44)
CARD_SURFACE = (40, 24, 62)

def create_base_canvas():
    """Create 1080x1920 gradient canvas with ambient lighting."""
    width, height = 1080, 1920
    im = Image.new('RGBA', (width, height), (0, 0, 0, 255))
    draw = ImageDraw.Draw(im)

    # Vertical gradient
    for y in range(height):
        t = y / height
        r = int(BG_TOP[0] * (1 - t) + BG_BOTTOM[0] * t)
        g = int(BG_TOP[1] * (1 - t) + BG_BOTTOM[1] * t)
        b = int(BG_TOP[2] * (1 - t) + BG_BOTTOM[2] * t)
        draw.line([(0, y), (width, y)], fill=(r, g, b, 255))

    # Ambient radial glows
    glow = Image.new('RGBA', (width, height), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)
    
    # Top rose glow
    glow_draw.ellipse([width//2 - 400, -200, width//2 + 400, 400], fill=(236, 72, 153, 35))
    # Bottom purple glow
    glow_draw.ellipse([width//2 - 500, height - 600, width//2 + 500, height + 400], fill=(168, 85, 247, 45))
    
    glow = glow.filter(ImageFilter.GaussianBlur(120))
    im = Image.alpha_composite(im, glow)
    return im

def draw_header(im, pill_text, headline, subtitle):
    """Draw centered headline and category badge at top."""
    draw = ImageDraw.Draw(im)
    width = im.width

    # Category Pill
    bbox = FONT_PILL.getbbox(pill_text)
    pw = bbox[2] - bbox[0] + 36
    ph = bbox[3] - bbox[1] + 18
    px = (width - pw) // 2
    py = 85

    # Pill background
    pill_img = Image.new('RGBA', (pw, ph), (0, 0, 0, 0))
    pill_draw = ImageDraw.Draw(pill_img)
    pill_draw.rounded_rectangle([0, 0, pw - 1, ph - 1], radius=ph//2, fill=(236, 72, 153, 35), outline=(236, 72, 153, 140), width=2)
    im.paste(pill_img, (px, py), pill_img)

    draw.text((px + 18, py + 8), pill_text, font=FONT_PILL, fill=ROSE_ACCENT)

    # Headline
    h_bbox = FONT_HEAD.getbbox(headline)
    hw = h_bbox[2] - h_bbox[0]
    hx = (width - hw) // 2
    hy = 145
    draw.text((hx, hy), headline, font=FONT_HEAD, fill=TEXT_WHITE)

    # Subtitle
    s_bbox = FONT_SUB.getbbox(subtitle)
    sw = s_bbox[2] - s_bbox[0]
    sx = (width - sw) // 2
    sy = 232
    draw.text((sx, sy), subtitle, font=FONT_SUB, fill=TEXT_MUTED)

def draw_device_mockup(im, screen_builder):
    """Draw modern smartphone frame and embed the custom screen."""
    mockup_x = 115
    mockup_y = 330
    mockup_w = 850
    mockup_h = 1650
    radius = 56
    border_w = 10

    # Device Shadow
    shadow = Image.new('RGBA', (im.width, im.height), (0, 0, 0, 0))
    s_draw = ImageDraw.Draw(shadow)
    s_draw.rounded_rectangle(
        [mockup_x - 10, mockup_y + 10, mockup_x + mockup_w + 10, mockup_y + mockup_h],
        radius=radius + 8,
        fill=(0, 0, 0, 160)
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(35))
    im.paste(shadow, (0, 0), shadow)

    # Frame body
    frame = Image.new('RGBA', (mockup_w, mockup_h), (0, 0, 0, 0))
    f_draw = ImageDraw.Draw(frame)
    f_draw.rounded_rectangle(
        [0, 0, mockup_w - 1, mockup_h - 1],
        radius=radius,
        fill=DEVICE_FRAME,
        outline=DEVICE_BORDER,
        width=border_w
    )

    # Screen dimensions
    screen_w = mockup_w - (border_w * 2)
    screen_h = mockup_h - (border_w * 2)
    screen_img = Image.new('RGBA', (screen_w, screen_h), (12, 6, 20, 255))

    # Build screen content
    screen_builder(screen_img)

    # Add Status Bar at top of screen
    s_draw = ImageDraw.Draw(screen_img)
    s_draw.text((45, 18), "9:41", font=FONT_MOCK_TINY, fill=(255, 255, 255, 220))
    
    # Speaker / Island Notch
    notch_w = 130
    notch_h = 24
    s_draw.rounded_rectangle(
        [(screen_w - notch_w)//2, 14, (screen_w + notch_w)//2, 14 + notch_h],
        radius=12,
        fill=(10, 5, 15, 255)
    )

    # Status icons placeholder (wifi / battery / 5g)
    s_draw.rectangle([screen_w - 90, 20, screen_w - 65, 32], outline=(255, 255, 255, 200), width=2)
    s_draw.rectangle([screen_w - 88, 22, screen_w - 70, 30], fill=(255, 255, 255, 200))
    s_draw.rectangle([screen_w - 65, 23, screen_w - 62, 29], fill=(255, 255, 255, 200))

    # Mask screen to inner rounded rectangle
    mask = Image.new('L', (screen_w, screen_h), 0)
    m_draw = ImageDraw.Draw(mask)
    m_draw.rounded_rectangle([0, 0, screen_w, screen_h], radius=radius - border_w, fill=255)

    frame.paste(screen_img, (border_w, border_w), mask)
    im.paste(frame, (mockup_x, mockup_y), frame)

def draw_verified_tick(draw, x, y, size=24):
    """Draw blue verified checkmark pill."""
    draw.ellipse([x, y, x + size, y + size], fill=VERIFIED_BLUE)
    # Checkmark lines
    draw.line([(x + size*0.28, y + size*0.52), (x + size*0.44, y + size*0.70)], fill=(255, 255, 255), width=3)
    draw.line([(x + size*0.44, y + size*0.70), (x + size*0.74, y + size*0.34)], fill=(255, 255, 255), width=3)

# ----------------- Screen Builders -----------------

def build_screen_discover(screen):
    """Screen 1: Discover Card (Isha, 24)."""
    draw = ImageDraw.Draw(screen)
    sw, sh = screen.size

    # App Header
    draw.text((45, 65), "Everlane", font=FONT_MOCK_TITLE, fill=(244, 114, 182))
    draw.text((sw - 120, 72), "Filters", font=FONT_MOCK_SMALL, fill=TEXT_MUTED)

    # Photo Card
    card_x = 35
    card_y = 130
    card_w = sw - 70
    card_h = 1000

    photo_path = os.path.join(ASSETS_DIR, 'isha.jpg')
    if os.path.exists(photo_path):
        photo = Image.open(photo_path).convert('RGBA')
        # Scale & crop photo to card
        ratio = max(card_w / photo.width, card_h / photo.height)
        new_size = (int(photo.width * ratio), int(photo.height * ratio))
        photo = photo.resize(new_size, Image.Resampling.LANCZOS)
        
        # Crop center
        crop_x = (photo.width - card_w) // 2
        crop_y = (photo.height - card_h) // 2
        photo = photo.crop((crop_x, crop_y, crop_x + card_w, crop_y + card_h))

        # Bottom gradient on photo
        p_draw = ImageDraw.Draw(photo)
        for gy in range(int(card_h * 0.4), card_h):
            t = (gy - card_h * 0.4) / (card_h * 0.6)
            alpha = int(230 * (t ** 1.5))
            p_draw.line([(0, gy), (card_w, gy)], fill=(12, 6, 20, alpha))

        # Round card corners
        card_mask = Image.new('L', (card_w, card_h), 0)
        ImageDraw.Draw(card_mask).rounded_rectangle([0, 0, card_w, card_h], radius=32, fill=255)
        screen.paste(photo, (card_x, card_y), card_mask)

    # Information on photo
    info_y = card_y + card_h - 260
    draw.text((card_x + 30, info_y), "Isha, 24", font=FONT_MOCK_TITLE, fill=TEXT_WHITE)
    draw_verified_tick(draw, card_x + 200, info_y + 8, size=26)
    
    draw.text((card_x + 30, info_y + 50), "📍 Indiranagar, Bengaluru · 3 km away", font=FONT_MOCK_SMALL, fill=(226, 232, 240))
    draw.text((card_x + 30, info_y + 90), "Architect & weekend painter 🎨", font=FONT_MOCK_BODY, fill=TEXT_WHITE)

    # Interest tags
    tags = ["☕ Coffee", "🎨 Art galleries", "✨ Long-term"]
    tx = card_x + 30
    ty = info_y + 145
    for tag in tags:
        t_box = FONT_MOCK_TINY.getbbox(tag)
        tw = t_box[2] - t_box[0] + 28
        th = 38
        draw.rounded_rectangle([tx, ty, tx + tw, ty + th], radius=19, fill=(255, 255, 255, 45), outline=(255, 255, 255, 80), width=1)
        draw.text((tx + 14, ty + 8), tag, font=FONT_MOCK_TINY, fill=TEXT_WHITE)
        tx += tw + 12

    # Bottom Actions Bar
    btn_y = card_y + card_h + 40
    # Pass button
    draw.ellipse([sw//2 - 170, btn_y, sw//2 - 70, btn_y + 100], fill=(30, 20, 45), outline=(255, 255, 255, 40), width=2)
    draw.text((sw//2 - 132, btn_y + 24), "✕", font=FONT_MOCK_TITLE, fill=(244, 63, 94))

    # Like button (Pink glowing)
    draw.ellipse([sw//2 + 70, btn_y, sw//2 + 170, btn_y + 100], fill=(236, 72, 153), outline=(255, 255, 255, 80), width=2)
    draw.text((sw//2 + 105, btn_y + 24), "♥", font=FONT_MOCK_TITLE, fill=TEXT_WHITE)

def build_screen_verified(screen):
    """Screen 2: Selfie Verified Profiles (Ananya, 25)."""
    draw = ImageDraw.Draw(screen)
    sw, sh = screen.size

    draw.text((45, 65), "← Profile Details", font=FONT_MOCK_TITLE, fill=TEXT_WHITE)

    # Portrait photo card
    card_x = 35
    card_y = 125
    card_w = sw - 70
    card_h = 420

    photo_path = os.path.join(ASSETS_DIR, 'ananya.jpg')
    if os.path.exists(photo_path):
        photo = Image.open(photo_path).convert('RGBA')
        ratio = max(card_w / photo.width, card_h / photo.height)
        photo = photo.resize((int(photo.width * ratio), int(photo.height * ratio)), Image.Resampling.LANCZOS)
        photo = photo.crop((0, 0, card_w, card_h))
        card_mask = Image.new('L', (card_w, card_h), 0)
        ImageDraw.Draw(card_mask).rounded_rectangle([0, 0, card_w, card_h], radius=28, fill=255)
        screen.paste(photo, (card_x, card_y), card_mask)

    # Verified Badge Guarantee Card
    by = card_y + card_h + 20
    draw.rounded_rectangle([card_x, by, card_x + card_w, by + 110], radius=22, fill=(15, 30, 55), outline=(56, 189, 248, 120), width=2)
    draw_verified_tick(draw, card_x + 25, by + 28, size=34)
    draw.text((card_x + 75, by + 22), "Selfie Verified Profile", font=FONT_MOCK_BODY, fill=VERIFIED_BLUE)
    draw.text((card_x + 75, by + 58), "Identity confirmed via live selfie scan. 100% real.", font=FONT_MOCK_SMALL, fill=(186, 230, 253))

    # Bio Card
    py1 = by + 130
    draw.rounded_rectangle([card_x, py1, card_x + card_w, py1 + 175], radius=22, fill=CARD_SURFACE, outline=(255, 255, 255, 30), width=1)
    draw.text((card_x + 25, py1 + 20), "A non-negotiable for me...", font=FONT_MOCK_SMALL, fill=(244, 114, 182))
    draw.text((card_x + 25, py1 + 60), "Weekend morning treks, exploring cozy bookshops\nand finding the best masala chai in the city.", font=FONT_MOCK_BODY, fill=TEXT_WHITE)

    # Voice Note Card
    py2 = py1 + 195
    draw.rounded_rectangle([card_x, py2, card_x + card_w, py2 + 130], radius=22, fill=CARD_SURFACE, outline=(255, 255, 255, 30), width=1)
    draw.text((card_x + 25, py2 + 18), "Voice Prompt: My ideal weekend vibe 🎙️", font=FONT_MOCK_SMALL, fill=TEXT_MUTED)
    # Audio Waveform bar
    draw.ellipse([card_x + 25, py2 + 55, card_x + 75, py2 + 105], fill=ROSE_ACCENT)
    draw.text((card_x + 43, py2 + 65), "▶", font=FONT_MOCK_SMALL, fill=TEXT_WHITE)
    # Wave bars
    for i in range(26):
        h = 10 + abs(int(math.sin(i * 0.4) * 28))
        wx = card_x + 95 + i * 16
        draw.rounded_rectangle([wx, py2 + 80 - h//2, wx + 6, py2 + 80 + h//2], radius=3, fill=(244, 114, 182))
    draw.text((card_x + card_w - 75, py2 + 68), "0:18", font=FONT_MOCK_SMALL, fill=TEXT_MUTED)

    # Lifestyle Highlights
    py3 = py2 + 150
    draw.rounded_rectangle([card_x, py3, card_x + card_w, py3 + 150], radius=22, fill=CARD_SURFACE, outline=(255, 255, 255, 30), width=1)
    draw.text((card_x + 25, py3 + 20), "Lifestyle & Values", font=FONT_MOCK_SMALL, fill=(244, 114, 182))
    draw.text((card_x + 25, py3 + 60), "🌿 Non-smoker   🐕 Dog lover   🎓 Master's degree", font=FONT_MOCK_BODY, fill=TEXT_WHITE)
    draw.text((card_x + 25, py3 + 100), "🕉️ Spiritual & Mindful   🍷 Social drinker", font=FONT_MOCK_BODY, fill=TEXT_WHITE)

def build_screen_hangouts(screen):
    """Screen 3: City Hangouts."""
    draw = ImageDraw.Draw(screen)
    sw, sh = screen.size

    draw.text((45, 65), "City Hangouts", font=FONT_MOCK_TITLE, fill=TEXT_WHITE)
    draw.text((45, 115), "Meet in public places safely with small groups", font=FONT_MOCK_SMALL, fill=TEXT_MUTED)

    # Filter chips
    chips = ["All Plans", "☕ Coffee", "🎶 Gigs", "🌳 Outdoors"]
    cx = 45
    cy = 160
    for i, c in enumerate(chips):
        active = (i == 0)
        c_box = FONT_MOCK_SMALL.getbbox(c)
        cw = c_box[2] - c_box[0] + 32
        ch = 44
        fill = ROSE_ACCENT if active else CARD_SURFACE
        text_color = TEXT_WHITE if active else TEXT_MUTED
        draw.rounded_rectangle([cx, cy, cx + cw, cy + ch], radius=22, fill=fill)
        draw.text((cx + 16, cy + 9), c, font=FONT_MOCK_SMALL, fill=text_color)
        cx += cw + 14

    card_x = 35
    card_w = sw - 70

    # Event 1
    y1 = 230
    draw.rounded_rectangle([card_x, y1, card_x + card_w, y1 + 245], radius=24, fill=CARD_SURFACE, outline=(255, 255, 255, 30), width=1)
    draw.text((card_x + 25, y1 + 22), "☕ Specialty Coffee & Book Discussion", font=FONT_MOCK_BODY, fill=TEXT_WHITE)
    draw.text((card_x + 25, y1 + 65), "Hosted by Meera · Third Wave Coffee, Indiranagar", font=FONT_MOCK_SMALL, fill=(244, 114, 182))
    draw.text((card_x + 25, y1 + 102), "📅 This Saturday · 4:00 PM  (3 spots left)", font=FONT_MOCK_SMALL, fill=TEXT_MUTED)
    draw.text((card_x + 25, y1 + 138), "A relaxed table to chat about books, sci-fi & life.", font=FONT_MOCK_SMALL, fill=(226, 232, 240))
    # Join button
    draw.rounded_rectangle([card_x + card_w - 200, y1 + 180, card_x + card_w - 25, y1 + 225], radius=20, fill=ROSE_ACCENT)
    draw.text((card_x + card_w - 170, y1 + 190), "Join Plan", font=FONT_MOCK_TINY, fill=TEXT_WHITE)

    # Event 2
    y2 = y1 + 270
    draw.rounded_rectangle([card_x, y2, card_x + card_w, y2 + 245], radius=24, fill=CARD_SURFACE, outline=(255, 255, 255, 30), width=1)
    draw.text((card_x + 25, y2 + 22), "🎶 Live Indie Music & Dinner", font=FONT_MOCK_BODY, fill=TEXT_WHITE)
    draw.text((card_x + 25, y2 + 65), "Hosted by Kabir · Fandom, Koramangala", font=FONT_MOCK_SMALL, fill=(244, 114, 182))
    draw.text((card_x + 25, y2 + 102), "📅 Sunday · 7:30 PM  (2 spots left)", font=FONT_MOCK_SMALL, fill=TEXT_MUTED)
    draw.text((card_x + 25, y2 + 138), "Catching the live acoustic set and great sourdough pizzas.", font=FONT_MOCK_SMALL, fill=(226, 232, 240))
    draw.rounded_rectangle([card_x + card_w - 200, y2 + 180, card_x + card_w - 25, y2 + 225], radius=20, fill=ROSE_ACCENT)
    draw.text((card_x + card_w - 170, y2 + 190), "Join Plan", font=FONT_MOCK_TINY, fill=TEXT_WHITE)

    # Event 3
    y3 = y2 + 270
    draw.rounded_rectangle([card_x, y3, card_x + card_w, y3 + 245], radius=24, fill=CARD_SURFACE, outline=(255, 255, 255, 30), width=1)
    draw.text((card_x + 25, y3 + 22), "🌳 Cubbon Park Bamboo Walk & Pets", font=FONT_MOCK_BODY, fill=TEXT_WHITE)
    draw.text((card_x + 25, y3 + 65), "Hosted by Tara · Central Bamboo Grove", font=FONT_MOCK_SMALL, fill=(244, 114, 182))
    draw.text((card_x + 25, y3 + 102), "📅 Sunday Morning · 8:30 AM  (Open group)", font=FONT_MOCK_SMALL, fill=TEXT_MUTED)
    draw.text((card_x + 25, y3 + 138), "Bring your dog or just come along for a quiet green walk.", font=FONT_MOCK_SMALL, fill=(226, 232, 240))
    draw.rounded_rectangle([card_x + card_w - 200, y3 + 180, card_x + card_w - 25, y3 + 225], radius=20, fill=ROSE_ACCENT)
    draw.text((card_x + card_w - 170, y3 + 190), "Join Plan", font=FONT_MOCK_TINY, fill=TEXT_WHITE)

def build_screen_chemistry(screen):
    """Screen 4: Chemistry & Compatibility."""
    draw = ImageDraw.Draw(screen)
    sw, sh = screen.size

    draw.text((45, 65), "Chemistry Report", font=FONT_MOCK_TITLE, fill=TEXT_WHITE)
    draw.text((45, 115), "Compatibility breakdown with Ananya", font=FONT_MOCK_SMALL, fill=TEXT_MUTED)

    card_x = 35
    card_w = sw - 70

    # Main Match Gauge Card
    y1 = 165
    draw.rounded_rectangle([card_x, y1, card_x + card_w, y1 + 320], radius=28, fill=CARD_SURFACE, outline=(236, 72, 153, 90), width=2)
    # Circle Gauge
    gx = sw // 2
    gy = y1 + 120
    gr = 80
    draw.ellipse([gx - gr, gy - gr, gx + gr, gy + gr], outline=(50, 30, 75), width=14)
    # Highlight arc
    draw.arc([gx - gr, gy - gr, gx + gr, gy + gr], start=-90, end=240, fill=ROSE_ACCENT, width=14)
    draw.text((gx - 54, gy - 30), "92%", font=FONT_HEAD, fill=TEXT_WHITE)
    
    draw.text((gx - 130, y1 + 225), "High Value Alignment", font=FONT_MOCK_BODY, fill=(244, 114, 182))
    draw.text((gx - 165, y1 + 265), "You both share core values on communication & life", font=FONT_MOCK_SMALL, fill=TEXT_MUTED)

    # Categories Breakdown Card
    y2 = y1 + 345
    draw.rounded_rectangle([card_x, y2, card_x + card_w, y2 + 480], radius=26, fill=CARD_SURFACE, outline=(255, 255, 255, 30), width=1)
    
    traits = [
        ("Communication Style", "95%", 0.95),
        ("Life Goals & Ambitions", "90%", 0.90),
        ("Daily Lifestyle & Habits", "92%", 0.92),
        ("Social Energy & Weekends", "88%", 0.88),
    ]

    ty = y2 + 30
    for title, score, pct in traits:
        draw.text((card_x + 30, ty), title, font=FONT_MOCK_BODY, fill=TEXT_WHITE)
        draw.text((card_x + card_w - 95, ty), score, font=FONT_MOCK_BODY, fill=(244, 114, 182))
        
        # Progress bar
        by = ty + 45
        bar_w = card_w - 60
        draw.rounded_rectangle([card_x + 30, by, card_x + 30 + bar_w, by + 12], radius=6, fill=(35, 20, 50))
        draw.rounded_rectangle([card_x + 30, by, card_x + 30 + int(bar_w * pct), by + 12], radius=6, fill=ROSE_ACCENT)
        ty += 105

def build_screen_chat(screen):
    """Screen 5: Real-Time Chat & Voice Prompts."""
    draw = ImageDraw.Draw(screen)
    sw, sh = screen.size

    # Chat Header
    photo_path = os.path.join(ASSETS_DIR, 'ananya.jpg')
    if os.path.exists(photo_path):
        photo = Image.open(photo_path).convert('RGBA').resize((70, 70), Image.Resampling.LANCZOS)
        p_mask = Image.new('L', (70, 70), 0)
        ImageDraw.Draw(p_mask).ellipse([0, 0, 70, 70], fill=255)
        screen.paste(photo, (45, 60), p_mask)

    draw.text((130, 65), "Ananya", font=FONT_MOCK_TITLE, fill=TEXT_WHITE)
    draw_verified_tick(draw, 275, 75, size=24)
    draw.text((130, 105), "Active now", font=FONT_MOCK_SMALL, fill=(52, 211, 153))

    # Standard Banner (Notice: Zero automated mention!)
    by = 150
    draw.rectangle([0, by, sw, by + 46], fill=(35, 20, 50))
    draw.text((sw//2 - 165, by + 12), "You matched · Be kind, be yourself", font=FONT_MOCK_SMALL, fill=TEXT_MUTED)

    # Chat Messages
    # Message 1 (Incoming from Ananya)
    m1_y = 230
    draw.rounded_rectangle([40, m1_y, 560, m1_y + 130], radius=24, fill=CARD_SURFACE)
    draw.text((65, m1_y + 20), "Hey there! Loved your prompt about\nweekend treks! Have you been recently? 😊", font=FONT_MOCK_BODY, fill=TEXT_WHITE)
    draw.text((495, m1_y + 92), "10:14 AM", font=FONT_MOCK_TINY, fill=TEXT_MUTED)

    # Message 2 (Outgoing from user)
    m2_y = m1_y + 155
    draw.rounded_rectangle([sw - 580, m2_y, sw - 40, m2_y + 140], radius=24, fill=(190, 24, 93))
    draw.text((sw - 555, m2_y + 20), "Hey Ananya! Yes, went to Skandagiri\nfor the sunrise last weekend! The view\nwas completely surreal ✨", font=FONT_MOCK_BODY, fill=TEXT_WHITE)
    draw.text((sw - 120, m2_y + 105), "10:17 AM ✓✓", font=FONT_MOCK_TINY, fill=(255, 255, 255, 180))

    # Message 3 (Incoming Voice Note from Ananya)
    m3_y = m2_y + 165
    draw.rounded_rectangle([40, m3_y, 540, m3_y + 115], radius=24, fill=CARD_SURFACE)
    draw.ellipse([60, m3_y + 22, 120, m3_y + 82], fill=ROSE_ACCENT)
    draw.text((85, m3_y + 36), "▶", font=FONT_MOCK_BODY, fill=TEXT_WHITE)
    # Waveform
    for i in range(16):
        h = 8 + abs(int(math.sin(i * 0.6) * 26))
        wx = 140 + i * 18
        draw.rounded_rectangle([wx, m3_y + 52 - h//2, wx + 6, m3_y + 52 + h//2], radius=3, fill=(244, 114, 182))
    draw.text((440, m3_y + 42), "0:14", font=FONT_MOCK_SMALL, fill=TEXT_MUTED)

    # Message 4 (Outgoing reply)
    m4_y = m3_y + 140
    draw.rounded_rectangle([sw - 560, m4_y, sw - 40, m4_y + 105], radius=24, fill=(190, 24, 93))
    draw.text((sw - 535, m4_y + 20), "Let's definitely grab coffee this Saturday\nand plan the next trek!", font=FONT_MOCK_BODY, fill=TEXT_WHITE)
    draw.text((sw - 120, m4_y + 70), "10:22 AM ✓✓", font=FONT_MOCK_TINY, fill=(255, 255, 255, 180))

    # Bottom Composer Bar
    cy = sh - 140
    draw.rectangle([0, cy, sw, sh], fill=(20, 10, 32))
    draw.rounded_rectangle([35, cy + 20, sw - 120, cy + 90], radius=35, fill=CARD_SURFACE, outline=(255, 255, 255, 30), width=1)
    draw.text((65, cy + 40), "A little hello...", font=FONT_MOCK_BODY, fill=TEXT_MUTED)
    # Send button
    draw.ellipse([sw - 100, cy + 20, sw - 30, cy + 90], fill=ROSE_ACCENT)
    draw.text((sw - 74, cy + 38), "↑", font=FONT_MOCK_TITLE, fill=TEXT_WHITE)

# ----------------- Main Generator -----------------

SCREENS = [
    {
        "filename": "01_discover.png",
        "pill": "DISCOVER",
        "headline": "Find Real Connections",
        "subtitle": "Curated profiles matched on lifestyle & values",
        "builder": build_screen_discover,
    },
    {
        "filename": "02_verified.png",
        "pill": "SELFIE VERIFIED",
        "headline": "100% Genuine Profiles",
        "subtitle": "Live selfie verification guarantees zero fakes",
        "builder": build_screen_verified,
    },
    {
        "filename": "03_hangouts.png",
        "pill": "CITY HANGOUTS",
        "headline": "Meet Offline Safely",
        "subtitle": "Host or join public meetups, gigs & coffee nearby",
        "builder": build_screen_hangouts,
    },
    {
        "filename": "04_chemistry.png",
        "pill": "CHEMISTRY MATCH",
        "headline": "Check Your Chemistry",
        "subtitle": "Deep compatibility insights before your first hello",
        "builder": build_screen_chemistry,
    },
    {
        "filename": "05_chat.png",
        "pill": "REAL-TIME CHAT",
        "headline": "Meaningful Conversations",
        "subtitle": "Voice notes, icebreakers and authentic connection",
        "builder": build_screen_chat,
    },
]

def main():
    print("Generating 1080x1920 Play Store screenshots...")
    for item in SCREENS:
        print(f"Creating {item['filename']}...")
        canvas = create_base_canvas()
        draw_header(canvas, item['pill'], item['headline'], item['subtitle'])
        draw_device_mockup(canvas, item['builder'])
        
        out_path = os.path.join(OUTPUT_DIR, item['filename'])
        # Save as high-quality PNG
        canvas.save(out_path, format='PNG', optimize=True)
        print(f"Saved: {out_path}")
    print("All screenshots generated successfully in:", OUTPUT_DIR)

if __name__ == '__main__':
    main()
