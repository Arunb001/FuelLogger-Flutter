import os
from PIL import Image, ImageDraw, ImageFont

output_dir = 'C:/Users/arunb/PycharmProjects/FuelLogger-Flutter/store_assets/screenshots'
os.makedirs(output_dir, exist_ok=True)

# 1080 x 1920 (9:16) standard Google Play Store dimensions
TARGET_W, TARGET_H = 1080, 1920

shots = [
    {
        'file': 'C:/Users/arunb/.gemini/antigravity/brain/77ae84a7-6f8b-4704-9bdc-ff81cfe6bb2f/.user_uploaded/media_1795428764308_8458ca13.jpg',
        'title': 'Real-World Mileage & Telemetry',
        'sub': 'Accurate lifetime vehicle analytics & cycle tracking',
        'out': '01_home_dashboard.png',
        'tag_color': (105, 240, 174) # green
    },
    {
        'file': 'C:/Users/arunb/.gemini/antigravity/brain/77ae84a7-6f8b-4704-9bdc-ff81cfe6bb2f/.user_uploaded/media_1795428764292_30ab17c5.jpg',
        'title': 'Breakdown by Fuel Type',
        'sub': 'Compare standard vs premium fuel performance',
        'out': '02_calculations_telemetry.png',
        'tag_color': (64, 196, 255) # blue
    },
    {
        'file': 'C:/Users/arunb/.gemini/antigravity/brain/77ae84a7-6f8b-4704-9bdc-ff81cfe6bb2f/.user_uploaded/media_1795428764288_f658dfa4.jpg',
        'title': 'Smart Fill-Up Logging',
        'sub': 'Full tank & partial fill cycle tracking',
        'out': '03_log_fill_up.png',
        'tag_color': (255, 82, 82) # red
    },
    {
        'file': 'C:/Users/arunb/.gemini/antigravity/brain/77ae84a7-6f8b-4704-9bdc-ff81cfe6bb2f/.user_uploaded/media_1795428764301_9cb3e886.jpg',
        'title': 'Multi-Vehicle Garage',
        'sub': 'Customize vehicles, colors & custom fuel types',
        'out': '04_garage_settings.png',
        'tag_color': (255, 171, 64) # amber
    },
    {
        'file': 'C:/Users/arunb/.gemini/antigravity/brain/77ae84a7-6f8b-4704-9bdc-ff81cfe6bb2f/.user_uploaded/media_1795428764305_a664b91c.jpg',
        'title': 'AMOLED Dark & 100% Offline',
        'sub': '1-Tap Google Sign-In with private cloud backup',
        'out': '05_secure_login.png',
        'tag_color': (105, 240, 174) # green
    }
]

try:
    font_title = ImageFont.truetype('arialbd.ttf', 50)
    font_sub = ImageFont.truetype('arial.ttf', 26)
except Exception:
    font_title = ImageFont.load_default()
    font_sub = ImageFont.load_default()

for s in shots:
    # Create AMOLED dark canvas #14161C
    canvas = Image.new('RGB', (TARGET_W, TARGET_H), (20, 22, 28))
    draw = ImageDraw.Draw(canvas)
    
    # Text headers
    t_bbox = draw.textbbox((0, 0), s['title'], font=font_title)
    t_w = t_bbox[2] - t_bbox[0]
    draw.text(((TARGET_W - t_w) // 2, 80), s['title'], fill=(255, 255, 255), font=font_title)
    
    # Subtitle
    s_bbox = draw.textbbox((0, 0), s['sub'], font=font_sub)
    s_w = s_bbox[2] - s_bbox[0]
    draw.text(((TARGET_W - s_w) // 2, 150), s['sub'], fill=s['tag_color'], font=font_sub)
    
    # Load app screen
    app_img = Image.open(s['file']).convert('RGB')
    
    # Scale app image to fit height nicely from y=225 to y=1900
    avail_h = TARGET_H - 235
    scale = avail_h / float(app_img.height)
    new_w = int(app_img.width * scale)
    new_h = int(app_img.height * scale)
    app_scaled = app_img.resize((new_w, new_h), Image.Resampling.LANCZOS)
    
    # Center horizontally
    pos_x = (TARGET_W - new_w) // 2
    pos_y = 225
    
    # Subtle border/shadow
    draw.rounded_rectangle([pos_x - 2, pos_y - 2, pos_x + new_w + 2, pos_y + new_h + 2], radius=16, outline=(40, 45, 58), width=2)
    
    # Paste app screen
    canvas.paste(app_scaled, (pos_x, pos_y))
    
    out_path = os.path.join(output_dir, s['out'])
    canvas.save(out_path, 'PNG')
    print("Generated: " + s['out'] + " | Size: " + str(canvas.size))

print("All screenshots generated successfully.")
