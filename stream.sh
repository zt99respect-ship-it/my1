#!/bin/bash

# ==========================================
# نظام المراقبة الذكية مع إصلاح وترميز الصوت
# ==========================================
KICK_CHANNEL="${KICK_CHANNEL:-W1pey}"
RESTREAM_KEY="${RESTREAM_KEY:-re_12215822_event12d2d60d5f814c68b3c0f0137cacab10}"
YOUTUBE_KEY="${YOUTUBE_KEY:-}"
QUALITY="${STREAM_QUALITY:-best}"
DEST="${STREAM_DEST:-restream}"

echo "========================================"
echo "🚀 نظام المراقبة الذكية لقناة: $KICK_CHANNEL"
echo "⏱️ يتم فحص حالة البث كل 30 ثانية تلقائياً..."
echo "========================================"

while true; do
    # فحص رابط البث والتأكد أنه يبدأ بـ http لتجنب الأخطاء
    KICK_M3U8=$(streamlink --hls-live-edge 3 --stream-segment-threads 4 "https://kick.com/$KICK_CHANNEL" "$QUALITY" --stream-url 2>/dev/null | grep "^http")

    if [ -n "$KICK_M3U8" ]; then
        echo "✅ تم رصد بث مباشر يعمل الآن! جاري بدء النقل مع تنقية الصوت..."
        
        # تشغيل البث مع إعادة ترميز الصوت (-c:a aac) لمنع التشويش والكهرباء
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
        
        echo "⚠️ انتهى البث الأصلي أو توقف. العودة لوضع المراقبة..."
    else
        echo "⏳ الشخص غير متصل حالياً (Offline). جارٍ إعادة الفحص خلال 30 ثانية..."
    fi

    # الانتظار 30 ثانية قبل الفحص التالي
    sleep 30
done




وملف .github/workflows/main.yml

name: 24/7 Master Broadcast

on:
  workflow_dispatch:
    inputs:
      kick_channel:
        description: 'Kick Channel Name'
        required: true
        default: 'W1pey'
      youtube_key:
        description: 'YouTube Stream Key'
        required: true
        default: ''
      restream_key:
        description: 'Restream Key'
        required: false
        default: 're_12215822_event12d2d60d5f814c68b3c0f0137cacab10'
      destination:
        description: 'Stream Destination (youtube, restream, both)'
        required: true
        default: 'both'
      quality:
        description: 'Stream Quality'
        required: true
        default: 'best'

jobs:
  broadcaster:
    runs-on: ubuntu-latest
    steps:
      - name: جلب ملفات المستودع
        uses: actions/checkout@v3

      - name: تثبيت FFmpeg و Streamlink
        run: |
          sudo apt-get update
          sudo apt-get install -y ffmpeg python3-pip
          sudo pip3 install --upgrade streamlink

      - name: تشغيل سكربت البث الشامل
        env:
          KICK_CHANNEL: ${{ github.event.inputs.kick_channel }}
          YOUTUBE_KEY: ${{ github.event.inputs.youtube_key }}
          RESTREAM_KEY: ${{ github.event.inputs.restream_key }}
          STREAM_DEST: ${{ github.event.inputs.destination }}
          STREAM_QUALITY: ${{ github.event.inputs.quality }}
        run: |
          chmod +x stream.sh
          ./stream.sh
