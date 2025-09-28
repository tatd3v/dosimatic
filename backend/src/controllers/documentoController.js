const Documento = require('../models/documento');
const Joi = require('joi');
const path = require('path');
const fs = require('fs').promises;

// Esquema de validación para crear documento
const createDocumentoSchema = Joi.object({
  codigo: Joi.string().required().max(50),
  nombre: Joi.string().required().max(255),
  descripcion: Joi.string().optional(),
  gestion_id: Joi.number().integer().positive().required(),
  convencion: Joi.string()
    .valid(
      'Manual',
      'Procedimiento',
      'Instructivo',
      'Formato',
      'Documento Externo'
    )
    .required(),
  usuario_creador: Joi.number().integer().positive().required(),
  vinculado_a: Joi.number().integer().positive().optional(),
  archivo_fuente: Joi.string().optional().max(255),
  archivo_pdf: Joi.string().optional().max(255)
});

// Esquema de validación para actualizar documento
const updateDocumentoSchema = Joi.object({
  nombre: Joi.string().max(255).optional(),
  descripcion: Joi.string().optional(),
  gestion_id: Joi.number().integer().positive().optional(),
  convencion: Joi.string()
    .valid(
      'Manual',
      'Procedimiento',
      'Instructivo',
      'Formato',
      'Documento Externo'
    )
    .optional(),
  estado: Joi.string()
    .valid(
      'pendiente_revision',
      'pendiente_aprobacion',
      'aprobado',
      'rechazado'
    )
    .optional(),
  vinculado_a: Joi.number().integer().positive().optional(),
  usuario_revisor: Joi.number().integer().positive().optional(),
  usuario_aprobador: Joi.number().integer().positive().optional(),
  comentarios_revision: Joi.string().optional(),
  comentarios_aprobacion: Joi.string().optional()
});

class DocumentoController {
  // Crear nuevo documento
  static async create(req, res) {
    try {
      // Convertir campos numéricos de string a number (multipart/form-data los envía como strings)
      if (req.body.gestion_id && req.body.gestion_id !== '') {
        req.body.gestion_id = parseInt(req.body.gestion_id);
      }
      if (req.body.usuario_creador && req.body.usuario_creador !== '') {
        req.body.usuario_creador = parseInt(req.body.usuario_creador);
      }
      if (req.body.vinculado_a && req.body.vinculado_a !== '') {
        req.body.vinculado_a = parseInt(req.body.vinculado_a);
      }

      // Validar datos de entrada
      const { error, value } = createDocumentoSchema.validate(req.body);
      if (error) {
        console.log('Validation error:', error.details);
        return res.status(400).json({
          success: false,
          message: 'Datos inválidos',
          errors: error.details.map(detail => detail.message)
        });
      }

      // Procesar archivos subidos
      const documentoData = { ...value };

      if (req.files) {
        if (req.files.archivo_fuente) {
          documentoData.archivo_fuente = req.files.archivo_fuente[0].filename;
        }
        if (req.files.archivo_pdf) {
          documentoData.archivo_pdf = req.files.archivo_pdf[0].filename;
        }
      }

      // Crear documento
      const documento = await Documento.create(documentoData);

      res.status(201).json({
        success: true,
        message: 'Documento creado exitosamente',
        data: documento
      });
    } catch (error) {
      console.error('Error creando documento:', error);

      // Limpiar archivos subidos si hay error
      if (req.files) {
        try {
          for (const file of Object.values(req.files).flat()) {
            await fs.unlink(file.path);
          }
        } catch (cleanupError) {
          console.error('Error limpiando archivos:', cleanupError);
        }
      }

      if (error.code === '23505') {
        // Código único violado
        return res.status(400).json({
          success: false,
          message: 'El código del documento ya existe'
        });
      }

      res.status(500).json({
        success: false,
        message: 'Error interno del servidor'
      });
    }
  }

