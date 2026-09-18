#!/bin/bash

# ==============================================================================
# نظام إعادة البث المباشر المباشر (Kick -> Restream / YouTube)
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

echo "========================================"
echo "🚀 نظام المراقبة المباشر للقناة: $STREAMER_NAME"
echo "🎯 وجهة البث المحددة: $DEST"
echo "========================================"

# التحقق من مفاتيح البث
if [ "$DEST" == "restream" ] && [ -z "$RESTREAM_KEY" ]; then
    echo "❌ خطأ قاتل: مفتاح Restream فارغ! يرجى إضافة RESTREAM_KEY في Secrets."
    exit 1
elif [ "$DEST" == "youtube" ] && [ -z "$YOUTUBE_KEY" ]; then
    echo "❌ خطأ قاتل: مفتاح YouTube فارغ! يرجى إضافة YOUTUBE_KEY في Secrets."
    exit 1
fi

STREAM_PID=""

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

start_live_stream() {
    local M3U8="$1"
    stop_stream
    echo "🔴 الستريمر $STREAMER_NAME أونلاين! بدء البث المباشر فوراً..."
    OUTPUTS=$(get_outputs)
    
    ffmpeg -hide_banner -loglevel info -nostdin \
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
        if [ -z "$STREAM_PID" ] || ! kill -0 "$STREAM_PID" 2>/dev/null; then
            if [ -n "$STREAM_PID" ] && ! kill -0 "$STREAM_PID" 2>/dev/null; then
                echo "⚠️ توقف البث المباشر! تفاصيل الخطأ:"
                [ -f /tmp/ffmpeg.log ] && tail -n 20 /tmp/ffmpeg.log
            fi
            start_live_stream "$KICK_M3U8"
        fi
    else
        if [ -n "$STREAM_PID" ]; then
            echo "⏹️ أوفلاين: الستريمر أوقف البث المباشر. إيقاف التوجيه والانتظار..."
            stop_stream
        fi
        echo "⏳ الستريمر $STREAMER_NAME أوفلاين حالياً.. جاري الفحص المستمر كل 10 ثوانٍ..."
    fi

    sleep 10
done
