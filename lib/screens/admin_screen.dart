import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'ad_details_screen.dart';
import 'add_post_screen.dart';
import 'question_details_screen.dart';
import '../utils/ad_promotion.dart';
import '../utils/category_subtype_suggestions.dart';
import '../utils/category_subtypes.dart';
import '../utils/service_category_suggestions.dart';
import '../utils/value_formatters.dart';

const Color yaHalaGreen = Color(0xFF1a6b3c);
const Color yaHalaGold = Color(0xFFc9952a);
const Color bgDark = Color(0xFF0e1621);
const Color cardColor = Color(0xFF1c2b3a);

enum _ReviewFilter { vip, featured, categoryTop, free }

class AdminScreen extends StatefulWidget {
  final bool isArabic;
  final bool isDark;

  const AdminScreen({super.key, required this.isArabic, required this.isDark});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with SingleTickerProviderStateMixin {
  late final TabController tabController;

  String t(String ar, String en) => widget.isArabic ? ar : en;

  @override
  void initState() {
    super.initState();
    tabController = TabController(length: 12, vsync: this);
  }

  @override
  void dispose() {
    tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: widget.isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: widget.isDark ? bgDark : const Color(0xFFF7F8F6),
        appBar: AppBar(
          backgroundColor: yaHalaGreen,
          foregroundColor: Colors.white,
          iconTheme: const IconThemeData(color: Colors.white),
          elevation: 0,
          centerTitle: true,
          title: Text(
            t('لوحة إدارة يا هلا', 'Yahala Admin'),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          actions: [
            IconButton(
              tooltip: t('إضافة إعلان', 'Add ad'),
              onPressed: _showAddAdDialog,
              icon: const Icon(Icons.add_business, color: Colors.white),
            ),
            IconButton(
              tooltip: t('إضافة إعلان VIP', 'Add VIP ad'),
              onPressed: _openVipAdForm,
              icon: const Icon(Icons.workspace_premium, color: Colors.white),
            ),
            IconButton(
              tooltip: t('إضافة أدمن', 'Add admin'),
              onPressed: _showAddAdminDialog,
              icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
            ),
            IconButton(
              tooltip: t('تسجيل الخروج', 'Sign out'),
              onPressed: () => FirebaseAuth.instance.signOut(),
              icon: const Icon(Icons.logout, color: Colors.white),
            ),
          ],
          bottom: TabBar(
            controller: tabController,
            isScrollable: true,
            indicatorColor: yaHalaGold,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: t('الرئيسية', 'Dashboard')),
              Tab(text: t('طلبات VIP', 'VIP Requests')),
              Tab(text: t('طلبات مميزة', 'Featured Requests')),
              Tab(text: t('أولوية الأقسام', 'Category Priority')),
              Tab(text: t('مجاني', 'Free')),
              Tab(text: t('منشور', 'Approved')),
              Tab(text: t('مرفوض', 'Rejected')),
              Tab(text: t('أسئلة', 'Questions')),
              Tab(text: t('طلبات أقسام', 'Section Requests')),
              Tab(text: t('إدارة VIP', 'VIP Manager')),
              Tab(text: t('مستخدمين', 'Users')),
              Tab(text: t('أدمنز', 'Admins')),
            ],
          ),
        ),
        body: TabBarView(
          controller: tabController,
          children: [
            _dashboard(),
            _adsList(status: 'pending', reviewFilter: _ReviewFilter.vip),
            _adsList(status: 'pending', reviewFilter: _ReviewFilter.featured),
            _adsList(
              status: 'pending',
              reviewFilter: _ReviewFilter.categoryTop,
            ),
            _adsList(status: 'pending', reviewFilter: _ReviewFilter.free),
            _adsList(status: 'approved', excludeQuestions: true),
            _adsList(status: 'rejected'),
            _adsList(category: 'سؤال'),
            _categorySuggestionRequests(),
            _slidesManager(),
            _usersAnalytics(),
            _adminsList(),
          ],
        ),
      ),
    );
  }

  Widget _dashboard() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('ads').snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        final pending = _countWhere(docs, status: 'pending');
        final approved = _countWhere(docs, status: 'approved');
        final featured = _countWhere(docs, featured: true);
        final rejected = _countWhere(docs, status: 'rejected');
        final questions = _countWhere(docs, category: 'سؤال');
        final totalViews = docs.fold<int>(0, (total, doc) {
          final data = doc.data() as Map<String, dynamic>;
          final views = data['views'];
          return total + (views is int ? views : int.tryParse('$views') ?? 0);
        });

        return ListView(
          padding: const EdgeInsets.all(18),
          children: [
            _heroPanel(pending),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _statCard(
                  t('قيد المراجعة', 'Pending'),
                  '$pending',
                  Icons.hourglass_top,
                  yaHalaGold,
                ),
                _statCard(
                  t('منشور', 'Approved'),
                  '$approved',
                  Icons.check_circle,
                  yaHalaGreen,
                ),
                _statCard(
                  t('إعلانات مميزة', 'Featured'),
                  '$featured',
                  Icons.star,
                  yaHalaGold,
                ),
                _statCard(
                  t('مرفوض', 'Rejected'),
                  '$rejected',
                  Icons.cancel,
                  Colors.red,
                ),
                _statCard(
                  t('أسئلة الجالية', 'Questions'),
                  '$questions',
                  Icons.forum,
                  Colors.blueGrey,
                ),
                _statCard(
                  t('مشاهدات', 'Views'),
                  '$totalViews',
                  Icons.visibility,
                  Colors.indigo,
                ),
              ],
            ),
            const SizedBox(height: 20),
            _sectionTitle(t('إجراءات سريعة', 'Quick actions')),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _quickAction(
                  Icons.add_business,
                  t('إضافة إعلان', 'Add ad'),
                  _showAddAdDialog,
                ),
                _quickAction(
                  Icons.workspace_premium,
                  t('إعلانات VIP', 'VIP ads'),
                  _showAddSlidesDialog,
                ),
                _quickAction(
                  Icons.person_add_alt_1,
                  t('إضافة أدمن', 'Add admin'),
                  _showAddAdminDialog,
                ),
                _quickAction(
                  Icons.pending_actions,
                  t('مراجعة الإعلانات', 'Review ads'),
                  () => tabController.animateTo(1),
                ),
                _quickAction(
                  Icons.star,
                  t('إدارة المميزة', 'Featured ads'),
                  () => tabController.animateTo(3),
                ),
                _quickAction(
                  Icons.forum,
                  t('أسئلة الجالية', 'Questions'),
                  () => tabController.animateTo(5),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _sectionTitle(t('آخر العناصر', 'Latest items')),
            const SizedBox(height: 10),
            _latestPreview(docs),
            const SizedBox(height: 20),
            _userStatsSummary(),
          ],
        );
      },
    );
  }

  Widget _heroPanel(int pending) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [yaHalaGreen, Color(0xFF0F4E2A)],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.admin_panel_settings, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('أهلاً بالأدمن', 'Welcome admin'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  pending == 0
                      ? t(
                          'كل شي تمام، لا يوجد إعلانات تنتظر المراجعة.',
                          'All clear. No ads are waiting.',
                        )
                      : t(
                          'عندك $pending إعلان بانتظار المراجعة.',
                          '$pending ads are waiting for review.',
                        ),
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return SizedBox(
      width: 170,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: widget.isDark ? cardColor : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                color: widget.isDark ? Colors.white : Colors.black,
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(label, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _quickAction(IconData icon, String label, VoidCallback onTap) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: widget.isDark ? cardColor : Colors.white,
        foregroundColor: widget.isDark ? Colors.white : yaHalaGreen,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }

  Widget _latestPreview(List<QueryDocumentSnapshot> docs) {
    final sorted = [...docs]
      ..sort((a, b) {
        final aData = a.data() as Map<String, dynamic>;
        final bData = b.data() as Map<String, dynamic>;
        final aDate = aData['createdAt'];
        final bDate = bData['createdAt'];
        if (aDate is Timestamp && bDate is Timestamp) {
          return bDate.compareTo(aDate);
        }
        return 0;
      });

    return Column(
      children: sorted.take(5).map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return _compactRow(doc.id, data);
      }).toList(),
    );
  }

  int _countWhere(
    List<QueryDocumentSnapshot> docs, {
    String? status,
    String? category,
    bool? featured,
  }) {
    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      if (status != null && data['status'] != status) return false;
      if (category != null && data['category'] != category) return false;
      if (featured != null && (data['isFeatured'] == true) != featured) {
        return false;
      }
      return true;
    }).length;
  }

  Widget _adsList({
    String? status,
    String? category,
    bool featuredOnly = false,
    bool excludeQuestions = false,
    _ReviewFilter? reviewFilter,
  }) {
    Query query = FirebaseFirestore.instance.collection('ads');

    if (status != null) query = query.where('status', isEqualTo: status);
    if (category != null) query = query.where('category', isEqualTo: category);
    if (featuredOnly) query = query.where('isFeatured', isEqualTo: true);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return _error(snapshot.error.toString());
        if (!snapshot.hasData) return _loading();

        var docs = snapshot.data!.docs;

        if (excludeQuestions) {
          docs = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['category'] != 'سؤال';
          }).toList();
        }

        if (reviewFilter != null) {
          docs = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return _matchesReviewFilter(data, reviewFilter);
          }).toList();
        }

        docs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aDate = aData['createdAt'];
          final bDate = bData['createdAt'];
          if (aDate is Timestamp && bDate is Timestamp) {
            return bDate.compareTo(aDate);
          }
          return 0;
        });

        if (docs.isEmpty) {
          return _empty(t('لا توجد عناصر هنا', 'Nothing here yet'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(18),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            return _adminCard(doc.id, data);
          },
        );
      },
    );
  }

  bool _matchesReviewFilter(Map<String, dynamic> data, _ReviewFilter filter) {
    final category = data['category']?.toString() ?? '';
    if (category == 'سؤال') return false;

    final placement = data['adPlacement']?.toString() ?? '';
    final paidType = data['paidAdType']?.toString().toLowerCase() ?? '';
    final tier = adPromotionTier(data);

    return switch (filter) {
      _ReviewFilter.vip =>
        placement == vipAdPlacement || paidType == 'home_vip' || tier >= 3,
      _ReviewFilter.featured =>
        placement == featuredHomeAdPlacement ||
            paidType == 'featured' ||
            paidType == 'home_featured' ||
            tier == 2,
      _ReviewFilter.categoryTop =>
        placement == categoryTopAdPlacement ||
            paidType == 'category_top' ||
            tier == 1,
      _ReviewFilter.free => !isPaidPlacementAd(data),
    };
  }

  Widget _categorySuggestionRequests() {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        _sectionTitle(t('طلبات أقسام الخدمات', 'Service section requests')),
        const SizedBox(height: 10),
        _serviceCategorySuggestions(),
        const SizedBox(height: 22),
        _sectionTitle(
          t(
            'طلبات أقسام المحلات والمحامين',
            'Store and lawyer section requests',
          ),
        ),
        const SizedBox(height: 10),
        _categorySubtypeSuggestions(),
      ],
    );
  }

  Widget _serviceCategorySuggestions() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('serviceCategorySuggestions')
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return _error(snapshot.error.toString());
        if (!snapshot.hasData) return _loading();

        final docs = snapshot.data!.docs.toList();
        _sortSuggestionsByCount(docs);

        if (docs.isEmpty) {
          return _empty(
            t(
              'لا توجد أقسام خدمات بانتظار الموافقة',
              'No service sections are waiting for approval',
            ),
          );
        }

        return Column(
          children: docs
              .map((doc) => _serviceCategorySuggestionCard(doc.id, doc.data()))
              .toList(),
        );
      },
    );
  }

  Widget _categorySubtypeSuggestions() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('categorySubtypeSuggestions')
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return _error(snapshot.error.toString());
        if (!snapshot.hasData) return _loading();

        final docs = snapshot.data!.docs.toList();
        _sortSuggestionsByCount(docs);

        if (docs.isEmpty) {
          return _empty(
            t(
              'لا توجد أقسام محلات أو محامين بانتظار الموافقة',
              'No store or lawyer sections are waiting for approval',
            ),
          );
        }

        return Column(
          children: docs
              .map((doc) => _categorySubtypeSuggestionCard(doc.id, doc.data()))
              .toList(),
        );
      },
    );
  }

  void _sortSuggestionsByCount(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    docs.sort((a, b) {
      final aCount = a.data()['count'];
      final bCount = b.data()['count'];
      final left = aCount is num ? aCount.toInt() : 0;
      final right = bCount is num ? bCount.toInt() : 0;
      return right.compareTo(left);
    });
  }

  Widget _serviceCategorySuggestionCard(String id, Map<String, dynamic> data) {
    final label = data['label']?.toString() ?? id;
    final count = data['count'];
    final countText = count is num ? count.toInt().toString() : '0';
    final lastAdId = data['lastAdId']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: widget.isDark ? cardColor : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: widget.isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.category, color: yaHalaGreen),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: widget.isDark ? Colors.white : Colors.black,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _meta(Icons.repeat, t('$countText مرات', '$countText repeats')),
              _meta(Icons.key, id),
              if (lastAdId.isNotEmpty) _meta(Icons.article, lastAdId),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _actionButton(
                Icons.check,
                t('اعتماد كقسم', 'Approve section'),
                yaHalaGreen,
                () => _approveServiceCategory(id, data),
              ),
              _actionButton(
                Icons.close,
                t('رفض', 'Reject'),
                Colors.deepOrange,
                () => _rejectServiceCategory(id),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _categorySubtypeSuggestionCard(String id, Map<String, dynamic> data) {
    final label = data['label']?.toString() ?? id;
    final category = data['category']?.toString() ?? '';
    final count = data['count'];
    final countText = count is num ? count.toInt().toString() : '0';
    final lastAdId = data['lastAdId']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: widget.isDark ? cardColor : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: widget.isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.category, color: yaHalaGreen),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: widget.isDark ? Colors.white : Colors.black,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _meta(Icons.folder, category),
              _meta(Icons.repeat, t('$countText مرات', '$countText repeats')),
              _meta(Icons.key, id),
              if (lastAdId.isNotEmpty) _meta(Icons.article, lastAdId),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _actionButton(
                Icons.check,
                t('اعتماد كقسم', 'Approve section'),
                yaHalaGreen,
                () => _approveCategorySubtype(id, data),
              ),
              _actionButton(
                Icons.close,
                t('رفض', 'Reject'),
                Colors.deepOrange,
                () => _rejectCategorySubtype(id),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _adminsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return _error(snapshot.error.toString());
        if (!snapshot.hasData) return _loading();

        final docs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return _isAdminUser(data);
        }).toList();

        return ListView(
          padding: const EdgeInsets.all(18),
          children: [
            _quickAction(
              Icons.person_add_alt_1,
              t('إضافة أدمن بالإيميل', 'Add admin by email'),
              _showAddAdminDialog,
            ),
            const SizedBox(height: 14),
            if (docs.isEmpty)
              _empty(t('لا يوجد أدمنز مسجلين', 'No admin users yet'))
            else
              ...docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final email = data['email']?.toString() ?? '';
                final name = data['name']?.toString() ?? '';
                return _userCard(doc.id, email, name, true);
              }),
          ],
        );
      },
    );
  }

  Widget _userStatsSummary() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return _error(snapshot.error.toString());
        if (!snapshot.hasData) return _loading();

        final stats = _buildUserStats(snapshot.data!.docs);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(t('إحصائيات المستخدمين', 'User analytics')),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _statCard(
                  t('عدد المستخدمين', 'Total users'),
                  '${stats.total}',
                  Icons.people_alt,
                  yaHalaGreen,
                ),
                _statCard(
                  t('مستخدمين جدد', 'New users'),
                  '${stats.currentPeriod}',
                  Icons.person_add_alt,
                  yaHalaGold,
                ),
                _statCard(
                  t('المعدل', 'Growth'),
                  stats.growthLabel,
                  stats.growthIcon,
                  stats.growthColor,
                ),
                _statCard(
                  t('نشيطين', 'Active'),
                  '${stats.active}',
                  Icons.bolt,
                  Colors.indigo,
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _usersAnalytics() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return _error(snapshot.error.toString());
        if (!snapshot.hasData) return _loading();

        final docs = snapshot.data!.docs;
        final stats = _buildUserStats(docs);
        final sorted = [...docs]
          ..sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aDate = _userActivityDate(aData);
            final bDate = _userActivityDate(bData);
            if (aDate == null && bDate == null) return 0;
            if (aDate == null) return 1;
            if (bDate == null) return -1;
            return bDate.compareTo(aDate);
          });

        return ListView(
          padding: const EdgeInsets.all(18),
          children: [
            _userAnalyticsHero(stats),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _statCard(
                  t('عدد المستخدمين', 'Total users'),
                  '${stats.total}',
                  Icons.people_alt,
                  yaHalaGreen,
                ),
                _statCard(
                  t('جدد آخر 30 يوم', 'New last 30 days'),
                  '${stats.currentPeriod}',
                  Icons.person_add_alt,
                  yaHalaGold,
                ),
                _statCard(
                  t('قبلها 30 يوم', 'Previous 30 days'),
                  '${stats.previousPeriod}',
                  Icons.history,
                  Colors.blueGrey,
                ),
                _statCard(
                  t('المعدل', 'Growth'),
                  stats.growthLabel,
                  stats.growthIcon,
                  stats.growthColor,
                ),
                _statCard(
                  t('نشيطين', 'Active'),
                  '${stats.active}',
                  Icons.bolt,
                  Colors.indigo,
                ),
                _statCard(
                  t('أدمنز', 'Admins'),
                  '${stats.admins}',
                  Icons.admin_panel_settings,
                  yaHalaGreen,
                ),
                _statCard(
                  t('عندهم رقم', 'With phone'),
                  '${stats.withPhone}',
                  Icons.phone,
                  Colors.teal,
                ),
                _statCard(
                  t('عندهم صورة', 'With photo'),
                  '${stats.withPhoto}',
                  Icons.account_circle,
                  Colors.deepPurple,
                ),
              ],
            ),
            const SizedBox(height: 20),
            _sectionTitle(t('أحدث المستخدمين نشاطاً', 'Latest active users')),
            const SizedBox(height: 10),
            if (sorted.isEmpty)
              _empty(t('لا يوجد مستخدمين بعد', 'No users yet'))
            else
              ...sorted.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return _analyticsUserCard(doc.id, data);
              }),
          ],
        );
      },
    );
  }

  Widget _userAnalyticsHero(_UserStats stats) {
    final improved = stats.currentPeriod >= stats.previousPeriod;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: widget.isDark ? cardColor : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: stats.growthColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(stats.growthIcon, color: stats.growthColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  improved
                      ? t('نمو المستخدمين جيد', 'User growth is healthy')
                      : t('النمو أقل من الفترة السابقة', 'Growth is lower'),
                  style: TextStyle(
                    color: widget.isDark ? Colors.white : Colors.black,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  t(
                    'آخر 30 يوم: ${stats.currentPeriod} مستخدم، الفترة السابقة: ${stats.previousPeriod}.',
                    'Last 30 days: ${stats.currentPeriod} users, previous period: ${stats.previousPeriod}.',
                  ),
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _analyticsUserCard(String id, Map<String, dynamic> data) {
    final name = data['name']?.toString() ?? '';
    final email = data['email']?.toString() ?? '';
    final phone = data['phone']?.toString() ?? '';
    final photoUrl = data['photoUrl']?.toString() ?? '';
    final isAdmin = _isAdminUser(data);
    final lastActivity = _userActivityDate(data);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: widget.isDark ? cardColor : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: yaHalaGreen.withValues(alpha: 0.12),
            backgroundImage: photoUrl.isNotEmpty
                ? NetworkImage(photoUrl)
                : null,
            child: photoUrl.isEmpty
                ? const Icon(Icons.person, color: yaHalaGreen)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty
                      ? (email.isEmpty ? t('مستخدم', 'User') : email)
                      : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: widget.isDark ? Colors.white : Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (email.isNotEmpty)
                  Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.grey),
                  ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (phone.isNotEmpty) _meta(Icons.phone, phone),
                    if (lastActivity != null)
                      _meta(Icons.schedule, _formatDate(lastActivity)),
                    if (isAdmin)
                      _meta(Icons.admin_panel_settings, t('أدمن', 'Admin')),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'admin') {
                FirebaseFirestore.instance.collection('users').doc(id).update({
                  'isAdmin': true,
                  'role': 'admin',
                  'adminUpdatedAt': FieldValue.serverTimestamp(),
                });
              } else if (value == 'removeAdmin') {
                _removeAdmin(id);
              }
            },
            itemBuilder: (context) => [
              if (!isAdmin)
                PopupMenuItem(
                  value: 'admin',
                  child: Text(t('جعله أدمن', 'Make admin')),
                ),
              if (isAdmin)
                PopupMenuItem(
                  value: 'removeAdmin',
                  child: Text(t('إزالة الأدمن', 'Remove admin')),
                ),
            ],
          ),
        ],
      ),
    );
  }

  _UserStats _buildUserStats(List<QueryDocumentSnapshot> docs) {
    final now = DateTime.now();
    final currentStart = now.subtract(const Duration(days: 30));
    final previousStart = now.subtract(const Duration(days: 60));

    var admins = 0;
    var withPhone = 0;
    var withPhoto = 0;
    var active = 0;
    var currentPeriod = 0;
    var previousPeriod = 0;

    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final created = _userCreatedDate(data);
      final activity = _userActivityDate(data);

      if (_isAdminUser(data)) admins++;
      if ((data['phone']?.toString() ?? '').trim().isNotEmpty) withPhone++;
      if ((data['photoUrl']?.toString() ?? '').trim().isNotEmpty) withPhoto++;
      if (activity != null && activity.isAfter(currentStart)) active++;
      if (created != null && created.isAfter(currentStart)) {
        currentPeriod++;
      } else if (created != null && created.isAfter(previousStart)) {
        previousPeriod++;
      }
    }

    final diff = currentPeriod - previousPeriod;
    final growthPercent = previousPeriod == 0
        ? (currentPeriod > 0 ? 100 : 0)
        : ((diff / previousPeriod) * 100).round();
    final growthLabel = diff == 0
        ? '0%'
        : '${diff > 0 ? '+' : ''}$growthPercent%';
    final growthColor = diff >= 0 ? yaHalaGreen : Colors.red;
    final growthIcon = diff >= 0 ? Icons.trending_up : Icons.trending_down;

    return _UserStats(
      total: docs.length,
      admins: admins,
      withPhone: withPhone,
      withPhoto: withPhoto,
      active: active,
      currentPeriod: currentPeriod,
      previousPeriod: previousPeriod,
      growthLabel: growthLabel,
      growthColor: growthColor,
      growthIcon: growthIcon,
    );
  }

  DateTime? _userCreatedDate(Map<String, dynamic> data) {
    return _dateFrom(data['createdAt']) ??
        _dateFrom(data['fcmTokenUpdatedAt']) ??
        _dateFrom(data['updatedAt']) ??
        _dateFrom(data['lastApprovedAdAt']);
  }

  DateTime? _userActivityDate(Map<String, dynamic> data) {
    final dates = [
      _dateFrom(data['updatedAt']),
      _dateFrom(data['fcmTokenUpdatedAt']),
      _dateFrom(data['lastApprovedAdAt']),
      _dateFrom(data['createdAt']),
    ].whereType<DateTime>().toList();
    if (dates.isEmpty) return null;
    dates.sort((a, b) => b.compareTo(a));
    return dates.first;
  }

  DateTime? _dateFrom(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  bool _isAdminUser(Map<String, dynamic> data) {
    return data['isAdmin'] == true ||
        data['IsAdmin'] == true ||
        data['role'] == 'admin';
  }

  Widget _userCard(String id, String email, String name, bool isAdmin) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: widget.isDark ? cardColor : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          const Icon(Icons.admin_panel_settings, color: yaHalaGreen),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? email : name,
                  style: TextStyle(
                    color: widget.isDark ? Colors.white : Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (email.isNotEmpty)
                  Text(email, style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ),
          if (isAdmin)
            TextButton.icon(
              onPressed: () => _removeAdmin(id),
              icon: const Icon(Icons.remove_circle_outline),
              label: Text(t('إزالة', 'Remove')),
            ),
        ],
      ),
    );
  }

  Widget _adminCard(String id, Map<String, dynamic> data) {
    final title = data['title']?.toString() ?? '';
    final description = data['description']?.toString() ?? '';
    final category = data['category']?.toString() ?? '';
    final city = data['city']?.toString() ?? '';
    final phone = data['phone']?.toString() ?? '';
    final status = data['status']?.toString() ?? 'pending';
    final isFeatured = data['isFeatured'] == true;
    final userEmail = data['userEmail']?.toString() ?? '';
    final views = data['views']?.toString() ?? '0';
    final favoritesCount = data['favoritesCount']?.toString() ?? '0';
    final placement = data['adPlacement']?.toString() ?? '';
    final paidLabel = _paidReviewLabel(data);
    final paymentStatus = data['paymentStatus']?.toString() ?? '';
    final activeUntil = data['activeUntil'];

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.isDark ? cardColor : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title.isEmpty ? t('بدون عنوان', 'Untitled') : title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: widget.isDark ? Colors.white : Colors.black,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _statusChip(status),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.grey),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _meta(Icons.category, category),
              if (city.isNotEmpty) _meta(Icons.location_on, city),
              if (phone.isNotEmpty) _meta(Icons.phone, phone),
              if (userEmail.isNotEmpty) _meta(Icons.email, userEmail),
              _meta(
                placement == vipAdPlacement
                    ? Icons.workspace_premium
                    : placement == featuredHomeAdPlacement
                    ? Icons.star
                    : placement == categoryTopAdPlacement
                    ? Icons.trending_up
                    : Icons.money_off,
                paidLabel,
              ),
              if (paymentStatus.isNotEmpty)
                _meta(Icons.payments, _paymentStatusLabel(paymentStatus)),
              if (activeUntil is Timestamp)
                _meta(
                  Icons.event_available,
                  '${t('ينتهي', 'Ends')}: ${_formatDate(activeUntil.toDate())}',
                ),
              _meta(Icons.visibility, views),
              _meta(Icons.favorite, favoritesCount),
              if (isFeatured) _meta(Icons.star, t('مميز', 'Featured')),
            ],
          ),
          if ((data['rejectionReason']?.toString() ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              '${t('سبب الرفض', 'Rejection reason')}: ${data['rejectionReason']}',
              style: const TextStyle(color: Colors.red),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _actionButton(
                Icons.visibility,
                t('عرض', 'View'),
                Colors.blueGrey,
                () => _openDetails(id, data),
              ),
              if (status == 'pending')
                _actionButton(
                  Icons.check,
                  _approveLabel(data),
                  yaHalaGreen,
                  () => _approve(id),
                ),
              if (status == 'pending')
                _actionButton(
                  Icons.close,
                  t('رفض', 'Reject'),
                  Colors.deepOrange,
                  () => _showRejectDialog(id),
                ),
              _actionButton(
                Icons.delete,
                t('حذف', 'Delete'),
                Colors.red,
                () => _confirmDelete(id),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _compactRow(String id, Map<String, dynamic> data) {
    final title = data['title']?.toString() ?? t('بدون عنوان', 'Untitled');
    final status = data['status']?.toString() ?? 'pending';
    return InkWell(
      onTap: () => _openDetails(id, data),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: widget.isDark ? cardColor : Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: widget.isDark ? Colors.white : Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            _statusChip(status),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String status) {
    final color = switch (status) {
      'approved' => yaHalaGreen,
      'rejected' => Colors.red,
      _ => yaHalaGold,
    };
    final label = switch (status) {
      'approved' => t('منشور', 'Approved'),
      'rejected' => t('مرفوض', 'Rejected'),
      _ => t('مراجعة', 'Pending'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _meta(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.grey, size: 16),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  String _paidReviewLabel(Map<String, dynamic> data) {
    final placement = data['adPlacement']?.toString() ?? '';
    final tier = adPromotionTier(data);
    if (placement == vipAdPlacement || tier >= 3) {
      return t('VIP مدفوع', 'Paid VIP');
    }
    if (placement == featuredHomeAdPlacement || tier == 2) {
      return t('مميز تحت VIP', 'Featured under VIP');
    }
    if (placement == categoryTopAdPlacement || tier == 1) {
      return t('أولوية أول 10 بالقسم', 'Top 10 category priority');
    }
    if (data['isPaidAdRequest'] == true) return t('طلب مدفوع', 'Paid request');
    return t('مجاني', 'Free');
  }

  String _paymentStatusLabel(String status) {
    return switch (status) {
      'free_pilot' => t('مجاني حاليا', 'Free pilot'),
      'not_required' => t('لا يحتاج دفع', 'No payment needed'),
      'pending' => t('بانتظار الدفع', 'Payment pending'),
      'paid' => t('مدفوع', 'Paid'),
      _ => status,
    };
  }

  int _defaultDurationDays(int priorityTier) {
    return 30;
  }

  int _durationDaysFromData(Map<String, dynamic> data, int priorityTier) {
    final value = data['requestedDurationDays'] ?? data['adDurationDays'];
    if (value is int && adDurationOptionsDays.contains(value)) return value;
    if (value is num && adDurationOptionsDays.contains(value.toInt())) {
      return value.toInt();
    }
    return _defaultDurationDays(priorityTier);
  }

  String _placementForTier(int priorityTier) {
    if (priorityTier >= 3) return vipAdPlacement;
    if (priorityTier == 2) return featuredHomeAdPlacement;
    if (priorityTier == 1) return categoryTopAdPlacement;
    return '';
  }

  String _approveLabel(Map<String, dynamic> data) {
    final tier = adPromotionTier(data);
    if (tier >= 3) return t('موافقة VIP', 'Approve VIP');
    if (tier == 2) return t('موافقة مميز', 'Approve featured');
    if (tier == 1) return t('موافقة أولوية القسم', 'Approve category priority');
    return t('موافقة', 'Approve');
  }

  Widget _actionButton(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        color: widget.isDark ? Colors.white : Colors.black,
        fontWeight: FontWeight.w900,
        fontSize: 18,
      ),
    );
  }

  Widget _loading() {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation(yaHalaGreen),
      ),
    );
  }

  Widget _empty(String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(text, style: const TextStyle(color: Colors.grey)),
      ),
    );
  }

  Widget _error(String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.red),
        ),
      ),
    );
  }

  Future<void> _approve(String id) async {
    final doc = await FirebaseFirestore.instance
        .collection('ads')
        .doc(id)
        .get();
    final data = doc.data() ?? {};
    final priorityTier = adPromotionTier(data);
    final shouldFeature = priorityTier > 0;
    final durationDays = _durationDaysFromData(data, priorityTier);
    final approvedPlacement = _placementForTier(priorityTier);

    await FirebaseFirestore.instance.collection('ads').doc(id).update({
      'status': 'approved',
      'isFeatured': shouldFeature,
      'priorityTier': priorityTier,
      'paymentRequired': false,
      'paymentStatus': priorityTier > 0 ? 'free_pilot' : 'not_required',
      'paidLaunchMode': priorityTier > 0
          ? 'free_until_payments_enabled'
          : 'not_required',
      'placementDurationDays': durationDays,
      if (approvedPlacement.isNotEmpty)
        'approvedAsPlacement': approvedPlacement,
      if (durationDays > 0)
        'activeUntil': Timestamp.fromDate(
          DateTime.now().add(Duration(days: durationDays)),
        )
      else
        'activeUntil': FieldValue.delete(),
      'activeFrom': FieldValue.serverTimestamp(),
      'rejectionReason': FieldValue.delete(),
      'approvedAt': FieldValue.serverTimestamp(),
    });

    if (!mounted) return;
    _snack(t('تمت الموافقة', 'Approved'));
  }

  Future<void> _approveServiceCategory(
    String id,
    Map<String, dynamic> data,
  ) async {
    final rawLabel = data['label']?.toString() ?? id;
    final label = cleanServiceCategoryLabel(rawLabel);
    final value = normalizeServiceCategoryName(label);

    if (value.isEmpty) {
      _snack(t('اسم القسم غير صالح', 'Invalid section name'));
      return;
    }

    if (isBuiltInServiceSubtype(value)) {
      await FirebaseFirestore.instance
          .collection('serviceCategorySuggestions')
          .doc(id)
          .update({
            'status': 'approved',
            'approvedAt': FieldValue.serverTimestamp(),
          });
      _snack(t('القسم موجود مسبقاً', 'Section already exists'));
      return;
    }

    final batch = FirebaseFirestore.instance.batch();
    final categoryRef = FirebaseFirestore.instance
        .collection('serviceCategories')
        .doc(value);
    final suggestionRef = FirebaseFirestore.instance
        .collection('serviceCategorySuggestions')
        .doc(id);

    batch.set(categoryRef, {
      'value': value,
      'label': label,
      'labelAr': label,
      'labelEn': label,
      'status': 'approved',
      'sourceSuggestionId': id,
      'approvedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    batch.update(suggestionRef, {
      'status': 'approved',
      'approvedValue': value,
      'approvedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();

    if (!mounted) return;
    _snack(t('تم اعتماد القسم', 'Service section approved'));
  }

  Future<void> _rejectServiceCategory(String id) async {
    await FirebaseFirestore.instance
        .collection('serviceCategorySuggestions')
        .doc(id)
        .update({
          'status': 'rejected',
          'rejectedAt': FieldValue.serverTimestamp(),
        });

    if (!mounted) return;
    _snack(t('تم رفض القسم', 'Service section rejected'));
  }

  Future<void> _approveCategorySubtype(
    String id,
    Map<String, dynamic> data,
  ) async {
    final category = data['category']?.toString() ?? '';
    final rawLabel = data['label']?.toString() ?? id;
    final label = cleanCategorySubtypeLabel(rawLabel);
    final value = normalizeCategorySubtypeName(label);

    if (category.isEmpty || value.isEmpty) {
      _snack(t('اسم القسم غير صالح', 'Invalid section name'));
      return;
    }

    if (isBuiltInSubtypeForCategory(category, value)) {
      await FirebaseFirestore.instance
          .collection('categorySubtypeSuggestions')
          .doc(id)
          .update({
            'status': 'approved',
            'approvedAt': FieldValue.serverTimestamp(),
          });
      _snack(t('القسم موجود مسبقاً', 'Section already exists'));
      return;
    }

    final batch = FirebaseFirestore.instance.batch();
    final categoryRef = FirebaseFirestore.instance
        .collection('categorySubtypes')
        .doc('${category}_$value');
    final suggestionRef = FirebaseFirestore.instance
        .collection('categorySubtypeSuggestions')
        .doc(id);

    batch.set(categoryRef, {
      'category': category,
      'value': value,
      'label': label,
      'labelAr': label,
      'labelEn': label,
      'status': 'approved',
      'sourceSuggestionId': id,
      'approvedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    batch.update(suggestionRef, {
      'status': 'approved',
      'approvedValue': value,
      'approvedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();

    if (!mounted) return;
    _snack(t('تم اعتماد القسم', 'Section approved'));
  }

  Future<void> _rejectCategorySubtype(String id) async {
    await FirebaseFirestore.instance
        .collection('categorySubtypeSuggestions')
        .doc(id)
        .update({
          'status': 'rejected',
          'rejectedAt': FieldValue.serverTimestamp(),
        });

    if (!mounted) return;
    _snack(t('تم رفض القسم', 'Section rejected'));
  }

  Future<void> _showRejectDialog(String id) async {
    final controller = TextEditingController();

    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t('رفض المنشور', 'Reject post')),
        content: TextField(
          controller: controller,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: t(
              'اكتب سبب الرفض بالتفصيل',
              'Write the rejection reason in detail',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(t('إلغاء', 'Cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: Text(
              t('رفض', 'Reject'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    controller.dispose();
    if (reason == null) return;
    if (reason.trim().isEmpty) {
      _snack(t('اكتب سبب الرفض أولاً', 'Add a rejection reason first'));
      return;
    }

    await FirebaseFirestore.instance.collection('ads').doc(id).update({
      'status': 'rejected',
      'isFeatured': false,
      'rejectionReason': reason.trim(),
      'rejectedAt': FieldValue.serverTimestamp(),
    });

    if (!mounted) return;
    _snack(t('تم الرفض', 'Rejected'));
  }

  Future<void> _confirmDelete(String id) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t('حذف نهائي', 'Delete permanently')),
        content: Text(
          t(
            'هل أنت متأكد؟ لا يمكن التراجع عن الحذف.',
            'Are you sure? This cannot be undone.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(t('إلغاء', 'Cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              t('حذف', 'Delete'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    await FirebaseFirestore.instance.collection('ads').doc(id).delete();

    if (!mounted) return;
    _snack(t('تم الحذف', 'Deleted'));
  }

  Future<void> _showAddAdminDialog() async {
    final controller = TextEditingController();

    final email = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t('إضافة أدمن', 'Add admin')),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            hintText: t('إيميل المستخدم', 'User email'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(t('إلغاء', 'Cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: yaHalaGreen),
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: Text(
              t('إضافة', 'Add'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    controller.dispose();
    if (email == null || email.trim().isEmpty) return;

    final normalized = email.trim().toLowerCase();
    final users = await FirebaseFirestore.instance
        .collection('users')
        .where('email', isEqualTo: normalized)
        .limit(1)
        .get();

    if (users.docs.isEmpty) {
      if (!mounted) return;
      _snack(
        t(
          'لم يتم العثور على مستخدم بهذا الإيميل',
          'No user found with this email',
        ),
      );
      return;
    }

    await users.docs.first.reference.update({
      'isAdmin': true,
      'role': 'admin',
      'adminUpdatedAt': FieldValue.serverTimestamp(),
    });

    if (!mounted) return;
    _snack(t('تمت إضافة الأدمن', 'Admin added'));
  }

  Future<void> _showAddSlidesDialog() async {
    final picker = ImagePicker();
    final List<XFile> selectedImages = [];
    var uploading = false;

    final shouldUpload = await showDialog<bool>(
      context: context,
      barrierDismissible: !uploading,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> pickImages() async {
              final images = await picker.pickMultiImage(imageQuality: 78);
              if (images.isEmpty) return;

              final remaining = 10 - selectedImages.length;
              selectedImages.addAll(images.take(remaining));

              if (images.length > remaining && mounted) {
                _snack(
                  t(
                    'يمكنك إضافة 10 صور كحد أقصى',
                    'You can add up to 10 images only',
                  ),
                );
              }

              setDialogState(() {});
            }

            return AlertDialog(
              title: Text(t('إضافة إعلان VIP', 'Add VIP ad')),
              content: SizedBox(
                width: 560,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t(
                        'اختر حتى 10 صور لإعلانات VIP أعلى الصفحة. المقاس الأفضل 1200 × 540.',
                        'Choose up to 10 images for top VIP ads. Best size: 1200 x 540.',
                      ),
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: uploading || selectedImages.length >= 10
                          ? null
                          : pickImages,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: Text(
                        t(
                          'اختيار الصور (${selectedImages.length}/10)',
                          'Choose images (${selectedImages.length}/10)',
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (selectedImages.isEmpty)
                      Container(
                        height: 120,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: widget.isDark
                              ? bgDark
                              : const Color(0xFFF3F3F3),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          t('لا يوجد صور مختارة', 'No images selected'),
                          style: const TextStyle(color: Colors.grey),
                        ),
                      )
                    else
                      SizedBox(
                        height: 130,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: selectedImages.length,
                          itemBuilder: (context, index) {
                            return Stack(
                              children: [
                                FutureBuilder<Uint8List>(
                                  future: selectedImages[index].readAsBytes(),
                                  builder: (context, snapshot) {
                                    return Container(
                                      width: 150,
                                      margin: const EdgeInsetsDirectional.only(
                                        end: 10,
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      decoration: BoxDecoration(
                                        color: widget.isDark
                                            ? bgDark
                                            : const Color(0xFFF3F3F3),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: snapshot.hasData
                                          ? Image.memory(
                                              snapshot.data!,
                                              fit: BoxFit.cover,
                                            )
                                          : const Center(
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            ),
                                    );
                                  },
                                ),
                                PositionedDirectional(
                                  top: 6,
                                  end: 16,
                                  child: InkWell(
                                    onTap: uploading
                                        ? null
                                        : () {
                                            selectedImages.removeAt(index);
                                            setDialogState(() {});
                                          },
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    if (uploading) ...[
                      const SizedBox(height: 14),
                      const LinearProgressIndicator(color: yaHalaGreen),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: uploading
                      ? null
                      : () => Navigator.pop(dialogContext, false),
                  child: Text(t('إلغاء', 'Cancel')),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: yaHalaGreen),
                  onPressed: uploading || selectedImages.isEmpty
                      ? null
                      : () async {
                          setDialogState(() => uploading = true);
                          await _uploadHomeSlides(selectedImages);
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext, true);
                          }
                        },
                  icon: const Icon(Icons.cloud_upload, color: Colors.white),
                  label: Text(
                    t('رفع الصور', 'Upload'),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (!mounted || shouldUpload != true) return;
    _snack(t('تمت إضافة إعلانات VIP', 'VIP ads added'));
  }

  Future<void> _openVipAdForm() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddPostScreen(
          isArabic: widget.isArabic,
          isDark: widget.isDark,
          initialAdPlacement: 'vip_slider',
          publishImmediately: true,
          createdByAdmin: true,
        ),
      ),
    );
  }

  Future<void> _uploadHomeSlides(List<XFile> images) async {
    final existing = await FirebaseFirestore.instance
        .collection('homeSlides')
        .get();
    final baseSort = existing.docs.length;
    final batch = FirebaseFirestore.instance.batch();

    for (var index = 0; index < images.length; index++) {
      final bytes = await images[index].readAsBytes();
      final name = '${DateTime.now().millisecondsSinceEpoch}_$index.jpg';
      final ref = FirebaseStorage.instance
          .ref()
          .child('home_slides')
          .child(name);

      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      final imageUrl = await ref.getDownloadURL();
      final slideRef = FirebaseFirestore.instance
          .collection('homeSlides')
          .doc();

      batch.set(slideRef, {
        'imageUrl': imageUrl,
        'active': true,
        'sort': baseSort + index,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': FirebaseAuth.instance.currentUser?.uid ?? '',
      });
    }

    await batch.commit();
  }

  Widget _slidesManager() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('homeSlides').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return _error(snapshot.error.toString());
        if (!snapshot.hasData) return _loading();

        final docs = [...snapshot.data!.docs]
          ..sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aSort = aData['sort'];
            final bSort = bData['sort'];
            return (aSort is int ? aSort : 0).compareTo(
              bSort is int ? bSort : 0,
            );
          });

        return ListView(
          padding: const EdgeInsets.all(18),
          children: [
            _quickAction(
              Icons.workspace_premium,
              t('إضافة إعلان VIP كامل', 'Add full VIP ad'),
              _openVipAdForm,
            ),
            const SizedBox(height: 10),
            _quickAction(
              Icons.add_photo_alternate,
              t('إضافة صور سلايدر فقط', 'Add slider images only'),
              _showAddSlidesDialog,
            ),
            const SizedBox(height: 14),
            if (docs.isEmpty)
              _empty(
                t('لا يوجد إعلانات VIP بعد', 'No VIP ads have been added yet'),
              )
            else
              ...docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return _slideCard(doc.id, data);
              }),
          ],
        );
      },
    );
  }

  Widget _slideCard(String id, Map<String, dynamic> data) {
    final imageUrl = data['imageUrl']?.toString() ?? '';
    final active = data['active'] != false;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.isDark ? cardColor : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 130,
            height: 82,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(14)),
            child: imageUrl.isEmpty
                ? Container(color: Colors.grey.shade200)
                : Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  active ? t('فعالة', 'Active') : t('موقفة', 'Inactive'),
                  style: TextStyle(
                    color: active ? yaHalaGreen : Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  t(
                    'تظهر كإعلان VIP أعلى الصفحة الرئيسية',
                    'Shown as a VIP ad at the top of the home page',
                  ),
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
          Switch(
            value: active,
            activeThumbColor: yaHalaGreen,
            onChanged: (value) {
              FirebaseFirestore.instance
                  .collection('homeSlides')
                  .doc(id)
                  .update({'active': value});
            },
          ),
          IconButton(
            tooltip: t('حذف', 'Delete'),
            onPressed: () => _deleteSlide(id),
            icon: const Icon(Icons.delete, color: Colors.red),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSlide(String id) async {
    await FirebaseFirestore.instance.collection('homeSlides').doc(id).delete();
    if (!mounted) return;
    _snack(t('تم حذف إعلان VIP', 'VIP ad deleted'));
  }

  Future<void> _showAddAdDialog() async {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final cityController = TextEditingController();
    final phoneController = TextEditingController();
    final priceController = TextEditingController();
    var category = 'خدمة';
    var status = 'approved';
    var paidPlacement = '';
    var allowCall = true;
    var allowSms = true;
    var allowInAppMessage = true;
    var commentsEnabled = true;

    final shouldCreate = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(t('إضافة إعلان من الأدمن', 'Add admin ad')),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: category,
                      decoration: InputDecoration(
                        labelText: t('القسم', 'Category'),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'وظيفة', child: Text('وظيفة')),
                        DropdownMenuItem(value: 'سكن', child: Text('سكن')),
                        DropdownMenuItem(value: 'خدمة', child: Text('خدمة')),
                        DropdownMenuItem(value: 'كوبون', child: Text('كوبون')),
                        DropdownMenuItem(
                          value: 'سؤال',
                          child: Text('سؤال للجالية'),
                        ),
                        DropdownMenuItem(
                          value: restaurantCategory,
                          child: Text('مطاعم وكافيهات'),
                        ),
                        DropdownMenuItem(
                          value: storesCategory,
                          child: Text('محلات تجارية'),
                        ),
                        DropdownMenuItem(
                          value: 'فعاليات',
                          child: Text('فعاليات'),
                        ),
                        DropdownMenuItem(
                          value: 'محامين وهجرة',
                          child: Text('محامين وهجرة'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() {
                          category = value;
                          if (category == 'كوبون' || category == 'سؤال') {
                            paidPlacement = '';
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: t('عنوان الإعلان', 'Ad title'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: descriptionController,
                      minLines: 3,
                      maxLines: 5,
                      decoration: InputDecoration(
                        labelText: t('الوصف', 'Description'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: cityController,
                      decoration: InputDecoration(
                        labelText: t('المدينة أو العنوان', 'City or address'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: t(
                          'رقم الهاتف - اختياري',
                          'Phone - optional',
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: priceController,
                      decoration: InputDecoration(
                        labelText: t(
                          'السعر/العرض - اختياري',
                          'Price/offer - optional',
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        t('طرق التواصل', 'Contact methods'),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    CheckboxListTile(
                      value: allowCall,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (value) {
                        setDialogState(() => allowCall = value ?? false);
                      },
                      title: Text(t('اتصال', 'Call')),
                    ),
                    CheckboxListTile(
                      value: allowSms,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (value) {
                        setDialogState(() => allowSms = value ?? false);
                      },
                      title: Text(t('رسالة نصية', 'Text message')),
                    ),
                    CheckboxListTile(
                      value: allowInAppMessage,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (value) {
                        setDialogState(
                          () => allowInAppMessage = value ?? false,
                        );
                      },
                      title: Text(t('رسالة عبر يا هلا', 'Message via Ya Hala')),
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: paidPlacement,
                      decoration: InputDecoration(
                        labelText: t('نوع الظهور', 'Placement type'),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: '',
                          child: Text(t('مجاني / عادي', 'Free / normal')),
                        ),
                        DropdownMenuItem(
                          value: vipAdPlacement,
                          child: Text(t('VIP أعلى الصفحة', 'Home VIP')),
                        ),
                        DropdownMenuItem(
                          value: featuredHomeAdPlacement,
                          child: Text(t('مميز تحت VIP', 'Featured under VIP')),
                        ),
                        DropdownMenuItem(
                          value: categoryTopAdPlacement,
                          child: Text(
                            t('أولوية أول 10 بالقسم', 'Top 10 in category'),
                          ),
                        ),
                      ],
                      onChanged: category == 'كوبون' || category == 'سؤال'
                          ? null
                          : (value) {
                              if (value == null) return;
                              setDialogState(() => paidPlacement = value);
                            },
                    ),
                    if (category == 'سؤال')
                      SwitchListTile(
                        value: commentsEnabled,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (value) {
                          setDialogState(() => commentsEnabled = value);
                        },
                        title: Text(t('السماح بالتعليقات', 'Allow comments')),
                      ),
                    DropdownButtonFormField<String>(
                      initialValue: status,
                      decoration: InputDecoration(
                        labelText: t('حالة الإعلان', 'Ad status'),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'approved',
                          child: Text(t('منشور مباشرة', 'Publish now')),
                        ),
                        DropdownMenuItem(
                          value: 'pending',
                          child: Text(t('قيد المراجعة', 'Pending')),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() => status = value);
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(t('إلغاء', 'Cancel')),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: yaHalaGreen),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(
                  t('نشر', 'Publish'),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (shouldCreate != true) {
      titleController.dispose();
      descriptionController.dispose();
      cityController.dispose();
      phoneController.dispose();
      priceController.dispose();
      return;
    }

    final title = titleController.text.trim();
    final description = descriptionController.text.trim();
    final city = cityController.text.trim();
    final phone = phoneController.text.trim();
    final price = cleanMoneyInput(priceController.text);

    titleController.dispose();
    descriptionController.dispose();
    cityController.dispose();
    phoneController.dispose();
    priceController.dispose();

    if (title.isEmpty || description.isEmpty || city.isEmpty) {
      _snack(
        t(
          'العنوان والوصف والموقع مطلوبين',
          'Title, description, and location are required',
        ),
      );
      return;
    }

    if (!allowCall && !allowSms && !allowInAppMessage) {
      _snack(
        t(
          'اختر طريقة تواصل واحدة على الأقل',
          'Choose at least one contact method',
        ),
      );
      return;
    }

    final paidType = switch (paidPlacement) {
      vipAdPlacement => 'vip',
      featuredHomeAdPlacement => 'featured',
      categoryTopAdPlacement => 'category_top',
      _ => '',
    };
    final priorityTier = switch (paidPlacement) {
      vipAdPlacement => 3,
      featuredHomeAdPlacement => 2,
      categoryTopAdPlacement => 1,
      _ => 0,
    };

    final user = FirebaseAuth.instance.currentUser;
    await FirebaseFirestore.instance.collection('ads').add({
      'title': title,
      'description': description,
      'city': city,
      'phone': phone,
      'price': price,
      'category': category,
      'allowCall': allowCall,
      'allowSms': allowSms,
      'allowInAppMessage': allowInAppMessage,
      'views': 0,
      'favoritesCount': 0,
      'likesCount': 0,
      'commentsCount': 0,
      if (category == 'سؤال') 'commentsEnabled': commentsEnabled,
      'status': status,
      'isFeatured': priorityTier > 0,
      'priorityTier': priorityTier,
      'paymentRequired': false,
      'paymentStatus': priorityTier > 0 ? 'free_pilot' : 'not_required',
      'paidLaunchMode': priorityTier > 0
          ? 'free_until_payments_enabled'
          : 'not_required',
      'placementDurationDays': _defaultDurationDays(priorityTier),
      if (paidPlacement.isNotEmpty) ...{
        'adPlacement': paidPlacement,
        'paidAdType': paidType,
        'isPaidAdRequest': true,
        'requestedPlacementLabel': _paidReviewLabel({
          'adPlacement': paidPlacement,
          'paidAdType': paidType,
          'priorityTier': priorityTier,
        }),
      },
      'imageUrl': '',
      'imageUrls': <String>[],
      'userId': user?.uid ?? '',
      'userEmail': user?.email ?? '',
      'createdByAdmin': true,
      'createdAt': FieldValue.serverTimestamp(),
      if (status == 'approved') ...{
        'approvedAt': FieldValue.serverTimestamp(),
        'activeFrom': FieldValue.serverTimestamp(),
        if (priorityTier > 0)
          'activeUntil': Timestamp.fromDate(
            DateTime.now().add(
              Duration(days: _defaultDurationDays(priorityTier)),
            ),
          ),
      },
    });

    if (!mounted) return;
    _snack(t('تمت إضافة الإعلان', 'Ad added'));
  }

  Future<void> _removeAdmin(String userId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user?.uid == userId) {
      _snack(t('لا يمكنك إزالة نفسك', 'You cannot remove yourself'));
      return;
    }

    await FirebaseFirestore.instance.collection('users').doc(userId).update({
      'isAdmin': false,
      'role': FieldValue.delete(),
      'adminUpdatedAt': FieldValue.serverTimestamp(),
    });

    if (!mounted) return;
    _snack(t('تمت إزالة الأدمن', 'Admin removed'));
  }

  void _openDetails(String id, Map<String, dynamic> data) {
    if (data['category'] == 'سؤال') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => QuestionDetailsScreen(
            isArabic: widget.isArabic,
            isDark: widget.isDark,
            questionId: id,
            data: data,
          ),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdDetailsScreen(
          isArabic: widget.isArabic,
          isDark: widget.isDark,
          data: data,
          adId: id,
        ),
      ),
    );
  }

  void _snack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _UserStats {
  final int total;
  final int admins;
  final int withPhone;
  final int withPhoto;
  final int active;
  final int currentPeriod;
  final int previousPeriod;
  final String growthLabel;
  final Color growthColor;
  final IconData growthIcon;

  const _UserStats({
    required this.total,
    required this.admins,
    required this.withPhone,
    required this.withPhoto,
    required this.active,
    required this.currentPeriod,
    required this.previousPeriod,
    required this.growthLabel,
    required this.growthColor,
    required this.growthIcon,
  });
}