  // Obtener todos los documentos con filtros
  static async getAll(req, res) {
    try {
      const filters = {
        codigo: req.query.codigo,
        nombre: req.query.nombre,
        search: req.query.search, // Nuevo parámetro para búsqueda combinada
        gestion_id: req.query.gestion_id
          ? parseInt(req.query.gestion_id)
          : undefined,
        convencion: req.query.convencion,
        estado: req.query.estado,
        limit: req.query.limit ? parseInt(req.query.limit) : 10,
        offset: req.query.offset ? parseInt(req.query.offset) : 0
      };

      // Remover valores undefined
      Object.keys(filters).forEach(key => {
        if (filters[key] === undefined) {
          delete filters[key];
        }
      });

      const result = await Documento.findAll(filters);
      const { documents, total, pages, currentPage, limit, offset } = result;

      res.json({
        success: true,
        data: documents,
        pagination: {
          total: total,
          pages: pages,
          currentPage: currentPage,
          limit: limit,
          offset: offset,
          hasNext: currentPage < pages,
          hasPrev: currentPage > 1
        }
      });
    } catch (error) {
      console.error('Error obteniendo documentos:', error);
      res.status(500).json({
        success: false,
        message: 'Error interno del servidor'
      });
    }
  }

  // Obtener documento por ID
  static async getById(req, res) {
    try {
      const { id } = req.params;

      if (!id || isNaN(parseInt(id))) {
        return res.status(400).json({
          success: false,
          message: 'ID de documento inválido'
        });
      }

      const documento = await Documento.findById(parseInt(id));

      if (!documento) {
        return res.status(404).json({
          success: false,
          message: 'Documento no encontrado'
        });
      }

      res.json({
        success: true,
        data: documento
      });
    } catch (error) {
      console.error('Error obteniendo documento:', error);
      res.status(500).json({
        success: false,
        message: 'Error interno del servidor'
      });
    }
  }

  // Actualizar documento
  static async update(req, res) {
    try {
      const { id } = req.params;
      const usuarioId = req.body.usuario_id || req.user?.id;

      if (!id || isNaN(parseInt(id))) {
        return res.status(400).json({
          success: false,
          message: 'ID de documento inválido'
        });
      }

      // Validar datos de entrada
      const { error, value } = updateDocumentoSchema.validate(req.body);
      if (error) {
        return res.status(400).json({
          success: false,
          message: 'Datos inválidos',
          errors: error.details.map(detail => detail.message)
        });
      }

      // Procesar archivos subidos
      const updateData = { ...value };

      if (req.files) {
        if (req.files.archivo_fuente) {
          updateData.archivo_fuente = req.files.archivo_fuente[0].filename;
        }
        if (req.files.archivo_pdf) {
          updateData.archivo_pdf = req.files.archivo_pdf[0].filename;
        }
      }

      // Actualizar documento
      const documento = await Documento.update(
        parseInt(id),
        updateData,
        usuarioId
      );

      res.json({
        success: true,
        message: 'Documento actualizado exitosamente',
        data: documento
      });
    } catch (error) {
      console.error('Error actualizando documento:', error);

      // Limpiar archivos subidos si hay error
      if (req.files) {
        await this.cleanupUploadedFiles(req.files);
      }

      if (error.message === 'Documento no encontrado') {
        return res.status(404).json({
          success: false,
          message: error.message
        });
      }

      res.status(500).json({
        success: false,
        message: 'Error interno del servidor'
      });
    }
  }

  // Eliminar documento
  static async delete(req, res) {
    try {
      const { id } = req.params;

      if (!id || isNaN(parseInt(id))) {
        return res.status(400).json({
          success: false,
          message: 'ID de documento inválido'
        });
      }

      const deleted = await Documento.delete(parseInt(id));

      if (!deleted) {
        return res.status(404).json({
          success: false,
          message: 'Documento no encontrado'
        });
      }

      res.json({
        success: true,
        message: 'Documento eliminado exitosamente'
      });
    } catch (error) {
      console.error('Error eliminando documento:', error);

      if (error.message.includes('documentos vinculados')) {
        return res.status(400).json({
          success: false,
          message: error.message
        });
      }

      res.status(500).json({
        success: false,
        message: 'Error interno del servidor'
      });
    }
  }

