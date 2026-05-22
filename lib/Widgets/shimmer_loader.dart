import 'package:flutter/material.dart';
import 'package:shimmer_animation/shimmer_animation.dart';


Widget shimmerBox({
  double width = double.infinity,
  double height = 20,
  double radius = 10,
}) {
  return Shimmer(
    duration: const Duration(seconds: 1),
    interval: const Duration(milliseconds: 200),
    color: Colors.white,
    colorOpacity: 0.4,
    enabled: true,
    direction: const ShimmerDirection.fromLTRB(),
    child: Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(radius),
      ),
    ),
  );
}


class ShimmerList extends StatelessWidget {
  const ShimmerList({
    super.key,
    this.itemCount = 8,
    this.avatarSize = 52,
    this.isCircle = true,
    this.lineCount = 3,
    this.expanded = true,
  });

  final int itemCount;
  final double avatarSize;
  final bool isCircle;
  final int lineCount;
  final bool expanded;

  Widget _row() {
    final radius = isCircle ? avatarSize / 2 : 10.0;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
      ),
      child: Row(
        children: [
          shimmerBox(width: avatarSize, height: avatarSize, radius: radius),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(lineCount, (i) {
                final widths = [double.infinity, 140.0, 100.0, 80.0];
                return Padding(
                  padding: EdgeInsets.only(bottom: i < lineCount - 1 ? 8 : 0),
                  child: shimmerBox(
                    height: i == 0 ? 14 : 12,
                    width: i < widths.length ? widths[i] : double.infinity,
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = ListView.builder(
      itemCount: itemCount,
      itemBuilder: (_, __) => _row(),
    );
    return expanded ? Expanded(child: list) : list;
  }
}


class ShimmerForm extends StatelessWidget {
  const ShimmerForm({super.key, this.fieldCount = 6});

  final int fieldCount;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: List.generate(fieldCount, (i) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              shimmerBox(height: 12, width: 100),
              const SizedBox(height: 8),
              shimmerBox(height: 48, radius: 12),
            ],
          ),
        )),
      ),
    );
  }
}


class ShimmerDetail extends StatelessWidget {
  const ShimmerDetail({
    super.key,
    this.sectionRowCounts = const [4, 5],
    this.showAvatar = true,
  });

  final List<int> sectionRowCounts;
  final bool showAvatar;

  Widget _section(int rows) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: shimmerBox(height: 14, width: 120),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: List.generate(rows, (i) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  shimmerBox(width: 100, height: 12),
                  shimmerBox(width: 120, height: 12),
                ],
              ),
            )),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (showAvatar)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  shimmerBox(width: 72, height: 72, radius: 36),
                  const SizedBox(height: 12),
                  shimmerBox(width: 100, height: 16),
                  const SizedBox(height: 8),
                  shimmerBox(width: 140, height: 14),
                  const SizedBox(height: 8),
                  shimmerBox(width: 80, height: 24, radius: 20),
                ],
              ),
            ),
          ...sectionRowCounts.map(_section),
        ],
      ),
    );
  }
}


class ShimmerGrid extends StatelessWidget {
  const ShimmerGrid({
    super.key,
    this.itemCount = 6,
    this.crossAxisCount = 2,
    this.childAspectRatio = 1.4,
  });

  final int itemCount;
  final int crossAxisCount;
  final double childAspectRatio;

  Widget _card() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        shimmerBox(width: 40, height: 40, radius: 10),
        const SizedBox(height: 10),
        shimmerBox(width: 80, height: 14),
        const SizedBox(height: 6),
        shimmerBox(width: 50, height: 18),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: crossAxisCount,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: childAspectRatio,
      children: List.generate(itemCount, (_) => _card()),
    );
  }
}


class ShimmerAppBar extends StatelessWidget {
  const ShimmerAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          shimmerBox(width: 40, height: 40, radius: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                shimmerBox(height: 16, width: 120),
                const SizedBox(height: 6),
                shimmerBox(height: 12, width: 90),
              ],
            ),
          ),
          shimmerBox(width: 40, height: 40, radius: 20),
          const SizedBox(width: 8),
          shimmerBox(width: 40, height: 40, radius: 20),
        ],
      ),
    );
  }
}


