import '../app_locale.dart';

/// Centralized UI string catalog for AR/EN.
///
/// Single source of truth for the active language is [AppLocale] (a
/// ValueNotifier wired into MaterialApp in main.dart). `AppStrings.isArabic`
/// mirrors it, so toggling the language anywhere (home top-bar or settings via
/// `AppLocale.toggle()`) updates every getter here and rebuilds the app.
///
/// RULES: translate UI labels / buttons / headers / section titles only.
/// NEVER translate user data (restaurant names, comments, descriptions,
/// usernames) — those are passed through from the database as the user typed.
class AppStrings {
  AppStrings._();

  /// Mirrors the app-wide language flag. Do not assign — toggle via
  /// `AppLocale.toggle()` so persistence + rebuilds stay consistent.
  static bool get isArabic => AppLocale.isArabic;

  // Bottom Navigation
  static String get home => isArabic ? 'الرئيسية' : 'Home';
  static String get explore => isArabic ? 'استكشاف' : 'Explore';
  static String get notifications => isArabic ? 'إشعارات' : 'Notifications';
  static String get profile => isArabic ? 'حسابي' : 'Profile';

  // Home Screen
  static String get latestExperiences => isArabic ? 'أحدث التجارب' : 'Latest Experiences';
  static String get seeAll => isArabic ? 'شاهد الكل' : 'See All';
  static String get worthIt => isArabic ? 'يستاهل' : 'Worth It';
  static String get wantToVisit => isArabic ? 'أود زيارته' : 'Want to Visit';
  static String get comment => isArabic ? 'تعليق' : 'Comment';
  static String get moodToday => isArabic ? 'حسب جوّك اليوم' : 'Your Mood Today';
  static String get searchHint => isArabic ? 'ابحث عن مطعم، تجربة، شخص...' : 'Search restaurants, experiences, people...';

  // Experience Detail
  static String get aboutExperience => isArabic ? 'عن التجربة' : 'About Experience';
  static String get atmosphere => isArabic ? 'أجواء المكان' : 'Atmosphere';
  static String get detailedRatings => isArabic ? 'التقييمات التفصيلية' : 'Detailed Ratings';
  static String get orderedDishes => isArabic ? 'الأطباق المطلوبة' : 'Ordered Dishes';
  static String get openInMap => isArabic ? 'افتح في الخريطة' : 'Open in Map';
  static String get share => isArabic ? 'مشاركة' : 'Share';
  static String get food => isArabic ? 'الطعام' : 'Food';
  static String get service => isArabic ? 'الخدمة' : 'Service';
  static String get ambiance => isArabic ? 'الأجواء' : 'Ambiance';
  static String get cleanliness => isArabic ? 'النظافة' : 'Cleanliness';
  static String get value => isArabic ? 'القيمة' : 'Value';

  // Profile Screen
  static String get myProfile => isArabic ? 'حسابي' : 'My Profile';
  static String get editProfile => isArabic ? 'تعديل الملف الشخصي' : 'Edit Profile';
  static String get myExperiences => isArabic ? 'تجاربي' : 'My Experiences';
  static String get saved => isArabic ? 'أود زيارته' : 'Saved';
  static String get statistics => isArabic ? 'إحصائيات' : 'Statistics';
  static String get followers => isArabic ? 'يتطلعون لتجاربي' : 'Followers';
  static String get following => isArabic ? 'أتطلع لتجاربهم' : 'Following';
  static String get experiences => isArabic ? 'تجربة' : 'Experiences';
  static String get restaurants => isArabic ? 'مطعم' : 'Restaurants';
  static String get cities => isArabic ? 'مدينة' : 'Cities';

