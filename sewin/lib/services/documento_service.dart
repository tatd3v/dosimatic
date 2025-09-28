import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../global/global_constantes.dart';
import '../models/documento_model.dart';
import 'logger_service.dart' show Logger;

class DocumentoService {
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
      'Authorization': 'Bearer $token',
    };
  }

  // Get all documents with pagination and filters
  static Future<Map<String, dynamic>> getDocumentos({
    int page = 1,
    int limit = 20, // Default page size
    String? estado,
    int? gestionId,
    String? search,
    String? convencion,
  }) async {
    try {
      final offset = (page - 1) * limit;
      final queryParams = <String, String>{
        'limit': limit.toString(),
        'offset': offset.toString(),
        if (estado != null && estado.isNotEmpty) 'estado': estado,
        if (gestionId != null && gestionId > 0)
          'gestion_id': gestionId.toString(),
        if (search != null && search.isNotEmpty) 'search': search.trim(),
        if (convencion != null && convencion.isNotEmpty)
          'convencion': convencion,
      };

      final uri = Uri.parse('$baseUrl/documentos').replace(
        queryParameters: queryParams,
      );

      final response = await http
          .get(
        uri,
        headers: await _getHeaders(),
      )
          .timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception(
              'La solicitud ha tomado demasiado tiempo. Por favor, intente nuevamente.');
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data =
            json.decode(utf8.decode(response.bodyBytes));
        return {
          'documentos': (data['data'] as List)
              .map((json) => Documento.fromJson(json))
              .toList(),
          'total': data['pagination']['total'] ?? 0,
          'pages': data['pagination']['pages'] ?? 1,
          'currentPage': data['pagination']['currentPage'] ?? 1,
          'limit': data['pagination']['limit'] ?? limit,
          'offset': data['pagination']['offset'] ?? offset,
          'hasNext': data['pagination']['hasNext'] ?? false,
          'hasPrev': data['pagination']['hasPrev'] ?? false,
        };
      } else {
        Logger.e('Failed to load documents',
            error: 'Status: ${response.statusCode}, Body: ${response.body}');
        throw Exception('Error al cargar documentos: ${response.statusCode}');
      }
    } catch (e) {
      Logger.e('Error loading documents', error: e);
      throw Exception('Error al cargar documentos: $e');
    }
  }

  // Get document by ID
  static Future<Documento> getDocumentoById(int id) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/documentos/$id'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return Documento.fromJson(data['data']);
      } else if (response.statusCode == 404) {
        Logger.w('Document not found', error: 'ID: $id');
        throw Exception('Documento no encontrado');
      } else {
        Logger.e('Failed to load document',
            error:
                'ID: $id, Status: ${response.statusCode}, Body: ${response.body}');
        throw Exception('Error al cargar el documento: ${response.statusCode}');
      }
    } catch (e) {
      Logger.e('Error loading document', error: e);
      throw Exception('Error al cargar el documento: $e');
    }
  }

  // Create new document
  static Future<Documento> createDocumento(Documento documento) async {
    try {
      // Create multipart request for file upload
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/documentos'),
      );

      // Add headers (excluding Content-Type as it's set automatically for multipart)
      final headers = await _getHeaders();
      headers.forEach((key, value) {
        if (key.toLowerCase() != 'content-type') {
          request.headers[key] = value;
        }
      });

      // Add form fields - convert numbers to strings for multipart
      request.fields.addAll({
        'codigo': documento.codigo,
        'nombre': documento.nombre,
        'descripcion': documento.descripcion,
        'gestion_id': documento.gestionId.toString(), // Convert to string
        'convencion': documento.convencion,
        'usuario_creador':
            documento.usuarioCreador.toString(), // Convert to string
      });

      // Add vinculado_a if it exists
      if (documento.vinculadoA != null) {
        request.fields['vinculado_a'] = documento.vinculadoA.toString();
      }

      // Add file if available (archivo_fuente should be file path)
      if (documento.archivoFuente != null &&
          documento.archivoFuente!.isNotEmpty) {
        // If it's a file path, add as multipart file
        try {
          request.files.add(await http.MultipartFile.fromPath(
            'archivo_fuente',
            documento.archivoFuente!,
          ));
        } catch (e) {
          // If fromPath fails, treat as filename string
          request.fields['archivo_fuente'] = documento.archivoFuente!;
        }
      }

      // Debug: Log request details
      Logger.d('Creating document with multipart request',
          error:
              'POST $baseUrl/documentos\nFields: ${request.fields}\nFiles: ${request.files.map((f) => '${f.field}: ${f.filename}')}\nConvencion: "${documento.convencion}"\nvinculadoA value: ${documento.vinculadoA}');

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201) {
        final Map<String, dynamic> data = json.decode(response.body);
        return Documento.fromJson(data['data']);
      } else {
        final Map<String, dynamic> errorData = json.decode(response.body);
        String errorMessage =
            errorData['message'] ?? 'Error al crear el documento';

        // Handle specific error codes
        if (response.statusCode == 409) {
          errorMessage = 'duplicate key - El identificador ya existe';
        } else if (response.statusCode == 400) {
          errorMessage = 'validation - Datos inválidos';
        } else if (response.statusCode == 403) {
          errorMessage = 'unauthorized - Sin permisos';
        } else if (response.statusCode == 500) {
          errorMessage = '500 - Error interno del servidor';
        }

        Logger.e('Failed to create document',
            error:
                'Status: ${response.statusCode}, Message: $errorMessage, Body: ${response.body}');
        throw Exception(errorMessage);
      }
    } catch (e) {
      Logger.e('Error creating document', error: e);
      throw Exception('Error al crear el documento: $e');
    }
  }

  // Update document
  static Future<Documento> updateDocumento(Documento documento) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/documentos/${documento.id}'),
        headers: {
          ...await _getHeaders(),
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'nombre': documento.nombre,
          'descripcion': documento.descripcion,
          'gestion_id': documento.gestionId,
          'convencion': documento.convencion,
          'estado': documento.estado,
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return Documento.fromJson(data['data']);
      } else {
        final error = json.decode(response.body)['message'];
        Logger.e('Failed to update document',
            error:
                'ID: ${documento.id}, Status: ${response.statusCode}, Message: $error');
        throw Exception(error ?? 'Error al actualizar el documento');
      }
    } catch (e) {
      Logger.e('Error updating document', error: e);
      throw Exception('Error al actualizar el documento: $e');
    }
  }

  // Delete document
  static Future<bool> deleteDocumento(int id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/documentos/$id'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        final error = json.decode(response.body)['message'];
        Logger.e('Failed to delete document',
            error: 'ID: $id, Status: ${response.statusCode}, Message: $error');
        throw Exception(error ?? 'Error al eliminar el documento');
      }
    } catch (e) {
      Logger.e('Error deleting document', error: e);
      throw Exception('Error al eliminar el documento: $e');
    }
  }

  // Upload document file (source or PDF)
  static Future<Documento> uploadDocumentoFile({
    required int documentoId,
    required File file,
    required bool isPdf,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/documentos/$documentoId/upload');
      final request = http.MultipartRequest('POST', uri);

      // Add headers
      final token = await _getToken();
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      // Add file
      final mimeType = lookupMimeType(file.path) ?? 'application/octet-stream';
      final fileField = isPdf ? 'archivo_pdf' : 'archivo_fuente';
      final fileExtension = file.path.split('.').last.toLowerCase();

      request.files.add(
        await http.MultipartFile.fromPath(
          fileField,
          file.path,
          contentType: MediaType.parse(mimeType),
          filename: 'documento_$documentoId.${isPdf ? 'pdf' : fileExtension}',
        ),
      );

      // Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return Documento.fromJson(data['data']);
      } else {
        final error = json.decode(response.body)['message'];
        Logger.e('Failed to upload file',
            error:
                'DocumentID: $documentoId, Status: ${response.statusCode}, Message: $error');
        throw Exception(error ?? 'Error al subir el archivo');
      }
    } catch (e) {
      Logger.e('Error uploading file', error: e);
      throw Exception('Error al subir el archivo: $e');
    }
  }

  // Get pending documents for review count
  static Future<int> getPendientesRevisionCount() async {
    try {
      final result = await _getPendientesList('revision',
          page: 1, limit: 1, countOnly: true);
      return result['total'] as int;
    } catch (e) {
      Logger.e('Error getting pending revision count', error: e);
      return 0;
    }
  }

  // Get pending documents for approval count
  static Future<int> getPendientesAprobacionCount() async {
    try {
      final result = await _getPendientesList('aprobacion',
          page: 1, limit: 1, countOnly: true);
      return result['total'] as int;
    } catch (e) {
      Logger.e('Error getting pending approval count', error: e);
      return 0;
    }
  }

  // Consolidated method to get pending documents list
  static Future<Map<String, dynamic>> _getPendientesList(
    String type, {
    int page = 1,
    int limit = 10,
    bool countOnly = false,
  }) async {
    try {
      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
      };

      final response = await http.get(
        Uri.parse('$baseUrl/documentos/pendientes/$type')
            .replace(queryParameters: queryParams),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return {
          'documentos': (data['data'] as List)
              .map((json) => Documento.fromJson(json))
              .toList(),
          'total':
              data['pagination']?['total'] ?? (data['data'] as List).length,
          'pages': data['pagination']?['pages'] ?? 1,
          'currentPage': data['pagination']?['currentPage'] ?? page,
          'limit': data['pagination']?['limit'] ?? limit,
          'offset': data['pagination']?['offset'] ?? 0,
          'hasNext': data['pagination']?['hasNext'] ?? false,
          'hasPrev': data['pagination']?['hasPrev'] ?? false,
        };
      } else {
        Logger.e('Failed to load pending $type list',
            error: 'Status: ${response.statusCode}');
        throw Exception(
            'Error al cargar pendientes de $type: ${response.statusCode}');
      }
    } catch (e) {
      Logger.e('Error loading pending $type list', error: e);
      throw Exception('Error al cargar pendientes de $type: $e');
    }
  }

  // Get pending documents for review with pagination
  static Future<Map<String, dynamic>> getPendientesRevision({
    int page = 1,
    int limit = 10,
  }) async {
    return _getPendientesList('revision', page: page, limit: limit);
  }

  // Get pending documents for approval with pagination
  static Future<Map<String, dynamic>> getPendientesAprobacion({
    int page = 1,
    int limit = 10,
  }) async {
    return _getPendientesList('aprobacion', page: page, limit: limit);
  }

  // Update document status (review, approve, etc.)
  static Future<Documento> updateDocumentoStatus({
    required int documentoId,
    required String status,
    String? comentarios,
    int? usuarioId,
  }) async {
    try {
      String endpoint;
      Map<String, dynamic> body = {};

      switch (status) {
        case 'enviar_revision':
          endpoint = 'enviar-revision';
          body['usuario_revisor'] = usuarioId;
          break;
        case 'revisar':
          endpoint = 'revisar';
          if (comentarios != null) body['comentarios_revision'] = comentarios;
          break;
        case 'aprobar':
          endpoint = 'aprobar';
          body['usuario_aprobador'] = usuarioId;
          if (comentarios != null) body['comentarios_aprobacion'] = comentarios;
          break;
        case 'rechazar':
          endpoint = 'rechazar';
          if (comentarios != null) body['comentarios_rechazo'] = comentarios;
          break;
        default:
          throw Exception('Estado de documento no válido');
      }

      final response = await http.post(
        Uri.parse('$baseUrl/documentos/$documentoId/$endpoint'),
        headers: {
          ...await _getHeaders(),
          'Content-Type': 'application/json',
        },
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return Documento.fromJson(data['data']);
      } else {
        final error = json.decode(response.body)['message'];
        Logger.e('Failed to update document status',
            error:
                'DocumentID: $documentoId, Status: $status, ResponseStatus: ${response.statusCode}, Message: $error');
        throw Exception(error ?? 'Error al actualizar el estado del documento');
      }
    } catch (e) {
      Logger.e('Error updating document status', error: e);
      throw Exception('Error al actualizar el estado del documento: $e');
    }
  }
}
