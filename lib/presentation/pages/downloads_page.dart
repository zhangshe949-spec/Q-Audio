import 'package:q_audio/presentation/widgets/placeholder_page.dart';
import 'package:flutter/material.dart';
import 'package:q_audio/core/constants/app_strings.dart';

/// 下载占位页
class DownloadsPage extends StatelessWidget {
  const DownloadsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PlaceholderPage(
      title: AppStrings.downloads,
      subtitle: AppStrings.placeholderPage,
    );
  }
}