  // Obtener histórico de versiones
  static async getHistorico(req, res) {
    try {
      const { id } = req.params;

      if (!id || isNaN(parseInt(id))) {
        return res.status(400).json({
          success: false,
          message: 'ID de documento inválido'
        });
      }

      const historico = await Documento.getHistorico(parseInt(id));

      res.json({
        success: true,
        data: historico
      });
    } catch (error) {
      console.error('Error obteniendo histórico:', error);
      res.status(500).json({
        success: false,
        message: 'Error interno del servidor'
      });
    }
  }

  // Marcar como revisado
  static async marcarRevisado(req, res) {
    try {
      const { id } = req.params;
      const { usuario_revisor, comentarios } = req.body;

      if (!id || isNaN(parseInt(id))) {
        return res.status(400).json({
          success: false,
          message: 'ID de documento inválido'
        });
      }

      if (!usuario_revisor) {
        return res.status(400).json({
          success: false,
          message: 'Usuario revisor es requerido'
        });
      }

      const documento = await Documento.marcarRevisado(
        parseInt(id),
        usuario_revisor,
        comentarios
      );

      res.json({
        success: true,
        message: 'Documento marcado como revisado',
        data: documento
      });
    } catch (error) {
      console.error('Error marcando como revisado:', error);
      res.status(500).json({
        success: false,
        message: 'Error interno del servidor'
      });
    }
  }

  // Marcar como aprobado
  static async marcarAprobado(req, res) {
    try {
      const { id } = req.params;
      const { usuario_aprobador, comentarios } = req.body;

      if (!id || isNaN(parseInt(id))) {
        return res.status(400).json({
          success: false,
          message: 'ID de documento inválido'
        });
      }

      if (!usuario_aprobador) {
        return res.status(400).json({
          success: false,
          message: 'Usuario aprobador es requerido'
        });
      }

      const documento = await Documento.marcarAprobado(
        parseInt(id),
        usuario_aprobador,
        comentarios
      );

      res.json({
        success: true,
        message: 'Documento aprobado exitosamente',
        data: documento
      });
    } catch (error) {
      console.error('Error aprobando documento:', error);
      res.status(500).json({
        success: false,
        message: 'Error interno del servidor'
      });
    }
  }

  // Rechazar documento
  static async rechazar(req, res) {
    try {
      const { id } = req.params;
      const { usuario_id, comentarios } = req.body;

      if (!id || isNaN(parseInt(id))) {
        return res.status(400).json({
          success: false,
          message: 'ID de documento inválido'
        });
      }

      if (!usuario_id) {
        return res.status(400).json({
          success: false,
          message: 'Usuario es requerido'
        });
      }

      const documento = await Documento.rechazar(
        parseInt(id),
        usuario_id,
        comentarios
      );

      res.json({
        success: true,
        message: 'Documento rechazado',
        data: documento
      });
    } catch (error) {
      console.error('Error rechazando documento:', error);
      res.status(500).json({
        success: false,
        message: 'Error interno del servidor'
      });
    }
  }

  // Obtener documentos pendientes de revisión con paginación
  static async getPendientesRevision(req, res) {
    try {
      const page = parseInt(req.query.page) || 1;
      const limit = parseInt(req.query.limit) || 10;

      const result = await Documento.getPendientesRevision(page, limit);

      res.json({
        success: true,
        data: result.data,
        pagination: result.pagination
      });
    } catch (error) {
      console.error('Error obteniendo pendientes de revisión:', error);
      res.status(500).json({
        success: false,
        message: 'Error interno del servidor'
      });
    }
  }

  // Obtener documentos pendientes de aprobación con paginación
  static async getPendientesAprobacion(req, res) {
    try {
      const page = parseInt(req.query.page) || 1;
      const limit = parseInt(req.query.limit) || 10;

      const result = await Documento.getPendientesAprobacion(page, limit);

      res.json({
        success: true,
        data: result.data,
        pagination: result.pagination
      });
    } catch (error) {
      console.error('Error obteniendo pendientes de aprobación:', error);
      res.status(500).json({
        success: false,
        message: 'Error interno del servidor'
      });
    }
  }

