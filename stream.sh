#!/bin/bash

# ==========================================
# نظام المراقبة الذكية وشاشات الانتظار البنفسجية
# ==========================================
KICK_CHANNEL="${KICK_CHANNEL:-W1pey}"
RESTREAM_KEY="${RESTREAM_KEY:-re_12215822_event12d2d60d5f814c68b3c0f0137cacab10}"
YOUTUBE_KEY="${YOUTUBE_KEY:-}"
QUALITY="${STREAM_QUALITY:-best}"
DEST="${STREAM_DEST:-both}"

# تحويل اسم القناة للحروف الكبيرة للعرض بشكل ممتاز
STREAMER_NAME=$(echo "$KICK_CHANNEL" | tr '[:lower:]' '[:upper:]')

FONT_PATH="/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"

echo "========================================"
echo "🚀 نظام المراقبة الذكية للقناة: $STREAMER_NAME"
echo "========================================"

# دالة إرسال البث إلى المنصات المحددة
push_to_destinations() {
    local INPUT_ARGS="$1"
    local VF_FILTER="$2"
    local DURATION="$3"

    local TIME_LIMIT=""
    if [ -n "$DURATION" ]; then
        TIME_LIMIT="-t $DURATION"
    fi

    if [ "$DEST" == "youtube" ]; then
        ffmpeg -hide_banner -loglevel error -nostdin $TIME_LIMIT $INPUT_ARGS \
          -vf "$VF_FILTER" \
          -c:v libx264 -preset ultrafast -pix_fmt yuv420p -g 60 \
          -c:a aac -b:a 128k -ar 44100 \
          -f flv "rtmp://a.rtmp.youtube.com/live2/$YOUTUBE_KEY"

    elif [ "$DEST" == "restream" ]; then
        ffmpeg -hide_banner -loglevel error -nostdin $TIME_LIMIT $INPUT_ARGS \
          -vf "$VF_FILTER" \
          -c:v libx264 -preset ultrafast -pix_fmt yuv420p -g 60 \
          -c:a aac -b:a 128k -ar 44100 \
          -f flv "rtmp://live.restream.io/live/$RESTREAM_KEY"

    else
        ffmpeg -hide_banner -loglevel error -nostdin $TIME_LIMIT $INPUT_ARGS \
          -vf "$VF_FILTER" \
          -c:v libx264 -preset ultrafast -pix_fmt yuv420p -g 60 \
          -c:a aac -b:a 128k -ar 44100 \
          -f flv "rtmp://live.restream.io/live/$RESTREAM_KEY" &

        ffmpeg -hide_banner -loglevel error -nostdin $TIME_LIMIT $INPUT_ARGS \
          -vf "$VF_FILTER" \
          -c:v libx264 -preset ultrafast -pix_fmt yuv420p -g 60 \
          -c:a aac -b:a 128k -ar 44100 \
          -f flv "rtmp://a.rtmp.youtube.com/live2/$YOUTUBE_KEY"
        wait
    fi
}

# 1. الشاشة الأولى: قبل بداية البث (الستريمر غير متصل بعد) - باللون البنفسجي الفاتح/المشع
send_initial_waiting_screen() {
    local DURATION=15
    echo "⏳ الستريمر $STREAMER_NAME غير متصل.. إرسال شاشة الانتظار الأولى (بنفسجي)..."

    # خلفية بنفسجية داكنة (0x1e0036) مع نصوص بنفسجية مضيئة وأنيميشن Pulsing
    local VF_FILTER="drawtext=fontfile=${FONT_PATH}:text='Waiting for streamer\: ${STREAMER_NAME}':fontcolor=0xD8B4FE:fontsize=34:x=(w-text_w)/2:y=(h-text_h)/2-40:alpha='0.5+0.5*sin(t*3)',drawtext=fontfile=${FONT_PATH}:text='Stream has not started yet...':fontcolor=0xA855F7:fontsize=24:x=(w-text_w)/2:y=(h-text_h)/2+30:alpha='0.4+0.6*cos(t*2)'"

    local INPUT_FLAGS="-f lavfi -i color=c=0x140024:s=1280x720:r=30 -f lavfi -i anullsrc=r=44100:cl=stereo"
    
    push_to_destinations "$INPUT_FLAGS" "$VF_FILTER" "$DURATION"
}

