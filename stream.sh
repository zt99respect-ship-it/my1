#!/bin/bash

# ==============================================================================
# نظام البث المستمر 24/7 - البث المباشر بأعلى جودة (محلول جذرياً لجميع المشاكل)
# ==============================================================================

KICK_CHANNEL="${KICK_CHANNEL:-PEERLESS}"
RESTREAM_KEY="${RESTREAM_KEY:-}"
YOUTUBE_KEY="${YOUTUBE_KEY:-}"
QUALITY="${STREAM_QUALITY:-best}"
DEST="${STREAM_DEST:-restream}"

# تنظيف المفاتيح
if [[ "$YOUTUBE_KEY" == "X" || "$YOUTUBE_KEY" == "x" ]]; then YOUTUBE_KEY=""; fi
if [[ "$RESTREAM_KEY" == "X" || "$RESTREAM_KEY" == "x" ]]; then RESTREAM_KEY=""; fi

STREAMER_NAME=$(echo "$KICK_CHANNEL" | tr '[:lower:]' '[:upper:]')

# جلب مسار ملف الخط
FONT_PATH=$(fc-match --format="%{file}" "Noto Naskh Arabic" 2>/dev/null)
if [ -z "$FONT_PATH" ] || [ ! -f "$FONT_PATH" ]; then
    FONT_PATH="/usr/share/fonts/truetype/noto/NotoNaskhArabic-Regular.ttf"
fi

echo "========================================"
echo "🚀 نظام المراقبة الذكية للقناة: $STREAMER_NAME"
echo "🎯 وجهة البث المحددة: $DEST"
echo "🎨 مسار الخط المستخدم: $FONT_PATH"
echo "========================================"

# التحقق من وجود مفاتيح البث قبل البدء
if [ "$DEST" == "restream" ] && [ -z "$RESTREAM_KEY" ]; then
    echo "❌ خطأ قاتل: مفتاح Restream غير موجود! يرجى التأكد من ضبط RESTREAM_KEY في Secrets."
    exit 1
fi

if [ "$DEST" == "youtube" ] && [ -z "$YOUTUBE_KEY" ]; then
    echo "❌ خطأ قاتل: مفتاح YouTube غير موجود! يرجى التأكد من ضبط YOUTUBE_KEY في Secrets."
    exit 1
fi

STREAM_PID=""
CURRENT_MODE="NONE"

# تثبيت المكتبات المطلوبة لإنشاء الصورة والصوت الصامت
python3 -m pip install --quiet pillow 2>/dev/null

# إنشاء صورة الانتظار وصوت صامت نقي عبر Python
generate_standby_assets() {
    python3 -c "
from PIL import Image, ImageDraw, ImageFont
import wave, struct, sys

streamer = sys.argv[1]
font_path = sys.argv[2]

# إنشاء صورة الانتظار
img = Image.new('RGB', (1920, 1080), color='#140024')
draw = ImageDraw.Draw(img)

try:
    font_title = ImageFont.truetype(font_path, 55)
    font_sub = ImageFont.truetype(font_path, 38)
except Exception:
    font_title = font_sub = ImageFont.load_default()

text1 = 'لم يبدأ البث المباشر بعد...'
text2 = f'جاري انتظار الستريمر {streamer}'

b1 = draw.textbbox((0, 0), text1, font=font_title)
b2 = draw.textbbox((0, 0), text2, font=font_sub)

draw.text(((1920 - (b1[2]-b1[0]))/2, 480 - (b1[3]-b1[1])/2), text1, fill='#FEB4D8', font=font_title)
draw.text(((1920 - (b2[2]-b2[0]))/2, 580 - (b2[3]-b2[1])/2), text2, fill='#F755A8', font=font_sub)

img.save('/tmp/standby.png')

# إنشاء ملف صوت WAV صامت حقيقي لتفادي أخطاء lavfi anullsrc
with wave.open('/tmp/silent.wav', 'w') as wav_file:
    wav_file.setnchannels(2)
    wav_file.setsampwidth(2)
    wav_file.setframerate(44100)
    wav_file.writeframes(struct.pack('<h', 0) * (44100 * 2 * 2))
" "$STREAMER_NAME" "$FONT_PATH"
}

