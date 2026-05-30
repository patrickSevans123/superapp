import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_ui/shared_ui.dart';
import 'core/router/app_router.dart';

class Superapp extends StatelessWidget {
  const Superapp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Superapp',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: appRouter,
    );
  }
}
