import 'package:flutter/material.dart';
import 'package:sewin/models/documento_model.dart';
import 'package:sewin/models/gestion_model.dart';
import 'package:sewin/services/documento_service.dart';
import 'package:sewin/services/gestion_service.dart';
import 'package:sewin/services/global_error_service.dart';
import 'package:sewin/services/auth_service.dart';
import 'package:sewin/services/logger_service.dart';
import 'package:file_picker/file_picker.dart';

class DocumentoModalForm extends StatefulWidget {
  final Documento? documento;
  final Function()? onSaved;

  const DocumentoModalForm({
    super.key,
    this.documento,
    this.onSaved,
  });

  @override
  State<DocumentoModalForm> createState() => _DocumentoModalFormState();
}

class _DocumentoModalFormState extends State<DocumentoModalForm> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Controllers
  final TextEditingController _codigoController = TextEditingController();
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _descripcionController = TextEditingController();
  final TextEditingController _versionController =
      TextEditingController(text: '1');

  // Form values
  String _selectedEstado = 'borrador';
  int? _selectedGestionId;
  String? _selectedGestionNombre;
  String? _selectedConvencion;
  int? _documentoVinculadoId;
  String? _archivoFuentePath;
  String? _archivoPdfPath;

  // Convenciones posibles
  final List<String> _convenciones = [
    'Manual',
    'Procedimiento',
    'Instructivo',
    'Formato',
    'Documento Externo'
  ];

  // Gestiones disponibles (dynamic data from API)
  List<Gestion> _gestiones = [];
  bool _loadingGestiones = false;

  // Documentos disponibles para vincular
  List<Map<String, dynamic>> _documentosDisponibles = [];
  bool _loadingDocumentos = false;

  @override
  void initState() {
    super.initState();
    _loadGestiones();
    _loadDocumentosDisponibles();
    if (widget.documento != null) {
      _loadDocumentoData();
    }
  }

  Future<void> _loadGestiones() async {
    setState(() {
      _loadingGestiones = true;
    });

    try {
      final gestiones = await GestionService.getGestiones();
      setState(() {
        _gestiones = gestiones;
        _loadingGestiones = false;
      });
    } catch (e) {
      Logger.e('Error loading gestiones',
          error: e, stackTrace: StackTrace.current);
      setState(() {
        _loadingGestiones = false;
      });
    }
  }

  Future<void> _loadDocumentosDisponibles() async {
    setState(() {
      _loadingDocumentos = true;
    });

    try {
      final result = await DocumentoService.getDocumentos(
        limit: 100, // Get more documents for selection
      );

      final documentos = result['documentos'] as List<Documento>;

      setState(() {
        _documentosDisponibles = documentos
            .where((doc) =>
                widget.documento == null ||
                doc.id !=
                    widget.documento!.id) // Exclude current document if editing
            .map((doc) => {
                  'id': doc.id,
                  'display': '(${doc.codigo}) ${doc.nombre}',
                })
            .toList();
        _loadingDocumentos = false;
      });
    } catch (e) {
      Logger.e('Error loading documentos disponibles',
          error: e, stackTrace: StackTrace.current);
      setState(() {
        _loadingDocumentos = false;
      });
    }
  }

  void _loadDocumentoData() {
    final doc = widget.documento!;
    _codigoController.text = doc.codigo;
    _nombreController.text = doc.nombre;
    _descripcionController.text = doc.descripcion;
    _versionController.text = doc.version.toString();
    _selectedEstado = doc.estado;
    _selectedGestionId = doc.gestionId;
    _selectedGestionNombre = doc.gestionNombre;
    _selectedConvencion = doc.convencion;
    _documentoVinculadoId = doc.vinculadoA;
    _archivoFuentePath = doc.archivoFuente;
    _archivoPdfPath = doc.archivoPdf;
  }

  @override
  void dispose() {
    _codigoController.dispose();
    _nombreController.dispose();
    _descripcionController.dispose();
    _versionController.dispose();
    super.dispose();
  }

  Future<void> _saveDocumento() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Get current user from auth
      final authService = AuthService();
      final currentUser = await authService.getCurrentUser();

      final documento = Documento(
        id: widget.documento?.id ?? 0,
        codigo: _codigoController.text.trim(),
        nombre: _nombreController.text.trim(),
        descripcion: _descripcionController.text.trim().isEmpty
            ? 'Descripción del documento ${_codigoController.text.trim()}'
            : _descripcionController.text.trim(),
        version: int.tryParse(_versionController.text) ?? 1,
        estado: _selectedEstado,
        gestionId: _selectedGestionId ?? 1,
        gestionNombre: _selectedGestionNombre ?? 'Gestión por defecto',
        convencion: _selectedConvencion ?? 'Instructivo',
        vinculadoA: _documentoVinculadoId,
        archivoFuente: _archivoFuentePath,
        archivoPdf: _archivoPdfPath,
        fechaCreacion: widget.documento?.fechaCreacion ?? DateTime.now(),
        fechaActualizacion: DateTime.now(),
        usuarioCreador: currentUser?['id'] ?? 1,
        creadorNombre: currentUser?['nombre'] ?? 'Usuario Actual',
        isSigned: false,
      );

      String actionMessage;
      if (widget.documento == null) {
        Logger.i('Creating new documento: ${documento.codigo}');
        await DocumentoService.createDocumento(documento);
        actionMessage = 'Documento creado exitosamente';
      } else {
        Logger.i('Updating documento: ${documento.codigo}');
        await DocumentoService.updateDocumento(documento);
        actionMessage = 'Documento actualizado exitosamente';
      }

      // Show success notification
      if (mounted) {
        GlobalErrorService.showSuccess(
          actionMessage,
          context: context,
          duration: const Duration(seconds: 3),
        );
      }

      if (mounted) {
        Navigator.of(context).pop();
        if (widget.onSaved != null) {
          widget.onSaved!();
        }
      }
    } catch (e) {
      Logger.e('Error saving documento', error: e);
      GlobalErrorService.showApiError(e, context: context);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.25, // 25% margin on each side
        vertical: screenHeight * 0.05, // 5% margin top/bottom
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: screenWidth * 0.9, // Max 70% of screen width
            minWidth: 400, // Minimum width for usability
            maxHeight: screenHeight * 0.9, // Max 90% of screen height
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        widget.documento == null
                            ? 'Nuevo Documento'
                            : 'Editar Documento',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Legend for required fields
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline,
                            color: Colors.blue[700], size: 16),
                        const SizedBox(width: 8),
                        const Text(
                          'Los campos con borde rojo son obligatorios',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Gestión (Required)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Gestión',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                              color: Colors.red.withAlpha(76), width: 1),
                        ),
                        child: DropdownButtonFormField<int>(
                          value:
                              _gestiones.any((g) => g.id == _selectedGestionId)
                                  ? _selectedGestionId
                                  : null,
                          items: _loadingGestiones
                              ? []
                              : _gestiones.map((gestion) {
                                  return DropdownMenuItem<int>(
                                    value: gestion.id,
                                    child: Text(gestion.nombre),
                                  );
                                }).toList(),
                          onChanged: _loadingGestiones
                              ? null
                              : (value) {
                                  setState(() {
                                    _selectedGestionId = value;
                                    _selectedGestionNombre = _gestiones
                                        .firstWhere((g) => g.id == value)
                                        .nombre;
                                  });
                                },
                          decoration: const InputDecoration(
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 16),
                            border: InputBorder.none,
                          ),
                          hint: _loadingGestiones
                              ? const Text('Cargando gestiones...')
                              : const Text('Seleccionar Gestión'),
                          validator: (value) {
                            if (value == null) {
                              return 'Por favor seleccione una gestión';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Convención (Required)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Convención',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                              color: Colors.red.withAlpha(76), width: 1),
                        ),
                        child: DropdownButtonFormField<String>(
                          value: _convenciones.contains(_selectedConvencion)
                              ? _selectedConvencion
                              : null,
                          items: _convenciones.map((convencion) {
                            return DropdownMenuItem<String>(
                              value: convencion,
                              child: Text(convencion),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedConvencion = value;
                            });
                          },
                          decoration: const InputDecoration(
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 16),
                            border: InputBorder.none,
                          ),
                          hint: const Text('Seleccionar Convención'),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor seleccione una convención';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Documento vinculado
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Documento vinculado',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<int>(
                        initialValue: _documentosDisponibles
                                .any((d) => d['id'] == _documentoVinculadoId)
                            ? _documentoVinculadoId
                            : null,
                        items: _loadingDocumentos
                            ? []
                            : _documentosDisponibles
                                .map<DropdownMenuItem<int>>(
                                    (doc) => DropdownMenuItem<int>(
                                          value: doc['id'] as int,
                                          child: Text(doc['display'] as String),
                                        ))
                                .toList(),
                        onChanged: _loadingDocumentos
                            ? null
                            : (value) {
                                setState(() {
                                  _documentoVinculadoId = value;
                                });
                              },
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 16),
                          border: OutlineInputBorder(),
                        ),
                        hint: _loadingDocumentos
                            ? const Text('Cargando documentos...')
                            : const Text('Seleccionar documento'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Archivo Fuente
                  _buildFileUploadField(
                    'Archivo Fuente',
                    _archivoFuentePath ?? 'Seleccionar archivo fuente',
                    () => _selectFile(isSource: true),
                  ),
                  const SizedBox(height: 16),

                  // Archivo PDF
                  _buildFileUploadField(
                    'Archivo PDF',
                    _archivoPdfPath ?? 'Seleccionar archivo PDF',
                    () => _selectFile(isSource: false),
                  ),
                  const SizedBox(height: 16),

                  // Identificador (Required)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Identificador',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                              color: Colors.red.withAlpha(76), width: 1),
                        ),
                        child: TextFormField(
                          controller: _codigoController,
                          decoration: const InputDecoration(
                            hintText: 'MGH-01-09-01',
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 16),
                            border: InputBorder.none,
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor ingrese un identificador';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Nombre del Documento (Required)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Nombre del Documento',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                              color: Colors.red.withAlpha(76), width: 1),
                        ),
                        child: TextFormField(
                          controller: _nombreController,
                          decoration: const InputDecoration(
                            hintText: 'DOCUMENTO DE PRUEBA',
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 16),
                            border: InputBorder.none,
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor ingrese un nombre';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Descripción del Documento (opcional)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Descripción',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          border:
                              Border.all(color: Colors.grey[300]!, width: 1),
                        ),
                        child: TextFormField(
                          controller: _descripcionController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            hintText: 'Descripción detallada del documento...',
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 16),
                            border: InputBorder.none,
                          ),
                          // Optional field - no validation needed
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Botones de acción
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _isLoading
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: const Text('Cancelar'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _saveDocumento,
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(widget.documento == null
                                ? 'Guardar'
                                : 'Actualizar'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Helper method to build file upload field
  Widget _buildFileUploadField(String label, String value, VoidCallback onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 16,
                      color: value == 'Seleccionar archivo'
                          ? Colors.grey[600]
                          : Colors.black,
                    ),
                  ),
                ),
                Icon(Icons.attach_file, color: Colors.grey[600]),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // File selection method
  void _selectFile({required bool isSource}) async {
    try {
      // Log file picker initialization
      Logger.d(
          '_selectFile() called - starting file picker for ${isSource ? 'source' : 'PDF'} file');

      List<String> allowedExtensions;
      String fileType;

      if (isSource) {
        // Source file can be various document formats
        allowedExtensions = ['pdf', 'doc', 'docx', 'txt', 'xlsx', 'xls'];
        fileType = 'archivo fuente';
      } else {
        // PDF file should only be PDF
        allowedExtensions = ['pdf'];
        fileType = 'archivo PDF';
      }

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: allowedExtensions,
        allowMultiple: false,
      );

      Logger.d('File picker result received');

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.single;
        Logger.d('Selected file: ${file.name}, size: ${file.size} bytes');

        // Handle web platform (path is always null on web)
        setState(() {
          if (isSource) {
            _archivoFuentePath = file.name; // Store filename for source file
          } else {
            _archivoPdfPath = file.name; // Store filename for PDF file
          }
        });

        Logger.d('File selected successfully: ${file.name}');
        Logger.d('File size: ${file.size} bytes');
        Logger.d('Platform: Web');

        // Use enhanced GlobalErrorService with local context
        GlobalErrorService.showSuccess('$fileType seleccionado: ${file.name}',
            context: context);
      } else {
        Logger.i('File picker cancelled or no files selected');
        // Use enhanced GlobalErrorService with local context
        GlobalErrorService.showWarning('Selección de $fileType cancelada',
            context: context);
      }
    } catch (e) {
      Logger.e('File picker error', error: e, stackTrace: StackTrace.current);

      // Use enhanced GlobalErrorService with local context
      GlobalErrorService.showError(
          'Error al seleccionar archivo: ${e.toString()}',
          context: context);
    }
  }
}
