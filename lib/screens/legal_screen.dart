import 'package:flutter/material.dart';

import '../constants.dart';

class LegalScreen extends StatelessWidget {
  final bool isArabic;
  final bool isDark;
  final int initialTab;

  const LegalScreen({
    super.key,
    required this.isArabic,
    required this.isDark,
    this.initialTab = 0,
  });

  String t(String ar, String en) => isArabic ? ar : en;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: DefaultTabController(
        length: 2,
        initialIndex: initialTab > 1 ? 1 : initialTab,
        child: Scaffold(
          backgroundColor: yahalaPageBg(isDark),
          appBar: AppBar(
            backgroundColor: yahalaGreen,
            foregroundColor: Colors.white,
            centerTitle: true,
            title: Text(
              t('الشروط والخصوصية', 'Terms & Privacy'),
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            bottom: TabBar(
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: yahalaGold,
              tabs: [
                Tab(text: t('الشروط', 'Terms')),
                Tab(text: t('الخصوصية', 'Privacy')),
              ],
            ),
          ),
          body: TabBarView(
            children: [_page(_termsSections()), _page(_privacySections())],
          ),
        ),
      ),
    );
  }

  Widget _page(List<_LegalSection> sections) {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Text(
          t('آخر تحديث: 18 يونيو 2026', 'Last updated: June 18, 2026'),
          style: TextStyle(
            color: yahalaMutedText(isDark),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        ...sections.map(_sectionCard),
      ],
    );
  }

  Widget _sectionCard(_LegalSection section) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: yahalaCardBg(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.title,
            style: TextStyle(
              color: yahalaText(isDark),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          ...section.items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 7),
                    child: Icon(Icons.circle, size: 6, color: yahalaGold),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(
                        color: yahalaMutedText(isDark),
                        height: 1.55,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<_LegalSection> _termsSections() {
    return [
      _LegalSection(t('قبول الشروط', 'Accepting the Terms'), [
        t(
          'باستخدام تطبيق يا هلا، أنت توافق على هذه الشروط وسياسة الخصوصية وأي تحديثات مستقبلية يتم نشرها داخل التطبيق.',
          'By using Yahala, you agree to these Terms, the Privacy Policy, and future updates shown in the app.',
        ),
        t(
          'إذا كنت تستخدم التطبيق لجهة أو محل أو نشاط تجاري، فأنت تؤكد أنك مخوّل بنشر المعلومات والعروض عنه.',
          'If you use the app for a business or organization, you confirm that you are authorized to publish its information and offers.',
        ),
      ]),
      _LegalSection(t('الإعلانات والمحتوى', 'Ads and Content'), [
        t(
          'المستخدم مسؤول عن صحة الإعلان والصور والأسعار والعنوان وطرق التواصل، وعن الالتزام بالقوانين المحلية والولائية والفدرالية.',
          'Users are responsible for the accuracy of ads, photos, prices, address, contact methods, and compliance with local, state, and federal laws.',
        ),
        t(
          'يا هلا يحق لها مراجعة أو رفض أو حذف أي إعلان أو سؤال أو تعليق، خصوصاً المحتوى المضلل أو المخالف أو المسيء أو الاحتيالي.',
          'Yahala may review, reject, or remove any ad, question, or comment, especially misleading, illegal, abusive, or fraudulent content.',
        ),
        t(
          'الإعلانات المدفوعة أو VIP أو المميزة تعني أولوية ظهور فقط، ولا تعني أن يا هلا تضمن صاحب الإعلان أو الخدمة أو المنتج.',
          'Paid, VIP, or featured placement means visibility priority only. It does not mean Yahala endorses or guarantees the advertiser, service, or product.',
        ),
      ]),
      _LegalSection(t('المعاملات والكوبونات', 'Transactions and Coupons'), [
        t(
          'يا هلا ليست طرفاً في البيع أو الشراء أو التوظيف أو السكن أو الخدمات أو الاتفاقات التي تتم بين المستخدمين.',
          'Yahala is not a party to sales, purchases, jobs, housing, services, or agreements between users.',
        ),
        t(
          'الكوبونات والعروض مسؤولية صاحب العرض، وقد تخضع لمدة أو كمية أو شروط استخدام. تحقق من التفاصيل قبل الشراء أو الاستخدام.',
          'Coupons and offers are the merchant’s responsibility and may have limits, expiration dates, or conditions. Review details before purchase or use.',
        ),
      ]),
      _LegalSection(t('الاستخدام الممنوع', 'Prohibited Use'), [
        t(
          'يُمنع نشر محتوى غير قانوني، احتيالي، تمييزي، مسيء، جنسي، عنيف، مخالف للحقوق، أو يحتوي معلومات شخصية حساسة للغير.',
          'Illegal, fraudulent, discriminatory, abusive, sexual, violent, rights-infringing, or sensitive personal content is prohibited.',
        ),
        t(
          'يُمنع استخدام الشات أو التعليقات للإزعاج، التهديد، السبام، أو محاولة الاحتيال.',
          'Chats and comments may not be used for harassment, threats, spam, or scams.',
        ),
      ]),
      _LegalSection(t('إخلاء المسؤولية', 'Disclaimer'), [
        t(
          'نقدم التطبيق كما هو ونسعى للحماية والمراجعة، لكن لا نضمن عدم وجود أخطاء أو انقطاع أو محتوى غير صحيح من المستخدمين.',
          'The app is provided as is. We work on safety and review, but do not guarantee error-free service or that all user content is accurate.',
        ),
        t(
          'إلى الحد المسموح قانوناً، لا تتحمل يا هلا مسؤولية الخسائر الناتجة عن تعاملات المستخدمين أو اعتمادهم على الإعلانات.',
          'To the extent allowed by law, Yahala is not responsible for losses from user transactions or reliance on ads.',
        ),
      ]),
    ];
  }

  List<_LegalSection> _privacySections() {
    return [
      _LegalSection(t('المعلومات التي نجمعها', 'Information We Collect'), [
        t(
          'قد نجمع معلومات الحساب مثل الاسم، البريد، رقم الهاتف، الصورة الشخصية، طريقة الدخول، ورمز الإشعارات.',
          'We may collect account data such as name, email, phone, profile photo, sign-in provider, and notification token.',
        ),
        t(
          'نجمع محتوى الإعلانات والأسئلة والكوبونات والصور والمدن والعناوين وطرق التواصل التي تختار نشرها.',
          'We collect ads, questions, coupons, photos, cities, addresses, and contact methods you choose to publish.',
        ),
        t(
          'قد نخزن المحادثات والتعليقات والإعجابات والمفضلة والمشاهدات لتشغيل التطبيق وتحسينه وحماية المستخدمين.',
          'We may store chats, comments, likes, favorites, and views to operate and improve the app and protect users.',
        ),
      ]),
      _LegalSection(t('كيف نستخدم المعلومات', 'How We Use Information'), [
        t(
          'نستخدم البيانات لتشغيل الحسابات، نشر الإعلانات، المراجعة، الإشعارات، الشات، الدعم، الأمان، والإحصائيات.',
          'We use data for accounts, publishing ads, moderation, notifications, chat, support, safety, and analytics.',
        ),
        t(
          'لا نبيع بياناتك الشخصية. بعض معلومات الإعلان العامة تظهر للمستخدمين لأنها جزء من الإعلان.',
          'We do not sell your personal data. Some public ad information is visible to users because it is part of the listing.',
        ),
      ]),
      _LegalSection(t('الخدمات الخارجية', 'Third-Party Services'), [
        t(
          'يعتمد التطبيق على خدمات مثل Firebase وGoogle وApple والتخزين السحابي والإشعارات، وقد تعالج هذه الخدمات البيانات حسب سياساتها.',
          'The app uses services such as Firebase, Google, Apple, cloud storage, and notifications, which may process data under their own policies.',
        ),
        t(
          'عند الضغط على اتصال أو SMS، يتم فتح تطبيقات الهاتف أو الرسائل في جهازك.',
          'When you tap call or SMS, your device phone or messaging apps are opened.',
        ),
      ]),
      _LegalSection(t('الأمان والاحتفاظ', 'Security and Retention'), [
        t(
          'نستخدم وسائل حماية معقولة، لكن لا يوجد نظام آمن 100%. لا ترسل معلومات حساسة في الإعلانات أو الشات.',
          'We use reasonable safeguards, but no system is 100% secure. Do not send sensitive information in ads or chats.',
        ),
        t(
          'نحتفظ بالبيانات طالما نحتاجها لتشغيل التطبيق أو الأمان أو الالتزام القانوني، ويمكنك طلب حذف حسابك من صفحة حسابي.',
          'We retain data as needed for the app, safety, or legal reasons. You may request account deletion from your profile.',
        ),
      ]),
      _LegalSection(t('حقوقك والتواصل', 'Your Rights and Contact'), [
        t(
          'يمكنك طلب الوصول إلى بياناتك أو تصحيحها أو حذفها حسب القوانين المطبقة.',
          'You may request access, correction, or deletion of your data where applicable by law.',
        ),
        t('للدعم: support@yahalaus.com', 'For support: support@yahalaus.com'),
      ]),
    ];
  }
}

class _LegalSection {
  final String title;
  final List<String> items;

  const _LegalSection(this.title, this.items);
}
