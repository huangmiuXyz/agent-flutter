/// 本地模型页 — 管理设备端 GGUF 模型并控制内嵌服务。
///
/// 通过 [LocalModelService] 把模型加载进本进程并起一个 OpenAI 兼容服务，
/// 服务就绪后自动写入 `language_models.openai_compatible.local_llm` provider，
/// 聊天模型选择器即可选用本地模型（工具调用 / 会话入库等能力由 Rust 引擎原样复用）。
library;

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:path/path.dart' as p;
import 'package:signals_hooks/signals_hooks.dart';

import 'package:agent/features/settings/models/local_model_info.dart';
import 'package:agent/services/local_llm/local_model_service.dart';
import 'package:agent/store/config_store.dart';
import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/button/app_icon_button.dart';
import 'package:agent/widgets/button/app_primary_button.dart';
import 'package:agent/widgets/button/app_secondary_button.dart';
import 'package:agent/widgets/button/button_base.dart';
import 'package:agent/widgets/card/app_card.dart';
import 'package:agent/widgets/content_frame/content_frame.dart';
import 'package:agent/widgets/dialog/app_dialog.dart';
import 'package:agent/widgets/field/app_field.dart';
import 'package:agent/widgets/list/app_big_list.dart';
import 'package:agent/widgets/select/app_select.dart';
import 'package:agent/widgets/switch/app_switch.dart';
import 'package:agent/widgets/text/app_text.dart';

/// 本地模型设置页。
class LocalModelPage extends HookWidget {
  const LocalModelPage({super.key});

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    final searchQuery = useState('');
    final selectedModel = useState<LocalModelInfo?>(null);
    final editContextCtrl = useTextEditingController();
    final editMaxTokensCtrl = useTextEditingController();

    // 订阅 config + 服务状态变化（跨窗口同步 / 服务启停后刷新 UI）
    useExistingSignal(ConfigStore.instance.data);
    useExistingSignal(LocalModelService.instance.status);
    useExistingSignal(LocalModelService.instance.activeModel);

    final models = useState<List<LocalModelInfo>>([]);
    if (models.value.isEmpty) {
      models.value = LocalModelService.instance.readModels();
    }
    final svc = LocalModelService.instance;

    void refreshModels() {
      models.value = svc.readModels();
    }

    // 默认选中第一个启用的模型（若有）
    if (selectedModel.value == null && models.value.isNotEmpty) {
      selectedModel.value =
          models.value.where((m) => m.enabled).firstOrNull ??
          models.value.first;
    }

