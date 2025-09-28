const express = require('express');
const cors = require('cors');
const path = require('path');
const swaggerJsdoc = require('swagger-jsdoc');
const swaggerUi = require('swagger-ui-express');
require('dotenv').config();

const { testConnection } = require('./config/database');
const documentosRoutes = require('./routes/documentos.routes');
const authRoutes = require('./routes/auth.routes');
const usersRoutes = require('./routes/users.routes');

const app = express();

// Configuración de CORS
const corsOptions = {
  origin:
    process.env.CORS_ORIGIN || 'http://localhost:3001,http://localhost:3500',
  credentials: true,
  optionsSuccessStatus: 200,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With']
};

// Middleware global
app.use(cors(corsOptions));
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true, limit: '50mb' }));

// Servir archivos estáticos (uploads)
const uploadsPath = process.env.UPLOADS_PATH || 'uploads';
app.use('/uploads', express.static(path.join(__dirname, '..', uploadsPath)));

// Configuración de Swagger
const swaggerOptions = {
  definition: {
    openapi: '3.0.0',
    info: {
      title: 'Sistema de Gestión Documental API',
      version: '1.0.0',
      description: 'API REST para sistema de gestión documental tipo Documatic',
      contact: {
        name: 'Equipo de Desarrollo',
        email: 'desarrollo@empresa.com'
      }
    },
    servers: [
      {
        url: `http://localhost:${process.env.PORT || 3500}`,
        description: 'Servidor de desarrollo'
      }
    ],
    components: {
      securitySchemes: {
        bearerAuth: {
          type: 'http',
          scheme: 'bearer',
          bearerFormat: 'JWT'
        }
      }
    }
  },
  apis: ['./src/routes/*.js'] // Rutas donde están las definiciones de Swagger
};

const specs = swaggerJsdoc(swaggerOptions);

// Ruta de documentación Swagger
app.use(
  '/api-docs',
  swaggerUi.serve,
  swaggerUi.setup(specs, {
    explorer: true,
    customCss: '.swagger-ui .topbar { display: none }',
    customSiteTitle: 'Sistema Documental API',
    swaggerOptions: {
      tagsSorter: (a, b) => {
        return a.localeCompare(b);
      }
    }
  })
);

// Ruta de salud del servidor
app.get('/health', (req, res) => {
  res.json({
    status: 'OK',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    environment: process.env.NODE_ENV || 'development'
  });
});

// Ruta de información del API
app.get('/api', (req, res) => {
  res.json({
    name: 'Sistema de Gestión Documental API',
    version: '1.0.0',
    description:
      'API REST para gestión de documentos con control de versiones y flujo de aprobación',
    endpoints: {
      documentos: '/api/documentos',
      swagger: '/api-docs',
      health: '/health'
    }
  });
});

// Rutas de la API
app.use('/api/documentos', documentosRoutes);
app.use('/api/auth', authRoutes);
app.use('/api/users', usersRoutes);

// Middleware de manejo de errores 404
app.use('*', (req, res) => {
  res.status(404).json({
    success: false,
    message: `Ruta no encontrada: ${req.method} ${req.originalUrl}`,
    availableEndpoints: {
      api: '/api',
      documentos: '/api/documentos',
      swagger: '/api-docs',
      health: '/health'
    }
  });
});

// Middleware global de manejo de errores
app.use((error, req, res, next) => {
  console.error('Error no manejado:', error);

  // Error de validación de Joi
  if (error.isJoi) {
    return res.status(400).json({
      success: false,
      message: 'Datos de entrada inválidos',
      details: error.details.map(detail => ({
        field: detail.path.join('.'),
        message: detail.message
      }))
    });
  }

  // Error de base de datos
  if (error.code) {
    switch (error.code) {
      case '23505': // Violación de restricción única
        return res.status(409).json({
          success: false,
          message: 'El registro ya existe (violación de restricción única)',
          field: error.constraint
        });
      case '23503': // Violación de clave foránea
        return res.status(400).json({
          success: false,
          message: 'Referencia inválida (violación de clave foránea)',
          field: error.constraint
        });
      case '23502': // Violación de NOT NULL
        return res.status(400).json({
          success: false,
          message: 'Campo requerido faltante',
          field: error.column
        });
    }
  }

  // Error genérico
  res.status(error.status || 500).json({
    success: false,
    message: error.message || 'Error interno del servidor',
    ...(process.env.NODE_ENV === 'development' && { stack: error.stack })
  });
});

// Función para inicializar el servidor
const initializeServer = async () => {
  try {
    // Probar conexión a la base de datos
    console.log('🔍 Probando conexión a la base de datos...');
    // await testConnection(); // Comentado temporalmente
    console.log('⚠️  Conexión a BD deshabilitada temporalmente');

    // Crear directorio de uploads si no existe
    const fs = require('fs');
    const uploadsDir = path.join(__dirname, '..', uploadsPath);
    if (!fs.existsSync(uploadsDir)) {
      fs.mkdirSync(uploadsDir, { recursive: true });
      console.log('📁 Directorio de uploads creado:', uploadsDir);
    }

    const PORT = process.env.PORT || 3001;

    app.listen(PORT, () => {
      console.log('🚀 Servidor iniciado exitosamente');
      console.log(`📡 Puerto: ${PORT}`);
      console.log(`🌐 URL: http://localhost:${PORT}`);
      console.log(`📚 Documentación: http://localhost:${PORT}/api-docs`);
      console.log(`💚 Health Check: http://localhost:${PORT}/health`);
      console.log(`📋 API Info: http://localhost:${PORT}/api`);
      console.log('─'.repeat(50));
    });
  } catch (error) {
    console.error('❌ Error al inicializar el servidor:', error.message);
    process.exit(1);
  }
};

// Manejo de cierre graceful
process.on('SIGTERM', () => {
  console.log('🛑 Recibida señal SIGTERM, cerrando servidor...');
  process.exit(0);
});

process.on('SIGINT', () => {
  console.log('🛑 Recibida señal SIGINT, cerrando servidor...');
  process.exit(0);
});

// Solo inicializar si este archivo es ejecutado directamente o desde server.js
if (require.main === module || require.main.filename.endsWith('server.js')) {
  initializeServer();
}

module.exports = app;