cleanup() {
    echo "🧹 إيقاف عمليات البث..."
    trap - EXIT INT TERM
    [ -n "$STREAM_PID" ] && kill -9 "$STREAM_PID" 2>/dev/null
    exit 0
}
trap cleanup EXIT INT TERM

stop_stream() {
    if [ -n "$STREAM_PID" ]; then
        kill -9 "$STREAM_PID" 2>/dev/null
        STREAM_PID=""
    fi
}

get_outputs() {
    if [ "$DEST" == "youtube" ]; then
        echo "-f flv rtmp://a.rtmp.youtube.com/live2/$YOUTUBE_KEY"
    elif [ "$DEST" == "restream" ]; then
        echo "-f flv rtmp://live.restream.io/live/$RESTREAM_KEY"
    else
        echo "-f flv rtmp://live.restream.io/live/$RESTREAM_KEY -f flv rtmp://a.rtmp.youtube.com/live2/$YOUTUBE_KEY"
    fi
}

start_standby_stream() {
    stop_stream

    # إنشاء الصورة وملف الصوت الصامت
    generate_standby_assets

    echo "⏳ بدء بث شاشة الانتظار إلى الوجهة المحددة (1080p60)..."
    OUTPUTS=$(get_outputs)

    # استخدام ملف صوت WAV حقيقي وبمعدل إطارات محدد لتفادي الـ Segmentation Fault
    ffmpeg -hide_banner -loglevel error -nostdin \
      -re -framerate 60 -loop 1 -i /tmp/standby.png \
      -stream_loop -1 -i /tmp/silent.wav \
      -map 0:v:0 -map 1:a:0 \
      -c:v libx264 -preset superfast -tune zerolatency -pix_fmt yuv420p -r 60 -g 120 -b:v 3500k \
      -c:a aac -b:a 128k -ar 44100 \
      -flvflags no_duration_filesize \
      $OUTPUTS >/tmp/ffmpeg.log 2>&1 &
    STREAM_PID=$!
}

start_live_stream() {
    local M3U8="$1"
    stop_stream
    echo "🔴 بدء إعادة بث القناة المباشرة بأعلى جودة وسلاسة (1080p60)..."
    OUTPUTS=$(get_outputs)
    ffmpeg -hide_banner -loglevel error -nostdin \
      -fflags +genpts -i "$M3U8" \
      -c:v libx264 -preset superfast -tune zerolatency -pix_fmt yuv420p -r 60 -g 120 \
      -b:v 6000k -maxrate 6000k -bufsize 12000k \
      -c:a aac -b:a 160k -ar 44100 \
      -flvflags no_duration_filesize \
      $OUTPUTS >/tmp/ffmpeg.log 2>&1 &
    STREAM_PID=$!
}

while true; do
    KICK_M3U8=$(streamlink --hls-live-edge 3 --stream-segment-threads 4 "https://kick.com/$KICK_CHANNEL" "$QUALITY" --stream-url 2>/dev/null | grep -m1 "^http")

    if [ -n "$KICK_M3U8" ]; then
        if [ "$CURRENT_MODE" != "LIVE" ] || ! kill -0 "$STREAM_PID" 2>/dev/null; then
            if [ -n "$STREAM_PID" ] && ! kill -0 "$STREAM_PID" 2>/dev/null; then
                echo "⚠️ توقف البث المباشر السابق! تفاصيل الخطأ:"
                [ -f /tmp/ffmpeg.log ] && tail -n 15 /tmp/ffmpeg.log
            fi
            echo "✅ الستريمر $STREAMER_NAME أونلاين! التبديل للبث المباشر..."
            start_live_stream "$KICK_M3U8"
            CURRENT_MODE="LIVE"
        fi
    else
        if [ "$CURRENT_MODE" != "STANDBY" ] || ! kill -0 "$STREAM_PID" 2>/dev/null; then
            if [ -n "$STREAM_PID" ] && ! kill -0 "$STREAM_PID" 2>/dev/null; then
                echo "⚠️ توقف بث الانتظار السابق! تفاصيل الخطأ:"
                [ -f /tmp/ffmpeg.log ] && tail -n 15 /tmp/ffmpeg.log
            fi
            echo "⏳ الستريمر $STREAMER_NAME غير متصل.. عرض شاشة الانتظار..."
            start_standby_stream
            CURRENT_MODE="STANDBY"
        fi
    fi

    sleep 10
done
