#!/bin/bash
# ==============================================================================
# بث ذكي 24/7 من Kick إلى YouTube / Restream مع شاشة انتظار عربية متحركة.
#
# الحل التقني لمشكلة النص العربي:
#   تم اعتماد libass (عبر فلتر ass=) بدلاً من drawtext.
#   libass يستخدم HarfBuzz لمعالجة تشكيل الحروف العربية واتجاه RTL تلقائياً
#   من النص المنطقي الطبيعي، فلا حاجة لـ arabic_reshaper ولا python-bidi.
#
# استراتيجية الشاشة المتحركة:
#   1) توليد ملف ASS فيه 10 ثوانٍ من الأنيميشن اللانهائي (بدون \fad).
#   2) ترميز standby.mp4 عالي الجودة من ASS على خلفية بنفسجية.
#   3) بث الفيديو مع -stream_loop -1 وإعادة ترميز حية (لضمان timestamps صحيحة).
#   4) عند عودة الستريمر: إيقاف standby وبدء البث المباشر فوراً.
# ==============================================================================

set -u

KICK_CHANNEL="${KICK_CHANNEL:-W1pey}"
YOUTUBE_KEY="${YOUTUBE_KEY:-}"
RESTREAM_KEY="${RESTREAM_KEY:-}"
QUALITY="${STREAM_QUALITY:-best}"
DEST="${STREAM_DEST:-both}"

RTMP_YT="rtmp://a.rtmp.youtube.com/live2/${YOUTUBE_KEY}"
RTMP_RS="rtmp://live.restream.io/live/${RESTREAM_KEY}"

STANDBY_ASS="/tmp/standby.ass"
STANDBY_MP4="/tmp/standby.mp4"

# إخفاء الأسرار من السجلات
[ -n "$YOUTUBE_KEY" ]  && echo "::add-mask::${YOUTUBE_KEY}"
[ -n "$RESTREAM_KEY" ] && echo "::add-mask::${RESTREAM_KEY}"

# ---- التحقق من المدخلات ----
DO_YT=false
DO_RS=false
case "$DEST" in
  youtube)  DO_YT=true ;;
  restream) DO_RS=true ;;
  both)     DO_YT=true; DO_RS=true ;;
  *) echo "❌ DEST غير صالح: $DEST"; exit 1 ;;
esac

if [ "$DO_YT" = true ] && [ -z "$YOUTUBE_KEY" ]; then
  echo "❌ YouTube مطلوب لكن YOUTUBE_KEY فارغ"; exit 1
fi
if [ "$DO_RS" = true ] && [ -z "$RESTREAM_KEY" ]; then
  echo "❌ Restream مطلوب لكن RESTREAM_KEY فارغ"; exit 1
fi

# ---- التحقق من libass ----
if ! ffmpeg -hide_banner -filters 2>&1 | grep -qE "^\s*\S+\s+ass\s"; then
  echo "❌ فلتر ass (libass) غير متوفر في FFmpeg"; exit 1
fi

STREAMER_NAME=$(echo "$KICK_CHANNEL" | tr '[:lower:]' '[:upper:]')

# ---- اختيار الخط العربي ----
FONT_NAME=""
for candidate in "Noto Naskh Arabic" "Scheherazade New" "Noto Sans Arabic" "Amiri" "DejaVu Sans"; do
  if fc-list : family 2>/dev/null | grep -qiF "$candidate"; then
    FONT_NAME="$candidate"
    break
  fi
done
[ -z "$FONT_NAME" ] && FONT_NAME="Sans"

echo "=========================================="
echo "🚀 القناة: $STREAMER_NAME  |  الوجهة: $DEST"
echo "🎨 الخط: $FONT_NAME"
echo "=========================================="

# ---- الحالة ----
PID_YT=""
PID_RS=""
WAS_LIVE=false
MODE=""   # "" | "live" | "standby"

