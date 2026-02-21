import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:microbiostock/views/login_view.dart';
import 'package:microbiostock/views/home_view.dart'; // Importante para as rotas

void main() async {
  // 1. GARANTE A INICIALIZAÇÃO: Essencial para não travar ao usar plugins (PDF, Auth, etc)
  WidgetsFlutterBinding.ensureInitialized();

  // Se você usa Firebase, a linha abaixo deve ser descomentada:
  // await Firebase.initializeApp();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MicrobioStock',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // Mantendo sua cor original
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00796B)),
        useMaterial3: true,
      ),
      // Mantendo suas localizações para datas em português
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('pt', 'BR')],
      
      // TELA INICIAL
      home: const LoginView(), 

      // 2. ADICIONANDO ROTAS: Isso evita loops infinitos de navegação
      routes: {
        '/login': (context) => const LoginView(),
        '/home': (context) => const HomeView(),
      },
    );
  }
}