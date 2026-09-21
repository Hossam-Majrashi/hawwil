# حوّل | Hawwil

<p align="center">
  <b>تطبيق مفتوح المصدر لتحويل ملفات MP3 و MP4 مع إدارة الأغلفة والوسوم الصوتية</b><br>
  <b>Open-source MP3 & MP4 converter with embedded cover art and metadata editor</b>
</p>

---

## العربية

### عن التطبيق
**حوّل (Hawwil)** هو تطبيق حديث وسريع مبني باستخدام إطار عمل **Flutter**، مصمم للتحويل ثنائي الاتجاه بين ملفات الصوت (MP3) وملفات الفيديو (MP4). يتيح لك التطبيق دمج الأغلفة (Cover Art) داخل الملفات الصوتية والمرئية، واستخراج إطارات الفيديو، وتعديل وسوم ID3، وإدارة قائمة تحويلات متعددة (Batch Conversion) بكل سلاسة، بالإضافة إلى محرر مستقل لأغلفة وتفاصيل ملفات MP3 دون الحاجة لتحويل الملف.

---

### لقطات من التطبيق

#### الصفحه الرئيسيه
<img width="1920" height="1040" alt="Screenshot_20260922_015405" src="https://github.com/user-attachments/assets/cf43ee4f-4590-4117-9be1-eebd57316a05" />

#### واجهة التطبيق مشروع جديد
<img width="1920" height="1040" alt="Screenshot_20260922_015431" src="https://github.com/user-attachments/assets/23d3365e-c3d3-4512-8b10-540a73c65a07" />

#### واجهة تعديل ملفات mp3
<img width="1920" height="1040" alt="Screenshot_20260922_015449" src="https://github.com/user-attachments/assets/3a453941-7956-4bcf-adf4-d03c3ef9e1e8" />

---

### المميزات الرئيسية
- **تحويل ثنائي الاتجاه (MP3 ⇄ MP4):**
  - تحويل MP3 إلى فيديو MP4 مع صورة غلاف مدمجة وصوت عالي النقاء.
  - استخراج الصوت من MP4 وتحويله إلى ملف MP3 مع حفظ الغلاف والوسوم تلقائياً.
- **تحويل دفعات الملفات (Batch Processing):**
  - سحب وإفلات أو اختيار ملفات متعددة دفعة واحدة.
  - شاشة متابعة توضح نسبة التقدم لكل ملف ونسبة الإنجاز الكلية، مع إمكانية الإلغاء وإعادة المحاولة.
- **إدارة الأغلفة والوسوم (Cover Art & Tags):**
  - قراءة واستخراج الغلاف المدمج من ملف MP3 تلقائياً.
  - إمكانية استبدال الغلاف بأي صورة مخصصة لكل ملف.
  - استخراج إطار محدد من الفيديو لاستخدامه كغلاف للصوت.
- **محرر مستقل لأغلفة وتفاصيل MP3:**
  - فحص وتعديل الغلاف المدمج لأي ملف MP3 وحفظه مباشرة دون الحاجة لتحويل الملف.
  - إمكانية إزالة الغلاف أو إضافة غلاف جديد وتعديل بيانات الملف.
- **إعدادات تحويل متقدمة:**
  - تخصيص معدل البت للصوت (128k, 192k, 256k, 320k).
  - تحديد دقة الفيديو (720p, 1080p, 1440p, 4K) ومعدل الإطارات (FPS).
  - اختيار مجلد حفظ مخصص للملفات الناتجة.
- **واجهة مستخدم عصرية ومتعددة اللغات:**
  - دعم كامل ومتقن للغتين العربية والإنجليزية.
  - دعم الوضع الداكن (Dark Mode) والوضع الفاتح (Light Mode).
  - تصميم متجاوب يعمل بكفاءة عبر منصات سطح المكتب والهواتف والويب.
- **حزم تثبيت متعددة لأنظمة لينكس:**
  - سكريبت بناء شامل يولد حزم: Deb و RPM و Arch Linux و AppImage و Flatpak و Tar.gz.

---