# 2. الشاشة الثانية: انقطاع/تعليق البث أثناء التشغيل - باللون البنفسجي الوردي/التحذيري
send_stream_crash_screen() {
    local DURATION=15
    echo "⚠️ انقطع البث من عند $STREAMER_NAME.. إرسال شاشة التعليق..."

    # خلفية بنفسجية مائلة للأحمر/الأرجواني مع أنيميشن الحركة العمودية
    local VF_FILTER="drawtext=fontfile=${FONT_PATH}:text='Stream paused by\: ${STREAMER_NAME}':fontcolor=0xF472B6:fontsize=34:x=(w-text_w)/2:y=(h-text_h)/2-40+10*sin(t*4):alpha='0.6+0.4*sin(t*3)',drawtext=fontfile=${FONT_PATH}:text='Reconnecting... Please wait':fontcolor=0xE879F9:fontsize=24:x=(w-text_w)/2:y=(h-text_h)/2+30:alpha='0.3+0.7*abs(cos(t*2))'"

    local INPUT_FLAGS="-f lavfi -i color=c=0x26001b:s=1280x720:r=30 -f lavfi -i anullsrc=r=44100:cl=stereo"

    push_to_destinations "$INPUT_FLAGS" "$VF_FILTER" "$DURATION"
}

WAS_LIVE=false

# الحلقة الرئيسية للمراقبة
while true; do
    KICK_M3U8=$(streamlink --hls-live-edge 3 --stream-segment-threads 4 "https://kick.com/$KICK_CHANNEL" "$QUALITY" --stream-url 2>/dev/null | grep "^http")

    if [ -n "$KICK_M3U8" ]; then
        echo "✅ الستريمر $STREAMER_NAME متصل الآن! جاري نقل البث المباشر..."
        WAS_LIVE=true

        if [ "$DEST" == "youtube" ]; then
            ffmpeg -nostdin -fflags +genpts+nobuffer -re -i "$KICK_M3U8" \
              -map 0:v -map 0:a \
              -c:v copy \
              -c:a aac -b:a 192k -ar 44100 \
              -flvflags no_duration_filesize -f flv "rtmp://a.rtmp.youtube.com/live2/$YOUTUBE_KEY"

        elif [ "$DEST" == "restream" ]; then
            ffmpeg -nostdin -fflags +genpts+nobuffer -re -i "$KICK_M3U8" \
              -map 0:v -map 0:a \
              -c:v copy \
              -c:a aac -b:a 192k -ar 44100 \
              -flvflags no_duration_filesize -f flv "rtmp://live.restream.io/live/$RESTREAM_KEY"

        else
            ffmpeg -nostdin -fflags +genpts+nobuffer -re -i "$KICK_M3U8" \
              -map 0:v -map 0:a \
              -c:v copy \
              -c:a aac -b:a 192k -ar 44100 \
              -flvflags no_duration_filesize -f flv "rtmp://live.restream.io/live/$RESTREAM_KEY" &

            ffmpeg -nostdin -fflags +genpts+nobuffer -re -i "$KICK_M3U8" \
              -map 0:v -map 0:a \
              -c:v copy \
              -c:a aac -b:a 192k -ar 44100 \
              -flvflags no_duration_filesize -f flv "rtmp://a.rtmp.youtube.com/live2/$YOUTUBE_KEY"
            wait
        fi

        echo "⚠️ انقطع البث المباشر!"
    else
        if [ "$WAS_LIVE" = true ]; then
            # إذا كان البث يعمل وانقطع -> تشغيل الشاشة الثانية (شاشة تعليق البث)
            send_stream_crash_screen
        else
            # إذا لم يبدأ البث بعد منذ بدء التشغيل -> تشغيل الشاشة الأولى (شاشة انتظار بدء البث)
            send_initial_waiting_screen
        fi
    fi
done
