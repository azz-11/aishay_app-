import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_locale.dart';
import 'l10n/app_strings.dart';
import 'edit_profile_screen.dart';

const _kDark    = Color(0xFF0F1923);
const _kDark2   = Color(0xFF1A2340);
const _kOrange  = Color(0xFFF26500);
const _kCardBg  = Color(0xFF1E2D45);
const _kTextSec = Color(0xFF94A3B8);

TextStyle _tj(double size, FontWeight weight, Color color) =>
    GoogleFonts.tajawal(fontSize: size, fontWeight: weight, color: color);

class SettingsScreen extends StatefulWidget {
  final Map<String, dynamic>? profile;
  const SettingsScreen({super.key, this.profile});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    AppLocale.notifier.addListener(_onLocaleChange);
    _loadPrefs();
  }

  void _onLocaleChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    AppLocale.notifier.removeListener(_onLocaleChange);
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      });
    }
  }

  Future<void> _toggleNotifications(bool val) async {
    setState(() => _notificationsEnabled = val);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', val);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kDark,
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
              children: [
                // ── الحساب ────────────────────────────────────────────────
                _sectionLabel('الحساب'),
                _tile(
                  icon: PhosphorIcons.pencilSimple(),
                  label: 'تعديل الملف الشخصي',
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EditProfileScreen(
                            profile: widget.profile ?? {}),
                      ),
                    );
                  },
                ),
                _tile(
                  icon: PhosphorIcons.lock(),
                  label: 'تغيير كلمة المرور',
                  onTap: () => _sendPasswordReset(context),
                ),

                const SizedBox(height: 24),

                // ── التفضيلات ─────────────────────────────────────────────
                _sectionLabel('التفضيلات'),
                _toggleTile(
                  icon: PhosphorIcons.translate(),
                  label: AppLocale.isArabic ? 'اللغة: عربي' : 'Language: English',
                  badge: _langBadge(),
                  onTap: () async {
                    await AppLocale.toggle();
                  },
                ),
                _switchTile(
                  icon: PhosphorIcons.bell(),
                  label: 'الإشعارات',
                  value: _notificationsEnabled,
                  onChanged: _toggleNotifications,
                ),

                const SizedBox(height: 24),

                // ── الخصوصية والقانوني ────────────────────────────────────
                _sectionLabel('الخصوصية والقانوني'),
                _tile(
                  icon: PhosphorIcons.shieldCheck(),
                  label: AppStrings.privacy,
                  onTap: () => _showSheet(context, AppStrings.privacy, _privacyText),
                ),
                _tile(
                  icon: PhosphorIcons.fileText(),
                  label: AppStrings.terms,
                  onTap: () => _showSheet(context, AppStrings.terms, _termsText),
                ),

                const SizedBox(height: 36),

                // ── Sign out ───────────────────────────────────────────────
                _signOutButton(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A2A40), _kDark],
        ),
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 14,
        bottom: 16,
        left: 16,
        right: 16,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(PhosphorIcons.caretRight(), color: Colors.white, size: 16),
            ),
          ),
          const SizedBox(width: 12),
          Text(AppStrings.settings, style: _tj(20, FontWeight.w900, Colors.white)),
        ],
      ),
    );
  }

  // ── Section label ──────────────────────────────────────────────────────────

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(text, style: _tj(12, FontWeight.w700, _kTextSec)),
  );

  // ── Tile variants ──────────────────────────────────────────────────────────

  Widget _tile({
    required IconData icon,
    required String label,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: _kCardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: [
            Icon(icon, color: _kOrange, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: _tj(13, FontWeight.w600, Colors.white))),
            trailing ?? Icon(PhosphorIcons.caretRight(),
                color: Colors.white.withValues(alpha: 0.3), size: 18),
          ],
        ),
      ),
    );
  }

  Widget _toggleTile({
    required IconData icon,
    required String label,
    Widget? badge,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: _kCardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: [
            Icon(icon, color: _kOrange, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: _tj(13, FontWeight.w600, Colors.white))),
            if (badge != null) badge,
          ],
        ),
      ),
    );
  }

  Widget _switchTile({
    required IconData icon,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Icon(icon, color: _kOrange, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: _tj(13, FontWeight.w600, Colors.white))),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: _kOrange,
            inactiveThumbColor: _kTextSec,
            inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
          ),
        ],
      ),
    );
  }

  Widget _langBadge() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: _kOrange.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: _kOrange.withValues(alpha: 0.4)),
    ),
    child: Text(
      AppLocale.isArabic ? 'AR' : 'EN',
      style: _tj(11, FontWeight.w800, _kOrange),
    ),
  );

  // ── Sign out ───────────────────────────────────────────────────────────────

  Widget _signOutButton(BuildContext context) => GestureDetector(
    onTap: () => _confirmSignOut(context),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(PhosphorIcons.signOut(), color: Colors.redAccent, size: 18),
          const SizedBox(width: 8),
          Text(AppStrings.logout, style: _tj(14, FontWeight.w800, Colors.redAccent)),
        ],
      ),
    ),
  );

  // ── Privacy / Terms bottom sheet ───────────────────────────────────────────

  void _showSheet(BuildContext context, String title, String content) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _kDark2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.92,
        minChildSize: 0.4,
        builder: (_, scrollCtrl) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: [
                  Text(title, style: _tj(16, FontWeight.w900, Colors.white)),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Divider(color: Colors.white.withValues(alpha: 0.08)),
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
                children: [
                  Text(
                    content,
                    style: GoogleFonts.tajawal(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.8),
                      height: 1.9,
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Password reset ─────────────────────────────────────────────────────────

  Future<void> _sendPasswordReset(BuildContext context) async {
    final email = Supabase.instance.client.auth.currentUser?.email ?? '';
    if (email.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: _kDark2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('تغيير كلمة المرور', style: _tj(15, FontWeight.w900, Colors.white)),
          content: Text(
            'سيتم إرسال رابط إعادة تعيين كلمة المرور إلى:\n$email',
            style: _tj(12, FontWeight.w400, _kTextSec),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('إلغاء', style: _tj(13, FontWeight.w600, _kTextSec)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('إرسال', style: _tj(13, FontWeight.w800, _kOrange)),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(email);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم إرسال رابط الإعادة إلى $email',
                style: GoogleFonts.tajawal()),
            backgroundColor: _kOrange,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e', style: GoogleFonts.tajawal())),
        );
      }
    }
  }

  // ── Sign out ───────────────────────────────────────────────────────────────

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: _kDark2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(AppStrings.logout, style: _tj(16, FontWeight.w900, Colors.white)),
          content: Text('هل أنت متأكد من تسجيل الخروج؟',
              style: _tj(13, FontWeight.w400, _kTextSec)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('إلغاء', style: _tj(13, FontWeight.w600, _kTextSec)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('خروج', style: _tj(13, FontWeight.w800, Colors.redAccent)),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true) {
      await Supabase.instance.client.auth.signOut();
      if (context.mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  // ── Privacy policy text ────────────────────────────────────────────────────

  static const _privacyText = r'''
سياسة الخصوصية
تطبيق «أي شيء»

آخر تحديث: يونيو ٢٠٢٦

━━━━━━━━━━━━━━━━━━━━━━━━━━━━

١. البيانات التي نجمعها

- بيانات الحساب: الاسم، اسم المستخدم، البريد الإلكتروني، الصورة الشخصية.
- بيانات التجارب: الصور، التقييمات، التعليقات، والمطاعم المزارة.
- بيانات الاستخدام: تفاعلاتك داخل التطبيق لتحسين التجربة.
- الموقع الجغرافي: فقط عند طلبك لميزة "حولي الآن" وبإذنك الصريح.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━

٢. كيف نستخدم بياناتك

- تشغيل الخدمة وعرض المحتوى المناسب لك.
- تحسين خوارزميات التوصية (بصورة مجهولة الهوية).
- إرسال الإشعارات المتعلقة بنشاطك في التطبيق.
- ضمان أمان المنصة وحماية المستخدمين.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━

٣. مشاركة البيانات

لا نبيع بياناتك لأطراف ثالثة ولا نشاركها إلا في الحالات التالية:
- مزودو الخدمة التقنية (Supabase للتخزين).
- الالتزامات القانونية بموجب الأنظمة السعودية.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━

٤. حقوقك

- طلب الاطلاع على بياناتك المحفوظة.
- تعديل معلوماتك الشخصية من إعدادات الحساب.
- طلب حذف حسابك وجميع بياناتك نهائياً.
- سحب إذن الوصول للموقع في أي وقت.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━

٥. أمان البيانات

نستخدم بروتوكولات تشفير معيارية لحماية بياناتك. كلمات المرور مشفّرة ولا يمكن لأحد الاطلاع عليها.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━

للتواصل: support@aishay.app

© ٢٠٢٦ أي شيء — جميع الحقوق محفوظة
''';

  // ── Terms of use text ──────────────────────────────────────────────────────

  static const _termsText = r'''
سياسة الاستخدام وشروط الخدمة
تطبيق «أي شيء»

آخر تحديث: يونيو ٢٠٢٦

━━━━━━━━━━━━━━━━━━━━━━━━━━━━

١. مقدمة وقبول الشروط

باستخدامك للتطبيق أو التسجيل فيه، فإنك توافق على الالتزام بهذه الشروط والسياسات كاملةً. إن كنت لا توافق على أي بند، يُرجى عدم استخدام التطبيق.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━

٢. الأهلية والتسجيل

- يُشترط أن يكون عمر المستخدم ١٨ عاماً أو أكثر.
- التسجيل مقيّد برمز دعوة صالح.
- يتعهد المستخدم بتقديم معلومات صحيحة ودقيقة.
- لكل شخص حساب واحد فقط.
- يتحمل المستخدم مسؤولية الحفاظ على سرية كلمة مروره.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━

٣. قواعد المحتوى والسلوك

المحتوى المسموح به:
الصور الحقيقية للمطاعم والأطباق، والتقييمات الصادقة المبنية على تجارب شخصية فعلية، والتعليقات البنّاءة المتعلقة بتجارب الطعام.

المحتوى المحظور:
- الألفاظ النابية أو الإساءة اللفظية بأي شكل.
- المحتوى المهين أو المحرج للأشخاص أو المنشآت.
- التحرش أو التنمر أو الترهيب.
- المحتوى الجنسي أو الإيحائي.
- أي محتوى يتعارض مع أحكام الشريعة الإسلامية والقوانين السعودية.
- التقييمات المزيفة أو المدفوعة.
- نشر معلومات شخصية لأشخاص آخرين دون إذنهم.
- انتهاك حقوق الملكية الفكرية.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━

٤. التقييمات والمصداقية

يلتزم المستخدم بأن تكون تقييماته مبنية على تجارب شخصية حقيقية. يُحظر التنسيق مع أطراف أخرى لرفع أو خفض تقييمات مطاعم معينة. يحق لـ«أي شيء» إزالة أي تقييم يشتبه في كونه مزيفاً.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━

٥. حقوق الملكية الفكرية

جميع حقوق الملكية الفكرية للتطبيق — بما يشمل الاسم «أي شيء»، الشعار، التصميم، والكود البرمجي — محفوظة لفريق «أي شيء». لا يجوز نسخها أو استخدامها دون إذن خطي مسبق.

يحتفظ المستخدم بملكية المحتوى الذي ينشره، ويمنح «أي شيء» ترخيصاً لعرضه داخل المنصة.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━

٦. إنهاء الحساب والمخالفات

تدرّج العقوبات:
١. تحذير — لأول مخالفة غير جسيمة.
٢. إيقاف مؤقت — من ٣ إلى ٣٠ يوماً.
٣. حذف دائم — في حالات المخالفات المتكررة أو الجسيمة.

يحق لـ«أي شيء» إنهاء أي حساب فوراً في حالة انتهاك القوانين السعودية أو محاولة اختراق الأنظمة.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━

٧. إخلاء المسؤولية

«أي شيء» منصة اجتماعية لمشاركة التجارب الشخصية، ولا يضمن التطبيق دقة أي تقييم أو توصية. لا يتحمل التطبيق مسؤولية أي ضرر ناتج عن الاعتماد على المحتوى المنشور.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━

٨. القانون المطبّق

تخضع هذه الشروط لأنظمة المملكة العربية السعودية النافذة.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━

للتواصل والشكاوى: support@aishay.app

© ٢٠٢٦ أي شيء — جميع الحقوق محفوظة
''';
}
