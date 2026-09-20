import 'package:q_audio/presentation/widgets/placeholder_page.dart';
import 'package:flutter/material.dart';
import 'package:q_audio/core/constants/app_strings.dart';

/// 播客占位页
class PodcastPage extends StatelessWidget {
  const PodcastPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PlaceholderPage(
      title: AppStrings.podcast,
      subtitle: AppStrings.placeholderPage,
    );
  }
}
