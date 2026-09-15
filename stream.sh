#!/bin/bash

# ==============================================================================
# شرح حل مشكلة النص العربي (تجنب Double BiDi):
# 1. سبب المشكلة السابق: استخدام drawtext + arabic_reshaper/python-bidi يسبب "عكس مضاعف" (Double BiDi)،
#    لأن FFmpeg يُعيد عكس الاتجاه مع تفعيل fribidi داخلياً.
# 2. الحل المعتمد (الحل ب): الانتقال كلياً إلى مكتبة libass عبر توليد ملف (.ass).
#    تعتمد libass على محرك HarfBuzz لتشكيل الحروف وترتيب الاتجاهات (RTL/LTR) تلقائياً
#    من النص المنطقي الطبيعي بدون الحاجة لأي مكتبات تشكيل خارجية.
# 3. الخط المستخدم: يُحدد تلقائياً عبر fontconfig بترتيب الموثوقية: 'Noto Naskh Arabic' ثم 'Scheherazade New'.
# 4. كيفية التحقق قبل الاعتماد:
#    تشغيل الأمر: ffmpeg -f lavfi -i color=c=0x26001b:s=1280x720 -vf ass=/tmp/standby.ass -vframes 1 test.png
#    ومعاينة الصورة الناتجة لضمان سلامة التشكيل والاتجاه.
# ==============================================================================

KICK_CHANNEL="${KICK_CHANNEL:-W1pey}"
RESTREAM_KEY="${RESTREAM_KEY:-re_12215822_event12d2d60d5f814c68b3c0f0137cacab10}"
YOUTUBE_KEY="${YOUTUBE_KEY:-}"
QUALITY="${STREAM_QUALITY:-best}"
DEST="${STREAM_DEST:-both}"

STREAMER_NAME=$(echo "$KICK_CHANNEL" | tr '[:lower:]' '[:upper:]')

# تحديد أفضل خط عربي متوفر عبر fontconfig
FONT_NAME="Noto Naskh Arabic"
if ! fc-match "$FONT_NAME" &>/dev/null; then
    FONT_NAME="Scheherazade New"
fi

echo "========================================"
echo "🚀 نظام المراقبة الذكية للقناة: $STREAMER_NAME"
echo "🎨 الخط المستخدم للنصوص: $FONT_NAME"
echo "========================================"

PIDS=""
WAS_LIVE=false
STANDBY_RUNNING=false

# تنظيف العمليات عند إغلاق السكربت أو إلغاء الـ Workflow
cleanup() {
    echo "🧹 إيقاف جميع العمليات وتنظيف البيئة..."
    trap - EXIT INT TERM
    if [ -n "$PIDS" ]; then
        kill -TERM $PIDS 2>/dev/null
        sleep 2
        kill -KILL $PIDS 2>/dev/null
    fi
    exit 0
}
trap cleanup EXIT INT TERM

# إيقاف العمليات الحالية بأمان
stop_pids() {
    if [ -n "$PIDS" ]; then
        kill -TERM $PIDS 2>/dev/null
        sleep 1
        kill -KILL $PIDS 2>/dev/null
        PIDS=""
    fi
}

# توليد ملف الترجمة ASS بالنص العربي الطبيعي المنطقي
generate_ass_file() {
    cat <<EOF > /tmp/standby.ass
[Script Info]
ScriptType: v4.00+
PlayResX: 1280
PlayResY: 720
ScaledBorderAndShadow: yes

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: Title,$FONT_NAME,46,&H00FEB4D8,&H00000000,&H00000000,&H80000000,-1,0,0,0,100,100,0,0,1,2,1,8,10,10,280,1
Style: Subtitle,$FONT_NAME,30,&H00F755A8,&H00000000,&H00000000,&H80000000,-1,0,0,0,100,100,0,0,1,2,1,8,10,10,360,1

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
Dialogue: 0,0:00:00.00,9:59:59.99,Title,,0,0,0,,{\fad(600,600)}علق البث من قبل الستريمر ${STREAMER_NAME}
Dialogue: 0,0:00:00.00,9:59:59.99,Subtitle,,0,0,0,,{\fad(600,600)}جاري إعادة الاتصال تلقائياً...
EOF
}

