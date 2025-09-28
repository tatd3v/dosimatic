class Gestion {
  final int id;
  final String nombre;
  final String? descripcion;
  final bool activo;
  final DateTime fechaCreacion;
  final DateTime fechaActualizacion;

  Gestion({
    required this.id,
    required this.nombre,
    this.descripcion,
    required this.activo,
    required this.fechaCreacion,
    required this.fechaActualizacion,
  });

  factory Gestion.fromJson(Map<String, dynamic> json) {
    return Gestion(
      id: json['id'],
      nombre: json['nombre'],
      descripcion: json['descripcion'],
      activo: json['activo'] ?? true,
      fechaCreacion: DateTime.parse(json['fecha_creacion']),
      fechaActualizacion: DateTime.parse(json['fecha_actualizacion']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'descripcion': descripcion,
      'activo': activo,
      'fecha_creacion': fechaCreacion.toIso8601String(),
      'fecha_actualizacion': fechaActualizacion.toIso8601String(),
    };
  }

  // Helper method to convert to the format expected by dropdown
  Map<String, dynamic> toDropdownItem() {
    return {
      'id': id,
      'nombre': nombre,
    };
  }
}
