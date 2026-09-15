#!/bin/bash

# ==========================================
# نظام المراقبة الذكية وشاشات الانتظار بالعربية المستمرة
# ==========================================
KICK_CHANNEL="${KICK_CHANNEL:-W1pey}"
RESTREAM_KEY="${RESTREAM_KEY:-re_12215822_event12d2d60d5f814c68b3c0f0137cacab10}"
YOUTUBE_KEY="${YOUTUBE_KEY:-}"
QUALITY="${STREAM_QUALITY:-best}"
DEST="${STREAM_DEST:-both}"

STREAMER_NAME=$(echo "$KICK_CHANNEL" | tr '[:lower:]' '[:upper:]')
FONT_PATH="/usr/share/fonts/truetype/sil/Scheherazade-Bold.ttf"

if [ ! -f "$FONT_PATH" ]; then
    FONT_PATH="/usr/share/fonts/truetype/sil/ScheherazadeRegOT.ttf"
fi

echo "========================================"
echo "🚀 نظام المراقبة الذكية للقناة: $STREAMER_NAME"
echo "========================================"

push_to_destinations() {
    local INPUT_ARGS="$1"
    local VF_FILTER="$2"
    local FF_PID=""

    local FF_OPTS="-c:v libx264 -preset ultrafast -tune zerolatency -pix_fmt yuv420p -g 60 -keyint_min 60 -sc_threshold 0 -c:a aac -b:a 128k -ar 44100 -flvflags no_duration_filesize -f flv"

    if [ "$DEST" == "youtube" ]; then
        ffmpeg -hide_banner -loglevel error -nostdin $INPUT_ARGS -vf "$VF_FILTER" $FF_OPTS "rtmp://a.rtmp.youtube.com/live2/$YOUTUBE_KEY" &
        FF_PID=$!

    elif [ "$DEST" == "restream" ]; then
        ffmpeg -hide_banner -loglevel error -nostdin $INPUT_ARGS -vf "$VF_FILTER" $FF_OPTS "rtmp://live.restream.io/live/$RESTREAM_KEY" &
        FF_PID=$!

    else
        ffmpeg -hide_banner -loglevel error -nostdin $INPUT_ARGS -vf "$VF_FILTER" $FF_OPTS "rtmp://live.restream.io/live/$RESTREAM_KEY" &
        local PID1=$!
        ffmpeg -hide_banner -loglevel error -nostdin $INPUT_ARGS -vf "$VF_FILTER" $FF_OPTS "rtmp://a.rtmp.youtube.com/live2/$YOUTUBE_KEY" &
        local PID2=$!
        FF_PID="$PID1 $PID2"
    fi

    for i in {1..3}; do
        sleep 10
        CHECK_STREAM=$(streamlink --hls-live-edge 3 --stream-segment-threads 4 "https://kick.com/$KICK_CHANNEL" "$QUALITY" --stream-url 2>/dev/null | grep "^http")
        if [ -n "$CHECK_STREAM" ]; then
            echo "⚡ تم رصد دخول الستريمر أونلاين! قطع شاشة الانتظار والانتقال للبث المباشر..."
            kill -9 $FF_PID 2>/dev/null
            wait $FF_PID 2>/dev/null
            return 0
        fi
    done

    kill -9 $FF_PID 2>/dev/null
    wait $FF_PID 2>/dev/null
}

send_initial_waiting_screen() {
    echo "⏳ الستريمر $STREAMER_NAME غير متصل.. إرسال شاشة الانتظار الأولى بالعربية..."

    # معالجة النص العربي (تشكيل + اتجاه) عبر Python
    local TEXT_TOP=$(python3 -c "import arabic_reshaper, bidi.algorithm; print(bidi.algorithm.get_display(arabic_reshaper.reshape('جاري انتظار بث الستريمر $STREAMER_NAME')))")
    local TEXT_BOTTOM=$(python3 -c "import arabic_reshaper, bidi.algorithm; print(bidi.algorithm.get_display(arabic_reshaper.reshape('لم يبدأ البث المباشر بعد...')))")

    local VF_FILTER="drawtext=fontfile=${FONT_PATH}:text='${TEXT_TOP}':fontcolor=0xD8B4FE:fontsize=48:x=(w-text_w)/2:y=(h-text_h)/2-50:alpha='0.6+0.4*sin(t*3)',drawtext=fontfile=${FONT_PATH}:text='${TEXT_BOTTOM}':fontcolor=0xA855F7:fontsize=36:x=(w-text_w)/2:y=(h-text_h)/2+40:alpha='0.4+0.6*cos(t*2)'"
    local INPUT_FLAGS="-re -f lavfi -i color=c=0x140024:s=1280x720:r=30 -f lavfi -i anullsrc=r=44100:cl=stereo"
    
    push_to_destinations "$INPUT_FLAGS" "$VF_FILTER"
}

