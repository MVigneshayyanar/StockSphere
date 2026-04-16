import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:heroicons/heroicons.dart';
import 'package:intl/intl.dart';
import 'package:maxbillup/Colors.dart';

class KnowledgePage extends StatefulWidget {
  final VoidCallback onBack;

  const KnowledgePage({
    super.key,
    required this.onBack,
  });

  @override
  State<KnowledgePage> createState() => _KnowledgePageState();
}

class _KnowledgePageState extends State<KnowledgePage> {
  String _selectedCategory = 'All';
  final List<String> _categories = ['All', 'General', 'Tutorial', 'FAQ', 'Tips', 'Updates'];

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) widget.onBack();
      },
      child: Scaffold(
        backgroundColor: kGreyBg,
        appBar: AppBar(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
          title: const Text('Knowledge Base',
              style: TextStyle(color: kWhite, fontWeight: FontWeight.w700, fontSize: 18)),
          backgroundColor: kPrimaryColor,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const HeroIcon(HeroIcons.arrowLeft, color: kWhite, size: 20),
            onPressed: widget.onBack,
          ),
        ),
        body: Column(
        children: [
          // Category Filter Section
          _buildCategoryFilter(),

          // Knowledge Posts List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('knowledge')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
                }

                if (snapshot.hasError) {
                  return _buildEmptyState();
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState();
                }

                // Filter and sort locally to avoid composite index requirement
                var docs = snapshot.data!.docs;

                // Filter by category
                if (_selectedCategory != 'All') {
                  docs = docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final category = (data['category'] ?? 'General').toString();
                    return category.toLowerCase() == _selectedCategory.toLowerCase();
                  }).toList();
                }

                // Sort by createdAt (newest first)
                docs.sort((a, b) {
                  final aData = a.data() as Map<String, dynamic>;
                  final bData = b.data() as Map<String, dynamic>;
                  final aTime = aData['createdAt'] as Timestamp?;
                  final bTime = bData['createdAt'] as Timestamp?;

                  if (aTime == null && bTime == null) return 0;
                  if (aTime == null) return 1;
                  if (bTime == null) return -1;
                  return bTime.compareTo(aTime);
                });

                if (docs.isEmpty) {
                  return _buildEmptyState();
                }

                return RefreshIndicator(
                  color: kPrimaryColor,
                  onRefresh: () async => setState(() {}),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: docs.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data() as Map<String, dynamic>;

                      return _buildKnowledgeCard(
                        context,
                        title: data['title'] ?? 'Untitled',
                        content: data['content'] ?? '',
                        category: data['category'] ?? 'General',
                        createdAt: data['createdAt'] as Timestamp?,
                        updatedAt: data['updatedAt'] as Timestamp?,
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return Container(
      height: 56,
      width: double.infinity,
      decoration: const BoxDecoration(
        color: kWhite,
        border: Border(bottom: BorderSide(color: kGrey200)),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = _selectedCategory == category;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: () => setState(() => _selectedCategory = category),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: isSelected ? kPrimaryColor : kGreyBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isSelected ? kPrimaryColor : kGrey200),
                ),
                alignment: Alignment.center,
                child: Text(
                  category,
                  style: TextStyle(
                    color: isSelected ? kWhite : kBlack54,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildKnowledgeCard(
      BuildContext context, {
        required String title,
        required String content,
        required String category,
        Timestamp? createdAt,
        Timestamp? updatedAt,
      }) {
    final categoryColor = _getCategoryColor(category);
    final timeAgo = _getTimeAgo(createdAt ?? updatedAt);

    return Container(
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kGrey200),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showKnowledgeDetail(context, title, content, category, createdAt, updatedAt),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: categoryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        category,
                        style: TextStyle(color: categoryColor, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                      ),
                    ),
                    Row(
                      children: [
                        HeroIcon(HeroIcons.clock, size: 12, color: kBlack54.withOpacity(0.6)),
                        const SizedBox(width: 4),
                        Text(timeAgo, style: const TextStyle(fontSize: 10, color: kBlack54, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kBlack87, height: 1.3),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  content,
                  style: const TextStyle(fontSize: 12, color: kBlack54, height: 1.5),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Text(
                      'Read Article',
                      style: TextStyle(color: kPrimaryColor, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                    ),
                    const SizedBox(width: 4),
                    const HeroIcon(HeroIcons.chevronRight, size: 10, color: kPrimaryColor),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showKnowledgeDetail(
      BuildContext context,
      String title,
      String content,
      String category,
      Timestamp? createdAt,
      Timestamp? updatedAt,
      ) {
    final categoryColor = _getCategoryColor(category);
    final formattedDate = _formatDate(createdAt ?? updatedAt);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: kWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Drag Handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40, height: 4,
              decoration: BoxDecoration(color: kGrey200, borderRadius: BorderRadius.circular(2)),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: categoryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          HeroIcon(_getCategoryIcon(category), size: 12, color: categoryColor),
                          const SizedBox(width: 6),
                          Text(category, style: TextStyle(color: categoryColor, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: kBlack87, height: 1.2)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const HeroIcon(HeroIcons.calendar, size: 12, color: kBlack54),
                      const SizedBox(width: 6),
                      Text(formattedDate, style: const TextStyle(fontSize: 12, color: kBlack54, fontWeight: FontWeight.w500)),
                    ],
                  ),
                  const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Divider(height: 1, color: kGrey200)),
                  Text(
                    content,
                    style: const TextStyle(fontSize: 14, color: kBlack87, height: 1.6, letterSpacing: 0.2),
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimaryColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text('Finished Reading', style: TextStyle(color: kWhite, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: kWhite, shape: BoxShape.circle, border: Border.all(color: kGrey200)),
            child: HeroIcon(HeroIcons.lightBulb, size: 48, color: kBlack54.withOpacity(0.2)),
          ),
          const SizedBox(height: 24),
          const Text('No knowledge posts yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kBlack87)),
          const SizedBox(height: 8),
          const Text('Check back later for tutorials and tips.', style: TextStyle(fontSize: 13, color: kBlack54)),
        ],
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'tutorial': return kPrimaryColor;
      case 'faq': return const Color(0xFFF59E0B);
      case 'tips': return const Color(0xFF10B981);
      case 'updates': return const Color(0xFF8B5CF6);
      default: return kBlack54;
    }
  }

  HeroIcons _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'tutorial': return HeroIcons.bookOpen;
      case 'faq': return HeroIcons.questionMarkCircle;
      case 'tips': return HeroIcons.lightBulb;
      case 'updates': return HeroIcons.sparkles;
      default: return HeroIcons.informationCircle;
    }
  }

  String _getTimeAgo(Timestamp? timestamp) {
    if (timestamp == null) return 'Recently';
    final difference = DateTime.now().difference(timestamp.toDate());
    if (difference.inDays > 0) return '${difference.inDays}d ago';
    if (difference.inHours > 0) return '${difference.inHours}h ago';
    if (difference.inMinutes > 0) return '${difference.inMinutes}m ago';
    return 'Just now';
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return '';
    return DateFormat('MMM dd, yyyy • hh:mm a').format(timestamp.toDate());
  }
}