  // Descargar archivo
  static async downloadFile(req, res) {
    try {
      const { id, tipo } = req.params; // tipo: 'fuente', 'pdf', o 'signed'

      if (!id || isNaN(parseInt(id))) {
        return res.status(400).json({
          success: false,
          message: 'ID de documento inválido'
        });
      }

      const documento = await Documento.findById(parseInt(id));

      if (!documento) {
        return res.status(404).json({
          success: false,
          message: 'Documento no encontrado'
        });
      }

      let fileName, filePath;

      if (tipo === 'fuente') {
        fileName = documento.archivo_fuente;
        filePath = path.join(process.env.UPLOADS_PATH || 'uploads', fileName);
      } else if (tipo === 'pdf') {
        fileName = documento.archivo_pdf;
        filePath = path.join(process.env.UPLOADS_PATH || 'uploads', fileName);
      } else if (tipo === 'signed') {
        fileName = documento.signed_file_path;
        if (!fileName) {
          return res.status(404).json({
            success: false,
            message: 'Documento no ha sido firmado aún'
          });
        }
        const { resolvePath } = require('../../lib/storage');
        const SIGNED_DIR = resolvePath(process.env.SIGNED_DIR || './signed');
        filePath = path.join(SIGNED_DIR, fileName);
      } else {
        return res.status(400).json({
          success: false,
          message: 'Tipo de archivo inválido. Use: fuente, pdf, o signed'
        });
      }

      if (!fileName) {
        return res.status(404).json({
          success: false,
          message: `Archivo ${tipo} no encontrado`
        });
      }

      try {
        await fs.access(filePath);

        // Determinar el tipo de contenido basado en la extensión del archivo
        const ext = path.extname(fileName).toLowerCase();
        let contentType = 'application/octet-stream';
        let downloadName = fileName;

        if (ext === '.docx') {
          contentType =
            'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
        } else if (ext === '.doc') {
          contentType = 'application/msword';
        } else if (ext === '.pdf') {
          contentType = 'application/pdf';
        } else if (ext === '.xlsx') {
          contentType =
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
        } else if (ext === '.xls') {
          contentType = 'application/vnd.ms-excel';
        }

        // Configurar headers para descarga
        res.setHeader('Content-Type', contentType);
        res.setHeader(
          'Content-Disposition',
          `attachment; filename="${downloadName}"`
        );
        res.setHeader('Cache-Control', 'no-cache');

        res.download(filePath, downloadName);
      } catch (error) {
        res.status(404).json({
          success: false,
          message: 'Archivo no encontrado en el servidor'
        });
      }
    } catch (error) {
      console.error('Error descargando archivo:', error);
      res.status(500).json({
        success: false,
        message: 'Error interno del servidor'
      });
    }
  }

  // Método auxiliar para limpiar archivos subidos en caso de error
  static async cleanupUploadedFiles(files) {
    try {
      const allFiles = Object.values(files).flat();
      for (const file of allFiles) {
        await fs.unlink(file.path);
      }
    } catch (error) {
      console.error('Error limpiando archivos:', error);
    }
  }

  // Convertir documento a PDF
  static async convertirPdf(req, res) {
    try {
      const { id } = req.params;

      if (!id || isNaN(parseInt(id))) {
        return res.status(400).json({
          success: false,
          message: 'ID de documento inválido'
        });
      }

      const documento = await Documento.findById(parseInt(id));

      if (!documento) {
        return res.status(404).json({
          success: false,
          message: 'Documento no encontrado'
        });
      }

      if (documento.estado !== 'aprobado') {
        return res.status(400).json({
          success: false,
          message: 'Solo se pueden convertir documentos aprobados'
        });
      }

      const archivoFuente = documento.archivo_fuente;
      if (!archivoFuente) {
        return res.status(404).json({
          success: false,
          message: 'Archivo fuente no encontrado'
        });
      }

      const { changeExtToPdf, docxToPdf } = require('../../lib/convert');
      const filePath = path.join(
        process.env.UPLOADS_PATH || 'uploads',
        archivoFuente
      );
      const pdfPath = changeExtToPdf(
        filePath,
        path.join(process.env.UPLOADS_PATH || 'uploads')
      );

      try {
        await fs.access(filePath);
        await docxToPdf(filePath, pdfPath);

        // Actualizar documento con la ruta del PDF
        await Documento.update(parseInt(id), {
          archivo_pdf: path.basename(pdfPath)
        });

        res.json({
          success: true,
          message: 'Documento convertido a PDF exitosamente',
          pdf_path: pdfPath
        });
      } catch (error) {
        console.error('Error convirtiendo archivo:', error);
        res.status(500).json({
          success: false,
          message: 'Error convirtiendo archivo a PDF'
        });
      }
    } catch (error) {
      console.error('Error convirtiendo a PDF:', error);
      res.status(500).json({
        success: false,
        message: 'Error interno del servidor'
      });
    }
  }

