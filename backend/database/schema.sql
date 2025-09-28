-- Esquema para sistema de documentos en base de datos existente secwin_db
-- Ejecutar estos comandos en la base de datos secwin_db

-- Crear tipos ENUM para el sistema de documentos
CREATE TYPE convencion_tipo AS ENUM (
    'Manual',
    'Procedimiento', 
    'Instructivo',
    'Formato',
    'Documento Externo'
);

CREATE TYPE estado_doc AS ENUM (
    'pendiente_revision',
    'pendiente_aprobacion', 
    'aprobado',
    'rechazado',
    'eliminado',
    'borrador'
);

-- Tabla de gestiones
CREATE TABLE IF NOT EXISTS gestiones (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(255) NOT NULL,
    descripcion TEXT,
    activo BOOLEAN DEFAULT true,
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Verificar si ya existe tabla usuarios, si no crearla básica
-- (Probablemente ya existe en tu BD secwin_db)
CREATE TABLE IF NOT EXISTS usuarios (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password VARCHAR(255),
    rol VARCHAR(50) DEFAULT 'usuario',
    activo BOOLEAN DEFAULT true,
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    reset_token VARCHAR(255),
    reset_token_expires TIMESTAMP,
    signature_image VARCHAR(255)
);

-- Tabla principal de documentos
CREATE TABLE IF NOT EXISTS documentos (
    id SERIAL PRIMARY KEY,
    codigo VARCHAR(50) NOT NULL UNIQUE,
    nombre VARCHAR(255) NOT NULL,
    descripcion TEXT,
    gestion_id INT NOT NULL REFERENCES gestiones(id) ON DELETE CASCADE,
    convencion convencion_tipo NOT NULL,
    vinculado_a INT REFERENCES documentos(id) ON DELETE SET NULL,
    archivo_fuente VARCHAR(255),
    archivo_pdf VARCHAR(255),
    version INT DEFAULT 1,
    estado estado_doc DEFAULT 'pendiente_revision',
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    usuario_creador INT REFERENCES usuarios(id),
    usuario_revisor INT REFERENCES usuarios(id),
    usuario_aprobador INT REFERENCES usuarios(id),
    fecha_revision TIMESTAMP,
    fecha_aprobacion TIMESTAMP,
    comentarios_revision TEXT,
    comentarios_aprobacion TEXT
);

-- Tabla de histórico de versiones
CREATE TABLE IF NOT EXISTS historico_documentos (
    id SERIAL PRIMARY KEY,
    documento_id INT NOT NULL REFERENCES documentos(id) ON DELETE CASCADE,
    version INT NOT NULL,
    archivo_fuente VARCHAR(255),
    archivo_pdf VARCHAR(255),
    estado estado_doc,
    fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    usuario_id INT REFERENCES usuarios(id),
    comentarios TEXT,
    accion VARCHAR(100) -- 'creado', 'actualizado', 'revisado', 'aprobado', 'rechazado', 'eliminado'
);

-- Índices para mejorar rendimiento
CREATE INDEX IF NOT EXISTS idx_documentos_codigo ON documentos(codigo);
CREATE INDEX IF NOT EXISTS idx_documentos_nombre ON documentos(nombre);
CREATE INDEX IF NOT EXISTS idx_documentos_codigo_nombre ON documentos(codigo, nombre);
CREATE INDEX IF NOT EXISTS idx_documentos_gestion ON documentos(gestion_id);
CREATE INDEX IF NOT EXISTS idx_documentos_estado ON documentos(estado);
CREATE INDEX IF NOT EXISTS idx_documentos_convencion ON documentos(convencion);
CREATE INDEX IF NOT EXISTS idx_historico_documento ON historico_documentos(documento_id);

-- Función para actualizar fecha_actualizacion automáticamente
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.fecha_actualizacion = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger para actualizar fecha_actualizacion en documentos
DROP TRIGGER IF EXISTS update_documentos_updated_at ON documentos;
CREATE TRIGGER update_documentos_updated_at 
    BEFORE UPDATE ON documentos 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Trigger para actualizar fecha_actualizacion en gestiones
DROP TRIGGER IF EXISTS update_gestiones_updated_at ON gestiones;
CREATE TRIGGER update_gestiones_updated_at 
    BEFORE UPDATE ON gestiones 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Nuevas tablas para sistema de gestión documental con versiones
-- Tabla principal de documentos (simplificada para el nuevo sistema)
CREATE TABLE IF NOT EXISTS documents (
    id SERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    created_by VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tabla de versiones de documentos
CREATE TABLE IF NOT EXISTS document_versions (
    id SERIAL PRIMARY KEY,
    document_id INT NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
    version INT NOT NULL,
    original_filename VARCHAR(255) NOT NULL,
    storage_path VARCHAR(500) NOT NULL,
    mime_type VARCHAR(100),
    size_bytes BIGINT,
    is_signed BOOLEAN DEFAULT false,
    signed_pdf_path VARCHAR(500),
    created_by VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(document_id, version)
);

-- Índices para el nuevo sistema
CREATE INDEX IF NOT EXISTS idx_document_versions_document_id ON document_versions(document_id);
CREATE INDEX IF NOT EXISTS idx_document_versions_version ON document_versions(document_id, version);
CREATE INDEX IF NOT EXISTS idx_documents_created_by ON documents(created_by);

-- Trigger para actualizar updated_at en documents
DROP TRIGGER IF EXISTS update_documents_updated_at ON documents;
CREATE TRIGGER update_documents_updated_at 
    BEFORE UPDATE ON documents 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Insertar datos de ejemplo solo si no existen
INSERT INTO gestiones (nombre, descripcion) 
SELECT * FROM (VALUES 
    ('Gestión de Calidad', 'Documentos relacionados con el sistema de gestión de calidad'),
    ('Recursos Humanos', 'Documentos de gestión de personal y recursos humanos'),
    ('Finanzas', 'Documentos financieros y contables'),
    ('Operaciones', 'Documentos operativos y de procesos')
) AS v(nombre, descripcion)
WHERE NOT EXISTS (SELECT 1 FROM gestiones WHERE nombre = v.nombre);

-- Crear usuarios por defecto con contraseñas hasheadas (bcrypt)
-- Contraseña para todos: admin123
INSERT INTO usuarios (nombre, email, password, rol, activo) VALUES 
('Administrador Sistema', 'admin.docs@empresa.com', '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'admin', true),
('Gerente General', 'gerente@empresa.com', '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'gerente', true),
('Juan Pérez', 'juan.perez@empresa.com', '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'creador', true),
('María García', 'maria.garcia@empresa.com', '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'revisor', true),
('Carlos López', 'carlos.lopez@empresa.com', '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'aprobador', true)
ON CONFLICT (email) DO NOTHING;
