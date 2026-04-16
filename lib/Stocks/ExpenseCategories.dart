import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:maxbillup/Colors.dart';
import 'package:maxbillup/utils/firestore_service.dart';
import 'package:maxbillup/utils/translation_helper.dart';
import 'package:maxbillup/services/currency_service.dart';
import 'package:heroicons/heroicons.dart';

class ExpenseCategoriesPage extends StatefulWidget {
  final String uid;
  final VoidCallback onBack;

  const ExpenseCategoriesPage({super.key, required this.uid, required this.onBack});

  @override
  State<ExpenseCategoriesPage> createState() => _ExpenseCategoriesPageState();
}

class _ExpenseCategoriesPageState extends State<ExpenseCategoriesPage> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  late Future<Stream<QuerySnapshot>> _categoriesStreamFuture;
  late Future<Stream<QuerySnapshot>> _expenseNamesStreamFuture;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _categoriesStreamFuture = FirestoreService().getCollectionStream('expenseCategories');
    _expenseNamesStreamFuture = FirestoreService().getCollectionStream('expenseNames');
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

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
          title: const Text('Expense Category',
              style: TextStyle(color: kWhite, fontWeight: FontWeight.w700, fontSize: 18)),
          backgroundColor: kPrimaryColor,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const HeroIcon(HeroIcons.arrowLeft, color: kWhite, size: 20),
            onPressed: widget.onBack,
          ),
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: kWhite,
            indicatorWeight: 4,
            labelColor: kWhite,
            unselectedLabelColor: kWhite.withOpacity(0.7),
            labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.5),
            tabs: [
              Tab(text: context.tr('Types')),
              Tab(text: context.tr('expense_names')),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildCategoriesTab(),
            _buildExpenseNamesTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoriesTab() {
    return Column(
      children: [
        // ENTERPRISE SEARCH & ADD HEADER
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          decoration: const BoxDecoration(
            color: kWhite,
            border: Border(bottom: BorderSide(color: kGrey200)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 46,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ValueListenableBuilder<TextEditingValue>(
      valueListenable: _searchController,
      builder: (context, value, _) {
        final bool hasText = value.text.isNotEmpty;
        return TextField(
                    controller: _searchController,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: kBlack87),
                    decoration: InputDecoration(
                      hintText: context.tr('search'),
                      hintStyle: const TextStyle(color: kBlack54, fontSize: 14),
                      prefixIcon: const HeroIcon(HeroIcons.magnifyingGlass, color: kPrimaryColor, size: 20),
                      filled: true,
                      fillColor: const Color(0xFFF8F9FA),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: hasText ? kPrimaryColor : kGrey200, width: hasText ? 1.5 : 1.0),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: hasText ? kPrimaryColor : kGrey200, width: hasText ? 1.5 : 1.0),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: kPrimaryColor, width: 2.0),
                      ),
                      labelStyle: TextStyle(color: hasText ? kPrimaryColor : kBlack54, fontSize: 13, fontWeight: FontWeight.w600),
                      floatingLabelStyle: TextStyle(color: hasText ? kPrimaryColor : kPrimaryColor, fontSize: 11, fontWeight: FontWeight.w900),
                    ),
                  
);
      },
    ),
                ),
              ),
              const SizedBox(width: 12),
              InkWell(
                onTap: () => _showAddCategoryDialog(context),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 46,
                  width: 46,
                  decoration: BoxDecoration(
                    color: kPrimaryColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const HeroIcon(HeroIcons.plus, color: kWhite, size: 24),
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: FutureBuilder<Stream<QuerySnapshot>>(
            future: _categoriesStreamFuture,
            builder: (context, futureSnapshot) {
              if (futureSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
              }
              if (!futureSnapshot.hasData) return const Center(child: Text("Unable to load categories"));

              return StreamBuilder<QuerySnapshot>(
                stream: futureSnapshot.data!,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return _buildEmptyState();

                  final categories = snapshot.data!.docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final name = (data['name'] ?? '').toString().toLowerCase();
                    return name.contains(_searchQuery);
                  }).toList();

                  if (categories.isEmpty) return _buildNoResults();

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                    itemCount: categories.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final data = categories[index].data() as Map<String, dynamic>;
                      final name = data['name'] ?? 'Unnamed Type';
                      final ts = data['timestamp'] as Timestamp?;
                      final dateStr = ts != null ? DateFormat('dd MMM yyyy').format(ts.toDate()) : 'N/A';

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
                            onTap: () => showDialog(
                              context: context,
                              builder: (ctx) => _EditDeleteCategoryDialog(
                                docId: categories[index].id,
                                initialName: name,
                                onChanged: () => setState(() {}),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              child: Column(children: [
                                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                  Row(children: [
                                    const HeroIcon(HeroIcons.tag, size: 14, color: kPrimaryColor),
                                    const SizedBox(width: 5),
                                    Text(name.length > 24 ? '${name.substring(0, 24)}…' : name,
                                        style: const TextStyle(fontWeight: FontWeight.w900, color: kPrimaryColor, fontSize: 13)),
                                  ]),
                                  Text('Created: $dateStr', style: const TextStyle(fontSize: 10.5, color: Colors.black, fontWeight: FontWeight.w500)),
                                ]),
                                const Divider(height: 20, color: kGreyBg),
                                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                  const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text('Expense type', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: kBlack54, letterSpacing: 0.5)),
                                  ]),
                                  Row(mainAxisSize: MainAxisSize.min, children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(color: kPrimaryColor.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: kPrimaryColor.withValues(alpha: 0.2))),
                                      child: const Text('Edit', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: kPrimaryColor)),
                                    ),
                                    const SizedBox(width: 8),
                                    const HeroIcon(HeroIcons.chevronRight, color: kPrimaryColor, size: 16),
                                  ]),
                                ]),
                              ]),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildExpenseNamesTab() {
    return Column(
      children: [
        // ENTERPRISE SEARCH HEADER
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          decoration: const BoxDecoration(
            color: kWhite,
            border: Border(bottom: BorderSide(color: kGrey200)),
          ),
          child: Container(
            height: 46,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ValueListenableBuilder<TextEditingValue>(
      valueListenable: _searchController,
      builder: (context, value, _) {
        final bool hasText = value.text.isNotEmpty;
        return TextField(
              controller: _searchController,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: kBlack87),
              decoration: InputDecoration(
                hintText: "Search expense titles...",
                hintStyle: TextStyle(color: kBlack54, fontSize: 14),
                prefixIcon: HeroIcon(HeroIcons.magnifyingGlass, color: kPrimaryColor, size: 20),
                filled: true,
                fillColor: const Color(0xFFF8F9FA),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: hasText ? kPrimaryColor : kGrey200, width: hasText ? 1.5 : 1.0),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: hasText ? kPrimaryColor : kGrey200, width: hasText ? 1.5 : 1.0),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: kPrimaryColor, width: 2.0),
                ),
                labelStyle: TextStyle(color: hasText ? kPrimaryColor : kBlack54, fontSize: 13, fontWeight: FontWeight.w600),
                floatingLabelStyle: TextStyle(color: hasText ? kPrimaryColor : kPrimaryColor, fontSize: 11, fontWeight: FontWeight.w900),
              ),
            
);
      },
    ),
          ),
        ),

        Expanded(
          child: FutureBuilder<Stream<QuerySnapshot>>(
            future: _expenseNamesStreamFuture,
            builder: (context, futureSnapshot) {
              if (futureSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
              }
              if (!futureSnapshot.hasData) return const Center(child: Text("Unable to load expense names"));

              return StreamBuilder<QuerySnapshot>(
                stream: futureSnapshot.data!,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return _buildEmptyStateExpenseNames();

                  final expenseNames = snapshot.data!.docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final name = (data['name'] ?? '').toString().toLowerCase();
                    return name.contains(_searchQuery);
                  }).toList();

                  if (expenseNames.isEmpty) return _buildNoResults();

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                    itemCount: expenseNames.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final data = expenseNames[index].data() as Map<String, dynamic>;
                      final name = data['name'] ?? 'Unnamed';
                      final usageCount = data['usageCount'] ?? 1;
                      final ts = data['lastUsed'] as Timestamp?;
                      final dateStr = ts != null ? DateFormat('dd MMM yyyy').format(ts.toDate()) : 'N/A';

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
                            onTap: () => Navigator.push(
                              context,
                              CupertinoPageRoute(builder: (_) => ExpenseNameDetailsPage(
                                docId: expenseNames[index].id,
                                name: name,
                                usageCount: usageCount is int ? usageCount : int.tryParse(usageCount.toString()) ?? 0,
                              )),
                            ).then((_) => setState(() {})),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              child: Column(children: [
                                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                  Row(children: [
                                    const HeroIcon(HeroIcons.documentText, size: 14, color: kOrange),
                                    const SizedBox(width: 5),
                                    Text(name.length > 24 ? '${name.substring(0, 24)}…' : name,
                                        style: const TextStyle(fontWeight: FontWeight.w900, color: kOrange, fontSize: 13)),
                                  ]),
                                  Text('Last: $dateStr', style: const TextStyle(fontSize: 10.5, color: Colors.black, fontWeight: FontWeight.w500)),
                                ]),
                                const Divider(height: 20, color: kGreyBg),
                                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    const Text('Usage count', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: kBlack54, letterSpacing: 0.5)),
                                    Text('$usageCount times', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 10, color: kBlack87)),
                                  ]),
                                  Row(mainAxisSize: MainAxisSize.min, children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(color: kOrange.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: kOrange.withValues(alpha: 0.2))),
                                      child: const Text('Edit', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: kOrange)),
                                    ),
                                    const SizedBox(width: 8),
                                    const HeroIcon(HeroIcons.chevronRight, color: kPrimaryColor, size: 16),
                                  ]),
                                ]),
                              ]),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyStateExpenseNames() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [HeroIcon(HeroIcons.documentText, size: 64, color: kGrey300), const SizedBox(height: 16), const Text('No expense names found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kBlack87))]));
  Widget _buildEmptyState() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [HeroIcon(HeroIcons.tag, size: 64, color: kGrey300), const SizedBox(height: 16), const Text('No categories found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kBlack87))]));
  Widget _buildNoResults() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const HeroIcon(HeroIcons.magnifyingGlass, size: 64, color: kGrey300), const SizedBox(height: 16), Text('No results for "$_searchQuery"', style: const TextStyle(color: kBlack54))]));

  void _showAddCategoryDialog(BuildContext context) {
    final TextEditingController nameController = TextEditingController();
    final List<String> suggestions = ['Salary', 'Rent', 'Fuel', 'Food', 'Electricity', 'Bill', 'Insurance', 'Miscellaneous'];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              backgroundColor: kWhite,
              title: const Text('Add New Type', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionLabel("Quick Select"),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: suggestions.map((s) {
                        final bool isSel = nameController.text == s;
                        return GestureDetector(
                          onTap: () => setDialogState(() => nameController.text = s),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSel ? kPrimaryColor : kGreyBg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: isSel ? kPrimaryColor : kGrey200),
                            ),
                            child: Text(s, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: isSel ? kWhite : kBlack54)),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    _buildSectionLabel("Category Identity"),
                    _buildDialogField(nameController, 'Category Name', HeroIcons.tag),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(fontWeight: FontWeight.bold, color: kBlack54))),
                ElevatedButton(
                  onPressed: () async {
                    if (nameController.text.trim().isEmpty) return;
                    await FirestoreService().addDocument('expenseCategories', {
                      'name': nameController.text.trim(),
                      'timestamp': FieldValue.serverTimestamp(),
                      'uid': widget.uid,
                    });
                    if (mounted) Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  child: const Text('ADD Type', style: TextStyle(color: kWhite, fontWeight: FontWeight.w800)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSectionLabel(String text) => Padding(padding: const EdgeInsets.only(bottom: 10, left: 4), child: Text(text, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kBlack54, letterSpacing: 0.5)));

  Widget _buildDialogField(TextEditingController ctrl, String label, HeroIcons icon) {
    return ValueListenableBuilder(
      valueListenable: ctrl,
      builder: (context, val, child) {
        bool filled = ctrl.text.isNotEmpty;
        return Container(
          decoration: BoxDecoration(color: kGreyBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: filled ? kPrimaryColor : kGrey200, width: filled ? 1.5 : 1.0)),
          child: ValueListenableBuilder<TextEditingValue>(
      valueListenable: ctrl,
      builder: (context, value, _) {
        final bool hasText = value.text.isNotEmpty;
        return TextField(
            controller: ctrl,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kBlack87),
            decoration: InputDecoration(hintText: label, prefixIcon: HeroIcon(icon, color: filled ? kPrimaryColor : kBlack54, size: 18),
              filled: true,
              fillColor: const Color(0xFFF8F9FA),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: hasText ? kPrimaryColor : kGrey200, width: hasText ? 1.5 : 1.0),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: hasText ? kPrimaryColor : kGrey200, width: hasText ? 1.5 : 1.0),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: kPrimaryColor, width: 2.0),
              ),
              labelStyle: TextStyle(color: hasText ? kPrimaryColor : kBlack54, fontSize: 13, fontWeight: FontWeight.w600),
              floatingLabelStyle: TextStyle(color: hasText ? kPrimaryColor : kPrimaryColor, fontSize: 11, fontWeight: FontWeight.w900),
            ),
          
);
      },
    ),
        );
      },
    );
  }
}

