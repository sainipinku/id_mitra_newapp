import 'package:flutter/material.dart';
import 'package:idmitra/models/schools/SchoolListModel.dart';
import 'package:idmitra/models/students/StudentsListModel.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:idmitra/api_mamanger/api_manager.dart';
import 'package:idmitra/api_mamanger/config.dart';
import 'package:idmitra/providers/students/students_cubit.dart';
import 'package:idmitra/screens/partner/dashboard/home/student_profile_page.dart';

const double kCardHeight = 420.0;

class StudentIdCardWidget extends StatelessWidget {
  final StudentDetailsData student;
  final String schoolId;
  final SchoolDetailsModel? schoolDetailsModel;

  const StudentIdCardWidget({
    super.key,
    required this.student,
    required this.schoolId,
    this.schoolDetailsModel,
  });


  Future<bool> _moveToExtra(BuildContext context) async {
    try {
      final response = await ApiManager().postWithoutRequest(
        Config.baseUrl +
            Routes.moveStudentToExtra(
              student.schoolId?.toString() ?? '',
              student.uuid ?? '',
            ),
      );
      return response != null &&
          (response.statusCode == 200 || response.statusCode == 201);
    } catch (e) {
      debugPrint("Move to extra error: $e");
      return false;
    }
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.delete_outline_rounded,
                      size: 50,
                      color: Colors.red.shade400,
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Are you sure you want to\ndelete this student?',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey, height: 1.5),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
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
                                success
                                    ? 'Student deleted successfully'
                                    : 'Failed to delete student',
                              ),
                              backgroundColor:
                              success ? Colors.green : Colors.red,
                            ),
                          );
                        }
                      },
                      child: const Text("Yes, I'm sure"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade300,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('No, cancel'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final cls = student.datumClass?.nameWithprefix ?? '';
    final sec = student.section?.name ?? '';
    final className = cls.isEmpty && sec.isEmpty
        ? ''
        : sec.isEmpty
        ? cls
        : '$cls - $sec';

    final fatherName = student.fatherName ?? '';
    final motherName = student.motherName ?? '';
    final dob = student.dob ?? '';
    final mobile = student.fatherPhone ?? student.phone?.toString() ?? '';
    final address = student.address ?? '';
    final session = student.session?.name ?? '';
    final schoolAddr = schoolDetailsModel?.address ?? '';

    return
      GestureDetector(
        onTap: () {},
        // => Navigator.push(
        //   context,
        //   MaterialPageRoute(
        //     builder: (_) => StudentProfilePage(
        //       student: student,
        //       schoolId: schoolId,
        //     ),
        //  ),
        //  ),
        child: Container(
          height: kCardHeight,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          clipBehavior: Clip.hardEdge,
          child: Column(
            children: [
              SizedBox(
                height: 85,
                child: _TopSection(school: schoolDetailsModel, session: session),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Column(
                  children: [
                    Text(
                      schoolDetailsModel?.name ?? '',
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF8B0000),
                        letterSpacing: 0.2,
                        height: 1.2,
                      ),
                    ),
                    if (schoolAddr.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        schoolAddr,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 7,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1565C0),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 4),
              _StudentPhoto(url: student.profilePhotoUrl),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  (student.name ?? '---').toUpperCase(),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1565C0),
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              if (className.isNotEmpty) ...[
                const SizedBox(height: 4),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFB71C1C),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'CLASS – $className',
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Container(
                height: 1,
                margin: const EdgeInsets.symmetric(horizontal: 12),
                color: Colors.grey.shade200,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 10, 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _InfoLine(
                          label: 'Father',
                          value: fatherName.isEmpty ? '-' : fatherName),
                      _InfoLine(
                          label: 'Mother',
                          value: motherName.isEmpty ? '-' : motherName),
                      _InfoLine(label: 'DOB', value: dob.isEmpty ? '-' : dob),
                      _InfoLine(
                          label: 'Mobile',
                          value: mobile.isEmpty ? '-' : mobile),
                      _InfoLine(
                          label: 'Address',
                          value: address.isEmpty ? '-' : address),
                    ],
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    //_PhonePill(phone: mobile.isEmpty ? '-' : mobile),

                    const SizedBox(width: 16),

                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Extra Button (Comment kar diya hai abhi ke liye)
                        // IconButton(
                        //   onPressed: () async {
                        //     final success = await _moveToExtra(context);
                        //     if (context.mounted) {
                        //       ScaffoldMessenger.of(context).showSnackBar(
                        //         SnackBar(
                        //           content: Text(
                        //             success
                        //                 ? 'Student moved to extra list'
                        //                 : 'Failed to move student to extra',
                        //           ),
                        //           backgroundColor: success ? Colors.green : Colors.red,
                        //         ),
                        //       );
                        //     }
                        //   },
                        //   icon: const Icon(Icons.move_to_inbox, color: Colors.orange, size: 22),
                        //   tooltip: 'Extra',
                        // ),
                        IconButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => StudentProfilePage(
                                student: student,
                                schoolId: schoolId,
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.edit, color: Colors.green, size: 22),
                          tooltip: 'Edit',
                        ),

                        IconButton(
                          onPressed: () => _confirmDelete(context),
                          icon: const Icon(Icons.delete_rounded, color: Colors.red, size: 22),
                          tooltip: 'Delete',
                        ),

                        IconButton(
                          onPressed: () async {
                            final success = await context
                                .read<StudentsCubit>()
                                .toggleStudentStatus(
                              student.uuid ?? '',
                              schoolId,
                              student.status ?? 0,
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    success ? 'Status updated' : 'Failed to update status',
                                  ),
                                  backgroundColor: success ? Colors.green : Colors.red,
                                ),
                              );
                            }
                          },
                          icon: Icon(
                            (student.status ?? 0) == 1
                                ? Icons.toggle_on_rounded
                                : Icons.toggle_off_rounded,
                            size: 26,
                            color: (student.status ?? 0) == 1 ? Colors.green : Colors.red,
                          ),
                          tooltip: (student.status ?? 0) == 1 ? 'Deactivate' : 'Activate',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
  }
}