# ---- توليد ملف ASS (10 ثوانٍ، loop سلس) ----
generate_ass() {
  cat > "$STANDBY_ASS" <<EOF
[Script Info]
ScriptType: v4.00+
PlayResX: 1280
PlayResY: 720
WrapStyle: 0
ScaledBorderAndShadow: yes

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: Title,${FONT_NAME},52,&H00FEB4D8,&H00000000,&H00000000,&H80000000,-1,0,0,0,100,100,0,0,1,2,1,8,10,10,300,1
Style: Subtitle,${FONT_NAME},34,&H00F755A8,&H00000000,&H00000000,&H80000000,-1,0,0,0,100,100,0,0,1,2,1,8,10,10,380,1

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
Dialogue: 0,0:00:00.00,0:00:10.00,Title,,0,0,0,,{\frz-1\t(0,2500,\fscx105\fscy105)\t(2500,5000,\fscx100\fscy100)\t(5000,7500,\fscx105\fscy105)\t(7500,10000,\fscx100\fscy100)\t(0,5000,\frz1)\t(5000,10000,\frz-1)}علق البث من قبل الستريمر ${STREAMER_NAME}
Dialogue: 0,0:00:00.00,0:00:10.00,Subtitle,,0,0,0,,{\blur0.5\t(0,2500,\blur2)\t(2500,5000,\blur0.5)\t(5000,7500,\blur2)\t(7500,10000,\blur0.5)\t(0,2500,\fscx103\fscy103)\t(2500,5000,\fscx100\fscy100)\t(5000,7500,\fscx103\fscy103)\t(7500,10000,\fscx100\fscy100)}جاري إعادة الاتصال تلقائياً...
EOF
}

# ---- توليد standby.mp4 مرة واحدة ----
generate_standby_video() {
  echo "🎬 توليد فيديو الانتظار (10 ثوانٍ)..."
  generate_ass
  ffmpeg -y -hide_banner -loglevel error \
    -f lavfi -i "color=c=0x26001b:s=1280x720:r=30:d=10" \
    -f lavfi -i "anullsrc=r=44100:cl=stereo:d=10" \
    -vf "ass=${STANDBY_ASS}" \
    -c:v libx264 -preset medium -tune stillimage \
    -crf 18 -pix_fmt yuv420p -g 60 -keyint_min 60 -sc_threshold 0 \
    -c:a aac -b:a 128k -ar 44100 \
    -shortest \
    "$STANDBY_MP4" || { echo "❌ فشل توليد فيديو الانتظار"; exit 1; }
  echo "✅ جاهز: $STANDBY_MP4"
}

