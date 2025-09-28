import 'package:flutter/material.dart';
import 'package:sewin/screens/documentos/documento.dart';
import 'screens/contact_list_screen.dart';
import 'screens/contact_list_screen1.dart';
import 'screens/contact_list_screen2.dart';
import 'screens/contact_list_screen3.dart';
import 'screens/users_screen.dart';
import 'screens/login_screen.dart';
import 'screens/reset_password_form_screen.dart';
import 'screens/signature_demo_screen.dart';
import 'screens/profile_screen.dart';
import 'services/auth_guard.dart';
import 'services/global_error_service.dart';
import 'dart:html' as html;
import 'dart:async';

void main() {
  runApp(const MyApp());
  _handleCurrentUrl();
}

void _handleCurrentUrl() {
  // Obtener la URL actual
  final uri = Uri.parse(html.window.location.href);

  // Si estamos en la ruta de reset-password, extraer el token
  if (uri.path.contains('reset-password')) {
    final token = uri.queryParameters['token'];
    if (token != null) {
      // Esperar un momento para asegurarnos que la app está inicializada
      Future.delayed(const Duration(milliseconds: 100), () {
        navigatorKey.currentState?.pushNamed(
          '/reset-password',
          arguments: token,
        );
      });
    }
  }
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: GlobalErrorService.scaffoldMessengerKey,
      title: 'Contact Manager',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      initialRoute: '/login',
      routes: {
        '/': (context) => AuthGuard(
              child: ContactListScreen(version: 0, title: 'Contactos'),
            ),
        '/users': (context) => AuthGuard(
              child: UsersScreen(),
            ),
        '/documentos': (context) => AuthGuard(
              child: DocumentosPage(),
            ),
        '/contact1': (context) => AuthGuard(
              child: ContactListScreen1(),
            ),
        '/contact2': (context) => AuthGuard(
              child: ContactListScreen2(),
            ),
        '/contact3': (context) => AuthGuard(
              child: ContactListScreen3(),
            ),
        '/login': (context) => LoginScreen(),
        '/reset-password': (context) {
          final token = ModalRoute.of(context)?.settings.arguments as String?;
          return ResetPasswordFormScreen(token: token ?? '');
        },
        '/signature-demo': (context) => const SignatureDemoScreen(),
        '/profile': (context) => AuthGuard(
              child: ProfileScreen(),
            ),
      },
    );
  }
}