### متطلبات التشغيل
- على أنظمة سطح المكتب (Linux / Windows / macOS): يجب تثبيت أداة **FFmpeg** في النظام.
  - **Ubuntu / Debian:** `sudo apt install ffmpeg`
  - **Fedora / RHEL:** `sudo dnf install ffmpeg`
  - **Arch Linux:** `sudo pacman -S ffmpeg`
  - **macOS:** `brew install ffmpeg`
  - **Windows:** تثبيت FFmpeg وإضافته لمتغيرات النظام (PATH).

---

### البناء والتشغيل من المصدر

#### 1. استنساخ المستودع
```bash
git clone https://github.com/USERNAME/hawwil.git
cd hawwil
```

#### 2. تحميل الحزم والاعتماديات
```bash
flutter pub get
```

#### 3. تشغيل التطبيق
```bash
# تشغيل على نظام لينكس
flutter run -d linux

# تشغيل على نظام ويندوز
flutter run -d windows

# تشغيل على نظام ماك
flutter run -d macos

# تشغيل على أندرويد
flutter run -d android
```

#### 4. حزم التثبيت لنظام لينكس
يحتوي المشروع على سكريبت شامل لبناء جميع صيغ الحزم:
```bash
# تثبيت متطلبات وأدوات الحزم
./build_linux.sh --install-deps

# بناء جميع صيغ الحزم (Deb, RPM, Arch, AppImage, Flatpak, Tar.gz)
./build_linux.sh

# أو بناء صيغة محددة فقط
./build_linux.sh --deb
./build_linux.sh --rpm
./build_linux.sh --arch
./build_linux.sh --appimage
./build_linux.sh --flatpak
./build_linux.sh --tar
```

#### 5. أوامر تثبيت وتشغيل الحزم المنشأة (في مجلد dist/)
- **Debian / Ubuntu / Linux Mint (APT):**
  ```bash
  sudo apt install ./dist/hawwil_1.0.0_amd64.deb
  ```
- **Fedora / RHEL 8+ / Rocky / Alma (DNF):**
  ```bash
  sudo dnf install ./dist/hawwil_1.0.0_x86_64.rpm
  ```
- **openSUSE / SLES (ZYPPER):**
  ```bash
  sudo zypper --no-gpg-checks install ./dist/hawwil_1.0.0_x86_64.rpm
  ```
- **Arch Linux / Manjaro (PACMAN):**
  ```bash
  sudo pacman -U ./dist/hawwil_1.0.0_x86_64.pkg.tar.zst
  ```
- **AppImage (يعمل على جميع التوزيعات دون تثبيت):**
  ```bash
  chmod +x ./dist/hawwil_1.0.0_x86_64.AppImage
  ./dist/hawwil_1.0.0_x86_64.AppImage
  ```
- **Flatpak:**
  ```bash
  flatpak install --user ./dist/hawwil_1.0.0_x86_64.flatpak
  ```
- **الأرشيف المحمول (Portable Tar.gz):**
  ```bash
  tar -xzf ./dist/hawwil_1.0.0_linux_x86_64.tar.gz
  cd hawwil_1.0.0 && ./run.sh
  ```

---
---

## English

### About Hawwil
**Hawwil (حوّل)** is a fast, modern cross-platform application built with **Flutter**, designed for seamless bi-directional conversion between audio (MP3) and video (MP4) files. It enables embedding cover art, extracting video frames as thumbnails, editing ID3 tags, and processing batch conversion queues with ease, along with a standalone MP3 cover art and tag editor that modifies audio files without re-encoding.

---

### Screenshots

#### Main Screen
<img width="1920" height="1040" alt="Screenshot_20260922_015405" src="https://github.com/user-attachments/assets/cf43ee4f-4590-4117-9be1-eebd57316a05" />

#### New Project Interface
<img width="1920" height="1040" alt="Screenshot_20260922_015431" src="https://github.com/user-attachments/assets/23d3365e-c3d3-4512-8b10-540a73c65a07" />

#### MP3 Cover & Tag Editor
<img width="1920" height="1040" alt="Screenshot_20260922_015449" src="https://github.com/user-attachments/assets/3a453941-7956-4bcf-adf4-d03c3ef9e1e8" />

---

