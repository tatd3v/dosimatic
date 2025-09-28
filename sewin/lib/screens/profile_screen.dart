import 'dart:convert' show json, base64Url, utf8, base64Decode;
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:signature/signature.dart';
import 'package:image/image.dart' as img;
import '../services/auth_service.dart';
import '../services/logger_service.dart';
import '../services/signature_service.dart';
import '../services/user_service.dart';
import '../widgets/app_drawer.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _currentUser;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  // Digital signature variables
  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 2,
    penColor: Colors.black,
    exportBackgroundColor: Colors.transparent,
  );
  Uint8List? _signatureBytes;
  String? _signatureFilePath;
  Uint8List? _tempSignatureBytes; // For web platform
  bool _isSignatureSaved = false; // Track if signature is saved

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  @override
  void dispose() {
    _signatureController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    try {
      // Get the user ID from the JWT token
      final authService = AuthService();
      final token = await authService.getToken();

      if (token == null) {
        throw Exception('No authentication token found');
      }

      // Extract user ID from JWT token
      final tokenParts = token.split('.');
      if (tokenParts.length != 3) {
        throw Exception('Invalid token format');
      }

      final payload = json.decode(
              utf8.decode(base64Url.decode(base64Url.normalize(tokenParts[1]))))
          as Map<String, dynamic>;

      final userId = payload['id']?.toString();
      if (userId == null) {
        throw Exception('No user ID found in token');
      }

      // Fetch the full user details from UserService
      final userService = UserService();
      final userData = await userService.getUserById(userId);

      if (mounted) {
        setState(() {
          _currentUser = userData;
          _isLoading = false;

          // User data loaded successfully

          // Load signature if exists
          if (_currentUser!['signature_image'] != null) {
            try {
              final signatureData = _currentUser!['signature_image'];
              if (signatureData is String && signatureData.isNotEmpty) {
                Uint8List? imageBytes;

                if (signatureData.startsWith('data:image/')) {
                  // Handle data URL (base64 encoded image)
                  final mimeMatch = RegExp(r'^data:image\/(\w+);base64,')
                      .firstMatch(signatureData);
                  if (mimeMatch != null) {
                    imageBytes = base64Decode(signatureData.split(',').last);
                  }
                } else {
                  // Handle raw base64 string (legacy)
                  imageBytes = base64Decode(signatureData);
                }

                // Update the state with the loaded signature
                if (mounted) {
                  setState(() {
                    _signatureBytes = imageBytes;
                  });
                }
              }
            } catch (e) {
              Logger.e('Error loading signature', error: e);
              // Clear any invalid signature data
              if (mounted) {
                setState(() {
                  _signatureBytes = null;
                });
              }
            }
          }
        });
      }
    } catch (e, stackTrace) {
      Logger.e('Error loading user data', error: e, stackTrace: stackTrace);

      if (mounted) {
        setState(() {
          _errorMessage =
              'Error al cargar la información del usuario: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  String _getInitials(String? name) {
    if (name == null || name.isEmpty) return 'U';
    final words = name.split(' ');
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  String _formatAffiliationDate() {
    if (_currentUser == null || _currentUser!['fecha_creacion'] == null) {
      return 'No disponible';
    }

    try {
      // Parse the ISO 8601 date string from the server
      final dateTime = DateTime.parse(_currentUser!['fecha_creacion']);

      // Format the date as DD/MM/YYYY HH:mm
      return '${dateTime.day.toString().padLeft(2, '0')}/'
          '${dateTime.month.toString().padLeft(2, '0')}/'
          '${dateTime.year} '
          '${dateTime.hour.toString().padLeft(2, '0')}:'
          '${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      Logger.e('Error formateando fecha de afiliación', error: e);
      return 'Fecha inválida';
    }
  }

  // Digital signature methods
  Future<Uint8List?> _removeWhiteBackground(Uint8List imageBytes) async {
    try {
      final image = img.decodeImage(imageBytes);
      if (image == null) return null;

      final transparentImage = img.Image(
        width: image.width,
        height: image.height,
        numChannels: 4,
      );

      img.fill(transparentImage, color: img.ColorRgba8(0, 0, 0, 0));

      for (int y = 0; y < image.height; y++) {
        for (int x = 0; x < image.width; x++) {
          final pixel = image.getPixel(x, y);
          final r = pixel.r.toInt();
          final g = pixel.g.toInt();
          final b = pixel.b.toInt();

          if (!(r > 240 && g > 240 && b > 240)) {
            transparentImage.setPixel(x, y, pixel);
          }
        }
      }

      return Uint8List.fromList(img.encodePng(transparentImage));
    } catch (e) {
      Logger.e('Error removing background', error: e);
      return imageBytes;
    }
  }

  Future<String?> _saveSignatureToFile(
      Uint8List signatureBytes, String userId) async {
    try {
      if (kIsWeb) {
        // For web, we'll use the SignatureService directly with bytes
        // Return a temporary identifier that we can use later
        final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
        final tempId = 'web_signature_${userId}_$timestamp';

        // Store the bytes temporarily in a variable for web
        _tempSignatureBytes = signatureBytes;

        Logger.d('Firma preparada para web: $tempId');
        return tempId;
      } else {
        // For mobile/desktop, save to temp directory
        final tempDir = Directory.systemTemp;
        final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
        final fileName = 'signature_${userId}_$timestamp.png';
        final filePath = '${tempDir.path}/$fileName';

        final file = File(filePath);
        await file.writeAsBytes(signatureBytes);

        Logger.d('Firma guardada en: $filePath');
        return filePath;
      }
    } catch (e) {
      Logger.e('Error guardando firma', error: e);
      return null;
    }
  }

  Future<void> _captureSignature() async {
    if (_signatureController.isEmpty) return;

    try {
      final signature = await _signatureController.toPngBytes();
      if (signature != null) {
        Uint8List? processedSignature = await _removeWhiteBackground(signature);

        if (processedSignature != null && _currentUser != null) {
          final userId = _currentUser!['id'].toString();
          final filePath =
              await _saveSignatureToFile(processedSignature, userId);

          setState(() {
            _signatureBytes = processedSignature;
            _signatureFilePath = filePath;
          });
        }
      }
    } catch (e) {
      Logger.e('Error capturing signature', error: e);
    }
  }

  Future<void> _uploadSignature() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.single.bytes != null) {
        Uint8List imageBytes = result.files.single.bytes!;
        imageBytes = await _removeWhiteBackground(imageBytes) ?? imageBytes;

        if (_currentUser != null) {
          final userId = _currentUser!['id'].toString();
          final filePath = await _saveSignatureToFile(imageBytes, userId);

          setState(() {
            _signatureBytes = imageBytes;
            _signatureFilePath = filePath;
          });
        }
      }
    } catch (e) {
      Logger.e('Error uploading signature', error: e);
    }
  }

  void _clearSignature() {
    _signatureController.clear();
    setState(() {
      _signatureBytes = null;
      _signatureFilePath = null;
      _tempSignatureBytes = null;
      _isSignatureSaved = false; // Reset saved state when clearing signature
    });
  }

  Future<void> _saveSignature() async {
    if ((_signatureFilePath == null && _tempSignatureBytes == null) ||
        _currentUser == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'No hay firma para guardar. Dibuja o sube una firma primero.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final userId = _currentUser!['id'].toString();
      bool success = false;

      if (kIsWeb && _tempSignatureBytes != null) {
        // For web, use the SignatureService method that works with bytes directly
        success = await SignatureService.associateSignatureToUserWithBytes(
            userId, _tempSignatureBytes!);
      } else if (_signatureFilePath != null) {
        // For native platforms, use the file path directly
        success = await SignatureService.associateSignatureToUser(
          userId,
          _signatureFilePath!,
        );
      }

      if (success) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Firma guardada exitosamente'),
              backgroundColor: Colors.green,
            ),
          );
        }

        // Update state to indicate signature is saved
        if (mounted) {
          setState(() {
            _isSignatureSaved = true;
          });
        }

        // Reload user data to show the saved signature
        await _loadCurrentUser();
      } else {
        throw Exception('No se pudo guardar la firma en el servidor');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar la firma: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Widget _buildProfileField({
    required String label,
    required String value,
    Widget? customContent,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF7F8C8D),
            ),
          ),
          const SizedBox(height: 8),
          customContent ??
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  color: Color(0xFF2C3E50),
                  fontWeight: FontWeight.w500,
                ),
              ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil'),
        backgroundColor: Colors.grey[100],
        foregroundColor: const Color(0xFF2C3E50),
        elevation: 0,
      ),
      drawer: const AppDrawer(),
      backgroundColor: Colors.grey[50],
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1ABC9C)),
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.red[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadCurrentUser,
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 500),
                      child: Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header with title
                              const Text(
                                'Detalles del Perfil',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2C3E50),
                                ),
                              ),
                              const SizedBox(height: 32),

                              // Avatar with initials
                              Center(
                                child: SizedBox(
                                  width: 70,
                                  height: 70,
                                  child: CircleAvatar(
                                    radius: 30,
                                    backgroundColor: const Color(0xFF1ABC9C),
                                    child: Text(
                                      _getInitials(_currentUser!['nombre']),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 24,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Nombre
                              _buildProfileField(
                                label: 'Nombre',
                                value: _currentUser!['nombre']?.toString() ??
                                    'Usuario',
                              ),
                              // Fecha/hora de la afiliación
                              _buildProfileField(
                                label: 'Afiliado desde',
                                value: _formatAffiliationDate(),
                              ),

                              // Digital Signature Section
                              const Text(
                                'Firma Digital',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2C3E50),
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Signature area
                              Container(
                                width: double.infinity,
                                height: 200,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                      color: Colors.grey.shade300, width: 2),
                                  borderRadius: BorderRadius.circular(8),
                                  color: Colors.grey.shade50,
                                ),
                                child: _signatureBytes != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: _signatureBytes!.isNotEmpty
                                            ? Image.memory(
                                                _signatureBytes!,
                                                fit: BoxFit.contain,
                                                errorBuilder: (context, error,
                                                    stackTrace) {
                                                  Logger.e(
                                                      'Error loading signature image',
                                                      error: error);
                                                  return Container(
                                                    color: Colors.grey[200],
                                                    child: Center(
                                                      child: Column(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .center,
                                                        children: [
                                                          Icon(
                                                              Icons
                                                                  .error_outline,
                                                              color: Colors.red,
                                                              size: 48),
                                                          SizedBox(height: 8),
                                                          Text(
                                                            'Error loading signature',
                                                            style: TextStyle(
                                                                color:
                                                                    Colors.red),
                                                          ),
                                                          Text(
                                                            '${_signatureBytes!.length} bytes',
                                                            style: TextStyle(
                                                                fontSize: 12),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  );
                                                },
                                              )
                                            : Container(
                                                color: Colors.grey[200],
                                                child: Center(
                                                  child: Text(
                                                      'Empty signature data'),
                                                ),
                                              ),
                                      )
                                    : Signature(
                                        controller: _signatureController,
                                        backgroundColor: Colors.transparent,
                                      ),
                              ),
                              const SizedBox(height: 16),

                              // Digital signature action buttons
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  // Upload button
                                  ElevatedButton.icon(
                                    onPressed: _uploadSignature,
                                    icon: const Icon(Icons.upload_file),
                                    label: const Text('Subir'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 8),
                                    ),
                                  ),

                                  // Capture button
                                  ElevatedButton.icon(
                                    onPressed: _signatureBytes == null
                                        ? _captureSignature
                                        : null,
                                    icon: const Icon(Icons.check),
                                    label: const Text('Capturar'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 8),
                                    ),
                                  ),

                                  // Clear button
                                  ElevatedButton.icon(
                                    onPressed: _clearSignature,
                                    icon: const Icon(Icons.clear),
                                    label: const Text('Limpiar'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 8),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 16),

                              // Save signature button
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: !_isSignatureSaved && 
                                          (_signatureFilePath != null ||
                                           _tempSignatureBytes != null) &&
                                          !_isSaving
                                      ? _saveSignature
                                      : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: !_isSignatureSaved &&
                                            (_signatureFilePath != null ||
                                             _tempSignatureBytes != null) &&
                                            !_isSaving
                                        ? const Color(0xFF1ABC9C)
                                        : Colors.grey[400],
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    elevation: 2,
                                  ),
                                  child: _isSaving
                                      ? const Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                        Color>(Colors.white),
                                              ),
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              'Guardando...',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        )
                                      : Text(
                                          _isSignatureSaved ? 'Firma Guardada' : 'Guardar Firma',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                ),
                              ),

                              // Information text
                              const Padding(
                                padding: EdgeInsets.only(top: 8.0),
                                child: Text(
                                  'Dibuja tu firma en el área gris, sube una imagen, o captura la firma dibujada antes de guardar.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                    fontStyle: FontStyle.italic,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
    );
  }
}
