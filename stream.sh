#!/bin/bash

# ==========================================
# نظام المراقبة الذكية 24/7 مع شاشة الانتظار (تحديث مهند)
# ==========================================

KICK_CHANNEL="${KICK_CHANNEL:-W1pey}"
RESTREAM_KEY="${RESTREAM_KEY:-re_12215822_event12d2d60d5f814c68b3c0f0137cacab10}"
YOUTUBE_KEY="${YOUTUBE_KEY:-}"
# إجبار النظام على جودة 1080p كأولوية قصوى
QUALITY="${STREAM_QUALITY:-1080p60,1080p,best}"
DEST="${STREAM_DEST:-both}"

OUT_YOUTUBE="rtmp://a.rtmp.youtube.com/live2/$YOUTUBE_KEY"
OUT_RESTREAM="rtmp://live.restream.io/live/$RESTREAM_KEY"

echo "========================================"
echo "🚀 نظام المراقبة المستمرة 24/7 لقناة: $KICK_CHANNEL"
echo "========================================"

# تحميل خط عربي عريض وجميل لشاشة الانتظار
if [ ! -f "cairo.ttf" ]; then
    wget -q -O cairo.ttf "https://github.com/googlefonts/cairo/raw/master/fonts/ttf/Cairo-Black.ttf"
fi

OFFLINE_PID=""

# دالة لإيقاف شاشة الانتظار فور بدء البث الحقيقي
stop_offline_screen() {
    if [ -n "$OFFLINE_PID" ]; then
        kill -9 "$OFFLINE_PID" 2>/dev/null
        wait "$OFFLINE_PID" 2>/dev/null
        OFFLINE_PID=""
    fi
}

# دالة لتشغيل شاشة الانتظار بمؤثرات بصرية
start_offline_screen() {
    if [ -z "$OFFLINE_PID" ]; then
        echo "⏳ الستريمر غير متصل. يتم الآن عرض شاشة (بانتظار البث)..."
        
        # كود FFmpeg لإنشاء خلفية زرقاء داكنة مع نص عربي متحرك وينبض
        FFMPEG_OFFLINE="ffmpeg -hide_banner -loglevel error -nostdin -re -f lavfi -i color=c=#0f172a:s=1920x1080:r=30 -f lavfi -i anullsrc=r=44100:cl=stereo -vf drawtext=fontfile=cairo.ttf:text='بانتظار البث المباشر...':fontcolor=white:fontsize=110:x=(w-text_w)/2:y=(h-text_h)/2+30*sin(t*2):alpha=0.6+0.4*sin(t*3):text_shaping=1,drawtext=fontfile=cairo.ttf:text='Waiting for Stream':fontcolor=gray:fontsize=50:x=(w-text_w)/2:y=(h-text_h)/2+150 -c:v libx264 -preset ultrafast -b:v 2000k -pix_fmt yuv420p -g 60 -c:a aac -b:a 128k"

        if [ "$DEST" == "youtube" ]; then
            $FFMPEG_OFFLINE -f flv "$OUT_YOUTUBE" &
        elif [ "$DEST" == "restream" ]; then
            $FFMPEG_OFFLINE -f flv "$OUT_RESTREAM" &
        else
            # تقنية tee للبث للمنصتين معاً بدون مضاعفة استهلاك المعالج
            $FFMPEG_OFFLINE -f tee "[f=flv]$OUT_RESTREAM|[f=flv]$OUT_YOUTUBE" &
        fi
        OFFLINE_PID=$!
    fi
}

while true; do
    # فحص رابط البث
    KICK_M3U8=$(streamlink --hls-live-edge 3 --stream-segment-threads 4 "https://kick.com/$KICK_CHANNEL" "$QUALITY" --stream-url 2>/dev/null | grep "^http")

    if [ -n "$KICK_M3U8" ]; then
        echo "✅ تم رصد بث مباشر يعمل الآن! جاري إيقاف شاشة الانتظار والتبديل للبث الحي..."
        
        stop_offline_screen
        
        if [ "$DEST" == "youtube" ]; then
            ffmpeg -hide_banner -loglevel warning -nostdin -fflags +genpts+nobuffer -re -i "$KICK_M3U8" \
              -c:v copy -c:a aac -b:a 192k -ar 44100 \
              -flvflags no_duration_filesize -f flv "$OUT_YOUTUBE"
        elif [ "$DEST" == "restream" ]; then
            ffmpeg -hide_banner -loglevel warning -nostdin -fflags +genpts+nobuffer -re -i "$KICK_M3U8" \
              -c:v copy -c:a aac -b:a 192k -ar 44100 \
              -flvflags no_duration_filesize -f flv "$OUT_RESTREAM"
        else
            # تقنية tee للبث الحقيقي للمنصتين باستهلاك منخفض للمعالج
            ffmpeg -hide_banner -loglevel warning -nostdin -fflags +genpts+nobuffer -re -i "$KICK_M3U8" \
              -c:v copy -c:a aac -b:a 192k -ar 44100 \
              -flvflags no_duration_filesize -f tee "[f=flv]$OUT_RESTREAM|[f=flv]$OUT_YOUTUBE"
        fi
        
        echo "⚠️ انتهى أو توقف البث الأصلي. العودة لوضع شاشة الانتظار..."
    else
        start_offline_screen
    fi

    # الانتظار 15 ثانية فقط لسرعة الاستجابة وتغيير الشاشات
    sleep 15
done
