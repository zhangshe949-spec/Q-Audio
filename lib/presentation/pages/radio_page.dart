import 'package:q_audio/presentation/widgets/placeholder_page.dart';
import 'package:flutter/material.dart';
import 'package:q_audio/core/constants/app_strings.dart';

/// 电台占位页
class RadioPage extends StatelessWidget {
  const RadioPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PlaceholderPage(
      title: AppStrings.radio,
      subtitle: AppStrings.placeholderPage,
    );
  }
}
