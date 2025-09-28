import 'package:flutter/material.dart';
import 'package:sewin/widgets/overlay_notification.dart';

class GlobalErrorService {
  static final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  static GlobalKey<ScaffoldMessengerState> get scaffoldMessengerKey =>
      _scaffoldMessengerKey;

  /// Show error message using overlay notification that appears over modals
  static void showError(String message, {Duration? duration, BuildContext? context}) {
    print('GlobalErrorService.showError called with: $message');
    print('Context provided: ${context != null}');

    if (context != null) {
      // Use overlay notification that appears over everything including modals
      OverlayNotification.show(
        context: context,
        message: message,
        type: NotificationType.error,
        duration: duration ?? const Duration(seconds: 4),
      );
      print('Error overlay notification shown');
    } else {
      // Fallback to global SnackBar if no context provided
      _scaffoldMessengerKey.currentState?.clearSnackBars();
      final snackBar = SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red[600],
        duration: duration ?? const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 10,
      );
      
      if (_scaffoldMessengerKey.currentState != null) {
        _scaffoldMessengerKey.currentState!.showSnackBar(snackBar);
        print('Error SnackBar shown globally');
      } else {
        print('ERROR: ScaffoldMessenger currentState is null for error message');
      }
    }
  }

  /// Show success message using overlay notification that appears over modals
  static void showSuccess(String message, {Duration? duration, BuildContext? context}) {
    print('GlobalErrorService.showSuccess called with: $message');
    print('Context provided: ${context != null}');

    if (context != null) {
      // Use overlay notification that appears over everything including modals
      OverlayNotification.show(
        context: context,
        message: message,
        type: NotificationType.success,
        duration: duration ?? const Duration(seconds: 3),
      );
      print('Success overlay notification shown');
    } else {
      // Fallback to global SnackBar if no context provided
      _scaffoldMessengerKey.currentState?.clearSnackBars();
      final snackBar = SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green[600],
        duration: duration ?? const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 10,
      );
      
      if (_scaffoldMessengerKey.currentState != null) {
        _scaffoldMessengerKey.currentState!.showSnackBar(snackBar);
        print('Success SnackBar shown globally');
      } else {
        print('ERROR: ScaffoldMessenger currentState is null for success message');
      }
    }
  }

  /// Show warning message using overlay notification that appears over modals
  static void showWarning(String message, {Duration? duration, BuildContext? context}) {
    print('GlobalErrorService.showWarning called with: $message');
    print('Context provided: ${context != null}');

    if (context != null) {
      // Use overlay notification that appears over everything including modals
      OverlayNotification.show(
        context: context,
        message: message,
        type: NotificationType.warning,
        duration: duration ?? const Duration(seconds: 3),
      );
      print('Warning overlay notification shown');
    } else {
      // Fallback to global SnackBar if no context provided
      _scaffoldMessengerKey.currentState?.clearSnackBars();
      final snackBar = SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_outlined, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.orange[600],
        duration: duration ?? const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 10,
      );
      
      if (_scaffoldMessengerKey.currentState != null) {
        _scaffoldMessengerKey.currentState!.showSnackBar(snackBar);
        print('Warning SnackBar shown globally');
      } else {
        print('ERROR: ScaffoldMessenger currentState is null for warning message');
      }
    }
  }

  /// Parse and display user-friendly error messages - can be shown locally or globally
  static void showApiError(dynamic error, {Duration? duration, BuildContext? context}) {
    String errorMsg = error.toString();
    String userFriendlyMessage;

    if (errorMsg.contains('duplicate key') ||
        errorMsg.contains('already exists')) {
      userFriendlyMessage =
          'El identificador ya existe. Por favor use un identificador único.';
    } else if (errorMsg.contains('validation') ||
        errorMsg.contains('invalid')) {
      userFriendlyMessage =
          'Datos inválidos. Verifique los campos obligatorios.';
    } else if (errorMsg.contains('network') ||
        errorMsg.contains('connection')) {
      userFriendlyMessage =
          'Error de conexión. Verifique su conexión a internet.';
    } else if (errorMsg.contains('unauthorized') || errorMsg.contains('403')) {
      userFriendlyMessage = 'No tiene permisos para realizar esta acción.';
    } else if (errorMsg.contains('404')) {
      userFriendlyMessage = 'Recurso no encontrado.';
    } else {
      userFriendlyMessage = 'Ha ocurrido un error inesperado. Intente nuevamente.';
      if (userFriendlyMessage.isEmpty) {
        userFriendlyMessage = 'Error inesperado. Por favor intente nuevamente.';
      }
    }

    showError(userFriendlyMessage, duration: duration, context: context);
  }
}