# تشغيل بث شاشة الانتظار عند تعليق البث
start_standby_stream() {
    generate_ass_file
    stop_pids

    local VF_FILTER="ass=/tmp/standby.ass"
    local INPUT_FLAGS="-re -f lavfi -i color=c=0x26001b:s=1280x720:r=30 -f lavfi -i anullsrc=r=44100:cl=stereo"
    local FF_OPTS="-c:v libx264 -preset ultrafast -tune zerolatency -pix_fmt yuv420p -g 60 -keyint_min 60 -sc_threshold 0 -c:a aac -b:a 128k -ar 44100 -flvflags no_duration_filesize -f flv"

    if [ "$DEST" == "youtube" ]; then
        ffmpeg -hide_banner -loglevel error -nostdin $INPUT_FLAGS -vf "$VF_FILTER" $FF_OPTS "rtmp://a.rtmp.youtube.com/live2/$YOUTUBE_KEY" &
        PIDS=$!
    elif [ "$DEST" == "restream" ]; then
        ffmpeg -hide_banner -loglevel error -nostdin $INPUT_FLAGS -vf "$VF_FILTER" $FF_OPTS "rtmp://live.restream.io/live/$RESTREAM_KEY" &
        PIDS=$!
    else
        ffmpeg -hide_banner -loglevel error -nostdin $INPUT_FLAGS -vf "$VF_FILTER" $FF_OPTS "rtmp://live.restream.io/live/$RESTREAM_KEY" &
        local PID1=$!
        ffmpeg -hide_banner -loglevel error -nostdin $INPUT_FLAGS -vf "$VF_FILTER" $FF_OPTS "rtmp://a.rtmp.youtube.com/live2/$YOUTUBE_KEY" &
        local PID2=$!
        PIDS="$PID1 $PID2"
    fi
}

# تشغيل البث المباشر الفعلي من Kick
start_live_stream() {
    local M3U8="$1"
    stop_pids

    local FF_OPTS="-map 0:v -map 0:a -c:v copy -c:a aac -b:a 192k -ar 44100 -flvflags no_duration_filesize -f flv"

    if [ "$DEST" == "youtube" ]; then
        ffmpeg -nostdin -fflags +genpts+nobuffer -re -i "$M3U8" $FF_OPTS "rtmp://a.rtmp.youtube.com/live2/$YOUTUBE_KEY" &
        PIDS=$!
    elif [ "$DEST" == "restream" ]; then
        ffmpeg -nostdin -fflags +genpts+nobuffer -re -i "$M3U8" $FF_OPTS "rtmp://live.restream.io/live/$RESTREAM_KEY" &
        PIDS=$!
    else
        ffmpeg -nostdin -fflags +genpts+nobuffer -re -i "$M3U8" $FF_OPTS "rtmp://live.restream.io/live/$RESTREAM_KEY" &
        local PID1=$!
        ffmpeg -nostdin -fflags +genpts+nobuffer -re -i "$M3U8" $FF_OPTS "rtmp://a.rtmp.youtube.com/live2/$YOUTUBE_KEY" &
        local PID2=$!
        PIDS="$PID1 $PID2"
    fi
}

# الحلقة الرئيسية للمراقبة
while true; do
    KICK_M3U8=$(streamlink --hls-live-edge 3 --stream-segment-threads 4 "https://kick.com/$KICK_CHANNEL" "$QUALITY" --stream-url 2>/devnull | grep -m1 "^http")

    if [ -n "$KICK_M3U8" ]; then
        echo "✅ الستريمر $STREAMER_NAME متصل الآن!"
        WAS_LIVE=true

        if [ "$STANDBY_RUNNING" = true ]; then
            stop_pids
            STANDBY_RUNNING=false
        fi

        LIVE_RUNNING=false
        if [ -n "$PIDS" ]; then
            LIVE_RUNNING=true
            for pid in $PIDS; do
                if ! kill -0 $pid 2>/devnull; then
                    LIVE_RUNNING=false
                    break
                fi
            done
        fi

        if [ "$LIVE_RUNNING" = false ]; then
            echo "🚀 بدء نقل البث المباشر..."
            start_live_stream "$KICK_M3U8"
        fi

        sleep 10
    else
        if [ "$WAS_LIVE" = true ]; then
            echo "⚠️ انقطع البث من عند $STREAMER_NAME.. عرض شاشة تعليق البث بالعربية..."
            if [ "$STANDBY_RUNNING" = false ]; then
                stop_pids
                start_standby_stream
                STANDBY_RUNNING=true
            else
                for pid in $PIDS; do
                    if ! kill -0 $pid 2>/devnull; then
                        start_standby_stream
                        break
                    fi
                done
            fi
        else
            echo "⏳ الستريمر $STREAMER_NAME غير متصل بعد.. في انتظار خروج الستريمر أونلاين..."
        fi
        sleep 10
    fi
done
