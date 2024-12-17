import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'pages/auth/login_page.dart';
import 'pages/main_page.dart';
import 'services/supabase_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://plcppiklytlocdurcvzi.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBsY3BwaWtseXRsb2NkdXJjdnppIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzQzNjU1ODksImV4cCI6MjA0OTk0MTU4OX0.tHu1SQFqGj-i7pdWoldLaV9Rm0x5xJ96bmsr2nTNk2U',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Check App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => kIsWeb 
          ? const Center(
              child: SizedBox(
                width: 480,
                child: WebWrapper(),
              ),
            )
          : const AppWrapper(),
        '/login': (context) => const LoginPage(),
      },
    );
  }
}

class WebWrapper extends StatelessWidget {
  const WebWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(20),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: const AppWrapper(),
      ),
    );
  }
}

class AppWrapper extends StatelessWidget {
  const AppWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return SupabaseService.isLoggedIn()
        ? const MainPage()
        : const LoginPage();
  }
}
