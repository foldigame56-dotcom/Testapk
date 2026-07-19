import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/server_store.dart';
import 'services/v2ray_service.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const VlessClientApp());
}

class VlessClientApp extends StatelessWidget {
  const VlessClientApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ServerStore()..loadFromDisk()),
        ChangeNotifierProvider(create: (_) => V2RayService()..init()),
      ],
      child: MaterialApp(
        title: 'GradelVPN',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: const HomeScreen(),
      ),
    );
  }
}
