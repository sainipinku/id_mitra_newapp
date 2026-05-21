import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:idmitra/models/schools/SchoolListModel.dart';
import 'package:idmitra/models/students/StudentsListModel.dart';
import 'package:idmitra/screens/home/student_profile_page.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:idmitra/providers/students/students_cubit.dart';

const Color kPrimary = Color(0xFF00A0E3);
const Color kPrimaryDk = Color(0xFF0080C0);
const Color kPrimaryLt = Color(0xFF33BAF0);
const Color kWhite = Color(0xFFFFFFFF);
const Color kSurface = Color(0xFFF8FBFF);
const Color kBorder = Color(0xFFE8F4FB);
const Color kTextDark = Color(0xFF1A2332);
const Color kTextMid = Color(0xFF6B7A8D);
const Color kTextLight = Color(0xFFADB8C4);

class StudentIdCardWidget extends StatefulWidget {
  final StudentDetailsData student;
  final String schoolId;
  final SchoolDetailsModel? schoolDetailsModel;

  const StudentIdCardWidget({
    super.key,
    required this.student,
    required this.schoolId,
    this.schoolDetailsModel,
  });

  @override
  State<StudentIdCardWidget> createState() => _StudentIdCardWidgetState();
}

class _StudentIdCardWidgetState extends State<StudentIdCardWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _DeleteDialog(student: widget.student),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cls = widget.student.datumClass?.nameWithprefix ?? '';
    final sec = widget.student.section?.name ?? '';
    final className = cls.isEmpty && sec.isEmpty
        ? ''
        : sec.isEmpty
        ? cls
        : '$cls — $sec';

    final fatherName = widget.student.fatherName ?? '';
    final motherName = widget.student.motherName ?? '';
    final dob = widget.student.dob ?? '';
    final mobile =
        widget.student.fatherPhone ?? widget.student.phone?.toString() ?? '';
    final address = widget.student.address ?? '';
    final session = widget.student.session?.name ?? '';
    final schoolAddr = widget.schoolDetailsModel?.address ?? '';
    final isActive = (widget.student.status ?? 0) == 1;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: kBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: kPrimary.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PremiumCardHeader(
            school: widget.schoolDetailsModel,
            session: session,
            rotationController: _rotationController,
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 26, 20, 0),
            child: Column(
              children: [
                Text(
                  (widget.schoolDetailsModel?.name ?? '').toUpperCase(),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: kPrimary,
                    letterSpacing: 0.8,
                    height: 1.3,
                  ),
                ),
                if (schoolAddr.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    schoolAddr,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 8,
                      color: kTextLight,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],

                const SizedBox(height: 12),

                _AnimatedPhotoRing(
                  student: widget.student,
                  rotationController: _rotationController,
                  isActive: isActive,
                ),

                const SizedBox(height: 10),

                Text(
                  (widget.student.name ?? '---').toUpperCase(),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: kTextDark,
                    letterSpacing: 1.2,
                  ),
                ),

                const SizedBox(height: 6),

                if (className.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [kPrimaryDk, kPrimary, kPrimaryLt],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: kPrimary.withOpacity(0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Text(
                      'CLASS  $className',
                      style: const TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                        color: kWhite,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),

                const SizedBox(height: 12),

                _GradientDivider(),

                const SizedBox(height: 10),

                _PremiumInfoRow(
                  icon: Icons.person_outline_rounded,
                  label: 'Father',
                  value: fatherName.isEmpty ? '—' : fatherName,
                ),
                const SizedBox(height: 6),
                // _PremiumInfoRow(
                //   icon: Icons.person_2_outlined,
                //   label: 'Mother',
                //   value: motherName.isEmpty ? '—' : motherName,
                // ),
                // const SizedBox(height: 6),
                // _PremiumInfoRow(
                //   icon: Icons.cake_outlined,
                //   label: 'DOB',
                //   value: dob.isEmpty ? '—' : dob,
                // ),
                // const SizedBox(height: 6),
                _PremiumInfoRow(
                  icon: Icons.phone_outlined,
                  label: 'Mobile',
                  value: mobile.isEmpty ? '—' : mobile,
                ),
                const SizedBox(height: 6),
                _PremiumInfoRow(
                  icon: Icons.location_on_outlined,
                  label: 'Address',
                  value: address.isEmpty ? '—' : address,
                ),

                const SizedBox(height: 12),

                const SizedBox(height: 4),
              ],
            ),
          ),

          _PremiumFooter(
            isActive: isActive,
            onEdit: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => StudentProfilePage(
                  student: widget.student,
                  schoolId: widget.schoolId,
                ),
              ),
            ),
            onDelete: () => _confirmDelete(context),
            onToggle: () async {
              final success = await context
                  .read<StudentsCubit>()
                  .toggleStudentStatus(
                    widget.student.uuid ?? '',
                    widget.schoolId,
                    widget.student.status ?? 0,
                  );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success ? 'Status updated' : 'Failed to update',
                    ),
                    backgroundColor: success ? Colors.green : Colors.red,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

