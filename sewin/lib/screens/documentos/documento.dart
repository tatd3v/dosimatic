import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sewin/models/documento_model.dart';
import 'package:sewin/services/documento_service.dart';
import 'package:sewin/services/global_error_service.dart';
import 'package:sewin/screens/documentos/documento_modal_form.dart';
import 'package:sewin/utils/document_utils.dart';
import 'package:sewin/widgets/app_drawer.dart';
import 'package:sewin/widgets/lookup.dart';
import 'package:sewin/global/global_constantes.dart';
import 'package:sewin/widgets/pagination_controls.dart';

class DocumentosPage extends StatefulWidget {
  const DocumentosPage({super.key});

  @override
  _DocumentosPageState createState() => _DocumentosPageState();
}

class _DocumentosPageState extends State<DocumentosPage> {
  // Lista para almacenar los documentos
  List<Documento> _documentos = [];
  List<Documento> _filteredDocumentos = [];
  List<Documento> _pendientesPorAprobar = [];
  List<Documento> _pendientesPorRevisar = [];
  int _pendientesRevisionCount = 0;
  int _pendientesAprobacionCount = 0;
  String? _errorMessage;
  // Search functionality
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // State variables for filtering
  String? _filterCodigo;
  String? _filterNombre;
  String? _filterEstado;
  String? _filterConvencion;
  String? _filterGestion;

  // Pagination state variables
  int _currentPage = 1;
  int _totalCount = 0;
  int _itemsPerPage = 10;

  // View selection state
  String _selectedView = 'resumen';

  // Loading state management
  bool _isLoading = false; // Tracks if data is being fetched
  bool _showLoadingIndicator =
      false; // Controls visibility of loading indicator
  Timer? _loadingTimer; // Timer for delayed loading indicator

  @override
  void initState() {
    super.initState();
    // Load initial documents when the widget is created
    _fetchDocuments();
  }