send_stream_crash_screen() {
    echo "⚠️ انقطع البث من عند $STREAMER_NAME.. إرسال شاشة تعليق البث بالعربية..."

    local TEXT_TOP=$(python3 -c "import arabic_reshaper, bidi.algorithm; print(bidi.algorithm.get_display(arabic_reshaper.reshape('علق البث من قبل الستريمر $STREAMER_NAME')))")
    local TEXT_BOTTOM=$(python3 -c "import arabic_reshaper, bidi.algorithm; print(bidi.algorithm.get_display(arabic_reshaper.reshape('جاري إعادة الاتصال تلقائياً...')))")

    local VF_FILTER="drawtext=fontfile=${FONT_PATH}:text='${TEXT_TOP}':fontcolor=0xF472B6:fontsize=48:x=(w-text_w)/2:y=(h-text_h)/2-50+10*sin(t*4):alpha='0.6+0.4*sin(t*3)',drawtext=fontfile=${FONT_PATH}:text='${TEXT_BOTTOM}':fontcolor=0xE879F9:fontsize=36:x=(w-text_w)/2:y=(h-text_h)/2+40:alpha='0.3+0.7*abs(cos(t*2))'"
    local INPUT_FLAGS="-re -f lavfi -i color=c=0x26001b:s=1280x720:r=30 -f lavfi -i anullsrc=r=44100:cl=stereo"

    push_to_destinations "$INPUT_FLAGS" "$VF_FILTER"
}

WAS_LIVE=false

while true; do
    KICK_M3U8=$(streamlink --hls-live-edge 3 --stream-segment-threads 4 "https://kick.com/$KICK_CHANNEL" "$QUALITY" --stream-url 2>/devnull | grep "^http")

    if [ -n "$KICK_M3U8" ]; then
        echo "✅ الستريمر $STREAMER_NAME متصل الآن! جاري نقل البث المباشر..."
        WAS_LIVE=true

        if [ "$DEST" == "youtube" ]; then
            ffmpeg -nostdin -fflags +genpts+nobuffer -re -i "$KICK_M3U8" \
              -map 0:v -map 0:a -c:v copy -c:a aac -b:a 192k -ar 44100 \
              -flvflags no_duration_filesize -f flv "rtmp://a.rtmp.youtube.com/live2/$YOUTUBE_KEY"

        elif [ "$DEST" == "restream" ]; then
            ffmpeg -nostdin -fflags +genpts+nobuffer -re -i "$KICK_M3U8" \
              -map 0:v -map 0:a -c:v copy -c:a aac -b:a 192k -ar 44100 \
              -flvflags no_duration_filesize -f flv "rtmp://live.restream.io/live/$RESTREAM_KEY"

        else
            ffmpeg -nostdin -fflags +genpts+nobuffer -re -i "$KICK_M3U8" \
              -map 0:v -map 0:a -c:v copy -c:a aac -b:a 192k -ar 44100 \
              -flvflags no_duration_filesize -f flv "rtmp://live.restream.io/live/$RESTREAM_KEY" &

            ffmpeg -nostdin -fflags +genpts+nobuffer -re -i "$KICK_M3U8" \
              -map 0:v -map 0:a -c:v copy -c:a aac -b:a 192k -ar 44100 \
              -flvflags no_duration_filesize -f flv "rtmp://a.rtmp.youtube.com/live2/$YOUTUBE_KEY"
            wait
        fi

        echo "⚠️ انقطع البث المباشر!"
    else
        if [ "$WAS_LIVE" = true ]; then
            send_stream_crash_screen
        else
            send_initial_waiting_screen
        fi
    fi
done