class _PremiumCardHeader extends StatelessWidget {
  final SchoolDetailsModel? school;
  final String session;
  final AnimationController rotationController;

  const _PremiumCardHeader({
    this.school,
    required this.session,
    required this.rotationController,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [kPrimaryDk, kPrimary, kPrimaryLt],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),

          Positioned.fill(child: _DotPatternPainter()),

          Positioned(
            top: -20,
            right: -20,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.07),
              ),
            ),
          ),
          Positioned(
            top: 5,
            right: 38,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          Positioned(
            bottom: -28,
            left: -15,
            child: Container(
              width: 75,
              height: 75,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.06),
              ),
            ),
          ),

          const Positioned(
            top: 12,
            left: 16,
            child: Text(
              'STUDENT · ID  · CARD',
              style: TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 2.0,
              ),
            ),
          ),

          if (session.isNotEmpty)
            Positioned(
              top: 9,
              right: 13,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.25),
                    width: 1,
                  ),
                ),
                child: Text(
                  session,
                  style: const TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          Positioned(
            bottom: -20,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: kWhite,
                  border: Border.all(
                    color: kPrimary.withOpacity(0.15),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: kPrimary.withOpacity(0.2),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipOval(
                  child:
                      (school?.logoUrl != null && school!.logoUrl!.isNotEmpty)
                      ? Image.network(
                          school!.logoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.school_rounded,
                            size: 20,
                            color: kPrimary,
                          ),
                        )
                      : const Icon(
                          Icons.school_rounded,
                          size: 20,
                          color: kPrimary,
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DotPatternPainter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _DotPainter());
  }
}

class _DotPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.12)
      ..style = PaintingStyle.fill;

    const spacing = 16.0;
    const radius = 1.2;

    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AnimatedPhotoRing extends StatelessWidget {
  final StudentDetailsData student;
  final AnimationController rotationController;
  final bool isActive;

  const _AnimatedPhotoRing({
    required this.student,
    required this.rotationController,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final url = student.profilePhotoUrl;
    final isOffline = student.isPhotoPendingSync && student.offlinePhotoPath != null;

    return SizedBox(
      width: 88,
      height: 88,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // ... (keep the existing rotation container logic)
          AnimatedBuilder(
            animation: rotationController,
            builder: (context, child) {
              return Transform.rotate(
                angle: rotationController.value * 2 * math.pi,
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: isActive
                        ? const SweepGradient(
                            colors: [
                              kPrimaryDk,
                              kPrimaryLt,
                              kWhite,
                              kPrimary,
                              kPrimaryDk,
                            ],
                          )
                        : const SweepGradient(
                            colors: [
                              Color(0xFFCCCCCC),
                              Color(0xFFEEEEEE),
                              Color(0xFFCCCCCC),
                            ],
                          ),
                  ),
                ),
              );
            },
          ),
          Container(
            width: 82,
            height: 82,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: kWhite,
            ),
          ),
          Container(
            width: 76,
            height: 76,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFF0F0F0),
            ),
            clipBehavior: Clip.hardEdge,
            child: isOffline
                ? Image.file(
                    File(student.offlinePhotoPath!),
                    fit: BoxFit.cover,
                  )
                : (url != null && url.isNotEmpty)
                    ? Image.network(
                        url,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.person_rounded,
                          size: 36,
                          color: Color(0xFFBBBBBB),
                        ),
                      )
                    : const Icon(
                        Icons.person_rounded,
                        size: 36,
                        color: Color(0xFFBBBBBB),
                      ),
          ),
        ],
      ),
    );
  }
}

