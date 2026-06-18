import 'package:flutter/material.dart';

void main() {
  runApp(const YahalaApp());
}

class YahalaApp extends StatelessWidget {
  const YahalaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'يا هلا',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, fontFamily: 'Arial'),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  bool isArabic = true;
  int currentIndex = 0;

  final green = const Color(0xFF1A6B3C);
  final gold = const Color(0xFFC9952A);
  final dark = const Color(0xFF1A1A1A);
  final bg = const Color(0xFFF7F7F7);

  String t(String ar, String en) => isArabic ? ar : en;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: green,
          centerTitle: true,
          title: Text(
            t('يا هلا', 'Yahala'),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          actions: [
            TextButton(
              onPressed: () => setState(() => isArabic = !isArabic),
              child: Text(
                isArabic ? 'EN' : 'عربي',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        body: currentIndex == 0 ? _home() : _placeholder(),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: (index) => setState(() => currentIndex = index),
          selectedItemColor: green,
          unselectedItemColor: Colors.grey,
          type: BottomNavigationBarType.fixed,
          items: [
            BottomNavigationBarItem(icon: const Icon(Icons.home), label: t('الرئيسية', 'Home')),
            BottomNavigationBarItem(icon: const Icon(Icons.search), label: t('استكشف', 'Explore')),
            BottomNavigationBarItem(icon: const Icon(Icons.add_circle), label: t('أضف', 'Add')),
            BottomNavigationBarItem(icon: const Icon(Icons.forum), label: t('الجالية', 'Community')),
            BottomNavigationBarItem(icon: const Icon(Icons.person), label: t('حسابي', 'Profile')),
          ],
        ),
      ),
    );
  }

  Widget _home() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t('جريدة العرب الرقمية في كاليفورنيا', 'Arab digital newspaper in California'),
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: dark),
          ),
          const SizedBox(height: 14),

          TextField(
            decoration: InputDecoration(
              hintText: t('ابحث عن وظيفة، سكن، خدمة...', 'Search jobs, housing, services...'),
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
            ),
          ),

          const SizedBox(height: 20),
          _mainAd(),
          const SizedBox(height: 22),

          _sectionTitle(t('إعلانات مميزة', 'Featured Ads')),
          const SizedBox(height: 10),
          SizedBox(
            height: 125,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _featuredMini(t('مطعم الشام', 'Al Sham'), t('خصم 20%', '20% off'), Icons.restaurant),
                _featuredMini(t('حفلة عربية', 'Arabic Party'), t('السبت القادم', 'Next Saturday'), Icons.celebration),
                _featuredMini(t('محامي هجرة', 'Immigration Lawyer'), t('استشارة مجانية', 'Free consultation'), Icons.gavel),
                _featuredMini(t('حلويات', 'Sweets'), t('عرض اليوم', 'Today deal'), Icons.cake),
              ],
            ),
          ),

          const SizedBox(height: 22),

          _sectionTitle(t('الأقسام', 'Categories')),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.35,
            children: [
              _categoryButton(Icons.work, t('وظائف', 'Jobs'), () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => JobsScreen(isArabic: isArabic)),
                );
              }),
              _category(Icons.home, t('سكن', 'Housing')),
              _category(Icons.handyman, t('خدمات', 'Services')),
              _category(Icons.local_offer, t('كوبونات', 'Coupons')),
              _category(Icons.forum, t('اسأل الجالية', 'Ask Community')),
              _category(Icons.add_circle, t('أضف إعلان', 'Add Post')),
            ],
          ),

          const SizedBox(height: 24),

          _sectionTitle(t('آخر الإعلانات', 'Latest Ads')),
          const SizedBox(height: 10),
          _latest(t('مطلوب موظف في مطعم', 'Restaurant worker needed'), t('لوس أنجلوس', 'Los Angeles')),
          _latest(t('غرفة للإيجار', 'Room for rent'), t('أنهايم', 'Anaheim')),
          _latest(t('كهربائي عربي متوفر', 'Arabic electrician available'), t('سان دييغو', 'San Diego')),
        ],
      ),
    );
  }

  Widget _mainAd() {
    return Container(
      width: double.infinity,
      height: 180,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(color: green, borderRadius: BorderRadius.circular(26)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.campaign, color: gold, size: 40),
          const Spacer(),
          Text(t('إعلان الصفحة الرئيسية', 'Home Page Ad'), style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 6),
          Text(
            t('مطعم عربي جديد في كاليفورنيا', 'New Arabic restaurant in California'),
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _featuredMini(String title, String subtitle, IconData icon) {
    return Container(
      width: 190,
      margin: const EdgeInsetsDirectional.only(end: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: green, size: 30),
          const Spacer(),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(color: gold, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _categoryButton(IconData icon, String title, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: _category(icon, title),
    );
  }

  Widget _category(IconData icon, String title) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: green, size: 34),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _latest(String title, String city) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
      child: Row(
        children: [
          Icon(Icons.article, color: green),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold))),
          Text(city, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: dark));
  }

  Widget _placeholder() {
    return Center(
      child: Text(
        t('قريباً', 'Coming soon'),
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class JobsScreen extends StatelessWidget {
  final bool isArabic;

  const JobsScreen({super.key, required this.isArabic});

  final Color green = const Color(0xFF1A6B3C);
  final Color gold = const Color(0xFFC9952A);
  final Color bg = const Color(0xFFF7F7F7);

  String t(String ar, String en) => isArabic ? ar : en;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: green,
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.white),
          title: Text(
            t('وظائف', 'Jobs'),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                decoration: InputDecoration(
                  hintText: t('ابحث عن وظيفة...', 'Search for a job...'),
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: gold,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {},
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: Text(
                    t('أضف وظيفة', 'Add Job'),
                    style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              _sectionTitle(t('وظائف مميزة', 'Featured Jobs')),
              const SizedBox(height: 12),

              _jobCard(
                title: t('مطلوب نادل في مطعم عربي', 'Waiter needed at Arabic restaurant'),
                company: t('مطعم الشام', 'Al Sham Restaurant'),
                city: 'Anaheim',
                salary: '\$20 / ${t('ساعة', 'hour')}',
                featured: true,
              ),

              const SizedBox(height: 18),

              _sectionTitle(t('آخر الوظائف', 'Latest Jobs')),
              const SizedBox(height: 12),

              _jobCard(
                title: t('مطلوب سائق توصيل', 'Delivery driver needed'),
                company: t('شركة توصيل', 'Delivery Company'),
                city: 'Los Angeles',
                salary: '\$18 / ${t('ساعة', 'hour')}',
              ),
              _jobCard(
                title: t('كاشير دوام كامل', 'Full-time cashier'),
                company: t('ماركت عربي', 'Arabic Market'),
                city: 'Irvine',
                salary: '\$19 / ${t('ساعة', 'hour')}',
              ),
              _jobCard(
                title: t('مساعد مطبخ', 'Kitchen assistant'),
                company: t('مطعم عائلي', 'Family Restaurant'),
                city: 'San Diego',
                salary: '\$17 / ${t('ساعة', 'hour')}',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold));
  }

  Widget _jobCard({
    required String title,
    required String company,
    required String city,
    required String salary,
    bool featured = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: featured ? const Color(0xFFFFF7E6) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: featured ? Border.all(color: gold, width: 1.2) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (featured)
            Text(
              isArabic ? '⭐ وظيفة مميزة' : '⭐ Featured Job',
              style: TextStyle(color: gold, fontWeight: FontWeight.bold),
            ),
          if (featured) const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(company, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.location_on, size: 18, color: Colors.grey),
              const SizedBox(width: 4),
              Text(city),
              const Spacer(),
              Text(salary, style: TextStyle(color: green, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}