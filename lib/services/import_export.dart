import 'dart:convert';

import 'package:file_picker/file_picker.dart';

import '../models/app_data.dart';
import '../models/category.dart';
import '../models/day_mode.dart';
import '../models/time_record.dart';
import '../utils/format.dart';

/// 导出全部数据为 JSON 文件。返回保存路径；用户取消时返回 null。
Future<String?> exportJsonFile(AppData data) async {
  final bytes = utf8.encode(
    const JsonEncoder.withIndent('  ').convert(data.toJson()),
  );
  final uri = await FilePicker.saveFile(
    dialogTitle: '导出数据（JSON）',
    fileName: '时间区块记录器_备份_${dateKey(DateTime.now())}.json',
    type: FileType.custom,
    allowedExtensions: ['json'],
    bytes: bytes,
  );
  return uri == null ? null : _uriLabel(uri);
}

/// 选择 JSON 备份文件并解析。取消时返回 null。
Future<AppData?> pickJsonFile() async {
  final files = await FilePicker.pickFiles(
    dialogTitle: '选择备份 JSON 文件',
    type: FileType.custom,
    allowedExtensions: ['json'],
  );
  if (files.isEmpty) return null;
  final bytes = await files.first.readAsBytes();
  final text = utf8.decode(bytes);
  final json = jsonDecode(text) as Map<String, dynamic>;
  return AppData.fromJson(json);
}

/// 导出全部记录为 CSV（带 UTF-8 BOM，便于 Excel 打开）。返回保存路径。
Future<String?> exportCsvFile(List<TimeRecord> records) async {
  final lines = <String>['日期,开始时间,结束时间,事件,分类,模式,实际时长(秒),暂停(秒),标签,来源'];
  for (final r in records) {
    final cat = AppCategory.fromCode(r.categoryCode).label;
    final mode = DayMode.fromCode(r.modeCode).label;
    final src = r.isBackfill ? '补录' : '计时';
    lines.add(
      [
        dateKey(r.start),
        formatDateTime(r.start),
        formatDateTime(r.end),
        r.eventName,
        cat,
        mode,
        '${r.durationSec}',
        '${r.pausedSec}',
        r.tags.join('|'),
        src,
      ].map(_csv).join(','),
    );
  }
  final bytes = utf8.encode('\uFEFF${lines.join('\r\n')}');
  final uri = await FilePicker.saveFile(
    dialogTitle: '导出 CSV 备份',
    fileName: '时间区块记录器_记录_${dateKey(DateTime.now())}.csv',
    type: FileType.custom,
    allowedExtensions: ['csv'],
    bytes: bytes,
  );
  return uri == null ? null : _uriLabel(uri);
}

String _csv(String v) => '"${v.replaceAll('"', '""')}"';

String _uriLabel(Uri uri) =>
    uri.scheme == 'file' ? uri.toFilePath() : uri.toString();