  // Add Experience
  static String get addExperience => isArabic ? 'أضف تجربة' : 'Add Experience';
  static String get restaurantName => isArabic ? 'اسم المطعم' : 'Restaurant Name';
  static String get experienceTitle => isArabic ? 'عنوان التجربة' : 'Experience Title';
  static String get visitTime => isArabic ? 'وقت التجربة' : 'Visit Time';
  static String get description => isArabic ? 'وصف التجربة' : 'Experience Description';
  static String get ratings => isArabic ? 'التقييمات' : 'Ratings';
  static String get dishes => isArabic ? 'الأطباق' : 'Dishes';
  static String get publishExperience => isArabic ? 'نشر التجربة' : 'Publish Experience';
  static String get next => isArabic ? 'التالي ←' : 'Next →';

  // Visit Time options
  static String get morning => isArabic ? 'صباحاً' : 'Morning';
  static String get noon => isArabic ? 'ظهراً' : 'Noon';
  static String get afternoon => isArabic ? 'عصراً' : 'Afternoon';
  static String get evening => isArabic ? 'مساءً' : 'Evening';
  static String get night => isArabic ? 'ليلاً' : 'Night';

  // Search Screen
  static String get exploreRestaurants => isArabic ? 'اكتشف الأماكن من خلال التجارب' : 'Discover Places Through Experiences';
  static String get experiencesTab => isArabic ? 'التجارب' : 'Experiences';
  static String get restaurantsTab => isArabic ? 'المطاعم' : 'Restaurants';
  static String get peopleTab => isArabic ? 'الأشخاص' : 'People';
  static String get noResults => isArabic ? 'لا توجد نتائج' : 'No Results';

  // Settings
  static String get settings => isArabic ? 'الإعدادات' : 'Settings';
  static String get language => isArabic ? 'اللغة' : 'Language';
  static String get logout => isArabic ? 'تسجيل الخروج' : 'Logout';
  static String get privacy => isArabic ? 'الخصوصية' : 'Privacy';
  static String get terms => isArabic ? 'شروط الاستخدام' : 'Terms of Use';

  // Notifications
  static String get noNotifications => isArabic ? 'لا توجد إشعارات بعد' : 'No notifications yet';
  static String get likedExperience => isArabic ? 'أعجب بتجربتك' : 'liked your experience';
  static String get savedExperience => isArabic ? 'حفظ تجربتك' : 'saved your experience';
  static String get startedFollowing => isArabic ? 'بدأ بمتابعتك' : 'started following you';
  static String get commentedOn => isArabic ? 'علّق على تجربتك' : 'commented on your experience';

  // Auth
  static String get login => isArabic ? 'تسجيل الدخول' : 'Login';
  static String get register => isArabic ? 'إنشاء حساب' : 'Register';
  static String get email => isArabic ? 'البريد الإلكتروني' : 'Email';
  static String get password => isArabic ? 'كلمة المرور' : 'Password';
  static String get displayName => isArabic ? 'الاسم الظاهر' : 'Display Name';
  static String get username => isArabic ? 'اسم المستخدم' : 'Username';
  static String get inviteCode => isArabic ? 'رمز الدعوة' : 'Invite Code';

  // ── Common actions / words ──────────────────────────────────────────────
  static String get cancel => isArabic ? 'إلغاء' : 'Cancel';
  static String get delete => isArabic ? 'حذف' : 'Delete';
  static String get save => isArabic ? 'حفظ' : 'Save';
  static String get saveChanges => isArabic ? 'حفظ التغييرات' : 'Save Changes';
  static String get refresh => isArabic ? 'تحديث' : 'Refresh';
  static String get error => isArabic ? 'خطأ' : 'Error';
  static String get linkCopied => isArabic ? 'تم نسخ الرابط' : 'Link copied';
  static String get location => isArabic ? 'الموقع' : 'Location';
  static String get sar => isArabic ? 'ر.س' : 'SAR';
  static String get chooseCity => isArabic ? 'اختر المدينة' : 'Choose City';
  static String get by => isArabic ? 'بواسطة' : 'By';

  // ── Time-ago (relative timestamps) ──────────────────────────────────────
  static String get justNow => isArabic ? 'الآن' : 'now';
  static String minutesAgo(int n) => isArabic ? 'منذ $n دقيقة' : '${n}m ago';
  static String hoursAgo(int n) => isArabic ? 'منذ $n ساعة' : '${n}h ago';
  static String daysAgo(int n) => isArabic ? 'منذ $n يوم' : '${n}d ago';

