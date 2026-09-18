#!/bin/bash

# ==============================================================================
# نظام البث المستمر 24/7 - البث المباشر بأعلى جودة (مصلح ضد Segmentation fault)
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

# جلب مسار ملف الخط بشكل مباشر ومستقر
FONT_PATH=$(fc-match --format="%{file}" "Noto Naskh Arabic" 2>/dev/null)
if [ -z "$FONT_PATH" ] || [ ! -f "$FONT_PATH" ]; then
    FONT_PATH="/usr/share/fonts/truetype/noto/NotoNaskhArabic-Regular.ttf"
fi

echo "========================================"
echo "🚀 نظام المراقبة الذكية للقناة: $STREAMER_NAME"
echo "🎯 وجهة البث المحددة: $DEST"
echo "🎨 مسار الخط المستخدم: $FONT_PATH"
echo "========================================"

STREAM_PID=""
CURRENT_MODE="NONE"

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

    echo "⏳ بدء بث شاشة الانتظار إلى الوجهة المحددة (1080p60)..."
    OUTPUTS=$(get_outputs)

    # استخدام drawtext المدمج المستقر بدلاً من ass لمنع خطأ Segmentation fault
    VF_TEXT="drawtext=fontfile='$FONT_PATH':text='لم يبدأ البث المباشر بعد...':fontcolor=0xFFFEB4D8:fontsize=55:x=(w-text_w)/2:y=(h-text_h)/2-50,drawtext=fontfile='$FONT_PATH':text='جاري انتظار الستريمر ${STREAMER_NAME}':fontcolor=0xFFF755A8:fontsize=38:x=(w-text_w)/2:y=(h-text_h)/2+40"

    ffmpeg -hide_banner -loglevel error -nostdin \
      -re -f lavfi -i color=c=0x140024:s=1920x1080:r=60 \
      -f lavfi -i anullsrc=r=44100:cl=stereo \
      -map 0:v:0 -map 1:a:0 \
      -vf "$VF_TEXT" \
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
