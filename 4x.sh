#!/bin/bash

# رنگ‌ها برای نمایش زیبا
GREEN='\033[0;32m'
NC='\033[0m'

clear
echo -e "${GREEN}Torrent-to-OneDrive نصب در حال شروع است...${NC}"

# نصب پیش‌نیازها
sudo apt update
sudo apt install -y python3 python3-pip python3-venv git curl unzip dos2unix whiptail

# ایجاد فولدر پروژه
mkdir -p /opt/torrent2onedrive && cd /opt/torrent2onedrive

# کلون بک‌اند
echo -e "${GREEN}دریافت بک‌اند FastAPI...${NC}"
git clone https://github.com/atbin44/torrent2onedrive.git backend
cd backend
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# اضافه کردن API انتقال فایل با rclone
echo -e "${GREEN}ساخت upload_to_onedrive.py...${NC}"
mkdir -p app/api
cat <<EOF > app/api/upload_to_onedrive.py
from fastapi import APIRouter
import subprocess

router = APIRouter()

@router.post("/upload-to-onedrive")
def upload_to_onedrive(local_path: str, remote_path: str = ""):
    remote = f"onedrive:{remote_path}" if remote_path else "onedrive:"
    try:
        result = subprocess.run(
            ["rclone", "move", local_path, remote, "--progress"],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )
        return {"stdout": result.stdout, "stderr": result.stderr}
    except Exception as e:
        return {"error": str(e)}
EOF

# ثبت روت در main.py (درج روت در زیر خط import اصلی)
sed -i "/from fastapi import FastAPI/a from app.api import upload_to_onedrive" main.py
sed -i "/app = FastAPI()/a app.include_router(upload_to_onedrive.router)" main.py

# راه‌اندازی بک‌اند به صورت systemd
echo -e "${GREEN}تنظیم سرویس بک‌اند با systemd...${NC}"
cat <<EOF | sudo tee /etc/systemd/system/torrent-backend.service
[Unit]
Description=Torrent2OneDrive Backend
After=network.target

[Service]
User=root
WorkingDirectory=/opt/torrent2onedrive/backend
ExecStart=/opt/torrent2onedrive/backend/venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable torrent-backend
sudo systemctl start torrent-backend

# نصب rclone
echo -e "${GREEN}نصب rclone...${NC}"
curl https://rclone.org/install.sh | sudo bash

# ایجاد مسیر کانفیگ rclone اگر وجود نداشت
mkdir -p /root/.config/rclone
# (در صورت نیاز فایل کانفیگ رو تنظیم کنید)

# نصب Node.js و فرانت‌اند
echo -e "${GREEN}نصب فرانت React + Vite...${NC}"
cd /opt/torrent2onedrive
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs

npm create vite@latest frontend -- --template react
cd frontend
npm install
npm install axios
npm install -D tailwindcss postcss autoprefixer
npx tailwindcss init -p

# اضافه کردن تنظیمات Tailwind
sed -i 's/content: \[\]/content: [".\/index.html", ".\/src\/.*\\.(js|ts|jsx|tsx)"]/' tailwind.config.js

# ساخت فایل‌های اولیه فرانت
mkdir -p src
cat <<EOF > src/index.css
@tailwind base;
@tailwind components;
@tailwind utilities;
EOF

cat <<EOF > src/App.jsx
import { useState } from "react";
import axios from "axios";

function App() {
  const [localPath, setLocalPath] = useState("");
  const [remotePath, setRemotePath] = useState("");
  const [response, setResponse] = useState("");

  const handleUpload = async () => {
    try {
      const res = await axios.post("http://localhost:8000/upload-to-onedrive", {
        local_path: localPath,
        remote_path: remotePath,
      });
      setResponse(JSON.stringify(res.data, null, 2));
    } catch (err) {
      setResponse(err.message);
    }
  };

  return (
    <div className="min-h-screen p-6 bg-gray-100">
      <div className="max-w-xl mx-auto bg-white rounded-2xl shadow p-4">
        <h1 className="text-2xl font-bold mb-4">