  // ── Experience detail ───────────────────────────────────────────────────
  static String get deleteExperience => isArabic ? 'حذف التجربة' : 'Delete Experience';
  static String get editExperience => isArabic ? 'تعديل التجربة' : 'Edit Experience';
  static String get deleteExperienceQ => isArabic ? 'حذف التجربة؟' : 'Delete experience?';
  static String get deleteConfirm => isArabic
      ? 'لا يمكن التراجع عن هذا الإجراء'
      : 'This action cannot be undone.';
  static String get deleteFailed => isArabic ? 'فشل الحذف' : 'Failed to delete';
  static String get cantOpenMap => isArabic ? 'لا يمكن فتح الخريطة' : 'Cannot open the map';

  // ── Search ──────────────────────────────────────────────────────────────
  static String get searchSubtitle => isArabic ? 'ابحث عن تجارب وأشخاص ومطاعم' : 'Search experiences, people and restaurants';
  static String get searchError => isArabic ? 'خطأ في البحث' : 'Search error';
  static String get noContentYet => isArabic ? 'لا يوجد محتوى بعد' : 'No content yet';
  static String get tryDifferentSearch => isArabic ? 'جرب كلمات بحث مختلفة' : 'Try different search terms';
  static String get viewExperiences => isArabic ? 'عرض التجارب' : 'View Experiences';
  static String get followAction => isArabic ? '+ متابعة' : '+ Follow';
  static String get followingState => isArabic ? 'تتابعه' : 'Following';

  // ── Notifications ───────────────────────────────────────────────────────
  static String get notificationsTitle => isArabic ? 'الإشعارات' : 'Notifications';
  static String get notificationsHint => isArabic
      ? 'ستظهر هنا إشعاراتك عندما يتفاعل الآخرون مع تجاربك'
      : 'Your notifications will appear here when others interact with your experiences';
  static String get loadNotificationsFailed => isArabic ? 'فشل تحميل الإشعارات' : 'Failed to load notifications';
  static String get cantOpenExperience => isArabic ? 'تعذّر فتح التجربة' : 'Could not open the experience';

