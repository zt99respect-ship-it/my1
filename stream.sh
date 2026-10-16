#!/bin/bash
set +m

# ═══════════════════════════════════════════════════
#  Mystery Town Broadcast — Kick → Restream
#  شاشة انتظار مطابقة لتصميم HTML
# ═══════════════════════════════════════════════════

# ─── الإعدادات ───
TITLE_AR="لم يبدأ ستريمرز ميستري تاون"
SUBTITLE_AR="جاري انتضار ستريمرز ميستري تاون المذكورين اعلاه"
LABEL_AR="قائمة الستريمرز:"

COLOR_TITLE="#ff7700"
COLOR_SUB="#ffffff"
COLOR_LABEL="#ff8800"
COLOR_LIST="#ffb366"
BG_TOP_R=42; BG_TOP_G=16; BG_TOP_B=0
BG_BOT_R=10; BG_BOT_G=3;  BG_BOT_B=0
GLOW_R=255;  GLOW_G=120;  GLOW_B=20

FONT_SIZE_TITLE=100
FONT_SIZE_SUB=52
FONT_SIZE_LABEL=30
FONT_SIZE_LIST=22

Y_LIST_LABEL=50
Y_LIST_START=110
Y_TITLE=430
Y_SUB=560

STREAMERS_LIST="${STREAMERS_LIST:-SXB,abuswe7l,firas,tmnaa,JASER,DRAK0OLA,Sopfix,xlxwi,EAGLE,OSAMAH,NQ}"

LOGO_URL="https://k.top4top.io/p_39265ztwc0.png"
LOGO_W=180
LOGO_BOTTOM=60
LOGO_SHOW=5
LOGO_CYCLE=7

FPS=60
GOP=120

UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
# ═══════════════════════════════════════════════════

RESTREAM_KEY="${RESTREAM_KEY:-}"
[ -z "$RESTREAM_KEY" ] && { echo "❌ مفتاح Restream فارغ"; exit 1; }
[ -z "$STREAMERS_LIST" ] && { echo "❌ قائمة الستريمرز فارغة"; exit 1; }

RESTREAM_URL="rtmp://live.restream.io/live/$RESTREAM_KEY"
FIFO="/tmp/relay.ts"

# ─── الخطوط ───
FONT_AR=""
for C in "$HOME/.fonts/Cairo-var.ttf" "$HOME/.fonts/NotoSansArabic-Bold.ttf"; do
    [ -s "$C" ] && { FONT_AR="$C"; break; }
done
[ -z "$FONT_AR" ] && { echo "❌ لا يوجد خط عربي"; exit 1; }

FONT_EN="$HOME/.fonts/Orbitron-var.ttf"
[ ! -s "$FONT_EN" ] && { echo "❌ لا يوجد Orbitron"; exit 1; }

echo "🔤 الخطوط: عربي=$FONT_AR | إنجليزي=$FONT_EN"

IFS=',' read -r -a STREAMERS <<< "$STREAMERS_LIST"
echo "🔢 عدد الستريمرز: ${#STREAMERS[@]}"

# ═══════════════════════════════════════════════════
#  توليد صور الشاشة — مطابقة للتصميم
# ═══════════════════════════════════════════════════
cat > /tmp/make_standby.py <<PYEOF
from PIL import Image, ImageDraw, ImageFilter, ImageFont
import urllib.request, io, os

W, H = 1920, 1080
FONT_AR = "$FONT_AR"
FONT_EN = "$FONT_EN"
TITLE = "$TITLE_AR"
SUBTITLE = "$SUBTITLE_AR"
LABEL = "$LABEL_AR"
C_TITLE = "$COLOR_TITLE"
C_SUB = "$COLOR_SUB"
C_LABEL = "$COLOR_LABEL"
C_LIST = "$COLOR_LIST"
FS_TITLE = $FONT_SIZE_TITLE
FS_SUB = $FONT_SIZE_SUB
FS_LABEL = $FONT_SIZE_LABEL
FS_LIST = $FONT_SIZE_LIST
Y_LIST_LABEL = $Y_LIST_LABEL
Y_LIST_START = $Y_LIST_START
Y_TITLE = $Y_TITLE
Y_SUB = $Y_SUB
BG_TOP = ($BG_TOP_R, $BG_TOP_G, $BG_TOP_B)
BG_BOT = ($BG_BOT_R, $BG_BOT_G, $BG_BOT_B)
GLOW = ($GLOW_R, $GLOW_G, $GLOW_B, 70)
LOGO_URL = "$LOGO_URL"
LOGO_W = $LOGO_W
STREAMERS_STR = "$STREAMERS_LIST"
os.makedirs("/tmp/standby", exist_ok=True)

