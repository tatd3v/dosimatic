import 'dart:convert';
import 'package:http/http.dart' as http;
import '../global/global_constantes.dart';

class LookupService {
  static String get _baseUrl => '${Constants.serverapp}/api';

  /// Generic method to perform lookup searches
  static Future<List<Map<String, dynamic>>> performLookup({
    required String endpoint,
    required String searchTerm,
  }) async {
    try {
      final String url = '$_baseUrl$endpoint';

      final Map<String, String> headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

      final Map<String, dynamic> body = {
        'codigo': searchTerm,
      };

      print('Making lookup request to: $url');
      print('Search term: $searchTerm');

      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: json.encode(body),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Failed to fetch lookup data: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in performLookup: $e');
      throw Exception('Network error: $e');
    }
  }

  /// Load initial data for a lookup endpoint
  static Future<List<Map<String, dynamic>>> loadInitialData(
      String endpoint) async {
    return performLookup(endpoint: endpoint, searchTerm: '0');
  }

  /// Search for specific term in a lookup endpoint
  static Future<List<Map<String, dynamic>>> searchData({
    required String endpoint,
    required String searchTerm,
  }) async {
    return performLookup(endpoint: endpoint, searchTerm: searchTerm);
  }

  // Specific lookup methods for each document column type

  /// Lookup for document codes
  static Future<List<Map<String, dynamic>>> lookupCodigo(
      {String searchTerm = '0'}) async {
    return performLookup(
      endpoint: '/documentos/lookup/codigo',
      searchTerm: searchTerm,
    );
  }

  /// Lookup for document names
  static Future<List<Map<String, dynamic>>> lookupNombre(
      {String searchTerm = '0'}) async {
    return performLookup(
      endpoint: '/documentos/lookup/nombre',
      searchTerm: searchTerm,
    );
  }

  /// Lookup for document states (estados)
  static Future<List<Map<String, dynamic>>> lookupEstado({String searchTerm = ''}) async {
    return await performLookup(
      endpoint: '/documentos/lookup/estado',
      searchTerm: searchTerm,
    );
  }

  /// Lookup for document conventions
  static Future<List<Map<String, dynamic>>> lookupConvencion(
      {String searchTerm = '0'}) async {
    return performLookup(
      endpoint: '/documentos/lookup/convencion',
      searchTerm: searchTerm,
    );
  }

  /// Lookup for management areas
  static Future<List<Map<String, dynamic>>> lookupGestion(
      {String searchTerm = '0'}) async {
    return performLookup(
      endpoint: '/documentos/lookup/gestion',
      searchTerm: searchTerm,
    );
  }

  /// Lookup for document IDs
  static Future<List<Map<String, dynamic>>> lookupId(
      {String searchTerm = '0'}) async {
    return performLookup(
      endpoint: '/documentos/lookup/id',
      searchTerm: searchTerm,
    );
  }

  /// General lookup
  static Future<List<Map<String, dynamic>>> lookupGeneral(
      {String searchTerm = '0'}) async {
    return performLookup(
      endpoint: '/documentos/lookup/general',
      searchTerm: searchTerm,
    );
  }

  /// Get the appropriate lookup method based on column name
  static Future<List<Map<String, dynamic>>> lookupByColumnName({
    required String columnName,
    String searchTerm = '0',
  }) async {
    switch (columnName.toLowerCase()) {
      case 'código':
        return lookupCodigo(searchTerm: searchTerm);
      case 'nombre':
        return lookupNombre(searchTerm: searchTerm);
      case 'estado':
        return lookupEstado(searchTerm: searchTerm);
      case 'convención':
        return lookupConvencion(searchTerm: searchTerm);
      case 'gestión':
        return lookupGestion(searchTerm: searchTerm);
      case 'id':
        return lookupId(searchTerm: searchTerm);
      default:
        return lookupGeneral(searchTerm: searchTerm);
    }
  }

  /// Extract endpoint from URL for backward compatibility
  static String extractEndpointFromUrl(String url) {
    final uri = Uri.parse(url);
    final pathSegments = uri.pathSegments;

    if (pathSegments.length >= 3 && pathSegments[0] == 'api') {
      // Extract the endpoint part after /api
      return '/${pathSegments.sublist(1).join('/')}';
    }

    // Fallback to general lookup
    return '/documentos/lookup/general';
  }
}
