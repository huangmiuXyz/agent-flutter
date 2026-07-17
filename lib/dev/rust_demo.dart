import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:agent/src/rust/api/simple.dart';
import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/button/app_button.dart';
import 'package:agent/widgets/text/app_text.dart';

class RustDemo extends ConsumerWidget {
  const RustDemo({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final custom = CustomTheme.of(context);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _sectionHeader(context, 'Sync: greet', custom),
        const SizedBox(height: 12),
        _ResultCard(
          label: 'greet("World")',
          result: greet(name: 'World'),
        ),
        const SizedBox(height: 32),

        _sectionHeader(context, 'Async: fibonacci', custom),
        const SizedBox(height: 12),
        _FibDemo(),
        const SizedBox(height: 32),

        _sectionHeader(context, 'Async: transpose', custom),
        const SizedBox(height: 12),
        _TransposeDemo(),
      ],
    );
  }

  Widget _sectionHeader(
    BuildContext context,
    String label,
    CustomTheme custom,
  ) {
    return AppText(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: custom.colors.textSecondary,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final String label;
  final String result;

  const _ResultCard({required this.label, required this.result});

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: custom.colors.panel,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(label, variant: AppTextVariant.caption),
          const SizedBox(height: 8),
          AppText(result, variant: AppTextVariant.subtitle),
        ],
      ),
    );
  }
}

class _FibDemo extends ConsumerStatefulWidget {
  @override
  ConsumerState<_FibDemo> createState() => _FibDemoState();
}

class _FibDemoState extends ConsumerState<_FibDemo> {
  final _controller = TextEditingController(text: '10');
  String _result = '';
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _compute() async {
    final n = int.tryParse(_controller.text);
    if (n == null) return;
    setState(() => _loading = true);
    final r = await fibonacci(n: n);
    setState(() {
      _result = 'fibonacci($n) = $r';
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: custom.colors.panel,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 100,
                child: TextField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    labelText: 'n',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              AppButton(
                variant: ButtonVariant.primary,
                onPressed: _loading ? null : _compute,
                text: _loading ? '计算中...' : '计算',
              ),
            ],
          ),
          if (_result.isNotEmpty) ...[
            const SizedBox(height: 12),
            AppText(_result, variant: AppTextVariant.subtitle),
          ],
        ],
      ),
    );
  }
}

class _TransposeDemo extends ConsumerStatefulWidget {
  @override
  ConsumerState<_TransposeDemo> createState() => _TransposeDemoState();
}

class _TransposeDemoState extends ConsumerState<_TransposeDemo> {
  final List<List<int>> _matrix = [
    [1, 2, 3],
    [4, 5, 6],
  ];
  List<List<int>>? _transposed;
  bool _loading = false;

  Future<void> _compute() async {
    setState(() => _loading = true);
    final input = _matrix.map((r) => Int32List.fromList(r)).toList();
    final result = await transpose(matrix: input);
    setState(() {
      _transposed = result.map((r) => r.toList()).toList();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: custom.colors.panel,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText('输入: ${_matrix[0].join(", ")} / ${_matrix[1].join(", ")}'),
          const SizedBox(height: 8),
          AppButton(
            variant: ButtonVariant.primary,
            onPressed: _loading ? null : _compute,
            text: _loading ? '计算中...' : '转置',
          ),
          if (_transposed != null) ...[
            const SizedBox(height: 12),
            AppText(
              '结果: ${_transposed!.map((r) => "[${r.join(",")}]").join(" / ")}',
              variant: AppTextVariant.subtitle,
            ),
          ],
        ],
      ),
    );
  }
}