### Key Features
- **Bi-Directional Conversion (MP3 ⇄ MP4):**
  - Convert MP3 audio to MP4 video with embedded cover art and crystal-clear sound.
  - Extract MP3 audio from MP4 video while preserving cover art and metadata tags.
- **Batch Processing Queue:**
  - Add single or multiple files into a unified queue.
  - Real-time progress monitoring per item and overall progress, with cancel and retry support.
- **Cover Art & Tag Management:**
  - Automatically extracts embedded cover art from MP3 files.
  - Replace or set custom images per file.
  - Extract specific video frames (seconds scrubbing) to use as audio artwork.
- **Standalone MP3 Cover Art & Tag Editor:**
  - Inspect, replace, or remove embedded artwork directly inside MP3 files without conversion.
  - View and update audio metadata tags.
- **Customizable Output Settings:**
  - Audio bitrate selection (128k, 192k, 256k, 320k).
  - Video resolution configuration (720p, 1080p, 1440p, 4K) and framerate (FPS).
  - Configurable custom output folder.
- **Modern & Bilingual UI:**
  - Native RTL (Arabic) and LTR (English) support.
  - Sleek Dark and Light themes.
  - Responsive design optimized for desktop, mobile, and web form factors.
- **Multi-Distribution Linux Packaging:**
  - Universal packaging script generating Deb, RPM, Arch Linux (.pkg.tar.zst), AppImage, Flatpak, and Portable Tar.gz bundles.

---

### Prerequisites
- On desktop platforms (Linux / Windows / macOS), **FFmpeg** must be installed on your system:
  - **Ubuntu / Debian:** `sudo apt install ffmpeg`
  - **Fedora / RHEL:** `sudo dnf install ffmpeg`
  - **Arch Linux:** `sudo pacman -S ffmpeg`
  - **macOS:** `brew install ffmpeg`
  - **Windows:** Install FFmpeg and add it to your system PATH.

---

### Building and Running from Source

#### 1. Clone the repository
```bash
git clone https://github.com/USERNAME/hawwil.git
cd hawwil
```

#### 2. Get dependencies
```bash
flutter pub get
```

#### 3. Run the application
```bash
# Run on Linux desktop
flutter run -d linux

# Run on Windows desktop
flutter run -d windows

# Run on macOS desktop
flutter run -d macos

# Run on Android
flutter run -d android
```

#### 4. Package for Linux distributions
A packaging script is provided to generate packages across multiple package formats:
```bash
# Install packaging dependencies
./build_linux.sh --install-deps

# Build all package formats (Deb, RPM, Arch, AppImage, Flatpak, Tar.gz)
./build_linux.sh

# Or build a specific package
./build_linux.sh --deb
./build_linux.sh --rpm
./build_linux.sh --arch
./build_linux.sh --appimage
./build_linux.sh --flatpak
./build_linux.sh --tar
```

#### 5. Installing the Generated Packages (from dist/ folder)
- **Debian / Ubuntu / Linux Mint (APT):**
  ```bash
  sudo apt install ./dist/hawwil_1.0.0_amd64.deb
  ```
- **Fedora / RHEL 8+ / Rocky / Alma (DNF):**
  ```bash
  sudo dnf install ./dist/hawwil_1.0.0_x86_64.rpm
  ```
- **openSUSE / SLES (ZYPPER):**
  ```bash
  sudo zypper --no-gpg-checks install ./dist/hawwil_1.0.0_x86_64.rpm
  ```
- **Arch Linux / Manjaro (PACMAN):**
  ```bash
  sudo pacman -U ./dist/hawwil_1.0.0_x86_64.pkg.tar.zst
  ```
- **AppImage (Universal, no installation required):**
  ```bash
  chmod +x ./dist/hawwil_1.0.0_x86_64.AppImage
  ./dist/hawwil_1.0.0_x86_64.AppImage
  ```
- **Flatpak:**
  ```bash
  flatpak install --user ./dist/hawwil_1.0.0_x86_64.flatpak
  ```
- **Portable Tarball (.tar.gz):**
  ```bash
  tar -xzf ./dist/hawwil_1.0.0_linux_x86_64.tar.gz
  cd hawwil_1.0.0 && ./run.sh
  ```

---

### License
This project is open-source under the [MIT License](LICENSE).