def load_font(path, size, weight=700):
    font = ImageFont.truetype(path, size)
    try:
        axes = font.get_variation_axes()
        if len(axes) == 1:
            font.set_variation_by_axes([weight])
        elif len(axes) == 2:
            font.set_variation_by_axes([0, weight])
        elif len(axes) == 3:
            font.set_variation_by_axes([0, weight, 0])
    except Exception:
        pass
    return font

# ═══ 1) الخلفية (تدرج + توهج + نمط ماس + خط الفاصل) ═══
bg = Image.new("RGB", (W, H))
d = ImageDraw.Draw(bg)
for y in range(H):
    t = y / H
    r = int(BG_TOP[0] + (BG_BOT[0] - BG_TOP[0]) * t)
    g = int(BG_TOP[1] + (BG_BOT[1] - BG_TOP[1]) * t)
    b = int(BG_TOP[2] + (BG_BOT[2] - BG_TOP[2]) * t)
    d.line([(0, y), (W, y)], fill=(r, g, b))
bg = bg.convert("RGBA")

# توهج مركزي
glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
gd = ImageDraw.Draw(glow)
gd.ellipse([W//2 - 800, H//2 - 600, W//2 + 800, H//2 + 600], fill=GLOW)
glow = glow.filter(ImageFilter.GaussianBlur(300))
bg = Image.alpha_composite(bg, glow)

# نمط ماس أسفل
pattern = Image.new("RGBA", (W, H), (0, 0, 0, 0))
pd = ImageDraw.Draw(pattern)
size = 60
start_y = H - 240
row = 0
y = start_y
while y < H + size:
    x = (size // 2) if row % 2 else 0
    while x < W + size:
        pts = [(x, y - size//2), (x + size//2, y), (x, y + size//2), (x - size//2, y)]
        pd.polygon(pts, outline=(255, 120, 20, 180), width=2)
        x += size
    y += size // 2
    row += 1
mask = Image.new("L", (W, H), 0)
md = ImageDraw.Draw(mask)
for yy in range(start_y, H):
    a = min(200, int((yy - start_y) / 0.6))
    md.line([(0, yy), (W, yy)], fill=a)
pattern.putalpha(mask)
bg = Image.alpha_composite(bg, pattern)

# خط الفاصل (Divider) — نصف العرض
divider_y = 340
divider_w = int(W * 0.55)
divider_x = (W - divider_w) // 2
div_glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
divd = ImageDraw.Draw(div_glow)
for i in range(divider_w):
    t = i / divider_w
    alpha = int(180 * (1 - abs(t - 0.5) * 2))
    divd.line([(divider_x + i, divider_y), (divider_x + i, divider_y + 1)], fill=(255, 120, 20, alpha))
div_glow = div_glow.filter(ImageFilter.GaussianBlur(2))
bg = Image.alpha_composite(bg, div_glow)

# ◆ diamond marker وسط الخط
bd = ImageDraw.Draw(bg)
font_diamond = load_font(FONT_AR, 28, 700)
bd.text((W//2, divider_y), "◆", font=font_diamond, fill=(255, 120, 20, 255), anchor="mm", direction="ltr")

bg.convert("RGB").save("/tmp/standby/bg.png", "PNG")
print("✅ bg.png")

# ═══ 2) دالة رسم نص مع توهج ═══
def make_text_png(text, font, color, out, direction="rtl"):
    c = color.lstrip("#")
    r, g, b = tuple(int(c[i:i+2], 16) for i in (0, 2, 4))

    tmp = Image.new("RGBA", (10, 10), (0, 0, 0, 0))
    td = ImageDraw.Draw(tmp)
    bbox = td.textbbox((0, 0), text, font=font, direction=direction)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    pad = 80
    Wn = tw + pad * 2
    Hn = th + pad * 2

    glow_layer = Image.new("RGBA", (Wn, Hn), (0, 0, 0, 0))
    gx = pad - bbox[0]
    gy = pad - bbox[1]
    for radius, alpha in [(40, 90), (25, 140), (12, 200)]:
        t = Image.new("RGBA", (Wn, Hn), (0, 0, 0, 0))
        tdd = ImageDraw.Draw(t)
        tdd.text((gx, gy), text, font=font, fill=(r, g, b, alpha), direction=direction)
        t = t.filter(ImageFilter.GaussianBlur(radius))
        glow_layer = Image.alpha_composite(glow_layer, t)

    outline = Image.new("RGBA", (Wn, Hn), (0, 0, 0, 0))
    od = ImageDraw.Draw(outline)
    ow = max(3, int(font.size / 22))
    for dx in range(-ow, ow + 1):
        for dy in range(-ow, ow + 1):
            if dx*dx + dy*dy <= ow*ow:
                od.text((gx+dx, gy+dy), text, font=font, fill=(0, 0, 0, 255), direction=direction)

    txt = Image.new("RGBA", (Wn, Hn), (0, 0, 0, 0))
    td2 = ImageDraw.Draw(txt)
    td2.text((gx, gy), text, font=font, fill=(r, g, b, 255), direction=direction)

    final = Image.alpha_composite(glow_layer, outline)
    final = Image.alpha_composite(final, txt)
    final.save(out, "PNG")
    return final.size

# ═══ 3) النصوص ═══
font_title = load_font(FONT_AR, FS_TITLE, 900)
font_sub = load_font(FONT_AR, FS_SUB, 700)
font_label = load_font(FONT_AR, FS_LABEL, 900)
font_list = load_font(FONT_EN, FS_LIST, 700)

title_size = make_text_png(TITLE, font_title, C_TITLE, "/tmp/standby/title.png", "rtl")
sub_size = make_text_png(SUBTITLE, font_sub, C_SUB, "/tmp/standby/sub.png", "rtl")
label_size = make_text_png(LABEL, font_label, C_LABEL, "/tmp/standby/label.png", "rtl")
print(f"✅ title.png {title_size} | sub.png {sub_size} | label.png {label_size}")

# ═══ 4) قائمة الستريمرز (tags) ═══
items = [s.strip() for s in STREAMERS_STR.split(',') if s.strip()]
total = len(items)

# توزيع على 3 أسطر
per_line = max(4, (total + 2) // 3)
lines = []
for i in range(0, total, per_line):
    lines.append(items[i:i+per_line])

# حساب أبعاد tag واحد
tag_pad_x = 22
tag_pad_y = 10
tag_font_h = FS_LIST + 4

# حساب الأبعاد الكلية
dummy = Image.new("RGBA", (10, 10), (0, 0, 0, 0))
dd = ImageDraw.Draw(dummy)

tags_per_line_px = []
for line_items in lines:
    total_w = 0
    for s in line_items:
        bb = dd.textbbox((0, 0), s.upper(), font=font_list)
        w = bb[2] - bb[0] + tag_pad_x * 2
        total_w += w + 12  # 12 = gap
    tags_per_line_px.append(total_w)

max_w = max(tags_per_line_px) if tags_per_line_px else 0
line_h = tag_font_h + tag_pad_y * 2 + 12  # 12 = gap vertical
total_h = len(lines) * line_h

list_img = Image.new("RGBA", (max_w + 40, total_h + 20), (0, 0, 0, 0))
ld = ImageDraw.Draw(list_img)

y_off = 10
for line_items in lines:
    # حساب العرض الكلي لهذا السطر
    line_w = 0
    items_w = []
    for s in line_items:
        bb = dd.textbbox((0, 0), s.upper(), font=font_list)
        w = bb[2] - bb[0] + tag_pad_x * 2
        items_w.append(w)
        line_w += w + 12
    line_w -= 12

    x_off = (list_img.width - line_w) // 2

    for i, s in enumerate(line_items):
        w = items_w[i]
        # خلفية tag
        tag_bg = Image.new("RGBA", (w, line_h - 12), (0, 0, 0, 0))
        tbd = ImageDraw.Draw(tag_bg)
        # مستطيل بحواف دائرية
        tbd.rounded_rectangle(
            [(0, 0), (w, line_h - 12)],
            radius=(line_h - 12) // 2,
            fill=(255, 120, 20, 20),
            outline=(255, 120, 20, 200),
            width=2
        )
        list_img.alpha_composite(tag_bg, (x_off, y_off))

        # النص
        bb = dd.textbbox((0, 0), s.upper(), font=font_list)
        tw = bb[2] - bb[0]
        th = bb[3] - bb[1]
        tx = x_off + (w - tw) // 2 - bb[0]
        ty = y_off + (line_h - 12 - th) // 2 - bb[1] + 2

        ld.text((tx, ty), s.upper(), font=font_list, fill=C_LIST)

        x_off += w + 12

    y_off += line_h

list_img.save("/tmp/standby/list.png", "PNG")
print(f"✅ list.png {list_img.size}")

# ═══ 5) الشعار ═══
try:
    req = urllib.request.Request(LOGO_URL, headers={"User-Agent": "Mozilla/5.0"})
    logo_data = urllib.request.urlopen(req, timeout=25).read()
    logo = Image.open(io.BytesIO(logo_data)).convert("RGBA")
    ratio = LOGO_W / logo.width
    logo = logo.resize((LOGO_W, int(logo.height * ratio)), Image.LANCZOS)
    logo.save("/tmp/standby/logo.png", "PNG")
    print(f"✅ logo.png {logo.size}")
except Exception as e:
    print(f"⚠️ logo fail: {e}")
    ph = Image.new("RGBA", (LOGO_W, LOGO_W), (0, 0, 0, 0))
    ph.save("/tmp/standby/logo.png", "PNG")

# ═══ 6) Content PNG شامل (list + title + sub) في مواضعها ═══
content = Image.new("RGBA", (W, H), (0, 0, 0, 0))
cd = ImageDraw.Draw(content)

# list: at top center
list_img_pos = ((W - list_img.width) // 2, Y_LIST_START)
content.alpha_composite(list_img, list_img_pos)

# label: above list
label_img = Image.open("/tmp/standby/label.png").convert("RGBA")
label_pos = ((W - label_img.width) // 2, Y_LIST_LABEL - label_img.height // 2)
content.alpha_composite(label_img, label_pos)

# title: center
title_img = Image.open("/tmp/standby/title.png").convert("RGBA")
title_pos = ((W - title_img.width) // 2, Y_TITLE - title_img.height // 2)
content.alpha_composite(title_img, title_pos)

# subtitle: below title
sub_img = Image.open("/tmp/standby/sub.png").convert("RGBA")
sub_pos = ((W - sub_img.width) // 2, Y_SUB - sub_img.height // 2)
content.alpha_composite(sub_img, sub_pos)

content.save("/tmp/standby/content.png", "PNG")
print(f"✅ content.png {content.size}")
PYEOF

echo "🎨 توليد صور الشاشة..."
python3 /tmp/make_standby.py
[ ! -s /tmp/standby/bg.png ] && { echo "❌ فشل التوليد"; exit 1; }

# ═══════════════════════════════════════════════════
#  FIFO
# ═══════════════════════════════════════════════════
rm -f "$FIFO"
mkfifo "$FIFO"
exec 3<>"$FIFO"

# ═══════════════════════════════════════════════════
#  منتج شاشة الانتظار (متحركة)
# ═══════════════════════════════════════════════════
start_producer_standby() {
    echo "⏳ تشغيل الشاشة المتحركة..."
    ffmpeg -y -hide_banner -loglevel warning -nostdin \
        -loop 1 -framerate $FPS -i /tmp/standby/bg.png \
        -loop 1 -framerate $FPS -i /tmp/standby/content.png \
        -loop 1 -framerate $FPS -i /tmp/standby/logo.png \
        -f lavfi -i "anullsrc=r=44100:cl=stereo" \
        -filter_complex "\
[0:v]format=rgba[bg];\
[1:v]format=rgba[content];\
[bg][content]overlay=0:0[v1];\
[2:v]format=rgba,scale='$LOGO_W*(1+0.06*sin(2*PI*t/3.5))':-1:eval=frame[logo_big];\
[v1][logo_big]overlay=x=(W-w)/2:y=H-h-$LOGO_BOTTOM:enable='between(mod(t\,$LOGO_CYCLE)\,0.3\,$LOGO_SHOW)'[v2];\
[v2]eq=brightness='0.02*sin(2*PI*t/5)':eval=frame[vout]" \
        -map "[vout]" -map 3:a:0 \
        -c:v libx264 -preset ultrafast -tune zerolatency \
        -pix_fmt yuv420p -r $FPS -g $GOP \
        -c:a aac -b:a 128k -ar 44100 -ac 2 \
        -max_muxing_queue_size 4096 \
        -f mpegts "$FIFO" >/tmp/prod.log 2>&1 &
    PROD=$!
}

# ═══════════════════════════════════════════════════
#  منتج البث المباشر
# ═══════════════════════════════════════════════════
start_producer_live() {
    local M3U8="$1"
    local NAME="$2"
    echo "🔴 منتج مباشر: $NAME"
    ffmpeg -y -hide_banner -loglevel warning -nostdin \
        -headers "User-Agent: $UA" \
        -reconnect 1 -reconnect_at_eof 1 -reconnect_streamed 1 \
        -reconnect_delay_max 5 \
        -analyzeduration 2000000 -probesize 2000000 \
        -fflags +genpts+igndts \
        -i "$M3U8" \
        -c:v copy -c:a aac -b:a 128k -ar 44100 -ac 2 \
        -max_muxing_queue_size 4096 \
        -muxdelay 0.1 -muxpreload 0.1 \
        -f mpegts "$FIFO" >/tmp/prod.log 2>&1 &
    PROD=$!
}

# ═══════════════════════════════════════════════════
#  المخرج — Bitrate 6500k
# ═══════════════════════════════════════════════════
start_output() {
    echo "🔗 الاتصال بـ Restream..."
    ffmpeg -y -hide_banner -loglevel warning -nostdin \
        -thread_queue_size 512 \
        -f mpegts -i "$FIFO" \
        -c:v libx264 -preset ultrafast -tune zerolatency \
        -pix_fmt yuv420p -g $GOP -r $FPS \
        -b:v 6500k -maxrate 7000k -bufsize 14000k \
        -c:a aac -b:a 160k -ar 44100 -ac 2 \
        -max_muxing_queue_size 4096 \
        -flvflags no_duration_filesize \
        -f flv "$RESTREAM_URL" >/tmp/out.log 2>&1 &
    OUT=$!
    sleep 6
    if ! kill -0 "$OUT" 2>/dev/null; then
        echo "❌ فشل المخرج:"; tail -n 10 /tmp/out.log
        return 1
    fi
    echo "✅ المخرج شغال (PID: $OUT)"
    return 0
}

kill_producer() {
    [ -n "$PROD" ] && kill -9 "$PROD" 2>/dev/null
    [ -n "$PROD" ] && wait "$PROD" 2>/dev/null
    PROD=""
}

# ═══════════════════════════════════════════════════
#  التشغيل الرئيسي
# ═══════════════════════════════════════════════════
echo "🚀 بدء التشغيل..."

start_producer_standby
sleep 5
kill -0 "$PROD" 2>/dev/null || { echo "❌ المنتج مات"; cat /tmp/prod.log; exit 1; }
echo "✅ شاشة الانتظار شغالة (PID: $PROD)"

start_output || exit 1

( if [ -n "$GH_TOKEN" ] && [ -n "$GITHUB_RUN_ID" ]; then
    OLD=$(timeout 10 gh run list --workflow="main.yml" --status=in_progress \
          --json databaseId -q ".[].databaseId" 2>/dev/null | \
          awk -v m="$GITHUB_RUN_ID" '$1 < m')
    for R in $OLD; do
        echo "🛑 إلغاء: $R"
        timeout 8 gh run cancel "$R" 2>/dev/null
    done
  fi ) >/tmp/cancel.log 2>&1 &

MODE="STANDBY"
ACTIVE=""
ACTIVE_IDX=-1
TICK=0

while true; do
    if ! kill -0 "$OUT" 2>/dev/null; then
        echo "⚠️ المخرج مات — إعادة..."
        kill_producer
        sleep 2
        start_output || exit 1
        sleep 2
        continue
    fi

    if ! kill -0 "$PROD" 2>/dev/null; then
        echo "⚠️ المنتج مات — إعادة..."
        if [ "$MODE" = "LIVE" ] && [ -n "$ACTIVE" ]; then
            URL=$(timeout 20 streamlink --http-header "User-Agent=$UA" \
                  --stream-timeout 15 "https://kick.com/$ACTIVE" best \
                  --stream-url 2>/dev/null | grep -m1 "^http")
            if [ -n "$URL" ]; then
                start_producer_live "$URL" "$ACTIVE"
            else
                start_producer_standby
                MODE="STANDBY"; ACTIVE=""; ACTIVE_IDX=-1
            fi
        else
            start_producer_standby
            MODE="STANDBY"
        fi
        sleep 3
        continue
    fi

    FOUND=""; FOUND_URL=""; FOUND_IDX=-1
    LIMIT=${#STREAMERS[@]}
    if [ "$MODE" = "LIVE" ] && [ "$ACTIVE_IDX" -ge 0 ]; then
        LIMIT=$((ACTIVE_IDX + 1))
    fi

    for ((i=0; i<LIMIT; i++)); do
        S=$(echo "${STREAMERS[$i]}" | xargs)
        [ -z "$S" ] && continue
        URL=$(timeout 20 streamlink --http-header "User-Agent=$UA" \
              --stream-timeout 15 "https://kick.com/$S" best \
              --stream-url 2>/dev/null | grep -m1 "^http")
        if [ -n "$URL" ]; then
            FOUND="$S"; FOUND_URL="$URL"; FOUND_IDX=$i; break
        fi
    done

    if [ -n "$FOUND" ]; then
        if [ "$MODE" != "LIVE" ] || [ "$ACTIVE" != "$FOUND" ]; then
            echo "🎯 التحويل إلى: $FOUND"
            kill_producer
            sleep 1
            start_producer_live "$FOUND_URL" "$FOUND"
            sleep 6
            if kill -0 "$PROD" 2>/dev/null; then
                MODE="LIVE"; ACTIVE="$FOUND"; ACTIVE_IDX=$FOUND_IDX
                echo "✅ مباشر: $FOUND"
            else
                echo "⚠️ فشل $FOUND"
                MODE="NONE"
            fi
        fi
    else
        if [ "$MODE" != "STANDBY" ]; then
            echo "⏳ لا يوجد بث — عودة للانتظار"
            kill_producer
            sleep 1
            start_producer_standby
            sleep 3
            MODE="STANDBY"; ACTIVE=""; ACTIVE_IDX=-1
        fi
    fi

    TICK=$((TICK + 1))
    if [ $((TICK % 4)) -eq 0 ]; then
        OS=$(kill -0 "$OUT" 2>/dev/null && echo "حي" || echo "ميت")
        PS=$(kill -0 "$PROD" 2>/dev/null && echo "حي" || echo "ميت")
        echo "── [$(date -u +%H:%M:%S)] $MODE | OUT=$OS | PROD=$PS ──"
    fi

    sleep 15
done
