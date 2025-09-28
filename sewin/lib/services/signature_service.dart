import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';
import '../global/global_constantes.dart';
import 'user_service.dart';

class SignatureServiceError implements Exception {
  final String message;
  final dynamic error;
  final StackTrace? stackTrace;

  SignatureServiceError(this.message, {this.error, StackTrace? stackTrace})
      : stackTrace = stackTrace ?? StackTrace.current;

  @override
  String toString() =>
      'SignatureServiceError: $message${error != null ? ' - $error' : ''}';
}

class SignatureService {
  static const String _signaturePathPrefix = 'signature_path_';
  static const String _signatureTimestampSuffix = '_timestamp';

  // Guardar firma como archivo
  static Future<String?> saveSignatureFile(
      Uint8List signatureBytes, String userId) async {
    if (userId.isEmpty) {
      throw ArgumentError('userId cannot be empty');
    }

    if (signatureBytes.isEmpty) {
      throw ArgumentError('signatureBytes cannot be empty');
    }

    Directory? signaturesDir;
    try {
      // Obtener el directorio de documentos de la aplicación
      final Directory appDocDir = await getApplicationDocumentsDirectory();
      signaturesDir = Directory('${appDocDir.path}/signatures');

      try {
        await signaturesDir.create(recursive: true);
      } catch (e) {
        throw SignatureServiceError(
          'Error creating signatures directory',
          error: e,
        );
      }

      // Generar nombre único para el archivo
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String fileName = 'signature_${userId}_$timestamp.png';
      final String filePath = '${signaturesDir.path}/$fileName';

      // Guardar el archivo
      try {
        final File file = File(filePath);
        await file.writeAsBytes(signatureBytes);
        print('Firma guardada en: $filePath');
        return filePath;
      } catch (e) {
        throw SignatureServiceError(
          'Error writing signature file',
          error: e,
        );
      }
    } on SignatureServiceError {
      rethrow;
    } catch (e, stackTrace) {
      throw SignatureServiceError(
        'Unexpected error saving signature file',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  // Asociar firma a un usuario usando bytes directamente (para web)
  static Future<bool> associateSignatureToUserWithBytes(
      String userId, Uint8List signatureBytes) async {
    if (userId.isEmpty) {
      throw ArgumentError('userId cannot be empty');
    }

    if (signatureBytes.isEmpty) {
      throw ArgumentError('signatureBytes cannot be empty');
    }

    try {
      // Crear la petición multipart
      final url =
          Uri.parse('${Constants.serverapp}/api/users/$userId/signature');
      final request = http.MultipartRequest('POST', url);

      // Añadir el archivo a la petición
      request.files.add(http.MultipartFile.fromBytes(
        'signature',
        signatureBytes,
        filename: 'signature_$userId.png',
        contentType: MediaType('image', 'png'),
      ));

      // Añadir token de autenticación
      final token = await AuthService().getToken();
      if (token == null) {
        throw SignatureServiceError('No se encontró token de autenticación');
      }
      request.headers['Authorization'] = 'Bearer $token';

      // Enviar la petición
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          final responseData = json.decode(response.body);
          print('Signature upload response: $responseData');
          
          // Check if response has success field and data
          if (responseData['success'] == true && responseData['data'] != null) {
            final data = responseData['data'] as Map<String, dynamic>;
            final serverPath = data['signature_path'] as String?;

            if (serverPath != null) {
              // Guardar localmente para acceso rápido
              final prefs = await _getPrefs();
              await Future.wait([
                prefs.setString('$_signaturePathPrefix$userId', serverPath),
                prefs.setString(
                  '$_signaturePathPrefix$userId$_signatureTimestampSuffix',
                  DateTime.now().toIso8601String(),
                ),
              ]);
              print('Signature saved successfully: $serverPath');
              return true;
            }
          }
          
          print('No signature_path found in response data');
          return false;
        } catch (e) {
          throw SignatureServiceError('Error parsing server response',
              error: e);
        }
      } else {
        print('Server error response: ${response.body}');
        String errorMessage = 'Server returned status code: ${response.statusCode}';
        
        try {
          final errorData = json.decode(response.body);
          if (errorData['message'] != null) {
            errorMessage = errorData['message'];
          }
        } catch (e) {
          // If we can't parse the error response, use the default message
        }
        
        throw SignatureServiceError(errorMessage);
      }
    } on SignatureServiceError {
      rethrow;
    } catch (e, stackTrace) {
      throw SignatureServiceError(
        'Error al asociar firma al usuario con bytes',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  // Asociar firma a un usuario (sube al servidor y guarda localmente)
  static Future<bool> associateSignatureToUser(
      String userId, String signatureFilePath) async {
    if (userId.isEmpty) {
      throw ArgumentError('userId cannot be empty');
    }

    if (signatureFilePath.isEmpty) {
      throw ArgumentError('signatureFilePath cannot be empty');
    }

    File? file;
    try {
      file = File(signatureFilePath);
      if (!await file.exists()) {
        throw SignatureServiceError(
            'Archivo de firma no encontrado: $signatureFilePath');
      }

      // Leer los bytes de la firma
      final Uint8List signatureBytes;
      try {
        signatureBytes = await file.readAsBytes();
      } catch (e) {
        throw SignatureServiceError('Error leyendo archivo de firma', error: e);
      }

      // Usar el método de bytes para subir la firma
      return await associateSignatureToUserWithBytes(userId, signatureBytes);
    } on SignatureServiceError {
      rethrow;
    } catch (e, stackTrace) {
      throw SignatureServiceError(
        'Error al asociar firma al usuario',
        error: e,
        stackTrace: stackTrace,
      );
    } finally {
      file = null;
    }
  }

  // Obtener instancia de SharedPreferences con manejo de errores
  static Future<SharedPreferences> _getPrefs() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (e, stackTrace) {
      throw SignatureServiceError(
        'Error accediendo a SharedPreferences',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  // Obtener ruta de firma de un usuario
  static Future<String?> getUserSignaturePath(String userId) async {
    if (userId.isEmpty) {
      throw ArgumentError('userId cannot be empty');
    }

    try {
      final prefs = await _getPrefs();
      return prefs.getString('$_signaturePathPrefix$userId');
    } on SignatureServiceError {
      rethrow;
    } catch (e, stackTrace) {
      throw SignatureServiceError(
        'Error obteniendo ruta de firma del usuario',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  // Verificar si un usuario tiene firma
  static Future<bool> userHasSignature(String userId) async {
    if (userId.isEmpty) {
      throw ArgumentError('userId cannot be empty');
    }

    final String? signaturePath;
    try {
      signaturePath = await getUserSignaturePath(userId);
      if (signaturePath == null) return false;

      // Verificar que el archivo aún existe
      try {
        final file = File(signaturePath);
        return await file.exists();
      } catch (e) {
        throw SignatureServiceError(
          'Error verificando existencia de archivo de firma',
          error: e,
        );
      }
    } on SignatureServiceError {
      rethrow;
    } catch (e, stackTrace) {
      throw SignatureServiceError(
        'Error verificando si el usuario tiene firma',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  // Obtener bytes de la firma de un usuario
  static Future<Uint8List?> getUserSignatureBytes(String userId) async {
    if (userId.isEmpty) {
      throw ArgumentError('userId cannot be empty');
    }

    File? file;
    try {
      final String? signaturePath = await getUserSignaturePath(userId);
      if (signaturePath == null) return null;

      file = File(signaturePath);
      if (!await file.exists()) return null;

      try {
        return await file.readAsBytes();
      } catch (e) {
        throw SignatureServiceError(
          'Error leyendo bytes del archivo de firma',
          error: e,
        );
      }
    } on SignatureServiceError {
      rethrow;
    } catch (e, stackTrace) {
      throw SignatureServiceError(
        'Error obteniendo bytes de la firma del usuario',
        error: e,
        stackTrace: stackTrace,
      );
    } finally {
      // Clean up any resources if needed
    }
  }

  /// Clears the user's signature both locally and on the server
  /// Returns true if successful, throws SignatureServiceError otherwise
  Future<bool> clearSignature(String userId) async {
    if (userId.isEmpty) {
      throw ArgumentError('userId cannot be empty');
    }

    try {
      // Clear local signature file if it exists
      try {
        final prefs = await _getPrefs();
        final signaturePathKey = '${_signaturePathPrefix}$userId';
        final signaturePath = prefs.getString(signaturePathKey);
        
        if (signaturePath != null) {
          final file = File(signaturePath);
          if (await file.exists()) {
            await file.delete();
          }
          await prefs.remove(signaturePathKey);
          await prefs.remove('${signaturePathKey}_timestamp');
        }
      } catch (e) {
        // If there's an error clearing local files, log it but continue
        if (kDebugMode) {
          print('Error clearing local signature files: $e');
        }
      }

      // Clear server signature using UserService
      try {
        await UserService().updateUserSignature(userId, null);
        return true;
      } catch (e) {
        if (e is SignatureServiceError) rethrow;
        throw SignatureServiceError('Error clearing server signature', error: e);
      }
    } catch (e, stackTrace) {
      if (e is SignatureServiceError) rethrow;
      throw SignatureServiceError(
        'Error clearing signature',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  // Obtener lista de todos los usuarios con firma
  Future<List<String>> getUsersWithSignature() async {
    try {
      final prefs = await _getPrefs();
      final Set<String> keys = prefs.getKeys();

      final List<String> usersWithSignature = [];
      final List<Future<void>> verificationFutures = [];

      for (final String key in keys) {
        if (key.startsWith(_signaturePathPrefix) &&
            !key.endsWith(_signatureTimestampSuffix)) {
          final userId = key.substring(_signaturePathPrefix.length);
          if (userId.isNotEmpty) {
            verificationFutures.add(
              userHasSignature(userId).then((hasSignature) {
                if (hasSignature) {
                  usersWithSignature.add(userId);
                }
              }),
            );
          }
        }
      }

      await Future.wait(verificationFutures);
      return usersWithSignature;
    } on SignatureServiceError {
      rethrow;
    } catch (e, stackTrace) {
      throw SignatureServiceError(
        'Error obteniendo lista de usuarios con firma',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  // Obtener información completa de firma de un usuario
  Future<Map<String, dynamic>> getUserSignatureInfo(String userId) async {
    if (userId.isEmpty) {
      throw ArgumentError('userId cannot be empty');
    }
    
    File? file;
    try {
      final prefs = await _getPrefs();
      final String? signaturePath = prefs.getString('$_signaturePathPrefix$userId');
      final String? timestamp = prefs.getString(
        '$_signaturePathPrefix${userId}_$_signatureTimestampSuffix',
      );

      if (signaturePath == null) {
        return {}; // Return empty map if no signature path exists
      }

      // Check if file exists and get its size
      file = File(signaturePath);
      final bool fileExists = await file.exists();
      final int fileSize = fileExists ? await file.length() : 0;

      return {
        'path': signaturePath,
        'timestamp': timestamp,
        'exists': fileExists,
        'size': fileSize,
      };
    } on SignatureServiceError {
      rethrow;
    } catch (e, stackTrace) {
      throw SignatureServiceError(
        'Error obteniendo información de firma',
        error: e,
        stackTrace: stackTrace,
      );
    } finally {
      file = null;
    }
  }
}
