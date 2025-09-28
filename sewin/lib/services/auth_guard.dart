import 'package:flutter/material.dart';
import 'auth_service.dart';

/// A widget that protects routes by requiring authentication.
/// If the user is not authenticated, it will redirect to the login screen.
class AuthGuard extends StatelessWidget {
  final Widget child;
  final AuthService _authService = AuthService();

  AuthGuard({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _authService.getCurrentUser(),
      builder: (context, snapshot) {
        // Show loading indicator while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // If no user data is available, redirect to login
        if (snapshot.data == null) {
          // Use post-frame callback to avoid setState during build
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pushNamedAndRemoveUntil(
              '/login',
              (route) => false,
            );
          });
          return const SizedBox.shrink(); // Return empty widget during navigation
        }

        // User is authenticated and data is available
        return child;
      },
    );
  }
}