// -----------------------------------------------------------------------------
// INTERNAL DIALOG: EDIT/DELETE CATEGORY
// -----------------------------------------------------------------------------
class _EditDeleteCategoryDialog extends StatefulWidget {
  final String docId;
  final String initialName;
  final VoidCallback onChanged;
  const _EditDeleteCategoryDialog({required this.docId, required this.initialName, required this.onChanged});
  @override State<_EditDeleteCategoryDialog> createState() => _EditDeleteCategoryDialogState();
}

class _EditDeleteCategoryDialogState extends State<_EditDeleteCategoryDialog> {
  late TextEditingController _controller;
  bool _isLoading = false;

  @override
  void initState() { super.initState(); _controller = TextEditingController(text: widget.initialName); }
  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  Future<void> _update() async {
    if (_controller.text.trim().isEmpty) return;
    setState(() => _isLoading = true);
    try {
      await FirestoreService().updateDocument('expenseCategories', widget.docId, {'name': _controller.text.trim()});
      widget.onChanged();
      if (mounted) Navigator.pop(context);
    } catch (e) { print(e.toString()); }
    finally { if (mounted) setState(() => _isLoading = false); }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), title: const Text('Delete Category?'), content: const Text('This will remove this category from the system.'), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: kErrorColor), onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: kWhite)))]));
    if (confirm == true) {
      setState(() => _isLoading = true);
      await FirestoreService().deleteDocument('expenseCategories', widget.docId);
      widget.onChanged();
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: kWhite,
      title: const Text('Edit Type', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(color: kGreyBg, borderRadius: BorderRadius.circular(12)),
            child: ValueListenableBuilder<TextEditingValue>(
      valueListenable: _controller,
      builder: (context, value, _) {
        final bool hasText = value.text.isNotEmpty;
        return TextField(
              controller: _controller,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              decoration: InputDecoration(prefixIcon: HeroIcon(HeroIcons.pencil, color: kPrimaryColor, size: 18),
                filled: true,
                fillColor: const Color(0xFFF8F9FA),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: hasText ? kPrimaryColor : kGrey200, width: hasText ? 1.5 : 1.0),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: hasText ? kPrimaryColor : kGrey200, width: hasText ? 1.5 : 1.0),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: kPrimaryColor, width: 2.0),
                ),
                labelStyle: TextStyle(color: hasText ? kPrimaryColor : kBlack54, fontSize: 13, fontWeight: FontWeight.w600),
                floatingLabelStyle: TextStyle(color: hasText ? kPrimaryColor : kPrimaryColor, fontSize: 11, fontWeight: FontWeight.w900),
              ),
            
);
      },
    ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: _delete, child: const Text("Delete", style: TextStyle(color: kErrorColor,fontWeight: FontWeight.bold))),
        ElevatedButton(onPressed: _update, style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, elevation: 0), child: const Text("Save", style: TextStyle(color: kWhite))),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// INTERNAL DIALOG: EDIT/DELETE EXPENSE NAME
