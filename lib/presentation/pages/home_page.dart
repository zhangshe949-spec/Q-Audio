import 'package:q_audio/presentation/widgets/placeholder_page.dart';
import 'package:flutter/material.dart';
import 'package:q_audio/core/constants/app_strings.dart';

/// 首页占位页
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return PlaceholderPage(
      title: AppStrings.home,
      subtitle: AppStrings.placeholderPage,
    );
  }
}