class _GradientDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            kBorder,
            kPrimary,
            kBorder,
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

class _PremiumInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _PremiumInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Icon box
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: kPrimary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Icon(icon, size: 11, color: kPrimary),
        ),
        const SizedBox(width: 7),
        // Label
        SizedBox(
          width: 44,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
              color: kTextMid,
              letterSpacing: 0.2,
            ),
          ),
        ),
        // Separator
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 5),
          child: Text('·', style: TextStyle(fontSize: 9, color: kTextLight)),
        ),
        // Value
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w500,
              color: kTextDark,
            ),
          ),
        ),
      ],
    );
  }
}

class _PremiumFooter extends StatelessWidget {
  final bool isActive;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggle;

  const _PremiumFooter({
    required this.isActive,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kSurface,
        border: Border(top: BorderSide(color: kBorder, width: 0.8)),
      ),
      child: Row(
        children: [
          // Edit
          Expanded(
            child: _FooterButton(
              icon: Icons.edit_outlined,
              label: 'Edit',
              iconColor: const Color(0xFF2E7D32),
              iconBg: const Color(0xFFEDF7ED),
              onTap: onEdit,
            ),
          ),
          _FooterDivider(),
          // Delete
          Expanded(
            child: _FooterButton(
              icon: Icons.delete_outline_rounded,
              label: 'Delete',
              iconColor: const Color(0xFFC62828),
              iconBg: const Color(0xFFFDEDED),
              onTap: onDelete,
            ),
          ),
          _FooterDivider(),
          // Toggle
          Expanded(
            child: _ToggleFooterButton(isActive: isActive, onTap: onToggle),
          ),
        ],
      ),
    );
  }
}

class _FooterDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 0.8, height: 44, color: kBorder);
  }
}

class _FooterButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color iconColor;
  final Color iconBg;
  final VoidCallback onTap;

  const _FooterButton({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.iconBg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: iconColor.withOpacity(0.08),
        highlightColor: iconColor.withOpacity(0.04),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 15, color: iconColor),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 7.5,
                  fontWeight: FontWeight.w700,
                  color: iconColor,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToggleFooterButton extends StatelessWidget {
  final bool isActive;
  final VoidCallback onTap;

  const _ToggleFooterButton({required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final Color color = isActive
        ? const Color(0xFF2E7D32)
        : const Color(0xFFBBBBBB);
    final Color bg = isActive
        ? const Color(0xFFEDF7ED)
        : const Color(0xFFF5F5F5);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: color.withOpacity(0.08),
        highlightColor: color.withOpacity(0.04),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    width: 28,
                    height: 15,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Align(
                      alignment: isActive
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        width: 11,
                        height: 11,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isActive ? 'Active' : 'Inactive',
                style: TextStyle(
                  fontSize: 7.5,
                  fontWeight: FontWeight.w700,
                  color: color,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeleteDialog extends StatelessWidget {
  final StudentDetailsData student;

  const _DeleteDialog({required this.student});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      elevation: 24,
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    Colors.red.shade50,
                    Colors.red.shade100.withOpacity(0.3),
                  ],
                ),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.red.shade100, width: 1.5),
              ),
              child: Icon(
                Icons.delete_outline_rounded,
                size: 32,
                color: Colors.red.shade400,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Delete Student?',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: kTextDark,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'This action cannot be undone.',
              style: TextStyle(fontSize: 12.5, color: kTextMid),
            ),
            const SizedBox(height: 26),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () async {
                      Navigator.pop(context);
                      final success = await context
                          .read<StudentsCubit>()
                          .deleteStudent(
                            student.uuid ?? '',
                            student.schoolId?.toString() ?? '',
                          );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              success ? 'Student deleted' : 'Failed to delete',
                            ),
                            backgroundColor: success
                                ? Colors.green
                                : Colors.red,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        );
                      }
                    },
                    child: const Text(
                      'Yes, Delete',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kTextMid,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      side: const BorderSide(
                        color: Color(0xFFE0E0E0),
                        width: 1,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
