import 'package:flutter/material.dart';
import 'package:idmitra/components/app_theme.dart';
import 'package:idmitra/utils/MyStyles.dart';


class _Homework {
  final String subject;
  final String title;
  final String description;
  final String dueDate;
  final bool isSubmitted;
  final Color subjectColor;

  const _Homework({
    required this.subject,
    required this.title,
    required this.description,
    required this.dueDate,
    required this.isSubmitted,
    required this.subjectColor,
  });
}

const _kHomework = [
  _Homework(
    subject: 'Math',
    title: 'Chapter 5 - Fractions',
    description: 'Solve exercises 5.1 to 5.4 from the textbook.',
    dueDate: '12 May 2026',
    isSubmitted: false,
    subjectColor: Color(0xFF3C40B6),
  ),
  _Homework(
    subject: 'Science',
    title: 'Plant Cell Diagram',
    description: 'Draw and label a plant cell diagram.',
    dueDate: '13 May 2026',
    isSubmitted: false,
    subjectColor: Color(0xFF008F70),
  ),
  _Homework(
    subject: 'English',
    title: 'Essay Writing',
    description: 'Write a 200-word essay on "My Favourite Season".',
    dueDate: '11 May 2026',
    isSubmitted: true,
    subjectColor: Color(0xFFF2A922),
  ),
  _Homework(
    subject: 'Hindi',
    title: 'Poem Recitation',
    description: 'Learn and recite the poem "Nanha Munna Rahi Hoon".',
    dueDate: '10 May 2026',
    isSubmitted: true,
    subjectColor: Color(0xFFD32F2F),
  ),
  _Homework(
    subject: 'Social Studies',
    title: 'Map Work',
    description: 'Mark the major rivers of India on the outline map.',
    dueDate: '14 May 2026',
    isSubmitted: false,
    subjectColor: Color(0xFF7B1FA2),
  ),
];


class ViewHomeworkScreen extends StatefulWidget {
  const ViewHomeworkScreen({super.key});

  @override
  State<ViewHomeworkScreen> createState() => _ViewHomeworkScreenState();
}

class _ViewHomeworkScreenState extends State<ViewHomeworkScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pending = _kHomework.where((h) => !h.isSubmitted).toList();
    final submitted = _kHomework.where((h) => h.isSubmitted).toList();

    return Scaffold(
      backgroundColor: AppTheme.appBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          color: AppTheme.black_Color,
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Homework',
            style: MyStyles.boldTxt(AppTheme.black_Color, 17)),
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            decoration: BoxDecoration(
              color: AppTheme.appBackgroundColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: AppTheme.btnColor,
                borderRadius: BorderRadius.circular(10),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.white,
              unselectedLabelColor: AppTheme.graySubTitleColor,
              labelStyle: MyStyles.semiBoldTxt(Colors.white, 13),
              unselectedLabelStyle:
                  MyStyles.regularTxt(AppTheme.graySubTitleColor, 13),
              dividerColor: Colors.transparent,
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Pending'),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('${pending.length}',
                            style: MyStyles.boldTxt(Colors.red, 10)),
                      ),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Submitted'),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('${submitted.length}',
                            style: MyStyles.boldTxt(Colors.green, 10)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _HomeworkList(items: pending),
          _HomeworkList(items: submitted),
        ],
      ),
    );
  }
}

class _HomeworkList extends StatelessWidget {
  final List<_Homework> items;
  const _HomeworkList({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline,
                size: 56, color: Colors.green.shade300),
            const SizedBox(height: 12),
            Text('All caught up!',
                style: MyStyles.boldTxt(AppTheme.black_Color, 16)),
            const SizedBox(height: 4),
            Text('No homework here.',
                style: MyStyles.regularTxt(AppTheme.graySubTitleColor, 13)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (_, i) => _HomeworkCard(hw: items[i]),
    );
  }
}

class _HomeworkCard extends StatelessWidget {
  final _Homework hw;
  const _HomeworkCard({required this.hw});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05), blurRadius: 6),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Row(
          children: [
            // Subject color strip
            Container(
              width: 4,
              height: 90,
              color: hw.subjectColor,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: hw.subjectColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(hw.subject,
                              style: MyStyles.boldTxt(hw.subjectColor, 11)),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: hw.isSubmitted
                                ? Colors.green.shade50
                                : Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                hw.isSubmitted
                                    ? Icons.check_circle_rounded
                                    : Icons.pending_rounded,
                                size: 12,
                                color: hw.isSubmitted
                                    ? Colors.green
                                    : Colors.orange,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                hw.isSubmitted ? 'Submitted' : 'Pending',
                                style: MyStyles.mediumTxt(
                                    hw.isSubmitted
                                        ? Colors.green
                                        : Colors.orange,
                                    10),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(hw.title,
                        style: MyStyles.boldTxt(AppTheme.black_Color, 13)),
                    const SizedBox(height: 4),
                    Text(hw.description,
                        style: MyStyles.regularTxt(
                            AppTheme.graySubTitleColor, 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.calendar_today_outlined,
                            size: 12,
                            color: AppTheme.graySubTitleColor),
                        const SizedBox(width: 4),
                        Text('Due: ${hw.dueDate}',
                            style: MyStyles.regularTxt(
                                AppTheme.graySubTitleColor, 11)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
