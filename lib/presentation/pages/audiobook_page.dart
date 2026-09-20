import 'package:q_audio/presentation/widgets/placeholder_page.dart';
import 'package:flutter/material.dart';
import 'package:q_audio/core/constants/app_strings.dart';

/// 小说（audiobook）占位页
class AudiobookPage extends StatelessWidget {
  const AudiobookPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PlaceholderPage(
      title: AppStrings.audiobook,
      subtitle: AppStrings.placeholderPage,
    );
  }
}