# ---- إدارة العمليات ----
is_alive() {
  local pid="$1"
  [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null
}

stop_pid() {
  local pid="$1"
  [ -z "$pid" ] && return 0
  if kill -0 "$pid" 2>/dev/null; then
    kill -TERM "$pid" 2>/dev/null
    for _ in 1 2 3 4 5 6; do
      kill -0 "$pid" 2>/dev/null || break
      sleep 0.4
    done
    kill -KILL "$pid" 2>/dev/null
    wait "$pid" 2>/dev/null
  fi
}

stop_all() {
  stop_pid "$PID_YT"; PID_YT=""
  stop_pid "$PID_RS"; PID_RS=""
}

cleanup() {
  trap - EXIT INT TERM
  echo "🧹 إيقاف كل العمليات..."
  stop_all
  exit 0
}
trap cleanup EXIT INT TERM

# ---- بدء البث المباشر لوجهة ----
start_live_yt() {
  local url="$1"
  ffmpeg -nostdin -hide_banner -loglevel warning \
    -fflags +genpts+nobuffer -re -i "$url" \
    -map 0:v -map 0:a? \
    -c:v copy -c:a aac -b:a 192k -ar 44100 \
    -flvflags no_duration_filesize -f flv "$RTMP_YT" &
  PID_YT=$!
}

start_live_rs() {
  local url="$1"
  ffmpeg -nostdin -hide_banner -loglevel warning \
    -fflags +genpts+nobuffer -re -i "$url" \
    -map 0:v -map 0:a? \
    -c:v copy -c:a aac -b:a 192k -ar 44100 \
    -flvflags no_duration_filesize -f flv "$RTMP_RS" &
  PID_RS=$!
}

# ---- بدء شاشة الانتظار لوجهة ----
start_standby_yt() {
  ffmpeg -nostdin -hide_banner -loglevel warning \
    -stream_loop -1 -re -i "$STANDBY_MP4" \
    -fflags +genpts \
    -c:v libx264 -preset veryfast -tune stillimage \
    -b:v 2500k -maxrate 2500k -bufsize 5000k \
    -pix_fmt yuv420p -g 60 -keyint_min 60 -sc_threshold 0 \
    -c:a aac -b:a 128k -ar 44100 \
    -flvflags no_duration_filesize -f flv "$RTMP_YT" &
  PID_YT=$!
}

start_standby_rs() {
  ffmpeg -nostdin -hide_banner -loglevel warning \
    -stream_loop -1 -re -i "$STANDBY_MP4" \
    -fflags +genpts \
    -c:v libx264 -preset veryfast -tune stillimage \
    -b:v 2500k -maxrate 2500k -bufsize 5000k \
    -pix_fmt yuv420p -g 60 -keyint_min 60 -sc_threshold 0 \
    -c:a aac -b:a 128k -ar 44100 \
    -flvflags no_duration_filesize -f flv "$RTMP_RS" &
  PID_RS=$!
}

# ---- تهيئة ----
generate_standby_video

# ---- الحلقة الرئيسية ----
while true; do
  KICK_M3U8=$(streamlink --hls-live-edge 3 --stream-segment-threads 4 \
    "https://kick.com/${KICK_CHANNEL}" "$QUALITY" --stream-url 2>/dev/null \
    | grep -m1 "^http")

  if [ -n "$KICK_M3U8" ]; then
    WAS_LIVE=true

    if [ "$MODE" != "live" ]; then
      echo "✅ [$(date +%H:%M:%S)] الستريمر Online — بدء البث المباشر"
      stop_all
      $DO_YT && start_live_yt "$KICK_M3U8"
      $DO_RS && start_live_rs "$KICK_M3U8"
      MODE="live"
    else
      # فحص صحة كل وجهة على حدة
      if $DO_YT && ! is_alive "$PID_YT"; then
        echo "⚠️ [$(date +%H:%M:%S)] ffmpeg YouTube توقف — إعادة تشغيل"
        start_live_yt "$KICK_M3U8"
      fi
      if $DO_RS && ! is_alive "$PID_RS"; then
        echo "⚠️ [$(date +%H:%M:%S)] ffmpeg Restream توقف — إعادة تشغيل"
        start_live_rs "$KICK_M3U8"
      fi
    fi
  else
    if [ "$WAS_LIVE" = true ]; then
      if [ "$MODE" != "standby" ]; then
        echo "⚠️ [$(date +%H:%M:%S)] البث انقطع — تشغيل شاشة الانتظار"
        stop_all
        $DO_YT && start_standby_yt
        $DO_RS && start_standby_rs
        MODE="standby"
      else
        if $DO_YT && ! is_alive "$PID_YT"; then
          echo "♻️ [$(date +%H:%M:%S)] إعادة تشغيل standby على YouTube"
          start_standby_yt
        fi
        if $DO_RS && ! is_alive "$PID_RS"; then
          echo "♻️ [$(date +%H:%M:%S)] إعادة تشغيل standby على Restream"
          start_standby_rs
        fi
      fi
    else
      echo "⏳ [$(date +%H:%M:%S)] في انتظار أول Online من الستريمر..."
    fi
  fi

  sleep 30
done