  // Revisar documento
  static async revisarDocumento(req, res) {
    try {
      const { id } = req.params;
      const { revisor_name, usuario_revisor } = req.body;

      if (!id || isNaN(parseInt(id))) {
        return res.status(400).json({
          success: false,
          message: 'ID de documento inválido'
        });
      }

      if (!revisor_name) {
        return res.status(400).json({
          success: false,
          message: 'Nombre del revisor es requerido'
        });
      }

      const documento = await Documento.findById(parseInt(id));

      if (!documento) {
        return res.status(404).json({
          success: false,
          message: 'Documento no encontrado'
        });
      }

      if (documento.estado !== 'pendiente_revision') {
        return res.status(400).json({
          success: false,
          message:
            'Solo se pueden revisar documentos en estado "pendiente_revision"'
        });
      }

      const archivoFuente = documento.archivo_fuente;
      if (!archivoFuente) {
        return res.status(404).json({
          success: false,
          message: 'Archivo fuente no encontrado'
        });
      }

      const { resolvePath } = require('../../lib/storage');
      const { exec } = require('child_process');
      const { promisify } = require('util');
      const execAsync = promisify(exec);

      const SIGNED_DIR = resolvePath(process.env.SIGNED_DIR || './signed');
      const inputPath = path.join(
        process.env.UPLOADS_PATH || 'uploads',
        archivoFuente
      );
      const ext = path.extname(archivoFuente);
      const signedFileName = `${documento.codigo}_v${documento.version}_revisado${ext}`;
      const signedPath = path.join(SIGNED_DIR, signedFileName);

      // Obtener imagen de firma del revisor o usar firma por defecto
      let signatureImagePath = null;

      if (usuario_revisor) {
        try {
          const { query } = require('../../lib/db');
          const result = await query(
            'SELECT signature_image FROM usuarios WHERE id = $1',
            [usuario_revisor]
          );

          if (result.rows.length > 0 && result.rows[0].signature_image) {
            const userSignaturePath = path.join(
              process.cwd(),
              result.rows[0].signature_image
            );

            try {
              await fs.access(userSignaturePath);
              signatureImagePath = userSignaturePath;
            } catch (error) {
              console.warn(
                'Imagen de firma de revisor no encontrada:',
                userSignaturePath
              );
            }
          }
        } catch (error) {
          console.warn('Error obteniendo firma de revisor:', error.message);
        }
      }

      // Crear directorio signatures si no existe
      const signaturesDir = process.env.SIGNATURES_PATH || 'signatures';
      try {
        await fs.mkdir(signaturesDir, { recursive: true });
      } catch (error) {
        // Directorio ya existe, continuar
      }

      // Usar script Python para firmar Word/Excel directamente
      if (ext.toLowerCase() === '.docx' || ext.toLowerCase() === '.doc') {
        const scriptPath = path.join(
          __dirname,
          '..',
          '..',
          'scripts',
          'firmar_word.py'
        );

        const command = signatureImagePath
          ? `python3 "${scriptPath}" "${inputPath}" "${signatureImagePath}" "${signedPath}" "${revisor_name}"`
          : `python3 "${scriptPath}" "${inputPath}" "" "${signedPath}" "${revisor_name}"`;

        const { stdout, stderr } = await execAsync(command);

        if (stderr && !stderr.includes('Warning')) {
          throw new Error(`Error en script Python: ${stderr}`);
        }
      } else if (
        ext.toLowerCase() === '.xlsx' ||
        ext.toLowerCase() === '.xls'
      ) {
        // Para Excel, usar DocumentSigner
        const DocumentSigner = require('../../lib/documentSigner');
        const signer = new DocumentSigner();
        await signer.signDocument(
          inputPath,
          signedPath,
          revisor_name,
          signatureImagePath
        );
      } else {
        return res.status(400).json({
          success: false,
          message: `Formato no soportado para revisión: ${ext}. Solo se admiten .docx, .doc, .xlsx, .xls`
        });
      }

      // Verificar que se creó el archivo revisado
      await fs.access(signedPath);

      // Actualizar documento como revisado
      await Documento.update(parseInt(id), {
        estado: 'pendiente_aprobacion',
        usuario_revisor: usuario_revisor || null,
        fecha_revision: new Date().toISOString(),
        archivo_revisado: path.basename(signedPath)
      });

      return res.json({
        success: true,
        message: 'Documento revisado exitosamente',
        signed_file_path: path.basename(signedPath),
        download_url: `/api/documentos/${id}/download/reviewed`
      });
    } catch (error) {
      console.error('Error revisando documento:', error);

      // Limpiar archivo firmado si hubo error
      if (signedPath) {
        try {
          await fs.unlink(signedPath);
        } catch (e) {
          console.error('Error limpiando archivo firmado:', e);
        }
      }

      res.status(500).json({
        success: false,
        message: 'Error interno del servidor al revisar el documento',
        error:
          process.env.NODE_ENV === 'development' ? error.message : undefined
      });
    }
  }

