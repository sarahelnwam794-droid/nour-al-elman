import 'dart:io';
import 'package:flutter/material.dart';
import 'package:project1/services/file_download_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:project1/widgets/skeleton_shimmer.dart';
import 'package:project1/widgets/error_state_widget.dart';
import 'package:project1/widgets/fade_slide_in.dart';

class StudentCoursesWidget extends StatefulWidget {
  final List<dynamic> coursesList;
  final bool isLoading;
  final bool hasError;
  final VoidCallback? onRetry;

  const StudentCoursesWidget({
    super.key,
    required this.coursesList,
    required this.isLoading,
    this.hasError = false,
    this.onRetry,
  });

  @override
  State<StudentCoursesWidget> createState() => _StudentCoursesWidgetState();
}

class _StudentCoursesWidgetState extends State<StudentCoursesWidget> {
  static const String _baseUrl = "https://nourelman.runasp.net";

  @override
  void initState() {
    super.initState();
  }

  String _getExtension(String? url) {
    if (url == null || url.isEmpty) return 'pdf';
    final ext = p.extension(url).replaceFirst('.', '').toLowerCase();
    return ext.isNotEmpty ? ext : 'pdf';
  }

  IconData _iconForExt(String ext) {
    switch (ext) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
        return Icons.image_outlined;
      case 'mp4':
      case 'mov':
      case 'avi':
        return Icons.video_file_outlined;
      case 'mp3':
      case 'wav':
        return Icons.audio_file_outlined;
      case 'pdf':
        return Icons.picture_as_pdf_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }

  Future<void> _downloadFile(dynamic course) async {
    final String? elementId = course['id']?.toString();
    final String? courseUrl = course['url']?.toString();
    if (elementId == null || elementId == '0' || courseUrl == null || courseUrl.isEmpty) {
      _showSnackBar("الملف غير متاح للتحميل");
      return;
    }

    final String courseName = (course['name'] ?? 'file')
        .toString()
        .replaceAll(RegExp(r'[^\u0600-\u06FF\w\s]+'), '_')
        .replaceAll(' ', '_');
    final String ext = _getExtension(courseUrl);
    final String fileName = "${courseName}_$elementId.$ext";

    _showSnackBar("جاري تحميل: ${course['name']}", isError: false);

    final error = await FileDownloadService.downloadAndOpen(
      urls: FileDownloadService.candidatesForPath(courseUrl),
      fileName: fileName,
    );
    if (error != null) _showSnackBar(error);
  }

  void _showSnackBar(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontFamily: 'Almarai')),
      backgroundColor: isError ? Colors.red : Colors.green,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Widget _buildDownloadButton(dynamic course) {
    return InkWell(
      onTap: () => _downloadFile(course),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _iconForExt(_getExtension(course['url']?.toString())),
              color: const Color(0xFFC66422),
              size: 22,
            ),
            const SizedBox(width: 4),
            const Text(
              "تحميل",
              style: TextStyle(
                color: Color(0xFFC66422),
                fontWeight: FontWeight.bold,
                fontFamily: 'Almarai',
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (widget.isLoading) {
      return SkeletonShimmer(
        key: const ValueKey('loading'),
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: 5,
          itemBuilder: (context, index) => Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Container(
                  width: 42, height: 42,
                  margin: const EdgeInsets.only(left: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC66422).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Bone(width: 120, height: 13),
                      SizedBox(height: 10),
                      Bone(width: 160, height: 12),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Bone.circle(size: 32),
              ],
            ),
          ),
        ),
      );
    }

    if (widget.hasError) {
      return ErrorStateWidget(key: const ValueKey('error'), onRetry: widget.onRetry ?? () {});
    }

    if (widget.coursesList.isEmpty) {
      return const Center(
          key: ValueKey('empty'),
          child: Text("لا توجد ملفات متاحة حالياً",
              style: TextStyle(fontFamily: 'Almarai')));
    }

    return ListView.builder(
      key: const ValueKey('content'),
      padding: const EdgeInsets.all(16),
      itemCount: widget.coursesList.length,
      itemBuilder: (context, index) {
        final course = widget.coursesList[index];
        final String ext = _getExtension(course['url']?.toString());

        return FadeSlideIn(
          index: index,
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 2)),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(left: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC66422).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(_iconForExt(ext),
                      color: const Color(0xFFC66422), size: 26),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow("الإسم", course['name'] ?? "غير متوفر"),
                      const SizedBox(height: 6),
                      _buildInfoRow(
                          "التفاصيل", course['description'] ?? "لا يوجد وصف"),

                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _buildDownloadButton(course),
              ],
            ),
          ),
        );
      },
    );


  }

  Widget _buildInfoRow(String label, String value) {
    return Wrap(
      alignment: WrapAlignment.start,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text("$label: ",
            style: const TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.w500,
                fontSize: 13,
                fontFamily: 'Almarai')),
        Text(value,
            style: const TextStyle(
                color: Color(0xFF2E3542),
                fontWeight: FontWeight.bold,
                fontSize: 14,
                fontFamily: 'Almarai')),
      ],
    );
  }
}