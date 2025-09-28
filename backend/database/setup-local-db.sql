-- Local Database Setup Script
-- Run this script to create a local database for development

-- Create types ENUM for the system of documents
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
    'eliminado'
);

-- Table gestiones
CREATE TABLE IF NOT EXISTS gestiones (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(255) NOT NULL,
    descripcion TEXT,
    activo BOOLEAN DEFAULT true,
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table usuarios
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

-- Main documents table
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

-- Document history table
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
    accion VARCHAR(100)
);

-- Insert sample data
INSERT INTO gestiones (nombre, descripcion) VALUES 
('Gestión de Calidad', 'Documentos relacionados con calidad'),
('Gestión Administrativa', 'Documentos administrativos');

INSERT INTO usuarios (nombre, email, password, rol) VALUES 
('Admin User', 'admin@test.com', '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'admin'),
('Test User', 'user@test.com', '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'usuario'),
('María García López', 'gerente@test.com', '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'gerente');

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_documentos_codigo ON documentos(codigo);
CREATE INDEX IF NOT EXISTS idx_documentos_gestion ON documentos(gestion_id);
CREATE INDEX IF NOT EXISTS idx_documentos_estado ON documentos(estado);
CREATE INDEX IF NOT EXISTS idx_documentos_convencion ON documentos(convencion);
CREATE INDEX IF NOT EXISTS idx_historico_documento ON historico_documentos(documento_id);
