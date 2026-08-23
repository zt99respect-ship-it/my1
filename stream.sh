#!/bin/bash

# ==========================================
# الإعدادات المحدثة (قناة W1pey)
# ==========================================
KICK_CHANNEL="${KICK_CHANNEL:-W1pey}"
YOUTUBE_KEY="${YOUTUBE_KEY:-}"
RESTREAM_KEY="${RESTREAM_KEY:-re_12215822_event12d2d60d5f814c68b3c0f0137cacab10}"
QUALITY="${STREAM_QUALITY:-best}"
DEST="${STREAM_DEST:-both}"

echo "========================================"
echo "جاري فحص وجلب أعلى جودة لقناة: $KICK_CHANNEL"
echo "========================================"

# استخدام خيارات إضافية لتجاوز القيود وجلب الدقة الحقيقية
KICK_M3U8=$(streamlink --hls-live-edge 3 --stream-segment-threads 4 "https://kick.com/$KICK_CHANNEL" "$QUALITY" --stream-url)

if [ -z "$KICK_M3U8" ]; then
  echo "لا يوجد بث مباشر حالياً أو أن الرابط محظور مؤقتاً. إعادة المحاولة بعد 3 دقائق..."
  sleep 180
  gh workflow run main.yml -f kick_channel="$KICK_CHANNEL" -f youtube_key="$YOUTUBE_KEY" -f restream_key="$RESTREAM_KEY" -f destination="$DEST" -f quality="$QUALITY"
  exit 0
fi

echo "تم الحصول على رابط البث بنجاح، جاري بدء الإرسال..."

# تشغيل البث بناءً على المنصة المستهدفة
if [ "$DEST" == "youtube" ]; then
    ffmpeg -fflags +genpts+nobuffer -re -i "$KICK_M3U8" \
      -map 0:v -map 0:a \
      -c:v copy -c:a copy \
      -b:a 192k \
      -flvflags no_duration_filesize \
      -f flv "rtmp://a.rtmp.youtube.com/live2/$YOUTUBE_KEY" &

elif [ "$DEST" == "restream" ]; then
    ffmpeg -fflags +genpts+nobuffer -re -i "$KICK_M3U8" \
      -map 0:v -map 0:a \
      -c:v copy -c:a copy \
      -b:a 192k \
      -flvflags no_duration_filesize \
      -f flv "rtmp://live.restream.io/live/$RESTREAM_KEY" &

else
    ffmpeg -fflags +genpts+nobuffer -re -i "$KICK_M3U8" \
      -map 0:v -map 0:a \
      -c:v copy -c:a copy \
      -b:a 192k \
      -flvflags no_duration_filesize \
      -f flv "rtmp://a.rtmp.youtube.com/live2/$YOUTUBE_KEY" &
      
    ffmpeg -fflags +genpts+nobuffer -re -i "$KICK_M3U8" \
      -map 0:v -map 0:a \
      -c:v copy -c:a copy \
      -b:a 192k \
      -flvflags no_duration_filesize \
      -f flv "rtmp://live.restream.io/live/$RESTREAM_KEY" &
fi

# مؤقت لمدة 5 ساعات و 45 دقيقة لتفادي إغلاق السيرفر من GitHub
sleep 20700

echo "إعادة تشغيل الدورة للحفاظ على استقرار السيرفر..."
killall ffmpeg

gh workflow run main.yml -f kick_channel="$KICK_CHANNEL" -f youtube_key="$YOUTUBE_KEY" -f restream_key="$RESTREAM_KEY" -f destination="$DEST" -f quality="$QUALITY"
