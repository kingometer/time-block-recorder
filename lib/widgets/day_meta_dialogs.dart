import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../utils/format.dart';

/// 编辑某天备注的独立弹窗。
Future<void> showNoteEditDialog(
  BuildContext context,
  AppState state,
  DateTime date,
) async {
  final meta = state.metaFor(date);
  final controller = TextEditingController(text: meta?.note ?? '');
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('编辑备注 · ${dateKey(date)}'),
      content: SingleChildScrollView(
        child: TextField(
          controller: controller,
          minLines: 6,
          maxLines: null,
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
          decoration: const InputDecoration(
            hintText: '输入备注内容…',
            border: OutlineInputBorder(),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            state.setDayNote(date, controller.text);
            Navigator.pop(ctx);
          },
          child: const Text('保存'),
        ),
      ],
    ),
  );
}

/// 编辑某天复盘的独立弹窗；顶部附带当日时间分析提示（只读参考，不写入复盘）。
Future<void> showReviewEditDialog(
  BuildContext context,
  AppState state,
  DateTime date,
) async {
  final meta = state.metaFor(date);
  final controller = TextEditingController(text: meta?.review ?? '');
  final hint = state.reviewAnalysisHint(date);
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('编辑复盘 · ${dateKey(date)}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hint != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(
                    ctx,
                  ).colorScheme.primaryContainer.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  hint,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: Theme.of(ctx).colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: controller,
              minLines: 6,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                hintText: '记录今日的主观总结…',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            state.setDayReview(date, controller.text);
            Navigator.pop(ctx);
          },
          child: const Text('保存'),
        ),
      ],
    ),
  );
}
