import 'package:flutter/material.dart';

import 'app.dart';
import 'models/app_data.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.init();
  final storage = StorageService();
  final loaded = await storage.load();
  final state = AppState(
    initialData: loaded ?? AppData.createDefault(),
    storage: storage,
  );
  await state.restoreTimerState();
  runApp(TimeBlockApp(state: state));
}