// -----------------------------------------------------------------------------
class _EditDeleteExpenseNameDialog extends StatefulWidget {
  final String docId;
  final String initialName;
  final VoidCallback onChanged;
  const _EditDeleteExpenseNameDialog({required this.docId, required this.initialName, required this.onChanged});
  @override State<_EditDeleteExpenseNameDialog> createState() => _EditDeleteExpenseNameDialogState();
}

class _EditDeleteExpenseNameDialogState extends State<_EditDeleteExpenseNameDialog> {
  late TextEditingController _controller;
  @override
  void initState() { super.initState(); _controller = TextEditingController(text: widget.initialName); }
  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: kWhite,
      title: const Text('Edit expense title', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
      content: Container(
        decoration: BoxDecoration(color: kGreyBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: kPrimaryColor, width: 1.5)),
        child: ValueListenableBuilder<TextEditingValue>(
      valueListenable: _controller,
      builder: (context, value, _) {
        final bool hasText = value.text.isNotEmpty;
        return TextField(
          controller: _controller,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          decoration: InputDecoration(prefixIcon: HeroIcon(HeroIcons.bars3BottomLeft, color: kPrimaryColor, size: 18),
            filled: true,
            fillColor: const Color(0xFFF8F9FA),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: hasText ? kPrimaryColor : kGrey200, width: hasText ? 1.5 : 1.0),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: hasText ? kPrimaryColor : kGrey200, width: hasText ? 1.5 : 1.0),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kPrimaryColor, width: 2.0),
            ),
            labelStyle: TextStyle(color: hasText ? kPrimaryColor : kBlack54, fontSize: 13, fontWeight: FontWeight.w600),
            floatingLabelStyle: TextStyle(color: hasText ? kPrimaryColor : kPrimaryColor, fontSize: 11, fontWeight: FontWeight.w900),
          ),
        
);
      },
    ),
      ),
      actions: [
        TextButton(onPressed: () async { await FirestoreService().deleteDocument('expenseNames', widget.docId); widget.onChanged(); if(mounted) Navigator.pop(context); }, child: const Text("Delete", style: TextStyle(color: kErrorColor,fontWeight: FontWeight.bold))),
        ElevatedButton(onPressed: () async { await FirestoreService().updateDocument('expenseNames', widget.docId, {'name': _controller.text.trim()}); widget.onChanged(); if(mounted) Navigator.pop(context); }, style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, elevation: 0), child: const Text("Save", style: TextStyle(color: kWhite))),
      ],
    );
  }
}