  /// Fetches documents from the backend and updates the UI
  /// Also fetches pending counts for the sidebar
  /// Now supports proper server-side pagination
  void _startLoadingTimer() {
    _loadingTimer?.cancel();
    _loadingTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _showLoadingIndicator = true;
        });
      }
    });
  }

  void _stopLoadingTimer() {
    _loadingTimer?.cancel();
    if (mounted) {
      setState(() {
        _showLoadingIndicator = false;
      });
    }
  }

  @override
  void dispose() {
    _loadingTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchDocuments({int page = 1}) async {
    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });
    _startLoadingTimer();

    try {
      // Fetch documents with pagination and pending counts in parallel
      final results = await Future.wait([
        DocumentoService.getDocumentos(
          page: page,
          limit: _itemsPerPage,
          search: _searchQuery.isNotEmpty ? _searchQuery : null,
          estado: _filterEstado,
          convencion: _filterConvencion,
          gestionId:
              _filterGestion != null ? int.tryParse(_filterGestion!) : null,
        ),
        DocumentoService.getPendientesRevisionCount(),
        DocumentoService.getPendientesAprobacionCount(),
      ]);

      final documentResult = results[0] as Map<String, dynamic>;
      final documentos = documentResult['documentos'] as List<Documento>;

      setState(() {
        _documentos = documentos;
        _filteredDocumentos = documentos; // No client-side filtering needed

        // Update pagination state
        _currentPage = documentResult['currentPage'] ?? 1;
        _totalCount = documentResult['total'] ?? 0;

        _pendientesRevisionCount = results[1] as int;
        _pendientesAprobacionCount = results[2] as int;

        // Update pending lists (these might need separate pagination later)
        _pendientesPorAprobar =
            documentos.where((doc) => doc.estado == 'en_revision').toList();

        _pendientesPorRevisar =
            documentos.where((doc) => doc.estado == 'borrador').toList();

        _isLoading = false;
      });
    } catch (e) {
      GlobalErrorService.showError('Error al cargar documentos: $e');
      setState(() {
        _errorMessage = 'Error al cargar documentos';
        _isLoading = false;
      });
    } finally {
      _stopLoadingTimer();
    }
  }

  // Función para obtener documentos filtrados por vista
  Future<void> _fetchFilteredDocuments(String view, {int page = 1}) async {
    if (view == 'resumen') {
      await _fetchDocuments(page: page);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _currentPage = page; // Update current page for filtered views
    });
    _startLoadingTimer();

    try {
      Map<String, dynamic> filteredResult = {};

      if (view == 'aprobar') {
        filteredResult = await DocumentoService.getPendientesAprobacion(
            page: page, limit: _itemsPerPage);
        setState(() {
          _pendientesPorAprobar =
              filteredResult['documentos'] as List<Documento>;
        });
      } else if (view == 'revisar') {
        filteredResult = await DocumentoService.getPendientesRevision(
            page: page, limit: _itemsPerPage);
        setState(() {
          _pendientesPorRevisar =
              filteredResult['documentos'] as List<Documento>;
        });
      }

      // Update pagination state with proper total count
      setState(() {
        _totalCount = filteredResult['total'] as int;
        _isLoading = false;
      });
      _stopLoadingTimer(); // Stop the loading timer after successful data load
    } catch (e) {
      _stopLoadingTimer(); // Ensure timer is stopped on error
      setState(() {
        _errorMessage = 'Error de conexión: $e';
        _isLoading = false;
      });
    }
  }

  // Función para eliminar un documento
  Future<void> _deleteDocumento(int id) async {
    final bool confirm = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Confirmar Eliminación'),
            content: const Text(
                '¿Estás seguro de que quieres eliminar este documento?'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Eliminar'),
              ),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      try {
        setState(() {
          _isLoading = true;
        });

        final success = await DocumentoService.deleteDocumento(id);
        if (success) {
          // Clear all filters and refresh the document list
          await _clearAllFilters();
          GlobalErrorService.showSuccess('Documento eliminado con éxito.');
        } else {
          setState(() {
            _isLoading = false;
          });
          GlobalErrorService.showError('Error al eliminar el documento.');
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        GlobalErrorService.showError('Error de conexión: $e');
      }
    }
  }

  // Show firmar context menu
  void _showFirmarMenu(BuildContext context, Documento doc) {
    showMenu(
      context: context,
      position: const RelativeRect.fromLTRB(100, 100, 0, 0),
      items: [
        const PopupMenuItem<String>(
          value: 'firmar_digital',
          child: Row(
            children: [
              Icon(Icons.edit_note, size: 18, color: Colors.green),
              SizedBox(width: 8),
              Text('Firma Digital'),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'firmar_fisica',
          child: Row(
            children: [
              Icon(Icons.draw, size: 18, color: Colors.blue),
              SizedBox(width: 8),
              Text('Firma Física'),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'aprobar',
          child: Row(
            children: [
              Icon(Icons.check_circle, size: 18, color: Colors.orange),
              SizedBox(width: 8),
              Text('Aprobar'),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value != null) {
        _handleFirmarAction(value, doc);
      }
    });
  }

  // Handle firmar action selection
  void _handleFirmarAction(String action, Documento doc) {
    switch (action) {
      case 'firmar_digital':
        // TODO: Implement digital signature functionality
        print('Firmar digitalmente documento: ${doc.nombre}');
        break;
      case 'firmar_fisica':
        // TODO: Implement physical signature functionality
        print('Firmar físicamente documento: ${doc.nombre}');
        break;
      case 'aprobar':
        // TODO: Implement approval functionality
        print('Aprobar documento: ${doc.nombre}');
        break;
    }
  }

  /// Applies filters to the document list
  List<Documento> _applyFilters(List<Documento> documents) {
    List<Documento> filtered = documents;

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where((doc) =>
              doc.codigo.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              doc.nombre.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }

    // Apply column filters
    if (_filterCodigo != null) {
      filtered = filtered.where((doc) => doc.codigo == _filterCodigo).toList();
    }
    if (_filterNombre != null) {
      filtered = filtered.where((doc) => doc.nombre == _filterNombre).toList();
    }
    if (_filterEstado != null) {
      filtered = filtered.where((doc) => doc.estado == _filterEstado).toList();
    }
    if (_filterConvencion != null) {
      filtered =
          filtered.where((doc) => doc.convencion == _filterConvencion).toList();
    }
    if (_filterGestion != null) {
      filtered =
          filtered.where((doc) => doc.gestionNombre == _filterGestion).toList();
    }

    return filtered;
  }

  /// Applies search filter and updates the document list
  /// Only triggers search when explicitly called (via button press or Enter key)
  /// Now performs server-side database search with proper pagination reset
  Future<void> _applySearchFilter() async {
    final query = _searchController.text.trim();
    setState(() {
      _searchQuery = query;
      _currentPage = 1; // Reset to first page when searching
    });

    // Handle specific column filters
    if (_filterCodigo != null) {
      setState(() => _searchQuery = _filterCodigo!);
    } else if (_filterNombre != null) {
      setState(() => _searchQuery = _filterNombre!);
    }

    // Use the main fetch method which now handles all filtering and pagination
    await _fetchDocuments(page: 1);
  }

  /// Clears all filters and resets the document list
  /// Performs fresh database fetch without any filters and resets pagination
  Future<void> _clearAllFilters() async {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _filterCodigo = null;
      _filterNombre = null;
      _filterEstado = null;
      _filterConvencion = null;
      _filterGestion = null;
      _currentPage = 1; // Reset pagination
      _selectedView = 'resumen'; // Reset to main view
    });

    // Use the main fetch method which handles everything
    await _fetchDocuments(page: 1);
  }

  /// Shows lookup dialog for column filtering using the real lookup.dart widget
  /// This makes API calls to search the database for large datasets
  Future<void> _showColumnLookup(
    BuildContext context,
    String columnName,
    Function(String?) onSelected,
    String? currentValue,
  ) async {
    // Generate the appropriate API URL for each column type
    String lookupUrl = _getLookupUrl(columnName);

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          width: 500,
          height: 600,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.teal[600],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.filter_list, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Filtrar por $columnName',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Clear filter option
              if (currentValue != null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 16),
                  child: ElevatedButton.icon(
                    onPressed: () {
                      onSelected(null);
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.clear_all),
                    label: const Text('Mostrar todo (Limpiar filtro)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange[600],
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),

              // Real lookup widget with API integration
              Expanded(
                child: lookupPage(
                  urllokup: lookupUrl,
                  etiqueta: columnName,
                  onCountSelected: () {
                    // Handle selection count if needed
                  },
                  onItemSelected: (String id, String code, String name) {
                    // For 'nombre' filter, use the display name instead of ID
                    // For other filters, use the id parameter
                    final selectedValue =
                        columnName.toLowerCase() == 'nombre' ? name : id;
                    onSelected(selectedValue);
                    // DON'T call Navigator.pop() here - the lookup widget handles it
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Generates the appropriate lookup URL for each column type
  String _getLookupUrl(String columnName) {
    final String baseUrl = '${Constants.serverapp}/api';

    switch (columnName.toLowerCase()) {
      case 'código':
        return '$baseUrl/documentos/lookup/codigo';
      case 'nombre':
        return '$baseUrl/documentos/lookup/nombre';
      case 'estado':
        return '$baseUrl/documentos/lookup/estado';
      case 'convención':
        return '$baseUrl/documentos/lookup/convencion';
      case 'gestión':
        return '$baseUrl/documentos/lookup/gestion';
      case 'id':
        return '$baseUrl/documentos/lookup/id';
      default:
        return '$baseUrl/documentos/lookup/general';
    }
  }

  int _getDocumentCount() {
    switch (_selectedView) {
      case 'aprobar':
        return _totalCount; // Use total count from pagination for filtered views
      case 'revisar':
        return _totalCount; // Use total count from pagination for filtered views
      default:
        return _totalCount;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Gestión de Documentos'),
        elevation: 0, // Remove shadow/elevation
        scrolledUnderElevation: 0, // Prevent elevation when scrolling
        surfaceTintColor: Colors.transparent, // Prevent color tinting
        backgroundColor: Colors.grey[100], // Match left navbar background color
      ),
      body: Column(
        children: [
          // Header section spanning full width
          _buildHeaderSection(),
          
          // Main content area with left navbar and right content
          Expanded(
            child: Row(
              children: [
                // Left Navbar
                Container(
                  width: 280,
                  color: Colors.grey[100],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                // Agregar Documento Button
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ElevatedButton(
                    onPressed: () => _showAddEditDialog(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Agregar Documento',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

                // RESUMEN Section
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        spreadRadius: 1,
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'RESUMEN',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Pendientes por Aprobar
                      InkWell(
                        onTap: () {
                          setState(() => _selectedView = 'aprobar');
                          _fetchFilteredDocuments('aprobar', page: 1);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 8, horizontal: 12),
                          decoration: BoxDecoration(
                            color: _selectedView == 'aprobar'
                                ? Colors.orange[50]
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 20,
                                height: 20,
                                decoration: const BoxDecoration(
                                  color: Colors.orange,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '$_pendientesAprobacionCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'Pendientes por Aprobar',
                                  style: TextStyle(fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Pendientes por Revisar
                      InkWell(
                        onTap: () {
                          setState(() => _selectedView = 'revisar');
                          _fetchFilteredDocuments('revisar', page: 1);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 8, horizontal: 12),
                          decoration: BoxDecoration(
                            color: _selectedView == 'revisar'
                                ? Colors.red[50]
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 20,
                                height: 20,
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '$_pendientesRevisionCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'Pendientes por Revisar',
                                  style: TextStyle(fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

                // Right Content Area
                Expanded(
                  child: _buildRightContent(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Navigation tabs with slash separators
          _buildHeaderTab('Inicio', false),
          _buildSlashSeparator(),
          _buildHeaderTab('Gestión Documental', false),
          _buildSlashSeparator(),
          _buildHeaderTab('Documentos', true),
        ],
      ),
    );
  }

  // Helper widget for slash separator
  Widget _buildSlashSeparator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Text(
        '/',
        style: TextStyle(
          fontSize: 14,
          color: Colors.grey[600],
        ),
      ),
    );
  }

  Widget _buildHeaderTab(String title, bool isActive) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 14,
        fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
        color: isActive ? const Color(0xFF2C3E50) : Colors.grey[600],
      ),
    );
  }

  Widget _buildRightContent() {
    if (_errorMessage != null) {
      return Center(child: Text(_errorMessage!));
    }

    List<Documento> documentsToShow;
    String title;

    switch (_selectedView) {
      case 'aprobar':
        documentsToShow = _pendientesPorAprobar;
        title = 'Pendientes por Aprobar';
        break;
      case 'revisar':
        documentsToShow = _pendientesPorRevisar;
        title = 'Pendientes por Revisar';
        break;
      default:
        documentsToShow = _documentos; // Use current page documents
        title =
            _searchQuery.isNotEmpty ? 'Resultados de búsqueda' : 'Documentos';
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        // Header with title and document count
        Row(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '(${_getDocumentCount()})',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.teal),
              onPressed: () => _fetchDocuments(page: _currentPage),
              tooltip: 'Actualizar documentos',
            ),
          ],
        ),
        // Search bar
        Row(
          children: [
            Expanded(
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: TextField(
                  controller: _searchController,
                  onSubmitted: (_) => _applySearchFilter(),
                  decoration: InputDecoration(
                    hintText: 'Buscar por código o nombre...',
                    hintStyle: TextStyle(color: Colors.grey[500]),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: InputBorder.none,
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear,
                                color: Colors.grey[400], size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                                _filteredDocumentos =
                                    _applyFilters(_documentos);
                              });
                            },
                          )
                        : null,
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: _applySearchFilter,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              child: const Text('Consultar'),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _clearAllFilters,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[600],
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              child: const Text('Limpiar'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Container(
            width: double.infinity,
            child: Stack(
              children: [
                SingleChildScrollView(
                  child: DataTable(
                    columns: [
                      const DataColumn(
                        label: Text('ID'),
                      ),
                      DataColumn(
                        label: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: () => _showColumnLookup(
                              context,
                              'Código',
                              (value) async {
                                setState(() {
                                  // Clear other filters when applying a new one
                                  _filterNombre = null;
                                  _filterEstado = null;
                                  _filterConvencion = null;
                                  _filterGestion = null;
                                  _filterCodigo = value;
                                });
                                await _applySearchFilter();
                              },
                              _filterCodigo,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('Código'),
                                if (_filterCodigo != null) ...[
                                  const SizedBox(width: 4),
                                  const Icon(Icons.filter_alt,
                                      size: 14, color: Colors.blue),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                      DataColumn(
                        label: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: () => _showColumnLookup(
                              context,
                              'Nombre',
                              (value) async {
                                setState(() {
                                  // Clear other filters when applying a new one
                                  _filterCodigo = null;
                                  _filterEstado = null;
                                  _filterConvencion = null;
                                  _filterGestion = null;
                                  _filterNombre = value;
                                });
                                await _applySearchFilter();
                              },
                              _filterNombre,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('Nombre'),
                                if (_filterNombre != null) ...[
                                  const SizedBox(width: 4),
                                  const Icon(Icons.filter_alt,
                                      size: 14, color: Colors.blue),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                      DataColumn(
                        label: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: () => _showColumnLookup(
                              context,
                              'Estado',
                              (value) async {
                                setState(() {
                                  // Clear other filters when applying a new one
                                  _filterCodigo = null;
                                  _filterNombre = null;
                                  _filterConvencion = null;
                                  _filterGestion = null;
                                  _filterEstado = value;
                                });
                                await _applySearchFilter();
                              },
                              _filterEstado,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('Estado'),
                                if (_filterEstado != null) ...[
                                  const SizedBox(width: 4),
                                  const Icon(Icons.filter_alt,
                                      size: 14, color: Colors.blue),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                      const DataColumn(label: Text('Descripción')),
                      DataColumn(
                        label: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: () => _showColumnLookup(
                              context,
                              'Convención',
                              (value) async {
                                setState(() {
                                  // Clear other filters when applying a new one
                                  _filterCodigo = null;
                                  _filterNombre = null;
                                  _filterEstado = null;
                                  _filterGestion = null;
                                  _filterConvencion = value;
                                });
                                await _applySearchFilter();
                              },
                              _filterConvencion,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('Convención'),
                                if (_filterConvencion != null) ...[
                                  const SizedBox(width: 4),
                                  const Icon(Icons.filter_alt,
                                      size: 14, color: Colors.blue),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                      DataColumn(
                        label: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: () => _showColumnLookup(
                              context,
                              'Gestión',
                              (value) async {
                                setState(() {
                                  // Clear other filters when applying a new one
                                  _filterCodigo = null;
                                  _filterNombre = null;
                                  _filterEstado = null;
                                  _filterConvencion = null;
                                  _filterGestion = value;
                                });
                                await _applySearchFilter();
                              },
                              _filterGestion,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('Gestión'),
                                if (_filterGestion != null) ...[
                                  const SizedBox(width: 4),
                                  const Icon(Icons.filter_alt,
                                      size: 14, color: Colors.blue),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                      const DataColumn(label: Text('Fecha')),
                      const DataColumn(label: Text('Eventos')),
                      const DataColumn(label: Text('Acciones')),
                    ],
                    rows: documentsToShow.map((document) {
                      return DataRow(
                        cells: [
                          DataCell(Text(document.id.toString())),
                          DataCell(Text(document.codigo)),
                          DataCell(Text(document.nombre)),
                          DataCell(Text(
                              DocumentUtils.formatEstado(document.estado))),
                          DataCell(Text(document.descripcion)),
                          DataCell(Text(document.convencion)),
                          DataCell(Text(document.gestionNombre)),
                          DataCell(Text(
                              document.fechaCreacion.toString().split(' ')[0])),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Firmar button
                                IconButton(
                                  icon: const Icon(Icons.edit_document,
                                      size: 18, color: Colors.blue),
                                  onPressed: () =>
                                      _showFirmarMenu(context, document),
                                  tooltip: 'Firmar documento',
                                ),
                              ],
                            ),
                          ),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit,
                                      size: 18, color: Colors.blue),
                                  onPressed: () => _showAddEditDialog(context,
                                      documento: document),
                                  tooltip: 'Editar',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete,
                                      size: 18, color: Colors.red),
                                  onPressed: () =>
                                      _deleteDocumento(document.id),
                                  tooltip: 'Eliminar',
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                    columnSpacing: 20,
                    showCheckboxColumn: false,
                  ),
                ),
                if (_showLoadingIndicator)
                  Container(
                    color: Colors.black.withOpacity(0.1),
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
              ],
            ),
          ),
        ),
        // Custom pagination controls for server-side pagination
        PaginationControls(
          currentPage: _currentPage,
          totalCount: _totalCount,
          itemsPerPage: _itemsPerPage,
          onPageChanged: (page) {
            setState(() => _currentPage = page);
            switch (_selectedView) {
              case 'aprobar':
                _fetchFilteredDocuments('aprobar', page: page);
                break;
              case 'revisar':
                _fetchFilteredDocuments('revisar', page: page);
                break;
              default:
                _fetchDocuments(page: page);
                break;
            }
          },
          showPagination: true, // Always show pagination controls
        ),
        ],
      ),
    );
  }

  // Diálogo para agregar o editar un documento usando DocumentoModalForm
  Future<void> _showAddEditDialog(BuildContext context,
      {Documento? documento}) async {
    showDialog(
      context: context,
      builder: (context) => DocumentoModalForm(
        documento: documento,
        onSaved: () {
          _fetchDocuments(
              page: _currentPage); // Refresh the documents list after saving
        },
      ),
    );
  }
}

// Data Source para el PaginatedDataTable with server-side pagination
class DocumentosDataSource extends DataTableSource {
  final List<Documento> _documentos;
  final BuildContext _context;
  final Function _onEdit;
  final Function _onDelete;

  DocumentosDataSource(
    this._documentos,
    this._context,
    this._onEdit,
    this._onDelete,
  );

  @override
  DataRow? getRow(int index) {
    // For server-side pagination, only show current page data
    if (index >= _documentos.length) {
      return null;
    }
    final doc = _documentos[index];
    return DataRow(
      cells: [
        DataCell(Text(doc.id.toString())),
        DataCell(Text(doc.codigo)),
        DataCell(Text(doc.nombre)),
        DataCell(Text(DocumentUtils.formatEstado(doc.estado))),
        DataCell(Text(doc.descripcion)),
        DataCell(Text(doc.convencion)),
        DataCell(Text(doc.gestionNombre)),
        DataCell(Text(doc.fechaCreacion.toString().split(' ')[0])),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Firmar button (visible as separate icon)
              IconButton(
                icon: const Icon(Icons.edit_document,
                    size: 20, color: Colors.blue),
                tooltip: 'Firmar documento',
                onPressed: () => _showFirmarMenu(_context, doc),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                onPressed: () => _onEdit(_context, documento: doc),
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
                tooltip: 'Editar documento',
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                onPressed: () => _onDelete(doc.id),
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
                tooltip: 'Eliminar documento',
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => _documentos.length; // Only show current page data count

  @override
  int get selectedRowCount => 0;

  // Show firmar context menu
  void _showFirmarMenu(BuildContext context, Documento doc) {
    showMenu(
      context: context,
      position: const RelativeRect.fromLTRB(100, 100, 0, 0),
      items: [
        const PopupMenuItem<String>(
          value: 'firmar_digital',
          child: Row(
            children: [
              Icon(Icons.edit_note, size: 18, color: Colors.green),
              SizedBox(width: 8),
              Text('Firma Digital'),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'firmar_fisica',
          child: Row(
            children: [
              Icon(Icons.draw, size: 18, color: Colors.blue),
              SizedBox(width: 8),
              Text('Firma Física'),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'aprobar',
          child: Row(
            children: [
              Icon(Icons.check_circle, size: 18, color: Colors.orange),
              SizedBox(width: 8),
              Text('Aprobar'),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value != null) {
        _handleFirmarAction(value, doc);
      }
    });
  }

  // Handle firmar action selection
  void _handleFirmarAction(String action, Documento doc) {
    switch (action) {
      case 'firmar_digital':
        // TODO: Implement digital signature functionality
        print('Firmar digitalmente documento: ${doc.nombre}');
        break;
      case 'firmar_fisica':
        // TODO: Implement physical signature functionality
        print('Firmar físicamente documento: ${doc.nombre}');
        break;
      case 'aprobar':
        // TODO: Implement approval functionality
        print('Aprobar documento: ${doc.nombre}');
        break;
    }
  }
}
