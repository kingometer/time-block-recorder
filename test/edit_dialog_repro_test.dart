import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:time_block_recorder/models/app_data.dart';
import 'package:time_block_recorder/pages/stats_page.dart';
import 'package:time_block_recorder/services/storage_service.dart';
import 'package:time_block_recorder/state/app_state.dart';

class _FakeStorage extends StorageService {
  @override
  Future<void> save(AppData data) async {}
}

void main() {
  testWidgets('编辑记录对话框正常渲染内容', (tester) async {
    final state = AppState(
      initialData: AppData.createDefault(),
      storage: _FakeStorage(),
    );
    final now = DateTime.now();
    state.addBackfill(
      event: state.data.events.first,
      start: now.subtract(const Duration(hours: 2)),
      end: now.subtract(const Duration(hours: 1)),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(home: StatsPage()),
      ),
    );
    await tester.pumpAndSettle();

    // 切到「记录」标签
    await tester.tap(find.text('记录'));
    await tester.pumpAndSettle();

    // 点击第一条记录打开编辑对话框
    await tester.tap(find.byType(ListTile).first);
    await tester.pumpAndSettle();

    final exception = tester.takeException();
    expect(exception, isNull, reason: '编辑记录对话框不应抛出异常：$exception');

    expect(find.text('编辑计时记录'), findsOneWidget);
    expect(find.text('开始时间'), findsOneWidget);
    expect(find.text('结束时间'), findsOneWidget);
    expect(find.text('删除'), findsOneWidget);
    expect(find.text('保存'), findsOneWidget);
  });
}