  // ── Add experience ──────────────────────────────────────────────────────
  static String get enterRestaurantName => isArabic ? 'أدخل اسم المطعم' : 'Enter the restaurant name';
  static String get enterTitle => isArabic ? 'أدخل عنوان التجربة' : 'Enter the experience title';
  static String get enterDescription => isArabic ? 'أدخل وصف التجربة' : 'Enter the experience description';
  static String titleTooLong(int max) => isArabic ? 'العنوان يجب ألا يتجاوز $max حرفاً' : 'Title must not exceed $max characters';
  static String descTooLong(int max) => isArabic ? 'الوصف يجب ألا يتجاوز $max حرف' : 'Description must not exceed $max characters';
  static String wordsCount(int n) => isArabic ? '$n/6 كلمات' : '$n/6 words';
  static String get titleMaxWords => isArabic ? 'العنوان يجب أن لا يتجاوز 6 كلمات' : 'Title must not exceed 6 words';
  static String get inappropriateContent => isArabic ? 'المحتوى لا يتوافق مع معايير المجتمع' : 'Content does not meet community standards';
  static String get published => isArabic ? 'تم النشر 🎉' : 'Published 🎉';
  static String get stepPhotosRestaurant => isArabic ? 'الصور والمطعم' : 'Photos & Restaurant';
  static String get stepAtmospherePrice => isArabic ? 'الأجواء والسعر' : 'Atmosphere & Price';
  static String get stepDishesDescription => isArabic ? 'الأطباق والوصف' : 'Dishes & Description';
  static String get camera => isArabic ? 'الكاميرا' : 'Camera';
  static String get gallery => isArabic ? 'معرض الصور' : 'Gallery';
  static String get photos => isArabic ? 'الصور' : 'Photos';
  static String get addPhoto => isArabic ? 'أضف صورة' : 'Add Photo';
  static String get restaurantLinked => isArabic ? 'تم ربط المطعم ✓' : 'Restaurant linked ✓';
  static String get searchOrEnterRestaurant => isArabic ? 'ابحث أو أدخل اسم المطعم' : 'Search or enter the restaurant name';
  static String get restaurantCategory => isArabic ? 'تصنيف المطعم' : 'Restaurant Category';
  static String get otherCategory => isArabic ? 'تصنيف آخر' : 'Other Category';
  static String get writeCategory => isArabic ? 'اكتب التصنيف...' : 'Type the category...';
  static String get overallRating => isArabic ? 'التقييم الكلي' : 'Overall Rating';
  static String get additionalDetails => isArabic ? 'تفاصيل إضافية' : 'Additional Details';
  static String get costPerPerson => isArabic ? 'التكلفة للفرد' : 'Cost per Person';
  static String get dishName => isArabic ? 'اسم الطبق' : 'Dish name';
  static String get price => isArabic ? 'السعر' : 'Price';
  static String get uploadingImage => isArabic ? 'جاري رفع الصورة...' : 'Uploading image...';
  static String get imageUploaded => isArabic ? 'تم رفع الصورة ✓' : 'Image uploaded ✓';
  static String get addDishPhotoOptional => isArabic ? 'أضف صورة للطبق (اختياري)' : 'Add dish photo (optional)';
  static String get titleHintExample => isArabic ? 'جلسة رائعة بعد المغرب، الهدوء شي مختلف...' : 'A great evening session, the calm was something else...';
  static String get descHint => isArabic ? 'شاركنا تجربتك... كيف كان الطعام؟ الخدمة؟ الأجواء؟' : 'Share your experience... How was the food? Service? Atmosphere?';
  static String get publishExperienceCta => isArabic ? '🔥 نشر التجربة' : '🔥 Publish Experience';
  static String get experienceShared => isArabic ? 'تجربتك انتشرت!' : 'Your experience is live!';
  static String get thanksMessage => isArabic ? 'شكراً — تجربتك ستساعد أصدقاءك يختارون صح 🔥' : 'Thanks — your experience will help your friends choose right 🔥';
  static String get backToFeed => isArabic ? 'العودة للفيد' : 'Back to Feed';

  // ── Edit profile ────────────────────────────────────────────────────────
  static String get nameRequired => isArabic ? 'الاسم مطلوب' : 'Name is required';
  static String get saveFailed => isArabic ? 'فشل الحفظ' : 'Failed to save';
  static String get tapToChangePhoto => isArabic ? 'اضغط لتغيير الصورة' : 'Tap to change photo';
  static String get name => isArabic ? 'الاسم' : 'Name';
  static String get city => isArabic ? 'المدينة' : 'City';
  static String get bio => isArabic ? 'النبذة الشخصية' : 'Bio';
  static String get cityHintExample => isArabic ? 'مثال: الرياض' : 'e.g. Riyadh';
  static String get bioHint => isArabic ? 'أخبر الناس عن نفسك...' : 'Tell people about yourself...';

  // ── Visit time: canonical Arabic values are STORED in the DB; display is
  //    localized. Never store the localized label — keep data consistent.
  static const List<String> visitTimeOptions = ['صباحاً', 'ظهراً', 'عصراً', 'مساءً', 'ليلاً'];

  /// Maps a stored (canonical Arabic) visit_time to the active language label.
  static String localizeVisitTime(String? time) {
    if (time == null || time.isEmpty) return '';
    if (isArabic) return time;
    switch (time) {
      case 'صباحاً': return morning;
      case 'ظهراً': return noon;
      case 'عصراً': return afternoon;
      case 'مساءً': return evening;
      case 'ليلاً': return night;
      default: return time; // unknown / free-text value: leave as-is
    }
  }
}
