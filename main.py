import os
import time
import json
import subprocess
import urllib.request

KICK_USERNAME = "drb7h"
RESTREAM_KEY = "re_11725544_event1f24e3174647428d86fc1329252bbf36"
RESTREAM_RTMP = f"rtmp://live.restream.io/live/{RESTREAM_KEY}"

IMG1_URL = "https://i.top4top.io/p_38841iil90.png"
IMG2_URL = "https://a.top4top.io/p_3884w5h790.png"
IMG1_LOCAL = "image1.png"
IMG2_LOCAL = "image2.png"

HEADERS = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    'Accept': 'application/json',
    'Referer': f'https://kick.com/{KICK_USERNAME}'
}

def download_image(url, output_path):
    try:
        req = urllib.request.Request(url, headers=HEADERS)
        with urllib.request.urlopen(req) as response, open(output_path, 'wb') as out_file:
            out_file.write(response.read())
    except Exception as e:
        print(f"[-] خطأ تحميل الصورة: {e}")

def get_kick_livestream_url(username):
    api_url = f"https://kick.com/api/v2/channels/{username}"
    req = urllib.request.Request(api_url, headers=HEADERS)
    try:
        with urllib.request.urlopen(req) as response:
            if response.status == 200:
                data = json.loads(response.read().decode('utf-8'))
                if data.get('livestream') and data.get('playback_url'):
                    return data.get('playback_url')
    except:
        pass
    return None

def start_restream(stream_url):
    filter_complex = (
        "[1:v]scale=300:-1[img1_scaled];"
        "[2:v]scale=300:-1[img2_scaled];"
        "[0:v][img1_scaled]overlay=(main_w-overlay_w)/2:main_h-overlay_h-20:enable='lt(mod(t,10),5)'[tmp];"
        "[tmp][img2_scaled]overlay=(main_w-overlay_w)/2:main_h-overlay_h-20:enable='gte(mod(t,10),5)'[v]"
    )
    ffmpeg_cmd = [
        'ffmpeg', '-re', '-i', stream_url, '-i', IMG1_LOCAL, '-i', IMG2_LOCAL,
        '-filter_complex', filter_complex, '-map', '[v]', '-map', '0:a:0?',
        '-c:v', 'libx264', '-preset', 'ultrafast', '-tune', 'zerolatency',
        '-b:v', '3000k', '-maxrate', '3500k', '-bufsize', '6000k',
        '-pix_fmt', 'yuv420p', '-g', '50', '-c:a', 'aac', '-b:a', '128k',
        '-ar', '44100', '-f', 'flv', RESTREAM_RTMP
    ]
    subprocess.run(ffmpeg_cmd)

def main():
    download_image(IMG1_URL, IMG1_LOCAL)
    download_image(IMG2_URL, IMG2_LOCAL)
    print(f"[*] بدء نظام المراقبة الذكي لقناة {KICK_USERNAME}...")
    while True:
        playback_url = get_kick_livestream_url(KICK_USERNAME)
        if playback_url:
            print("[+] البث يعمل الآن! بدء إعادة التوجيه...")
            start_restream(playback_url)
            print("[!] توقف البث. العودة لوضع المراقبة الانتظار...")
        else:
            print("[-] القناة أوفلاين. إعادة الفحص خلال 15 ثانية...")
        time.sleep(15)

if __name__ == "__main__":
    main()