    Future<void> onAddModel() async {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['gguf'],
        dialogTitle: '选择本地模型文件 (.gguf)',
      );
      final path = files.map((f) => f.path).whereType<String>().firstOrNull;
      if (path == null || path.isEmpty) return;
      final fileName = path.split('/').last.replaceAll('.gguf', '');
      final updated = [
        ...models.value,
        LocalModelInfo(name: fileName, path: path),
      ];
      svc.saveModels(updated);
      refreshModels();
      selectedModel.value = updated.last;
    }

    Future<void> onAddDirectory() async {
      final dirPath = await FilePicker.getDirectoryPath(
        dialogTitle: '选择本地模型目录',
      );
      if (dirPath == null || dirPath.isEmpty) return;
      if (!context.mounted) return;

      // 弹窗内勾选结果（child 每次选中变化时刷新此列表）
      final picked = <LocalModelInfo>[];
      final confirmed = await AppDialog.show(
        context: context,
        title: '从目录添加模型',
        width: 560,
        okText: '添加',
        onOk: () {},
        child: _ScanDirectoryBody(
          path: dirPath,
          onResult: (m) {
            picked
              ..clear()
              ..addAll(m);
          },
        ),
      );
      if (confirmed != true || picked.isEmpty) return;

      final existingPaths = models.value.map((m) => m.path).toSet();
      final newModels = [
        for (final m in picked)
          if (!existingPaths.contains(m.path)) m,
      ];
      if (newModels.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: AppText('所选模型已在列表中')));
        }
        return;
      }
      final updated = [...models.value, ...newModels];
      svc.saveModels(updated);
      refreshModels();
      selectedModel.value ??= updated.first;
    }

    Future<void> onToggleEnabled(LocalModelInfo model, bool enabled) async {
      // 正在运行（或加载中）的模型被停用时先停止服务
      if (!enabled && svc.current?.path == model.path) {
        await svc.stop();
      }
      final updated = [
        for (final m in models.value)
          if (m.name == model.name && m.path == model.path)
            LocalModelInfo(
              name: m.name,
              path: m.path,
              contextSize: m.contextSize,
              maxTokens: m.maxTokens,
              enabled: enabled,
              gpuLayers: m.gpuLayers,
            )
          else
            m,
      ];
      svc.saveModels(updated);
      refreshModels();
      // 当前选中项被停用时切换选中到其它启用模型
      if (!enabled && selectedModel.value?.path == model.path) {
        selectedModel.value =
            updated.where((m) => m.enabled).firstOrNull ?? updated.firstOrNull;
      }
    }

    Future<void> onEditContext(LocalModelInfo model) async {
      editContextCtrl.text = '${model.contextSize}';
      editMaxTokensCtrl.text = model.maxTokens?.toString() ?? '';
      final confirmed = await AppDialog.show(
        context: context,
        title: '编辑模型参数',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppField(
              label: 'Context Size (tokens)',
              placeholder: '例如 4096',
              controller: editContextCtrl,
            ),
            SizedBox(height: custom.spacing.sm),
            AppField(
              label: '最大生成 token（思考也计入，留空=4096）',
              placeholder: '例如 4096',
              controller: editMaxTokensCtrl,
            ),
          ],
        ),
        okText: '保存',
      );
      if (confirmed == true) {
        final v = int.tryParse(editContextCtrl.text.trim());
        if (v == null || v <= 0) {
          if (context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: AppText('请输入有效的上下文长度')));
          }
          return;
        }
        final rawMax = editMaxTokensCtrl.text.trim();
        final maxTokens = rawMax.isEmpty ? null : int.tryParse(rawMax);
        if (rawMax.isNotEmpty && (maxTokens == null || maxTokens <= 0)) {
          if (context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: AppText('请输入有效的最长生成长度')));
          }
          return;
        }
        final updated = [
          for (final m in models.value)
            if (m.name == model.name && m.path == model.path)
              LocalModelInfo(
                name: m.name,
                path: m.path,
                contextSize: v,
                maxTokens: maxTokens,
                enabled: m.enabled,
                gpuLayers: m.gpuLayers,
              )
            else
              m,
        ];
        svc.saveModels(updated);
        refreshModels();
      }
    }

    Future<void> onDelete(LocalModelInfo model) async {
      final confirmed = await AppDialog.show(
        context: context,
        title: '删除本地模型',
        child: AppText('确定要移除「${model.label}」吗？不会删除模型文件。'),
        okText: '删除',
      );
      if (confirmed != true) return;
      // 正在运行的模型被删除时先停止服务
      if (svc.current?.path == model.path) {
        await svc.stop();
      }
      final updated = models.value
          .where((m) => !(m.name == model.name && m.path == model.path))
          .toList();
      svc.saveModels(updated);
      refreshModels();
      if (selectedModel.value?.path == model.path) {
        selectedModel.value = updated.isEmpty ? null : updated.first;
      }
    }

    final query = searchQuery.value.trim().toLowerCase();
    final filtered = models.value
        .where(
          (m) =>
              query.isEmpty ||
              m.label.toLowerCase().contains(query) ||
              m.path.toLowerCase().contains(query),
        )
        .toList();

    final sections = filtered.isEmpty
        ? <AppBigSection>[]
        : [
            AppBigSection(
              label: '已添加',
              itemCount: filtered.length,
              itemBuilder: (ctx, i, {required isFirst, required isLast}) {
                final model = filtered[i];
                final active = svc.current?.path == model.path;
                return AppBigRow(
                  icon: 'hardDrive',
                  name: model.label,
                  description: model.path,
                  mono: true,
                  dot: active,
                  dotColor: active ? null : Colors.transparent,
                  clickable: false,
                  actions: [
                    AppSecondaryButton(
                      text: '${model.contextSize}',
                      icon: 'textCursorInput',
                      size: ButtonSize.sm,
                      onPressed: () => onEditContext(model),
                    ),
                    const SizedBox(width: 4),
                    AppSwitch(
                      value: model.enabled,
                      size: SwitchSize.sm,
                      onChanged: (v) => onToggleEnabled(model, v),
                    ),
                    const SizedBox(width: 4),
                    AppIconButton(
                      icon: 'trash2',
                      size: ButtonSize.sm,
                      tooltip: '删除模型',
                      onPressed: () => onDelete(model),
                    ),
                  ],
                );
              },
            ),
          ];

    return ContentFrame(
      scrollable: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ServiceControlCard(
            models: models.value,
            selected: selectedModel.value,
            onSelected: (m) => selectedModel.value = m,
          ),
          SizedBox(height: custom.spacing.md),
          Expanded(
            child: AppBigList(
              count: filtered.length,
              countLabel: '个模型',
              showSearch: true,
              searchTerm: searchQuery.value,
              onSearchChanged: (v) => searchQuery.value = v,
              searchPlaceholder: '搜索本地模型...',
              actions: [
                AppSecondaryButton(
                  text: '添加目录',
                  icon: 'folderOpen',
                  size: ButtonSize.sm,
                  onPressed: onAddDirectory,
                ),
                const SizedBox(width: 4),
                AppPrimaryButton(
                  text: '添加模型',
                  icon: 'plus',
                  size: ButtonSize.sm,
                  onPressed: onAddModel,
                ),
              ],
              emptyState: AppBigEmpty(
                icon: 'hardDrive',
                title: query.isEmpty ? '暂无本地模型' : '没有匹配的模型',
                hint: query.isEmpty
                    ? '点击「添加目录」扫描 .gguf，或「添加模型」选择单个文件'
                    : '试试其他关键词',
              ),
              sections: sections.isNotEmpty ? sections : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// 服务控制卡：状态指示 + 模型选择 + 启动/停止。
class _ServiceControlCard extends HookWidget {
  final List<LocalModelInfo> models;
  final LocalModelInfo? selected;
  final ValueChanged<LocalModelInfo?> onSelected;

  const _ServiceControlCard({
    required this.models,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    final svc = LocalModelService.instance;
    final status = useExistingSignal(svc.status).value;
    final loadingMsg = useExistingSignal(svc.loadingMsg).value;
    final errorMsg = useExistingSignal(svc.errorMsg).value;
    final port = useExistingSignal(svc.port).value;

    final (statusLabel, statusColor) = switch (status) {
      LocalModelStatus.stopped => ('未运行', custom.colors.textSecondary),
      LocalModelStatus.loading => ('加载中...', custom.colors.accent),
      LocalModelStatus.ready => ('运行中', Colors.green),
      LocalModelStatus.error => ('启动失败', Colors.red),
    };

    final starting = status == LocalModelStatus.loading;

    return AppCard(
      padding: EdgeInsets.all(custom.spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 标题 + 状态
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              AppText(statusLabel, variant: AppTextVariant.subtitle),
              if (port != null) ...[
                const SizedBox(width: 8),
                AppText('端口 $port', variant: AppTextVariant.caption),
              ],
            ],
          ),
          if (loadingMsg != null) ...[
            const SizedBox(height: 8),
            AppText(loadingMsg, variant: AppTextVariant.caption),
          ],
          if (status == LocalModelStatus.ready) ...[
            const SizedBox(height: 8),
            AppText(
              '已注册为提供商「本地模型」，可在聊天模型选择器中选用',
              variant: AppTextVariant.caption,
            ),
          ],
          if (status == LocalModelStatus.error && errorMsg != null) ...[
            const SizedBox(height: 8),
            AppText(errorMsg, variant: AppTextVariant.caption),
          ],
          SizedBox(height: custom.spacing.md),
          // 模型选择 + 启停按钮
          // 底部对齐：AppSelect 带 label 时整体更高，需与输入框对齐
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: AppSelect<LocalModelInfo>(
                  label: '运行模型',
                  placeholder: '选择要运行的模型',
                  value: selected,
                  options: [
                    for (final m in models)
                      if (m.enabled)
                        AppSelectOption<LocalModelInfo>(
                          value: m,
                          label: m.label,
                        ),
                  ],
                  onChanged: onSelected,
                ),
              ),
              const SizedBox(width: 8),
              AppPrimaryButton(
                text: '启动',
                icon: 'play',
                disabled: starting || selected == null,
                onPressed: selected == null || starting
                    ? null
                    : () async {
                        try {
                          await svc.start(selected!);
                        } catch (_) {
                          // 状态已由信号反映为 error
                        }
                      },
              ),
              const SizedBox(width: 8),
              AppSecondaryButton(
                text: '停止',
                icon: 'square',
                disabled: status == LocalModelStatus.stopped,
                onPressed: status == LocalModelStatus.stopped
                    ? null
                    : () => svc.stop(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 从目录递归扫描 .gguf 文件并多选添加的弹窗内容。
///
/// 进入即异步递归扫描 [path] 及子目录，找到的 `.gguf` 文件默认全选；
/// 每次勾选变化时通过 [onResult] 把当前选中的模型回调出去，
/// 供外部在弹窗确认后批量写入 config。
class _ScanDirectoryBody extends StatefulWidget {
  final String path;
  final ValueChanged<List<LocalModelInfo>> onResult;

  const _ScanDirectoryBody({required this.path, required this.onResult});

  @override
  State<_ScanDirectoryBody> createState() => _ScanDirectoryBodyState();
}

class _ScanDirectoryBodyState extends State<_ScanDirectoryBody> {
  bool _scanning = true;
  String? _error;
  List<LocalModelInfo> _found = const [];
  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    _scan();
  }

  Future<void> _scan() async {
    setState(() {
      _scanning = true;
      _error = null;
      _found = const [];
      _selected.clear();
    });
    _emit();
    try {
      final root = Directory(widget.path);
      final found = <LocalModelInfo>[];
      await for (final entity in root.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is File && entity.path.toLowerCase().endsWith('.gguf')) {
          found.add(
            LocalModelInfo(
              name: p.basenameWithoutExtension(entity.path),
              path: entity.path,
            ),
          );
        }
      }
      if (!mounted) return;
      setState(() {
        _found = found;
        _scanning = false;
        _selected.addAll(found.map((m) => m.path));
      });
      _emit();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _scanning = false;
        _error = '$e';
      });
    }
  }

  void _emit() {
    widget.onResult([
      for (final m in _found)
        if (_selected.contains(m.path)) m,
    ]);
  }

  void _toggleOne(String path) {
    setState(() {
      if (!_selected.add(path)) _selected.remove(path);
    });
    _emit();
  }

  void _toggleAll(bool select) {
    setState(() {
      if (select) {
        _selected.addAll(_found.map((m) => m.path));
      } else {
        _selected.clear();
      }
    });
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    return SizedBox(
      height: 380,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppText(
            widget.path,
            variant: AppTextVariant.caption,
            color: custom.colors.textSecondary,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: custom.spacing.md),
          Expanded(child: _buildStatus(custom)),
        ],
      ),
    );
  }

  Widget _buildStatus(CustomTheme custom) {
    if (_scanning) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          SizedBox(height: custom.spacing.md),
          AppText(
            _found.isEmpty ? '正在扫描目录...' : '已找到 ${_found.length} 个模型...',
            variant: AppTextVariant.body,
            color: custom.colors.textSecondary,
          ),
        ],
      );
    }

    if (_error != null) {
      return AppText(
        '扫描失败：$_error',
        variant: AppTextVariant.body,
        color: custom.colors.danger,
      );
    }

    if (_found.isEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AppText(
            '该目录下未找到 .gguf 文件',
            variant: AppTextVariant.body,
            color: custom.colors.textSecondary,
          ),
        ],
      );
    }

    final allSelected = _selected.length == _found.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            AppText(
              '共 ${_found.length} 个模型，已选 ${_selected.length}',
              variant: AppTextVariant.caption,
              color: custom.colors.textSecondary,
            ),
            const Spacer(),
            AppSecondaryButton(
              text: allSelected ? '取消全选' : '全选',
              size: ButtonSize.sm,
              onPressed: () => _toggleAll(!allSelected),
            ),
          ],
        ),
        SizedBox(height: custom.spacing.xs),
        Expanded(
          child: ListView.separated(
            itemCount: _found.length,
            separatorBuilder: (_, _) =>
                Divider(height: 1, color: custom.colors.separator),
            itemBuilder: (ctx, i) {
              final model = _found[i];
              final checked = _selected.contains(model.path);
              return InkWell(
                onTap: () => _toggleOne(model.path),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Checkbox(
                        value: checked,
                        onChanged: (_) => _toggleOne(model.path),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppText(
                              model.label,
                              variant: AppTextVariant.body,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            AppText(
                              p.relative(model.path, from: widget.path),
                              variant: AppTextVariant.caption,
                              color: custom.colors.textSecondary,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
