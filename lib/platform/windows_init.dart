import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

Future<void> initializeWindows() async {
  await windowManager.ensureInitialized();

  const WindowOptions windowOptions = WindowOptions(
    title: 'Plantões RET',
    size: Size(1280, 850),
    minimumSize: Size(1000, 700),
    center: true,
    skipTaskbar: false,
  );

  windowManager.waitUntilReadyToShow(
    windowOptions,
    () async {
      await windowManager.show();
      await windowManager.focus();
      await windowManager.setTitle('Plantões RET');
      await windowManager.setResizable(false);
      await windowManager.setMaximizable(false);
      await windowManager.setFullScreen(false);
    },
  );
}