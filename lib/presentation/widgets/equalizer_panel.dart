import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/equalizer/equalizer_providers.dart';

/// 均衡器面板组件
class EqualizerPanel extends ConsumerStatefulWidget {
  const EqualizerPanel({super.key});

  @override
  ConsumerState<EqualizerPanel> createState() => _EqualizerPanelState();
}

class _EqualizerPanelState extends ConsumerState<EqualizerPanel>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

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
    final enabled = ref.watch(equalizerEnabledProvider);
    final currentPresetId = ref.watch(equalizerCurrentPresetProvider);
    final customGains = ref.watch(equalizerCustomGainsProvider);
    final service = ref.read(equalizerServiceProvider);
    final allPresets = service.getAllPresets();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 头部：启用开关 + 预设选择
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Icon(
                Icons.equalizer,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Text(
                '均衡器',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const Spacer(),
              Switch(
                value: enabled,
                onChanged: (v) =>
                    ref.read(equalizerEnabledProvider.notifier).setEnabled(v),
              ),
            ],
          ),
        ),

        // 预设选择器
        if (enabled) ...[
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: DropdownButtonFormField<String>(
              value: currentPresetId,
              decoration: const InputDecoration(
                labelText: '预设',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: allPresets.map((preset) {
                return DropdownMenuItem<String>(
                  value: preset.id,
                  child: Row(
                    children: [
                      Text(preset.name),
                      if (preset.isCustom) ...[
                        const SizedBox(width: 8),
                        Icon(
                          Icons.star,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  ref
                      .read(equalizerCurrentPresetProvider.notifier)
                      .selectPreset(value);
                }
              },
            ),
          ),

          // 10 段均衡器滑块
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child:
                _buildBands(context, customGains, currentPresetId == 'custom'),
          ),

          // 底部操作栏
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              children: [
                if (currentPresetId == 'custom')
                  TextButton.icon(
                    onPressed: () =>
                        _showSavePresetDialog(context, ref, customGains),
                    icon: const Icon(Icons.save),
                    label: const Text('保存为预设'),
                  )
                else if (service.customPresets
                    .any((p) => p.id == currentPresetId))
                  TextButton.icon(
                    onPressed: () =>
                        _confirmDeletePreset(context, ref, currentPresetId),
                    icon: const Icon(Icons.delete, color: Colors.red),
                    label:
                        const Text('删除预设', style: TextStyle(color: Colors.red)),
                  ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () =>
                      ref.read(equalizerCustomGainsProvider.notifier).reset(),
                  icon: const Icon(Icons.restore),
                  label: const Text('重置'),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBands(BuildContext context, List<double> gains, bool isCustom) {
    final labels = [
      '31',
      '62',
      '125',
      '250',
      '500',
      '1k',
      '2k',
      '4k',
      '8k',
      '16k'
    ];
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 180,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(10, (i) {
          return Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // 增益值显示
                Text(
                  gains[i] == 0
                      ? '0'
                      : gains[i] > 0
                          ? '+${gains[i].toStringAsFixed(1)}'
                          : gains[i].toStringAsFixed(1),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: gains[i] != 0
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                        fontWeight:
                            gains[i] != 0 ? FontWeight.w600 : FontWeight.normal,
                      ),
                ),
                const SizedBox(height: 4),
                // 滑块轨道
                Expanded(
                  child: RotatedBox(
                    quarterTurns: -1,
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 4,
                        thumbShape:
                            const RoundSliderThumbShape(enabledThumbRadius: 8),
                        overlayShape:
                            const RoundSliderOverlayShape(overlayRadius: 16),
                        activeTrackColor: gains[i] != 0
                            ? colorScheme.primary
                            : colorScheme.primary.withOpacity(0.5),
                        inactiveTrackColor: colorScheme.surfaceContainerHighest,
                        thumbColor: gains[i] != 0
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                      ),
                      child: Slider(
                        value: gains[i],
                        min: -12.0,
                        max: 12.0,
                        divisions: 48,
                        label: gains[i].toStringAsFixed(1),
                        onChanged: isCustom
                            ? (value) => ref
                                .read(equalizerCustomGainsProvider.notifier)
                                .updateBand(i, value)
                            : null,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                // 频率标签
                Text(
                  labels[i],
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
                Text(
                  'Hz',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 9,
                      ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Future<void> _showSavePresetDialog(
    BuildContext context,
    WidgetRef ref,
    List<double> gains,
  ) async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('保存均衡器预设'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '预设名称',
            hintText: '输入自定义预设名称',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                ref
                    .read(equalizerServiceProvider)
                    .saveCustomPreset(name, gains);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('已保存预设：$name')),
                );
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeletePreset(
    BuildContext context,
    WidgetRef ref,
    String presetId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除预设'),
        content: const Text('确定要删除这个自定义预设吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(equalizerServiceProvider).deleteCustomPreset(presetId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('预设已删除')),
        );
      }
    }
  }
}

/// 迷你均衡器按钮（用于 PlayerPage 顶部栏）
class EqualizerButton extends ConsumerWidget {
  const EqualizerButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(equalizerEnabledProvider);

    return IconButton(
      key: const Key('equalizer-button'),
      icon: Icon(
        enabled ? Icons.equalizer : Icons.equalizer_outlined,
        color: enabled
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      tooltip: '均衡器',
      onPressed: () => _showEqualizerBottomSheet(context, ref),
    );
  }

  void _showEqualizerBottomSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: const EqualizerPanel(),
        ),
      ),
    );
  }
}