class _TopSection extends StatelessWidget {
  final SchoolDetailsModel? school;
  final String session;
  const _TopSection({this.school, required this.session});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        Positioned.fill(
          child: Container(color: const Color(0xFFF5ECD7)),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: CustomPaint(
            size: const Size(88, 85),
            painter: _RedCornerPainter(),
          ),
        ),
        Positioned(
          bottom: -28,
          left: -8,
          right: -8,
          child: Container(
            height: 50,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(50)),
            ),
          ),
        ),
        Positioned(
          top: 10,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              height: 50,
              width: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(color: const Color(0xFFB8860B), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 5,
                  ),
                ],
              ),
              child: ClipOval(
                child: (school?.logoUrl != null && school!.logoUrl!.isNotEmpty)
                    ? Image.network(
                  school!.logoUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.school,
                    size: 24,
                    color: Color(0xFF8B0000),
                  ),
                )
                    : const Icon(
                  Icons.school,
                  size: 24,
                  color: Color(0xFF8B0000),
                ),
              ),
            ),
          ),
        ),
        if (session.isNotEmpty)
          Positioned(
            top: 7,
            right: 7,
            child: Text(
              session,
              style: const TextStyle(
                fontSize: 7.5,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        Positioned(
          top: 18,
          right: 22,
          child: Transform.rotate(
            angle: -0.4,
            child: const Icon(
              Icons.send_rounded,
              size: 14,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

class _RedCornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p1 = Paint()..color = const Color(0xFFB71C1C);
    canvas.drawPath(
      Path()
        ..moveTo(size.width, 0)
        ..lineTo(size.width, size.height)
        ..lineTo(size.width * 0.22, size.height)
        ..lineTo(size.width, 0)
        ..close(),
      p1,
    );
    final p2 = Paint()..color = const Color(0xFFD32F2F);
    canvas.drawPath(
      Path()
        ..moveTo(size.width, 0)
        ..lineTo(size.width * 0.48, 0)
        ..lineTo(size.width, size.height * 0.48)
        ..close(),
      p2,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _StudentPhoto extends StatelessWidget {
  final String? url;
  const _StudentPhoto({this.url});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFB71C1C), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: CircleAvatar(
        radius: 36,
        backgroundColor: Colors.grey.shade200,
        backgroundImage:
        (url != null && url!.isNotEmpty) ? NetworkImage(url!) : null,
        child: (url == null || url!.isEmpty)
            ? const Icon(Icons.person, size: 36, color: Colors.grey)
            : null,
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final String label;
  final String value;
  const _InfoLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 46,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: Color(0xFF333333),
            ),
          ),
        ),
        const Text(
          ' - ',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: Color(0xFF333333),
          ),
        ),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 9,
              color: Color(0xFF444444),
            ),
          ),
        ),
      ],
    );
  }
}

// class _PhonePill extends StatelessWidget {
//   final String phone;
//   const _PhonePill({required this.phone});
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
//       decoration: BoxDecoration(
//         color: const Color(0xFFB8860B),
//         borderRadius: BorderRadius.circular(20),
//       ),
//       child: Row(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Container(
//             height: 16,
//             width: 16,
//             decoration: const BoxDecoration(
//               color: Colors.white,
//               shape: BoxShape.circle,
//             ),
//             child: const Icon(Icons.phone, size: 10, color: Color(0xFFB8860B)),
//           ),
//           const SizedBox(width: 6),
//           Text(
//             phone,
//             style: const TextStyle(
//               fontSize: 10,
//               fontWeight: FontWeight.w700,
//               color: Colors.white,
//               letterSpacing: 0.3,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }