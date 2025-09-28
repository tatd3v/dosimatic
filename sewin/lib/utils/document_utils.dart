/// Utility functions for document-related operations
class DocumentUtils {
  /// Converts a database estado value to a user-friendly display string
  static String formatEstado(String? estado) {
    if (estado == null) return 'Sin Estado';
    
    // Trim whitespace and convert to lowercase for comparison
    final cleanEstado = estado.trim().toLowerCase();
    
    switch (cleanEstado) {
      case 'borrador':
        return 'Borrador';
      case 'pendiente_revision':
        return 'Pendiente por Revisión';
      case 'pendiente_aprobacion':
        return 'Pendiente por Aprobación';
      case 'aprobado':
        return 'Aprobado';
      case 'rechazado':
        return 'Rechazado';
      default:
        return estado; // Return as is if no match found
    }
  }
}
