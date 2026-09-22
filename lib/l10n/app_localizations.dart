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
      'screenCoverEditor': 'محرر غلاف MP3',
      'screenSettings': 'الإعدادات',
      'screenFfmpegSetup': 'تثبيت أداة FFmpeg',

      // Splash / About
      'aboutTitle': 'مرحباً بك في حوّل',
      'aboutFeature1': 'تحويل MP3 إلى MP4 مع اعتماد صورة الغلاف كإطار مرئي كامل.',
      'aboutFeature2': 'استخراج الصوت من MP4 إلى MP3 مع تضمين إطار الفيديو كغلاف.',
      'aboutFeature3': 'محرر مخصص لصور أغلفة MP3 والبيانات الوصفية دون الحاجة لتحويل.',
      'aboutFeature4': 'دعم المعالجة والتحويل المجمّع (Batch Conversion) بسرعة عالية.',
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
      'homeCoverEditorTitle': 'محرر أغلفة MP3',
      'homeCoverEditorSub': 'عرض واستبدال أو إزالة صورة الغلاف وتعديل الوسوم مباشرة',
      'homeSettingsTitle': 'الإعدادات',
      'homeSettingsSub': 'تخصيص الدقة، معدل البت، مجلد الحفظ، المظهر واللغة',
      'quickStatus': 'حالة النظام',
      'ffmpegReady': 'أداة FFmpeg جاهزة للعمل',
      'ffmpegMissing': 'أداة FFmpeg غير متوفرة بالنظام',

      // Create Project
      'pickFiles': 'إضافة ملفات',
      'pickFilesDesc': 'اختر ملفات MP3 أو MP4 لإضافتها لقائمة التحويل',
      'dropFilesHere': 'أفلت الملفات هنا أو اضغط للاختيار',
      'noFilesSelected': 'لم يتم اختيار أي ملفات بعد',
      'fileQueueCount': 'عدد الملفات في القائمة: {count}',
      'direction': 'اتجاه التحويل',
      'mp3ToMp4': 'MP3 ➔ MP4 (صوت إلى فيديو)',
      'mp4ToMp3': 'MP4 ➔ MP3 (فيديو إلى صوت)',
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
      'coverEditorTitle': 'محرر أغلفة وتفاصيل MP3',
      'pickMp3File': 'اختر ملف MP3 للتعديل',
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

      // Settings
      'settingsTitle': 'الإعدادات العامة',
      'defaultResolution': 'الدقة الافتراضية للفيديو (MP3 ➔ MP4)',
      'defaultVideoBitrate': 'معدل بت الفيديو الافتراضي',
      'defaultAudioBitrate': 'معدل بت الصوت الافتراضي',
      'defaultOutputFolder': 'مجلد الحفظ الافتراضي',
      'changeFolder': 'تغيير المجلد',
      'notSet': 'غير محدد (المجلد الافتراضي)',
      'languageAndAppearance': 'اللغة والمظهر',

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
      'screenCoverEditor': 'MP3 Cover Art Editor',
      'screenSettings': 'Settings',
      'screenFfmpegSetup': 'FFmpeg Setup',

      // Splash / About
      'aboutTitle': 'Welcome to Hawwil',
      'aboutFeature1': 'Convert MP3 to MP4 using embedded cover art as a full-frame static video.',
      'aboutFeature2': 'Extract MP4 audio to MP3 and optionally embed video frames as cover art.',
      'aboutFeature3': 'Standalone MP3 Cover Art Editor: view, replace, or remove cover art without conversion.',
      'aboutFeature4': 'High-performance batch processing with real-time queue and progress tracking.',
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
      'homeCoverEditorSub': 'Inspect, replace, or remove cover art and edit MP3 tags in-place',
      'homeSettingsTitle': 'Settings',
      'homeSettingsSub': 'Configure resolution, bitrates, default folder, language, and theme',
      'quickStatus': 'System Status',
      'ffmpegReady': 'FFmpeg is ready and operational',
      'ffmpegMissing': 'FFmpeg binary not detected on system',

      // Create Project
      'pickFiles': 'Add Files',
      'pickFilesDesc': 'Select MP3 or MP4 files to add to the conversion queue',
      'dropFilesHere': 'Drag & drop files here or click to browse',
      'noFilesSelected': 'No files added to the queue yet',
      'fileQueueCount': 'Files in queue: {count}',
      'direction': 'Conversion Direction',
      'mp3ToMp4': 'MP3 ➔ MP4 (Audio to Video)',
      'mp4ToMp3': 'MP4 ➔ MP3 (Video to Audio)',
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
      'coverEditorTitle': 'MP3 Cover Art & Tag Editor',
      'pickMp3File': 'Pick MP3 File to Edit',
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

      // Settings
      'settingsTitle': 'General Settings',
      'defaultResolution': 'Default Video Resolution (MP3 ➔ MP4)',
      'defaultVideoBitrate': 'Default Video Bitrate',
      'defaultAudioBitrate': 'Default Audio Bitrate',
      'defaultOutputFolder': 'Default Output Folder',
      'changeFolder': 'Change Folder',
      'notSet': 'Not set (defaults to source directory)',
      'languageAndAppearance': 'Language & Appearance',

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
    }
  };

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