class ShimmerProfileHeader extends StatelessWidget {
  const ShimmerProfileHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 30),
      child: Column(
        children: [
          const SizedBox(height: 20),
          shimmerBox(width: 110, height: 110, radius: 55),
          const SizedBox(height: 16),
          shimmerBox(width: 140, height: 18),
          const SizedBox(height: 8),
          shimmerBox(width: 180, height: 14),
          const SizedBox(height: 8),
          shimmerBox(width: 120, height: 13),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}


typedef HomeShimmer = ShimmerGrid;
typedef StudentListShimmer = ShimmerList;
class SchoolListShimmer extends ShimmerList {
  const SchoolListShimmer({super.key}) : super(avatarSize: 48, lineCount: 4);
}
class OrderListShimmer extends StatelessWidget {
  const OrderListShimmer({super.key});
  @override
  Widget build(BuildContext context) => ShimmerList(
    itemCount: 6,
    avatarSize: 56,
    isCircle: false,
    lineCount: 3,
    expanded: false,
  );
}
typedef OrderDetailShimmer = ShimmerDetail;
typedef StudentProfileShimmer = ShimmerDetail;
typedef StudentFormShimmer = ShimmerForm;
typedef AddStudentFormShimmer = ShimmerForm;
typedef ProfileHeaderShimmer = ShimmerProfileHeader;
typedef DashboardAppBarShimmer = ShimmerAppBar;

class HolidayListShimmer extends StatelessWidget {
  const HolidayListShimmer({super.key, this.itemCount = 6});
  final int itemCount;

  Widget _card() => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        shimmerBox(width: 46, height: 56, radius: 10),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: shimmerBox(height: 16)),
                  const SizedBox(width: 8),
                  shimmerBox(width: 60, height: 14, radius: 20),
                ],
              ),
              const SizedBox(height: 8),
              shimmerBox(height: 12, width: 200),
              const SizedBox(height: 8),
              Row(
                children: [
                  shimmerBox(width: 110, height: 22, radius: 20),
                  const SizedBox(width: 6),
                  shimmerBox(width: 110, height: 22, radius: 20),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        shimmerBox(width: 20, height: 20, radius: 4),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => ListView.builder(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    itemCount: itemCount,
    itemBuilder: (_, __) => _card(),
  );
}

class HolidayCalendarShimmer extends StatelessWidget {
  const HolidayCalendarShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Calendar card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    shimmerBox(width: 32, height: 32, radius: 8),
                    const SizedBox(width: 10),
                    shimmerBox(width: 120, height: 16),
                    const Spacer(),
                    shimmerBox(width: 60, height: 28, radius: 8),
                    const SizedBox(width: 10),
                    shimmerBox(width: 32, height: 32, radius: 8),
                  ],
                ),
                const SizedBox(height: 12),
                // Day headers
                Row(
                  children: List.generate(7, (_) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: shimmerBox(height: 12),
                    ),
                  )),
                ),
                const SizedBox(height: 8),
                // Grid cells
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    childAspectRatio: 0.95,
                  ),
                  itemCount: 35,
                  itemBuilder: (_, __) => Padding(
                    padding: const EdgeInsets.all(2),
                    child: shimmerBox(height: double.infinity, radius: 8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Summary panel
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                shimmerBox(width: 140, height: 16),
                const SizedBox(height: 12),
                ...List.generate(3, (_) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      shimmerBox(width: 10, height: 10, radius: 5),
                      const SizedBox(width: 8),
                      Expanded(child: shimmerBox(height: 12)),
                      const SizedBox(width: 8),
                      shimmerBox(width: 60, height: 12),
                    ],
                  ),
                )),
                const Divider(height: 20),
                Row(
                  children: List.generate(4, (i) => Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: i < 3 ? 8 : 0),
                      child: shimmerBox(height: 48, radius: 10),
                    ),
                  )),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class StaffOrderListShimmer extends StatelessWidget {
  StaffOrderListShimmer({super.key, this.itemCount = 6});
  final int itemCount;

  Widget _card() => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        shimmerBox(width: 60, height: 60, radius: 6),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: shimmerBox(height: 14)),
                  const SizedBox(width: 8),
                  shimmerBox(width: 80, height: 14),
                ],
              ),
              const SizedBox(height: 8),
              shimmerBox(height: 12, width: 140),
              const SizedBox(height: 8),
              Row(
                children: [
                  shimmerBox(width: 80, height: 20, radius: 20),
                  const Spacer(),
                  shimmerBox(width: 70, height: 12),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        shimmerBox(width: 20, height: 20, radius: 4),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => ListView.builder(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
    itemCount: itemCount,
    itemBuilder: (_, __) => _card(),
  );
}



class AttendanceStatsShimmer extends StatelessWidget {
  const AttendanceStatsShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: List.generate(5, (i) => Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < 4 ? 8 : 0),
            child: Column(
              children: [
                shimmerBox(height: 18, width: 36),
                const SizedBox(height: 5),
                shimmerBox(height: 10, width: 44),
              ],
            ),
          ),
        )),
      ),
    );
  }
}

class AttendanceCardShimmer extends StatelessWidget {
  const AttendanceCardShimmer({super.key, this.itemCount = 8});
  final int itemCount;

  Widget _card() => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        // avatar circle
        shimmerBox(width: 52, height: 52, radius: 26),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // name + roll row
              Row(
                children: [
                  Expanded(child: shimmerBox(height: 14)),
                  const SizedBox(width: 8),
                  shimmerBox(width: 50, height: 13),
                ],
              ),
              const SizedBox(height: 7),
              shimmerBox(height: 11, width: 160), // father name
              const SizedBox(height: 5),
              shimmerBox(height: 11, width: 140), // mother name
              const SizedBox(height: 7),
              shimmerBox(width: 70, height: 22, radius: 20), // status badge
            ],
          ),
        ),
        const SizedBox(width: 10),
        // toggle pill
        shimmerBox(width: 52, height: 28, radius: 20),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        itemCount: itemCount,
        itemBuilder: (_, __) => _card(),
      ),
    );
  }
}

class AttendanceBulkBottomShimmer extends StatelessWidget {
  const AttendanceBulkBottomShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(child: shimmerBox(height: 48, radius: 12)),
          const SizedBox(width: 12),
          Expanded(child: shimmerBox(height: 48, radius: 12)),
        ],
      ),
    );
  }
}
