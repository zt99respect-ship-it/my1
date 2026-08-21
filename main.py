import os
import time
import json
import subprocess
import urllib.request
import socket

# ضبط مهلة الاتصال لمنع تعليق السكريبت عند انقطاع الشبكة
socket.setdefaulttimeout(15)

# البيانات الخاصة بقناة drb7h وسيرفر Restream
KICK_USERNAME = "1Mali"
RESTREAM_KEY = "re_11725544_eventa752cf60ea2c4cecbd8820b54335d0aa"
RESTREAM_RTMP = f"rtmp://live.restream.io/live/{RESTREAM_KEY}"

IMG1_URL = "https://i.top4top.io/p_38841iil90.png"
IMG2_URL = "https://a.top4top.io/p_3884w5h790.png"
IMG1_LOCAL = "image1.png"
IMG2_LOCAL = "image2.png"

# حد أقصى للتشغيل: 5 ساعات (18,000 ثانية) للتناوب التلقائي في GitHub Actions
MAX_RUN_TIME = 18000

HEADERS = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept': 'application/json',
    'Referer': f'https://kick.com/{KICK_USERNAME}'
}

def download_image(url, output_path):
    try:
        req = urllib.request.Request(url, headers=HEADERS)
        with urllib.request.urlopen(req, timeout=10) as response, open(output_path, 'wb') as out_file:
            out_file.write(response.read())
        print(f"[+] تم تحميل الصورة بنجاح: {output_path}")
    except Exception as e:
        print(f"[-] خطأ في تحميل الصورة ({output_path}): {e}")

def get_kick_livestream_url(username):
    api_url = f"https://kick.com/api/v2/channels/{username}"
    req = urllib.request.Request(api_url, headers=HEADERS)
    try:
        with urllib.request.urlopen(req, timeout=10) as response:
            if response.status == 200:
                data = json.loads(response.read().decode('utf-8'))
                if data.get('livestream') and data.get('playback_url'):
                    return data.get('playback_url')
    except Exception:
        pass
    return None

def start_restream(stream_url):
    filter_complex = (
        "[0:v]scale=1920:1080:flags=lanczos[main_scaled];"
        "[1:v]scale=185:-1[img1_scaled];"
        "[2:v]scale=185:-1[img2_scaled];"
        "[main_scaled][img1_scaled]overlay=(main_w-overlay_w)/2:main_h-overlay_h-10:enable='lt(mod(t,10),5)'[tmp];"
        "[tmp][img2_scaled]overlay=(main_w-overlay_w)/2:main_h-overlay_h-10:enable='gte(mod(t,10),5)'[v]"
    )
    
    ffmpeg_cmd = [
        'ffmpeg',
        '-re',
        '-i', stream_url,
        '-i', IMG1_LOCAL,
        '-i', IMG2_LOCAL,
        '-filter_complex', filter_complex,
        '-map', '[v]',
        '-map', '0:a:0?',
        '-c:v', 'libx264',
        '-preset', 'veryfast',
        '-tune', 'zerolatency',
        '-crf', '18',
        '-maxrate', '9000k',
        '-bufsize', '18000k',
        '-pix_fmt', 'yuv420p',
        '-g', '60',
        '-c:a', 'aac',
        '-b:a', '256k',
        '-ar', '48000',
        '-f', 'flv',
        RESTREAM_RTMP
    ]
    try:
        subprocess.run(ffmpeg_cmd, check=False)
    except Exception as e:
        print(f"[-] تنبيه: حدث خطأ أثناء تشغيل FFmpeg: {e}")

def main():
    start_time = time.time()
    download_image(IMG1_URL, IMG1_LOCAL)
    download_image(IMG2_URL, IMG2_LOCAL)
    
    print(f"[*] بدء نظام المراقبة الدائم لقناة {KICK_USERNAME} والبث إلى Restream...")
    
    while True:
        if time.time() - start_time > MAX_RUN_TIME:
            print("[!] إغلاق الجلسة الحالية بنجاح بعد 5 ساعات لبدء جلسة جديدة...")
            break

        try:
            if not os.path.exists(IMG1_LOCAL):
                download_image(IMG1_URL, IMG1_LOCAL)
            if not os.path.exists(IMG2_LOCAL):
                download_image(IMG2_URL, IMG2_LOCAL)

            playback_url = get_kick_livestream_url(KICK_USERNAME)
            
            if playback_url:
                print("[+] البث يعمل الآن! بدء إعادة التوجيه التلقائي إلى Restream...")
                start_restream(playback_url)
                print("[!] توقف البث أو انقطع الاتصال. إعادة المحاولة والمراقبة...")
            else:
                print("[-] القناة أوفلاين. إعادة الفحص خلال 10 ثوانٍ...")
                
        except KeyboardInterrupt:
            print("[!] تم إيقاف السكريبت يدوياً.")
            break
        except Exception as e:
            print(f"[!] حدث خطأ في النظام: {e}. إعادة التشغيل التلقائي خلال 10 ثوانٍ...")
        
        time.sleep(10)

if __name__ == "__main__":
    main()
