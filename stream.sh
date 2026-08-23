#!/bin/bash

# ==========================================
# نظام المراقبة الذكية المحدث (بدون أخطاء وهمية)
# ==========================================
KICK_CHANNEL="${KICK_CHANNEL:-W1pey}"
RESTREAM_KEY="${RESTREAM_KEY:-re_12215822_event12d2d60d5f814c68b3c0f0137cacab10}"
YOUTUBE_KEY="${YOUTUBE_KEY:-}"
QUALITY="${STREAM_QUALITY:-best}"
DEST="${STREAM_DEST:-restream}"

echo "========================================"
echo "🚀 تم تفعيل نظام المراقبة الذكية لقناة: $KICK_CHANNEL"
echo "⏱️ يتم فحص حالة البث كل 30 ثانية تلقائياً..."
echo "========================================"

while true; do
    # جلب الرابط والتحقق من أنه رابط حقيقي يبدأ بـ http فقط لتجنب الأخطاء الوهمية
    KICK_M3U8=$(streamlink --hls-live-edge 3 --stream-segment-threads 4 "https://kick.com/$KICK_CHANNEL" "$QUALITY" --stream-url 2>/dev/null | grep "^http")

    if [ -n "$KICK_M3U8" ]; then
        echo "✅ تم رصد بث مباشر يعمل الآن! جاري بدء النقل فوراً..."
        
        # تشغيل البث حسب الوجهة المختارة
        if [ "$DEST" == "youtube" ]; then
            ffmpeg -nostdin -fflags +genpts+nobuffer -re -i "$KICK_M3U8" \
              -map 0:v -map 0:a -c:v copy -c:a copy -b:a 192k \
              -flvflags no_duration_filesize -f flv "rtmp://a.rtmp.youtube.com/live2/$YOUTUBE_KEY"
              
        elif [ "$DEST" == "restream" ]; then
            ffmpeg -nostdin -fflags +genpts+nobuffer -re -i "$KICK_M3U8" \
              -map 0:v -map 0:a -c:v copy -c:a copy -b:a 192k \
              -flvflags no_duration_filesize -f flv "rtmp://live.restream.io/live/$RESTREAM_KEY"
              
        else
            ffmpeg -nostdin -fflags +genpts+nobuffer -re -i "$KICK_M3U8" \
              -map 0:v -map 0:a -c:v copy -c:a copy -b:a 192k \
              -flvflags no_duration_filesize -f flv "rtmp://live.restream.io/live/$RESTREAM_KEY" &
              
            ffmpeg -nostdin -fflags +genpts+nobuffer -re -i "$KICK_M3U8" \
              -map 0:v -map 0:a -c:v copy -c:a copy -b:a 192k \
              -flvflags no_duration_filesize -f flv "rtmp://a.rtmp.youtube.com/live2/$YOUTUBE_KEY"
            wait
        fi
        
        echo "⚠️ انتهى البث الأصلي أو توقف. العودة لوضع المراقبة..."
    else
        echo "⏳ الشخص غير متصل حالياً (Offline). جارٍ إعادة الفحص خلال 30 ثانية..."
    fi

    # الانتظار 30 ثانية بهدوء قبل الفحص التالي
    sleep 30
done