  // Firmar documento
  static async firmarDocumento(req, res) {
    try {
      const { id } = req.params;
      const { signer_name, usuario_firmante } = req.body;

      if (!id || isNaN(parseInt(id))) {
        return res.status(400).json({
          success: false,
          message: 'ID de documento inválido'
        });
      }

      if (!signer_name) {
        return res.status(400).json({
          success: false,
          message: 'Nombre del firmante es requerido'
        });
      }

      const documento = await Documento.findById(parseInt(id));

      if (!documento) {
        return res.status(404).json({
          success: false,
          message: 'Documento no encontrado'
        });
      }

      if (documento.estado !== 'aprobado') {
        return res.status(400).json({
          success: false,
          message: 'Solo se pueden firmar documentos aprobados'
        });
      }

      const archivoFuente = documento.archivo_fuente;
      if (!archivoFuente) {
        return res.status(404).json({
          success: false,
          message: 'Archivo fuente no encontrado'
        });
      }

      const { resolvePath } = require('../../lib/storage');
      const { exec } = require('child_process');
      const { promisify } = require('util');
      const execAsync = promisify(exec);

      const SIGNED_DIR = resolvePath(process.env.SIGNED_DIR || './signed');
      const inputPath = path.join(
        process.env.UPLOADS_PATH || 'uploads',
        archivoFuente
      );
      const ext = path.extname(archivoFuente);
      const signedFileName = `${documento.codigo}_v${documento.version}_signed${ext}`;
      const signedPath = path.join(SIGNED_DIR, signedFileName);

      // Obtener imagen de firma del usuario o usar firma por defecto
      let signatureImagePath = null;

      console.log('🔍 Debug firma - usuario_firmante:', usuario_firmante);

      if (usuario_firmante) {
        try {
          const { query } = require('../../lib/db');
          const result = await query(
            'SELECT signature_image FROM usuarios WHERE id = $1',
            [usuario_firmante]
          );
          console.log('🔍 Debug firma - resultado DB:', result.rows);

          if (result.rows.length > 0 && result.rows[0].signature_image) {
            // Usar path.join para construir la ruta relativa
            const userSignaturePath = path.join(
              process.cwd(),
              result.rows[0].signature_image
            );
            console.log('🔍 Debug firma - ruta construida:', userSignaturePath);

            // Verificar que existe la imagen del usuario
            try {
              await fs.access(userSignaturePath);
              signatureImagePath = userSignaturePath;
              console.log(
                '✅ Debug firma - imagen encontrada:',
                signatureImagePath
              );
            } catch (error) {
              console.warn(
                '❌ Imagen de firma de usuario no encontrada:',
                userSignaturePath
              );
              console.warn('Error:', error.message);

              // Intentar con ruta relativa como último recurso
              const relativePath = result.rows[0].signature_image;
              try {
                await fs.access(relativePath);
                signatureImagePath = relativePath;
                console.log(
                  '✅ Debug firma - imagen encontrada (ruta relativa):',
                  relativePath
                );
              } catch (e) {
                console.warn(
                  '❌ No se pudo acceder a la imagen con ruta relativa:',
                  relativePath
                );
              }
            }
          } else {
            console.log('❌ Debug firma - usuario sin signature_image en DB');
          }
        } catch (error) {
          console.warn('Error obteniendo firma de usuario:', error.message);
        }
      } else {
        console.log('❌ Debug firma - no se proporcionó usuario_firmante');
      }

      // Crear directorio signatures si no existe
      const signaturesDir = process.env.SIGNATURES_PATH || 'signatures';
      try {
        await fs.mkdir(signaturesDir, { recursive: true });
      } catch (error) {
        // Directorio ya existe, continuar
      }

      // Usar script Python para firmar Word/Excel directamente
      if (ext.toLowerCase() === '.docx' || ext.toLowerCase() === '.doc') {
        const scriptPath = path.join(
          __dirname,
          '..',
          '..',
          'scripts',
          'firmar_word.py'
        );

        // Si no hay imagen de firma, crear una firma de texto simple
        if (!signatureImagePath) {
          console.log('Firmando documento sin imagen de firma, solo con texto');
          // Crear comando sin imagen de firma - el script Python manejará esto
          const command = `python3 "${scriptPath}" "${inputPath}" "" "${signedPath}" "${signer_name}"`;
          const { stdout, stderr } = await execAsync(command);

          if (stderr && !stderr.includes('Warning')) {
            throw new Error(`Error en script Python: ${stderr}`);
          }
        } else {
          // Firmar con imagen
          const command = `python3 "${scriptPath}" "${inputPath}" "${signatureImagePath}" "${signedPath}" "${signer_name}"`;
          const { stdout, stderr } = await execAsync(command);

          if (stderr && !stderr.includes('Warning')) {
            throw new Error(`Error en script Python: ${stderr}`);
          }
        }
      } else if (
        ext.toLowerCase() === '.xlsx' ||
        ext.toLowerCase() === '.xls'
      ) {
        // Para Excel, usar DocumentSigner
        const DocumentSigner = require('../../lib/documentSigner');
        const signer = new DocumentSigner();
        await signer.signDocument(
          inputPath,
          signedPath,
          signer_name,
          signatureImagePath
        );
      } else {
        return res.status(400).json({
          success: false,
          message: `Formato no soportado para firma: ${ext}. Solo se admiten .docx, .doc, .xlsx, .xls`
        });
      }

      // Verificar que se creó el archivo firmado
      await fs.access(signedPath);

      // Actualizar documento como firmado
      await Documento.update(parseInt(id), {
        is_signed: true,
        signed_file_path: signedFileName,
        signer_name: signer_name,
        signed_at: new Date(),
        usuario_firmante: usuario_firmante
      });

      res.json({
        success: true,
        message: 'Documento firmado exitosamente',
        signed_file_path: signedPath,
        download_url: `/api/documentos/${id}/download/signed`
      });
    } catch (error) {
      console.error('Error firmando archivo:', error);
      res.status(500).json({
        success: false,
        message: `Error firmando documento: ${error.message}`
      });
    }
  }
}

module.exports = {
  create: DocumentoController.create,
  getAll: DocumentoController.getAll,
  getById: DocumentoController.getById,
  update: DocumentoController.update,
  delete: DocumentoController.delete,
  getHistorico: DocumentoController.getHistorico,
  marcarRevisado: DocumentoController.marcarRevisado,
  marcarAprobado: DocumentoController.marcarAprobado,
  rechazar: DocumentoController.rechazar,
  getPendientesRevision: DocumentoController.getPendientesRevision,
  getPendientesAprobacion: DocumentoController.getPendientesAprobacion,
  downloadFile: DocumentoController.downloadFile,
  convertirPdf: DocumentoController.convertirPdf,
  revisarDocumento: DocumentoController.revisarDocumento,
  firmarDocumento: DocumentoController.firmarDocumento
};
