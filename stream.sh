#!/bin/bash

# ==========================================
# نظام المراقبة الذكية 24/7 مع شاشة الانتظار (النسخة الأكثر استقراراً)
# ==========================================

KICK_CHANNEL="${KICK_CHANNEL:-W1pey}"
RESTREAM_KEY="${RESTREAM_KEY:-re_12215822_event12d2d60d5f814c68b3c0f0137cacab10}"
YOUTUBE_KEY="${YOUTUBE_KEY:-}"
QUALITY="${STREAM_QUALITY:-1080p60,1080p,best}"
DEST="${STREAM_DEST:-both}"

OUT_YOUTUBE="rtmp://a.rtmp.youtube.com/live2/$YOUTUBE_KEY"
OUT_RESTREAM="rtmp://live.restream.io/live/$RESTREAM_KEY"

echo "========================================"
echo "🚀 نظام المراقبة المستمرة 24/7 لقناة: $KICK_CHANNEL"
echo "========================================"

if [ ! -f "cairo.ttf" ]; then
    wget -q -O cairo.ttf "https://github.com/googlefonts/cairo/raw/master/fonts/ttf/Cairo-Black.ttf"
fi

OFFLINE_PID=""

stop_offline_screen() {
    if [ -n "$OFFLINE_PID" ]; then
        kill -9 "$OFFLINE_PID" 2>/dev/null
        wait "$OFFLINE_PID" 2>/dev/null
        OFFLINE_PID=""
    fi
}

start_offline_screen() {
    if [ -z "$OFFLINE_PID" ]; then
        echo "⏳ الستريمر غير متصل. يتم الآن عرض شاشة (بانتظار البث)..."
        
        VF_FILTER="drawtext=fontfile=cairo.ttf:text='بانتظار البث المباشر...':fontcolor=white:fontsize=110:x=(w-text_w)/2:y=(h-text_h)/2+30*sin(t*2):alpha=0.6+0.4*sin(t*3),drawtext=fontfile=cairo.ttf:text='Waiting for Stream':fontcolor=gray:fontsize=50:x=(w-text_w)/2:y=(h-text_h)/2+150"

        if [ "$DEST" == "youtube" ]; then
            ffmpeg -hide_banner -loglevel error -nostdin -re -f lavfi -i color=c=#0f172a:s=1920x1080:r=30 -f lavfi -i anullsrc=r=44100:cl=stereo -vf "$VF_FILTER" -map 0:v -map 1:a -c:v libx264 -preset ultrafast -b:v 2000k -pix_fmt yuv420p -g 60 -c:a aac -b:a 128k -f flv "$OUT_YOUTUBE" &
        elif [ "$DEST" == "restream" ]; then
            ffmpeg -hide_banner -loglevel error -nostdin -re -f lavfi -i color=c=#0f172a:s=1920x1080:r=30 -f lavfi -i anullsrc=r=44100:cl=stereo -vf "$VF_FILTER" -map 0:v -map 1:a -c:v libx264 -preset ultrafast -b:v 2000k -pix_fmt yuv420p -g 60 -c:a aac -b:a 128k -f flv "$OUT_RESTREAM" &
        else
            # إلغاء tee واستخدام التوجيه المزدوج لمنع الكراش
            ffmpeg -hide_banner -loglevel error -nostdin -re -f lavfi -i color=c=#0f172a:s=1920x1080:r=30 -f lavfi -i anullsrc=r=44100:cl=stereo -vf "$VF_FILTER" \
              -map 0:v -map 1:a -c:v libx264 -preset ultrafast -b:v 2000k -pix_fmt yuv420p -g 60 -c:a aac -b:a 128k -f flv "$OUT_RESTREAM" \
              -map 0:v -map 1:a -c:v libx264 -preset ultrafast -b:v 2000k -pix_fmt yuv420p -g 60 -c:a aac -b:a 128k -f flv "$OUT_YOUTUBE" &
        fi
        OFFLINE_PID=$!
    fi
}

while true; do
    KICK_M3U8=$(streamlink --hls-live-edge 3 --stream-segment-threads 4 "https://kick.com/$KICK_CHANNEL" "$QUALITY" --stream-url 2>/dev/null | grep "^http")

    if [ -n "$KICK_M3U8" ]; then
        echo "✅ تم رصد بث مباشر يعمل الآن! جاري إيقاف شاشة الانتظار والتبديل للبث الحي..."
        
        stop_offline_screen
        
        # إزالة -re لمنع تلف البيانات، واستخدام :0 لضمان سحب المسار الصحيح فقط
        if [ "$DEST" == "youtube" ]; then
            ffmpeg -hide_banner -loglevel warning -nostdin -fflags +genpts+nobuffer -i "$KICK_M3U8" \
              -map 0:v:0 -map 0:a:0 -c:v copy -c:a aac -b:a 192k -ar 44100 \
              -flvflags no_duration_filesize -f flv "$OUT_YOUTUBE"
        elif [ "$DEST" == "restream" ]; then
            ffmpeg -hide_banner -loglevel warning -nostdin -fflags +genpts+nobuffer -i "$KICK_M3U8" \
              -map 0:v:0 -map 0:a:0 -c:v copy -c:a aac -b:a 192k -ar 44100 \
              -flvflags no_duration_filesize -f flv "$OUT_RESTREAM"
        else
            # توجيه مباشر للمنصتين بدون tee لضمان الاستقرار التام
            ffmpeg -hide_banner -loglevel warning -nostdin -fflags +genpts+nobuffer -i "$KICK_M3U8" \
              -map 0:v:0 -map 0:a:0 -c:v copy -c:a aac -b:a 192k -ar 44100 -flvflags no_duration_filesize -f flv "$OUT_RESTREAM" \
              -map 0:v:0 -map 0:a:0 -c:v copy -c:a aac -b:a 192k -ar 44100 -flvflags no_duration_filesize -f flv "$OUT_YOUTUBE"
        fi
        
        echo "⚠️ انتهى أو توقف البث الأصلي. العودة لوضع شاشة الانتظار..."
    else
        start_offline_screen
    fi

    sleep 15
done
