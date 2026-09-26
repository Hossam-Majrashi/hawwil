import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizations(const Locale('ar'));
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  bool get isArabic => locale.languageCode == 'ar';
  TextDirection get textDirection =>
      isArabic ? TextDirection.rtl : TextDirection.ltr;

  static const Map<String, Map<String, String>> _localizedValues = {
    'ar': {
      // General
      'appName': 'حوّل',
      'appTagline': 'تحويل الصوت والفيديو مع حفظ صور الأغلفة والبيانات الوصفية',
      'appDescription':
          'حوّل (Hawwil) هو تطبيق احترافي للتحويل بين ملفات MP3 الصوتية وفيديوهات MP4، مع معالجة ذكية ودقيقة لصور الأغلفة المضمنة، واستخراج الإطارات، وتحرير الوسوم، والتحويل المجمّع.',
      'cancel': 'إلغاء',
      'retry': 'إعادة المحاولة',
      'save': 'حفظ',
      'saved': 'تم الحفظ بنجاح',
      'start': 'بدء',
      'close': 'إغلاق',
      'delete': 'حذف',
      'remove': 'إزالة',
      'replace': 'استبدال',
      'choose': 'اختيار',
      'back': 'رجوع',
      'next': 'التالي',
      'ok': 'موافق',
      'apply': 'تطبيق',
      'done': 'تم',
      'error': 'خطأ',
      'warning': 'تنبيه',
      'success': 'نجاح',
      'loading': 'جارٍ التحميل...',

      // Screens
      'screenSplash': 'عن التطبيق',
      'screenLanguage': 'اختيار اللغة',
      'screenTheme': 'اختيار المظهر',
      'screenHome': 'الرئيسية',
      'screenCreateProject': 'مشروع تحويل جديد',
      'screenProgress': 'قائمة التحويل',
      'screenCoverEditor': 'محرر الأغلفة',
      'screenMergeMedia': 'دمج الوسائط',
      'screenSettings': 'الإعدادات',
      'screenFfmpegSetup': 'تثبيت أداة FFmpeg',

      // Splash / About
      'aboutTitle': 'مرحباً بك في حوّل',
      'aboutFeature1': 'تحويل MP3 إلى MP4 مع اعتماد صورة الغلاف كإطار مرئي كامل.',
      'aboutFeature2': 'استخراج الصوت من MP4 إلى MP3 مع تضمين إطار الفيديو كغلاف.',
      'aboutFeature3': 'محرر مخصص لصور الأغلفة والبيانات الوصفية لملفات MP3 و MP4 دون الحاجة لتحويل.',
      'aboutFeature4': 'دعم المعالجة والتحويل المجمّع (Batch Conversion) بسرعة فائقة مع تسريع العتاد.',
      'getStarted': 'ابدأ الآن',

      // Language
      'selectLanguage': 'اختر لغة التطبيق',
      'languageArabic': 'العربية (افتراضي)',
      'languageEnglish': 'English',

      // Theme
      'selectTheme': 'اختر المظهر المفضل',
      'themeDark': 'الوضع الليلي (داكن)',
      'themeLight': 'الوضع النهاري (فاتح)',
      'themeSystem': 'تلقائي (حسب النظام)',

      // Home
      'homeCreateProjectTitle': 'بدء مشروع جديد',
      'homeCreateProjectSub': 'تحويل ملف فردي أو دفعة ملفات بين MP3 و MP4',
      'homeCoverEditorTitle': 'محرر الأغلفة',
      'homeCoverEditorSub': 'عرض واستبدال أو إزالة صورة الغلاف وتعديل الوسوم لملفات MP3 و MP4',
      'homeMergeMediaTitle': 'دمج الوسائط',
      'homeMergeMediaSub': 'دمج الصور والفيديوهات في مسار بصري متتابع مع مقطع صوتي مخصص',
      'homeSettingsTitle': 'الإعدادات',
      'homeSettingsSub': 'تخصيص الدقة، معدل البت، مجلد الحفظ، المظهر واللغة',
      'quickStatus': 'حالة النظام',
      'ffmpegReady': 'أداة FFmpeg جاهزة للعمل',
      'ffmpegMissing': 'أداة FFmpeg غير متوفرة بالنظام',

      // Create Project
      'pickFiles': 'إضافة ملفات',
      'pickFilesDesc': 'اختر ملفات وسائط لإضافتها لقائمة التحويل',
      'dropFilesHere': 'أفلت الملفات هنا أو اضغط للاختيار',
      'noFilesSelected': 'لم يتم اختيار أي ملفات بعد',
      'fileQueueCount': 'عدد الملفات في القائمة: {count}',
      'direction': 'اتجاه التحويل',
      'targetFormat': 'صيغة الإخراج',
      'videoOutputFormatBatch': 'صيغة إخراج الفيديو للقائمة',
      'applyToAllVideos': 'تطبيق على كل الفيديوهات',
      'mp3ToMp4': 'MP3 ➔ MP4 (صوت إلى فيديو)',
      'mp4ToMp3': 'MP4 ➔ MP3 (فيديو إلى صوت)',
      'videoToAudio': 'فيديو ➔ صوت',
      'videoToVideo': 'تحويل فيديو',
      'audioToVideo': 'صوت ➔ فيديو',
      'formatMp3': 'MP3 (استخراج صوت)',
      'formatAac': 'AAC (استخراج صوت)',
      'formatWav': 'WAV (استخراج صوت)',
      'formatFlac': 'FLAC (استخراج صوت)',
      'formatOgg': 'OGG (استخراج صوت)',
      'formatOpus': 'Opus (استخراج صوت)',
      'formatMp4': 'MP4 (H.264 / AAC)',
      'formatMkv': 'MKV (H.264 / AAC)',
      'formatMov': 'MOV (H.264 / AAC)',
      'formatWebm': 'WebM (VP9 / Opus)',
      'formatAvi': 'AVI (MPEG-4 / MP3)',
      'formatFlv': 'FLV (H.264 / AAC)',
      'formatWmv': 'WMV (WMV2 / WMA)',
      'formatMpg': 'MPG (MPEG-2 / MP2)',
      'formatMpeg': 'MPEG (MPEG-2 / MP2)',
      'formatOgv': 'OGV (Theora / Vorbis)',
      'embeddedCover': 'غلاف مدمج',
      'noCover': 'لا يوجد غلاف',
      'pickImageForVideo': 'اختر صورة لإطار الفيديو',
      'changeImage': 'تغيير الصورة',
      'scrubFrame': 'تحديد إطار الغلاف من الفيديو',
      'scrubTimestamp': 'التوقيت: {time} ثانية',
      'startConversion': 'بدء عملية التحويل ({count})',
      'clearQueue': 'تفريغ القائمة',
      'outputSettings': 'إعدادات الإخراج',
      'resolution': 'دقة الفيديو',
      'videoBitrate': 'معدل بت الفيديو',
      'audioBitrate': 'معدل بت الصوت',
      'editMetadata': 'تعديل البيانات الوصفية (ID3)',
      'title': 'العنوان',
      'artist': 'الفنان',
      'album': 'الألبوم',

      // Progress
      'progressTitle': 'تقدم التحويل',
      'overallProgress': 'التقدم الإجمالي: {percent}%',
      'itemsCompleted': 'اكتمل {done} من {total}',
      'statusQueued': 'في الانتظار',
      'statusConverting': 'جارٍ التحويل ({percent}%)',
      'statusCompleted': 'اكتمل بنجاح',
      'statusFailed': 'فشل التحويل',
      'statusCancelled': 'تم الإلغاء',
      'cancelItem': 'إلغاء',
      'retryItem': 'إعادة',
      'cancelAll': 'إلغاء الكل',
      'openOutputFolder': 'فتح مجلد الإخراج',
      'conversionCompleteMessage': 'اكتملت جميع عمليات التحويل في القائمة!',
      'viewResults': 'عرض النتائج',
      'startNewProject': 'بدء مشروع جديد',

      // Cover Editor
      'coverEditorTitle': 'محرر الأغلفة',
      'pickMp3File': 'اختر ملف MP3 أو MP4 للتعديل',
      'pickMp3': 'ملف MP3 (صوت)',
      'pickMp4': 'ملف MP4 (فيديو)',
      'selectMediaTypePrompt': 'اختر نوع الملف لتعديل الغلاف والبيانات',
      'mp3Description': 'عرض وتعديل أو استبدال صورة الغلاف ووسوم ID3 الصوتية',
      'mp4Description': 'عرض وتعديل أو استبدال بوستر الفيديو أو التقاط إطار',
      'captureFrameFromVideo': 'التقاط إطار كغلاف',
      'currentCover': 'صورة الغلاف الحالية',
      'noCoverInFile': 'الملف لا يحتوي على صورة غلاف مدمجة',
      'uploadNewCover': 'اختيار صورة جديدة',
      'removeCover': 'حذف الغلاف',
      'saveChanges': 'حفظ التعديلات في الملف',
      'saving': 'جارٍ الحفظ...',
      'fileInfo': 'معلومات الملف',
      'duration': 'المدة',
      'fileSize': 'حجم الملف',
      'audioQuality': 'جودة الصوت',
      'viewFullImage': 'عرض الصورة بالكامل',
      'imageDimensions': '{width} × {height} بكسل ({size})',
      'coverFitContain': 'احتواء كامل (بدون قص)',
      'coverFitCover': 'ملء الإطار (قص الأطراف)',
      'downloadCover': 'تنزيل الغلاف',
      'downloadCoverTooltip': 'تنزيل صورة الغلاف الحالية',
      'coverDownloaded': 'تم تنزيل صورة الغلاف بنجاح',
      'coverDownloadFailed': 'تعذر تنزيل صورة الغلاف',
      'mp4CoverSaved': 'تم حفظ تعديلات غلاف وبيانات MP4 بنجاح',
      'switchFile': 'تغيير الملف',

      // Settings
      'settingsTitle': 'الإعدادات العامة',
      'defaultResolution': 'الدقة الافتراضية للفيديو (MP3 ➔ MP4)',
      'defaultVideoBitrate': 'معدل بت الفيديو الافتراضي',
      'defaultAudioBitrate': 'معدل بت الصوت الافتراضي',
      'defaultOutputFolder': 'مجلد الحفظ الافتراضي',
      'changeFolder': 'تغيير المجلد',
      'notSet': 'غير محدد (المجلد الافتراضي)',
      'languageAndAppearance': 'اللغة والمظهر',
      'hardwareAcceleration': 'تسريع العتاد (كرت الشاشة والمعالج)',
      'hardwareAccelerationDesc': 'استخدام كرت الشاشة (GPU) وتعدد أنوية المعالج لتسريع التحويل الفائق',
      'hwAccelAuto': 'تلقائي (كرت الشاشة إن وجد)',
      'hwAccelNvenc': 'NVIDIA NVENC (كرت الشاشة)',
      'hwAccelVaapi': 'VAAPI (تسريع العتاد)',
      'hwAccelQsv': 'Intel QSV (تسريع العتاد)',
      'hwAccelVideoToolbox': 'Apple VideoToolbox (تسريع العتاد)',
      'hwAccelCpuUltrafast': 'المعالج فائق السرعة (CPU Ultrafast)',
      'resOriginal': 'الأصلية (بدون تكبير)',
      'bitrateAuto': 'تلقائي (جودة ذكية CRF 23)',
      'audioBitrateAuto': 'تلقائي (مطابق للمصدر)',
      'gpuActive': 'تسريع كرت الشاشة نشط',
      'cpuMultithreadActive': 'المعالج متعدد الأنوية نشط',

      // FFmpeg Setup (Desktop)
      'ffmpegSetupTitle': 'إعداد FFmpeg مطلوب',
      'ffmpegSetupMessage':
          'تطبيق حوّل على أنظمة سطح المكتب يعتمد على أداة FFmpeg المثبتة بالنظام لضمان أعلى أداء وكفاءة في تحويل الوسائط.',
      'ffmpegInstallUbuntu': 'لتثبيت FFmpeg على Ubuntu/Debian/Mint:',
      'ffmpegInstallFedora': 'لتثبيت FFmpeg على Fedora/RHEL:',
      'ffmpegInstallArch': 'لتثبيت FFmpeg على Arch/Manjaro:',
      'ffmpegInstallMac': 'لتثبيت FFmpeg على macOS (Homebrew):',
      'ffmpegInstallWindows': 'لتثبيت FFmpeg على Windows (Winget):',
      'recheckFfmpeg': 'إعادة فحص التثبيت',
      'ffmpegInstalledSuccess': 'تم اكتشاف FFmpeg بنجاح! يمكنك الآن المتابعة.',

      // Web Notice
      'webNoticeTitle': 'ملاحظة إصدار الويب',
      'webNoticeDesc':
          'يمكنك معاينة الملفات وتجربة الواجهة على الويب. لتنفيذ التحويل الكامل والترميز الفائق بالسرعة القصوى، يرجى تشغيل تطبيق سطح المكتب أو الهاتف.',

      // Merge Media
      'mergeMediaDesc': 'رتب الصور والفيديوهات مع مسار صوتي لإنشاء فيديو مدمج',
      'addMediaFiles': 'إضافة وسائط',
      'addMediaFilesDesc': 'اختر صوراً، فيديوهات، أو مقاطع صوتية لإضافتها للمشروع',
      'trackImages': 'المسار 1: الصور',
      'trackVideos': 'المسار 2: الفيديوهات',
      'trackAudio': 'المسار 3: الصوت فقط',
      'mediaPool': 'صندوق الوسائط المضافة',
      'mediaPoolEmpty': 'لا توجد وسائط مضافة بعد. اضغط على "إضافة وسائط" لبدء العمل.',
      'timelineHelp': 'اسحب العناصر من الصندوق إلى مساراتها المطابقة للترتيب التلقائي المتتابع بدون فجوات',
      'dragHere': 'أفلت العنصر هنا',
      'imageDuration': 'مدة عرض الصورة',
      'seconds': 'ثانية',
      'exportMerge': 'تصدير ودمج الوسائط',
      'exportingMerge': 'جاري دمج وتصدير الوسائط...',
      'previewPlayer': 'معاينة العمل المدمج',
      'noVisualItemsWarning': 'يرجى إضافة عنصر وسائط واحد على الأقل للمخطط الزمني قبل التصدير',
      'clearTimeline': 'إفراغ المسارات',
      'removeItem': 'حذف',
      'adjustDuration': 'تعديل مدة الصورة',
      'mergeExportSuccess': 'تم دمج وتصدير الوسائط بنجاح!',
      'outputResolution': 'دقة الفيديو المدمج',
      'cancelMerge': 'إلغاء الدمج',
      'play': 'تشغيل',
      'pause': 'إيقاف مؤقت',
      'replay': 'إعادة',

      // Developer
      'developer': 'المطور',
      'email': 'البريد الإلكتروني',
      'website': 'الموقع الإلكتروني',
    },
    'en': {
      // General
      'appName': 'Hawwil',
      'appTagline': 'Audio & Video Converter with Embedded Cover Art & Tags',
      'appDescription':
          'Hawwil (Arabic: حوّل, "Convert") is a professional converter between MP3 audio and MP4 video, featuring first-class ID3 APIC cover art handling, frame extraction, tag editing, and fast batch conversion.',
      'cancel': 'Cancel',
      'retry': 'Retry',
      'save': 'Save',
      'saved': 'Saved successfully',
      'start': 'Start',
      'close': 'Close',
      'delete': 'Delete',
      'remove': 'Remove',
      'replace': 'Replace',
      'choose': 'Choose',
      'back': 'Back',
      'next': 'Next',
      'ok': 'OK',
      'apply': 'Apply',
      'done': 'Done',
      'error': 'Error',
      'warning': 'Warning',
      'success': 'Success',
      'loading': 'Loading...',

      // Screens
      'screenSplash': 'About Hawwil',
      'screenLanguage': 'Language Selection',
      'screenTheme': 'Theme Selection',
      'screenHome': 'Home',
      'screenCreateProject': 'Create Project',
      'screenProgress': 'Conversion Queue',
      'screenCoverEditor': 'Cover Art Editor',
      'screenMergeMedia': 'Merge Media',
      'screenSettings': 'Settings',
      'screenFfmpegSetup': 'FFmpeg Setup',

      // Splash / About
      'aboutTitle': 'Welcome to Hawwil',
      'aboutFeature1': 'Convert MP3 to MP4 using embedded cover art as a full-frame static video.',
      'aboutFeature2': 'Extract MP4 audio to MP3 and optionally embed video frames as cover art.',
      'aboutFeature3': 'Standalone Cover Art Editor: view, replace, or remove cover art for MP3 and MP4 without conversion.',
      'aboutFeature4': 'High-performance batch processing with real-time queue and hardware acceleration.',
      'getStarted': 'Get Started',

      // Language
      'selectLanguage': 'Select Application Language',
      'languageArabic': 'العربية (Arabic - Default)',
      'languageEnglish': 'English',

      // Theme
      'selectTheme': 'Select Theme Preference',
      'themeDark': 'Dark Theme',
      'themeLight': 'Light Theme',
      'themeSystem': 'System Default',

      // Home
      'homeCreateProjectTitle': 'Create Project',
      'homeCreateProjectSub': 'Convert single or batch audio & video files between MP3 and MP4',
      'homeCoverEditorTitle': 'Cover Art Editor',
      'homeCoverEditorSub': 'Inspect, replace, or remove cover art and edit tags for MP3 and MP4 files',
      'homeMergeMediaTitle': 'Merge Media',
      'homeMergeMediaSub': 'Combine images and videos sequentially with custom audio tracks',
      'homeSettingsTitle': 'Settings',
      'homeSettingsSub': 'Configure resolution, bitrates, default folder, language, and theme',
      'quickStatus': 'System Status',
      'ffmpegReady': 'FFmpeg is ready and operational',
      'ffmpegMissing': 'FFmpeg binary not detected on system',

      // Create Project
      'pickFiles': 'Add Files',
      'pickFilesDesc': 'Select media files to add to the conversion queue',
      'dropFilesHere': 'Drag & drop files here or click to browse',
      'noFilesSelected': 'No files added to the queue yet',
      'fileQueueCount': 'Files in queue: {count}',
      'direction': 'Conversion Direction',
      'targetFormat': 'Target Format',
      'videoOutputFormatBatch': 'Batch Video Output Format',
      'applyToAllVideos': 'Apply to all videos',
      'mp3ToMp4': 'MP3 ➔ MP4 (Audio to Video)',
      'mp4ToMp3': 'MP4 ➔ MP3 (Video to Audio)',
      'videoToAudio': 'Video ➔ Audio',
      'videoToVideo': 'Video Convert',
      'audioToVideo': 'Audio ➔ Video',
      'formatMp3': 'MP3 (Audio extraction)',
      'formatAac': 'AAC (Audio extraction)',
      'formatWav': 'WAV (Audio extraction)',
      'formatFlac': 'FLAC (Audio extraction)',
      'formatOgg': 'OGG (Audio extraction)',
      'formatOpus': 'Opus (Audio extraction)',
      'formatMp4': 'MP4 (H.264 / AAC)',
      'formatMkv': 'MKV (H.264 / AAC)',
      'formatMov': 'MOV (H.264 / AAC)',
      'formatWebm': 'WebM (VP9 / Opus)',
      'formatAvi': 'AVI (MPEG-4 / MP3)',
      'formatFlv': 'FLV (H.264 / AAC)',
      'formatWmv': 'WMV (WMV2 / WMA)',
      'formatMpg': 'MPG (MPEG-2 / MP2)',
      'formatMpeg': 'MPEG (MPEG-2 / MP2)',
      'formatOgv': 'OGV (Theora / Vorbis)',
      'embeddedCover': 'Embedded Cover',
      'noCover': 'No Cover',
      'pickImageForVideo': 'Select frame image for video',
      'changeImage': 'Change Image',
      'scrubFrame': 'Scrub video frame for cover art',
      'scrubTimestamp': 'Timestamp: {time}s',
      'startConversion': 'Start Conversion ({count})',
      'clearQueue': 'Clear Queue',
      'outputSettings': 'Output Settings',
      'resolution': 'Video Resolution',
      'videoBitrate': 'Video Bitrate',
      'audioBitrate': 'Audio Bitrate',
      'editMetadata': 'Edit Metadata (ID3)',
      'title': 'Title',
      'artist': 'Artist',
      'album': 'Album',

      // Progress
      'progressTitle': 'Conversion Progress',
      'overallProgress': 'Overall Progress: {percent}%',
      'itemsCompleted': '{done} of {total} completed',
      'statusQueued': 'Queued',
      'statusConverting': 'Converting ({percent}%)',
      'statusCompleted': 'Completed',
      'statusFailed': 'Failed',
      'statusCancelled': 'Cancelled',
      'cancelItem': 'Cancel',
      'retryItem': 'Retry',
      'cancelAll': 'Cancel All',
      'openOutputFolder': 'Open Output Folder',
      'conversionCompleteMessage': 'All files in the queue have been processed!',
      'viewResults': 'View Results',
      'startNewProject': 'Start New Project',

      // Cover Editor
      'coverEditorTitle': 'Cover Art Editor',
      'pickMp3File': 'Select MP3 or MP4 File to Edit',
      'pickMp3': 'MP3 File (Audio)',
      'pickMp4': 'MP4 File (Video)',
      'selectMediaTypePrompt': 'Select file type to edit cover and metadata',
      'mp3Description': 'Inspect, replace, or remove embedded cover art and audio ID3 tags',
      'mp4Description': 'Change or remove video poster/cover or capture video frame',
      'captureFrameFromVideo': 'Capture Frame as Cover',
      'currentCover': 'Current Cover Art',
      'noCoverInFile': 'No embedded cover art found in this file',
      'uploadNewCover': 'Choose New Image',
      'removeCover': 'Remove Cover Art',
      'saveChanges': 'Save Changes to File',
      'saving': 'Saving...',
      'fileInfo': 'File Information',
      'duration': 'Duration',
      'fileSize': 'File Size',
      'audioQuality': 'Audio Quality',
      'viewFullImage': 'View Full Image',
      'imageDimensions': '{width} × {height} px ({size})',
      'coverFitContain': 'Contain (No Crop)',
      'coverFitCover': 'Fill Frame (Crop)',
      'downloadCover': 'Download Cover',
      'downloadCoverTooltip': 'Download current cover art',
      'coverDownloaded': 'Cover art downloaded successfully',
      'coverDownloadFailed': 'Failed to download cover art',
      'mp4CoverSaved': 'MP4 cover and metadata updated successfully',
      'switchFile': 'Switch File',

      // Settings
      'settingsTitle': 'General Settings',
      'defaultResolution': 'Default Video Resolution (MP3 ➔ MP4)',
      'defaultVideoBitrate': 'Default Video Bitrate',
      'defaultAudioBitrate': 'Default Audio Bitrate',
      'defaultOutputFolder': 'Default Output Folder',
      'changeFolder': 'Change Folder',
      'notSet': 'Not set (defaults to source directory)',
      'languageAndAppearance': 'Language & Appearance',
      'hardwareAcceleration': 'Hardware Acceleration (GPU & CPU)',
      'hardwareAccelerationDesc': 'Leverage GPU and multi-core CPU for maximum conversion speed',
      'hwAccelAuto': 'Auto (GPU if available)',
      'hwAccelNvenc': 'NVIDIA NVENC (GPU)',
      'hwAccelVaapi': 'VAAPI (Hardware)',
      'hwAccelQsv': 'Intel QSV (Hardware)',
      'hwAccelVideoToolbox': 'Apple VideoToolbox (Hardware)',
      'hwAccelCpuUltrafast': 'CPU Ultrafast',
      'resOriginal': 'Original (No Upscaling)',
      'bitrateAuto': 'Auto (Quality CRF 23)',
      'audioBitrateAuto': 'Auto (Match Source)',
      'gpuActive': 'GPU Acceleration Active',
      'cpuMultithreadActive': 'Multi-core CPU Active',

      // FFmpeg Setup (Desktop)
      'ffmpegSetupTitle': 'FFmpeg Setup Required',
      'ffmpegSetupMessage':
          'Hawwil on desktop relies on a system-installed FFmpeg binary for high-speed, native audio and video encoding.',
      'ffmpegInstallUbuntu': 'To install FFmpeg on Ubuntu/Debian/Mint:',
      'ffmpegInstallFedora': 'To install FFmpeg on Fedora/RHEL:',
      'ffmpegInstallArch': 'To install FFmpeg on Arch/Manjaro:',
      'ffmpegInstallMac': 'To install FFmpeg on macOS (Homebrew):',
      'ffmpegInstallWindows': 'To install FFmpeg on Windows (Winget):',
      'recheckFfmpeg': 'Recheck Installation',
      'ffmpegInstalledSuccess': 'FFmpeg successfully detected! You are ready to go.',

      // Web Notice
      'webNoticeTitle': 'Web Version Notice',
      'webNoticeDesc':
          'You can explore the interface and preview files on the web. For full native conversion and encoding, please run the desktop or mobile application.',

      // Merge Media
      'mergeMediaDesc': 'Arrange images and videos with an audio soundtrack to create a merged video',
      'addMediaFiles': 'Add Media Files',
      'addMediaFilesDesc': 'Select images, videos, or audio clips to add to the project',
      'trackImages': 'Track 1: Images',
      'trackVideos': 'Track 2: Videos',
      'trackAudio': 'Track 3: Audio only',
      'mediaPool': 'Added Media Pool',
      'mediaPoolEmpty': 'No media files added yet. Click "Add Media Files" to begin.',
      'timelineHelp': 'Drag items onto their matching track to snap them into sequence with no gaps',
      'dragHere': 'Drop item here',
      'imageDuration': 'Image Duration',
      'seconds': 'seconds',
      'exportMerge': 'Export & Merge Media',
      'exportingMerge': 'Exporting & merging media...',
      'previewPlayer': 'Merged Media Preview',
      'noVisualItemsWarning': 'Please add at least one media item to the timeline before exporting',
      'clearTimeline': 'Clear Timeline',
      'removeItem': 'Remove',
      'adjustDuration': 'Adjust Image Duration',
      'mergeExportSuccess': 'Media merged and exported successfully!',
      'outputResolution': 'Output Resolution',
      'cancelMerge': 'Cancel Merge',
      'play': 'Play',
      'pause': 'Pause',
      'replay': 'Replay',

      // Developer
      'developer': 'Developer',
      'email': 'Email',
      'website': 'Website',
    }
  };

  String get developer => tr('developer');
  String get email => tr('email');
  String get website => tr('website');

  String tr(String key, [Map<String, String>? params]) {
    final lang = locale.languageCode == 'ar' ? 'ar' : 'en';
    var text = _localizedValues[lang]?[key] ?? _localizedValues['ar']?[key] ?? key;
    if (params != null) {
      params.forEach((paramKey, paramValue) {
        text = text.replaceAll('{$paramKey}', paramValue);
      });
    }
    return text;
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['ar', 'en'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
