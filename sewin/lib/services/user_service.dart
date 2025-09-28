import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:sewin/global/global_constantes.dart';
import 'package:sewin/services/auth_service.dart';

class UserServiceError implements Exception {
  final String message;
  final dynamic error;
  final StackTrace? stackTrace;

  UserServiceError(this.message, {this.error, StackTrace? stackTrace}) 
    : stackTrace = stackTrace ?? StackTrace.current;

  @override
  String toString() => 'UserServiceError: $message${error != null ? ' - $error' : ''}';
}

class UserService {
  static final UserService _instance = UserService._internal();
  
  factory UserService() => _instance;
  
  UserService._internal();

  /// Fetches a user by ID from the server
  /// Returns a Map containing the user data if successful
  /// Throws UserServiceError if the request fails
  Future<Map<String, dynamic>> getUserById(String userId) async {
    try {
      final token = await AuthService().getToken();
      if (token == null) {
        throw UserServiceError('No authentication token available');
      }

      final response = await http.get(
        Uri.parse('${Constants.serverapp}/api/users/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        
        // Check if we have data and if it's in the expected format
        if (responseData.containsKey('data')) {
          final userData = responseData['data'] as Map<String, dynamic>;
          return userData;
        }
        
        // If response doesn't have 'data' key, return the whole response
        return responseData;
        
      } else if (response.statusCode == 404) {
        throw UserServiceError('User not found');
      } else {
        final errorData = json.decode(response.body);
        throw UserServiceError(
          errorData['message'] ?? 'Failed to fetch user',
        );
      }
    } catch (e) {
      if (e is UserServiceError) rethrow;
      throw UserServiceError('Error fetching user', error: e);
    }
  }

  /// Updates a user's signature
  /// Returns the updated user data if successful
  /// Throws UserServiceError if the request fails
  Future<Map<String, dynamic>> updateUserSignature(
    String userId, 
    Uint8List? signatureBytes,
  ) async {
    try {
      final token = await AuthService().getToken();
      if (token == null) {
        throw UserServiceError('No authentication token available');
      }

      final response = await http.put(
        Uri.parse('${Constants.serverapp}/api/users/$userId/signature'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'signature_image': signatureBytes != null 
              ? base64Encode(signatureBytes)
              : null,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorData = json.decode(response.body);
        throw UserServiceError(
          errorData['message'] ?? 'Failed to update signature',
        );
      }
    } catch (e) {
      if (e is UserServiceError) rethrow;
      throw UserServiceError('Error updating signature', error: e);
    }
  }
}
