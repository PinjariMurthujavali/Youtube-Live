#!/usr/bin/env bash
# 24/7 YouTube LIVE loop of an existing video (Ubuntu/Debian VM, e.g. Oracle Cloud Always Free)
# Usage:  bash setup-live.sh
set -e

VIDEO_URL="https://youtu.be/zzFDohnmN34"      # your already-published video
RTMP_URL="rtmp://a.rtmp.youtube.com/live2"
WORKDIR="$HOME/live"

read -rsp "Paste YouTube STREAM KEY (hidden): " KEY; echo
[ -z "$KEY" ] && { echo "Stream key empty"; exit 1; }

echo "==> Installing ffmpeg + yt-dlp"
sudo apt-get update -y
sudo apt-get install -y ffmpeg python3-pip
sudo pip3 install -U yt-dlp --break-system-packages 2>/dev/null || sudo pip3 install -U yt-dlp

echo "==> Downloading your video"
mkdir -p "$WORKDIR" && cd "$WORKDIR"
yt-dlp -f "bv*[height<=1080]+ba/b[height<=1080]" --merge-output-format mp4 -o "video.mp4" "$VIDEO_URL"

echo "==> Saving stream key (root-only file)"
echo "YT_KEY=$KEY" | sudo tee /etc/yt-live.env >/dev/null
sudo chmod 600 /etc/yt-live.env

echo "==> Creating auto-restart service"
sudo tee /etc/systemd/system/yt-live.service >/dev/null <<EOF
[Unit]
Description=YouTube 24/7 live loop
After=network-online.target
Wants=network-online.target

[Service]
User=$USER
EnvironmentFile=/etc/yt-live.env
ExecStart=/usr/bin/ffmpeg -hide_banner -loglevel warning -re -stream_loop -1 -i $WORKDIR/video.mp4 \\
  -vf scale=1280:720 -c:v libx264 -preset veryfast -b:v 3000k -maxrate 3000k -bufsize 6000k \\
  -pix_fmt yuv420p -g 60 -keyint_min 60 -c:a aac -b:a 160k -ar 44100 \\
  -f flv $RTMP_URL/\${YT_KEY}
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now yt-live
sleep 5
systemctl --no-pager status yt-live | head -12
echo
echo "DONE. Check YouTube Studio > Live: stream should show 'Receiving data'."
echo "Logs:   journalctl -u yt-live -f"
echo "Stop:   sudo systemctl stop yt-live"
