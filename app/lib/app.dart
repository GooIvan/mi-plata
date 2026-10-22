import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';

class MiPlataApp extends StatelessWidget {
  const MiPlataApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'mi-plata',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: const Scaffold(body: Center(child: Text('mi-plata'))),
    );
  }
}
