import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../global/global_constantes.dart';
import '../models/gestion_model.dart';
import 'logger_service.dart';

class GestionService {
  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  static String get baseUrl => '${Constants.serverapp}/api';

  // Headers for API requests
  static Future<Map<String, String>> _getHeaders() async {
    final token = await _getToken();
    return {
      'accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // Get all gestiones
  /// This Dart function retrieves a list of "Gestion" objects from a remote API endpoint and handles
  /// potential errors during the process.
  ///
  /// Returns:
  ///   A Future<List<Gestion>> is being returned.
  static Future<List<Gestion>> getGestiones() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/gestiones'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> gestionesData = data['data'] ?? [];
        return gestionesData.map((json) => Gestion.fromJson(json)).toList();
      } else {
        Logger.e('Failed to load gestiones',
            error: 'Status: ${response.statusCode}, Body: ${response.body}');
        throw Exception('Error al cargar gestiones: ${response.statusCode}');
      }
    } catch (e) {
      Logger.e('Error loading gestiones', error: e);
      throw Exception('Error al cargar gestiones: $e');
    }
  }

  // Get gestion by ID
  static Future<Gestion> getGestionById(int id) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/gestiones/$id'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return Gestion.fromJson(data['data']);
      } else if (response.statusCode == 404) {
        Logger.w('Gestion not found', error: 'ID: $id');
        throw Exception('Gestión no encontrada');
      } else {
        Logger.e('Failed to load gestion',
            error:
                'ID: $id, Status: ${response.statusCode}, Body: ${response.body}');
        throw Exception('Error al cargar la gestión: ${response.statusCode}');
      }
    } catch (e) {
      Logger.e('Error loading gestion', error: e);
      throw Exception('Error al cargar la gestión: $e');
    }
  }

  // Create new gestion
  static Future<Gestion> createGestion(Gestion gestion) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/gestiones'),
        headers: await _getHeaders(),
        body: json.encode({
          'nombre': gestion.nombre,
          'descripcion': gestion.descripcion,
        }),
      );

      if (response.statusCode == 201) {
        final Map<String, dynamic> data = json.decode(response.body);
        return Gestion.fromJson(data['data']);
      } else {
        final error = json.decode(response.body)['message'];
        Logger.e('Failed to create gestion',
            error: 'Status: ${response.statusCode}, Message: $error');
        throw Exception(error ?? 'Error al crear la gestión');
      }
    } catch (e) {
      Logger.e('Error creating gestion', error: e);
      throw Exception('Error al crear la gestión: $e');
    }
  }

  // Update gestion
  static Future<Gestion> updateGestion(Gestion gestion) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/gestiones/${gestion.id}'),
        headers: await _getHeaders(),
        body: json.encode({
          'nombre': gestion.nombre,
          'descripcion': gestion.descripcion,
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return Gestion.fromJson(data['data']);
      } else {
        final error = json.decode(response.body)['message'];
        Logger.e('Failed to update gestion',
            error:
                'ID: ${gestion.id}, Status: ${response.statusCode}, Message: $error');
        throw Exception(error ?? 'Error al actualizar la gestión');
      }
    } catch (e) {
      Logger.e('Error updating gestion', error: e);
      throw Exception('Error al actualizar la gestión: $e');
    }
  }

  // Delete gestion
  static Future<bool> deleteGestion(int id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/gestiones/$id'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        final error = json.decode(response.body)['message'];
        Logger.e('Failed to delete gestion',
            error: 'ID: $id, Status: ${response.statusCode}, Message: $error');
        throw Exception(error ?? 'Error al eliminar la gestión');
      }
    } catch (e) {
      Logger.e('Error deleting gestion', error: e);
      throw Exception('Error al eliminar la gestión: $e');
    }
  }
}