// ==========================================
// EXPENSE NAME DETAILS PAGE
// ==========================================
class ExpenseNameDetailsPage extends StatefulWidget {
  final String docId;
  final String name;
  final int usageCount;

  const ExpenseNameDetailsPage({super.key, required this.docId, required this.name, required this.usageCount});

  @override
  State<ExpenseNameDetailsPage> createState() => _ExpenseNameDetailsPageState();
}

class _ExpenseNameDetailsPageState extends State<ExpenseNameDetailsPage> {
  late String _name;
  List<Map<String, dynamic>> _expenses = [];
  bool _isLoading = true;
  String _currencySymbol = '';

  @override
  void initState() {
    super.initState();
    _name = widget.name;
    _loadCurrency();
    _loadExpenses();
  }

  void _loadCurrency() async {
    final storeId = await FirestoreService().getCurrentStoreId();
    if (storeId == null) return;
    final doc = await FirebaseFirestore.instance.collection('store').doc(storeId).get();
    if (doc.exists && mounted) {
      setState(() => _currencySymbol = CurrencyService.getSymbolWithSpace(doc.data()?['currency']));
    }
  }

  Future<void> _loadExpenses() async {
    setState(() => _isLoading = true);
    try {
      final col = await FirestoreService().getStoreCollection('expenses');
      final snap = await col.where('expenseName', isEqualTo: _name).orderBy('timestamp', descending: true).get();
      if (mounted) {
        setState(() {
          _expenses = snap.docs.map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>}).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading expenses by name: $e');
      // Fallback without orderBy
      try {
        final col = await FirestoreService().getStoreCollection('expenses');
        final snap = await col.where('expenseName', isEqualTo: _name).get();
        if (mounted) {
          final docs = snap.docs.map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>}).toList();
          docs.sort((a, b) {
            final tsA = a['timestamp'] as Timestamp?;
            final tsB = b['timestamp'] as Timestamp?;
            if (tsA == null || tsB == null) return 0;
            return tsB.compareTo(tsA);
          });
          setState(() { _expenses = docs; _isLoading = false; });
        }
      } catch (_) {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteExpense(String expenseId, int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: kWhite,
        title: const Text('Delete Expense?', style: TextStyle(fontWeight: FontWeight.w800, color: kBlack87)),
        content: const Text('This expense will be permanently removed. This action cannot be undone.', style: TextStyle(color: kBlack54, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold, color: kBlack54))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: kErrorColor, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text('Delete', style: TextStyle(color: kWhite, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirestoreService().deleteDocument('expenses', expenseId);
        if (mounted) {
          setState(() => _expenses.removeAt(index));
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Expense deleted'), backgroundColor: kGoogleGreen));
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: kErrorColor));
      }
    }
  }

  void _showEditNameDialog() {
    final ctrl = TextEditingController(text: _name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: kWhite,
        title: const Text('Edit Expense Name', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Expense name',
            filled: true, fillColor: kGreyBg,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kGrey200)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kGrey200)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kPrimaryColor, width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await FirestoreService().deleteDocument('expenseNames', widget.docId);
              if (mounted) { Navigator.pop(ctx); Navigator.pop(context); }
            },
            child: const Text('Delete', style: TextStyle(color: kErrorColor, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = ctrl.text.trim();
              if (newName.isEmpty) return;
              await FirestoreService().updateDocument('expenseNames', widget.docId, {'name': newName});
              if (mounted) { setState(() => _name = newName); Navigator.pop(ctx); }
            },
            style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Save', style: TextStyle(color: kWhite, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalAmount = _expenses.fold(0.0, (sum, e) => sum + ((e['amount'] ?? 0) as num).toDouble());

    return Scaffold(
      backgroundColor: kGreyBg,
      appBar: AppBar(
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(bottom: Radius.circular(24))),
        title: Text(_name, style: const TextStyle(color: kWhite, fontWeight: FontWeight.w700, fontSize: 18)),
        backgroundColor: kPrimaryColor,
        leading: IconButton(icon: const HeroIcon(HeroIcons.arrowLeft, color: kWhite, size: 20), onPressed: () => Navigator.pop(context)),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(icon: const HeroIcon(HeroIcons.pencilSquare, color: kWhite, size: 20), onPressed: _showEditNameDialog),
        ],
      ),
      body: RefreshIndicator(
        color: kPrimaryColor,
        onRefresh: _loadExpenses,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Summary Card
            Container(
              decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(12), border: Border.all(color: kGrey200)),
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                Row(children: [
                  CircleAvatar(
                    backgroundColor: kOrange.withValues(alpha: 0.12),
                    radius: 24,
                    child: Text(_name.isNotEmpty ? _name[0].toUpperCase() : 'E',
                        style: const TextStyle(color: kOrange, fontWeight: FontWeight.w900, fontSize: 20)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: kBlack87)),
                    Text('${_expenses.length} ${_expenses.length == 1 ? 'expense' : 'expenses'}',
                        style: const TextStyle(fontSize: 12, color: kBlack54, fontWeight: FontWeight.w500)),
                  ])),
                ]),
                const Divider(height: 20, color: kGreyBg),
                Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                  _buildStat('Expenses', _expenses.length.toString(), kPrimaryColor),
                  _buildStat('Total', '$_currencySymbol${totalAmount.toStringAsFixed(0)}', kErrorColor),
                ]),
              ]),
            ),
            const SizedBox(height: 16),

            // Expenses Header
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 12),
              child: Text('Expense History', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: kBlack87)),
            ),

            // Expenses List
            if (_isLoading)
              const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(color: kPrimaryColor)))
            else if (_expenses.isEmpty)
              Center(child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(children: [
                  const HeroIcon(HeroIcons.documentText, size: 48, color: kGrey300),
                  const SizedBox(height: 12),
                  const Text('No expenses found under this name', style: TextStyle(color: kBlack54, fontWeight: FontWeight.w600)),
                ]),
              ))
            else
              ...List.generate(_expenses.length, (i) {
                final e = _expenses[i];
                final ts = e['timestamp'] as Timestamp?;
                final dateStr = ts != null ? DateFormat('dd MMM yyyy').format(ts.toDate()) : 'N/A';
                final amount = ((e['amount'] ?? 0) as num).toDouble();
                final expenseType = (e['expenseType'] ?? 'Other').toString();
                final paymentMode = (e['paymentMode'] ?? 'Cash').toString();
                final refNumber = (e['referenceNumber'] ?? e['expenseNumber'] ?? '').toString();

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(12), border: Border.all(color: kGrey200)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Column(children: [
                        // Row 1: ref number | date
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Row(children: [
                            const HeroIcon(HeroIcons.documentText, size: 14, color: kPrimaryColor),
                            const SizedBox(width: 5),
                            Text(refNumber.isNotEmpty ? refNumber : 'No Ref', style: const TextStyle(fontWeight: FontWeight.w900, color: kPrimaryColor, fontSize: 13)),
                          ]),
                          Text(dateStr, style: const TextStyle(fontSize: 10.5, color: Colors.black, fontWeight: FontWeight.w500)),
                        ]),
                        const SizedBox(height: 10),
                        // Row 2: expense type | amount
                        Row(children: [
                          Expanded(child: Text(expenseType, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black87))),
                          Text('$_currencySymbol${amount.toStringAsFixed(2)}',
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: kErrorColor)),
                        ]),
                        const Divider(height: 20, color: kGreyBg),
                        // Row 3: payment mode | delete button
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Text('Payment mode', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: kBlack54, letterSpacing: 0.5)),
                            Text(paymentMode, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 10, color: kBlack87)),
                          ]),
                          GestureDetector(
                            onTap: () => _deleteExpense(e['id'], i),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(color: kErrorColor.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8), border: Border.all(color: kErrorColor.withValues(alpha: 0.2))),
                              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                                HeroIcon(HeroIcons.trash, size: 12, color: kErrorColor),
                                SizedBox(width: 4),
                                Text('Delete', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: kErrorColor, letterSpacing: 0.3)),
                              ]),
                            ),
                          ),
                        ]),
                      ]),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String label, String value, Color color) {
    return Column(children: [
      Text(value, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: color)),
      Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: kBlack54, letterSpacing: 0.5)),
    ]);
  }
}
