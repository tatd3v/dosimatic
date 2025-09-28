const express = require('express');
const router = express.Router();
const DocumentoController = require('../controllers/documentoController');
const {
  uploadDocumentFiles,
  handleMulterError
} = require('../middleware/upload');

/**
 * @swagger
 * components:
 *   schemas:
 *     Documento:
 *       type: object
 *       required:
 *         - codigo
 *         - nombre
 *         - gestion_id
 *         - convencion
 *         - usuario_creador
 *       properties:
 *         id:
 *           type: integer
 *           description: ID único del documento
 *         codigo:
 *           type: string
 *           maxLength: 50
 *           description: Código único del documento
 *         nombre:
 *           type: string
 *           maxLength: 255
 *           description: Nombre del documento
 *         descripcion:
 *           type: string
 *           description: Descripción del documento
 *         gestion_id:
 *           type: integer
 *           minimum: 1
 *           description: ID de la gestión asociada (debe ser un número positivo)
 *         convencion:
 *           type: string
 *           enum: [Manual, Procedimiento, Instructivo, Formato, Documento Externo]
 *           description: Tipo de convención del documento
 *         archivo_fuente:
 *           type: string
 *           description: Nombre del archivo fuente
 *         archivo_pdf:
 *           type: string
 *           description: Nombre del archivo PDF
 *         version:
 *           type: integer
 *           description: Versión del documento
 *         estado:
 *           type: string
 *           enum: [pendiente_revision, pendiente_aprobacion, aprobado, rechazado]
 *           description: Estado actual del documento
 *         fecha_creacion:
 *           type: string
 *           format: date-time
 *         fecha_actualizacion:
 *           type: string
 *           format: date-time
 *         usuario_creador:
 *           type: integer
 *         usuario_revisor:
 *           type: integer
 *         usuario_aprobador:
 *           type: integer
 */

/**
 * @swagger
 * /api/documentos:
 *   post:
 *     summary: Crear nuevo documento
 *     tags: [Documentos]
 *     requestBody:
 *       required: true
 *       content:
 *         multipart/form-data:
 *           schema:
 *             type: object
 *             required:
 *               - codigo
 *               - nombre
 *               - gestion_id
 *               - convencion
 *               - usuario_creador
 *             properties:
 *               codigo:
 *                 type: string
 *               nombre:
 *                 type: string
 *               descripcion:
 *                 type: string
 *               gestion_id:
 *                 type: integer
 *               convencion:
 *                 type: string
 *               usuario_creador:
 *                 type: integer
 *               archivo_fuente:
 *                 type: string
 *                 format: binary
 *               archivo_pdf:
 *                 type: string
 *                 format: binary
 *     responses:
 *       201:
 *         description: Documento creado exitosamente
 *       400:
 *         description: Datos inválidos
 *       500:
 *         description: Error interno del servidor
 */
router.post(
  '/',
  uploadDocumentFiles,
  handleMulterError,
  DocumentoController.create
);

/**
 * @swagger
 * /api/documentos:
 *   get:
 *     summary: Obtener lista de documentos con filtros
 *     tags: [Documentos]
 *     parameters:
 *       - in: query
 *         name: search
 *         schema:
 *           type: string
 *         description: Filtrar por código y nombre simultáneamente
 *       - in: query
 *         name: codigo
 *         schema:
 *           type: string
 *         description: Filtrar por código específico
 *       - in: query
 *         name: nombre
 *         schema:
 *           type: string
 *         description: Filtrar por nombre específico
 *       - in: query
 *         name: gestion_id
 *         schema:
 *           type: integer
 *         description: Filtrar por gestión
 *       - in: query
 *         name: convencion
 *         schema:
 *           type: string
 *         description: Filtrar por convención
 *       - in: query
 *         name: estado
 *         schema:
 *           type: string
 *         description: Filtrar por estado
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *           default: 50
 *         description: Límite de resultados
 *       - in: query
 *         name: offset
 *         schema:
 *           type: integer
 *           default: 0
 *         description: Offset para paginación
 *     responses:
 *       200:
 *         description: Lista de documentos con paginación
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 data:
 *                   type: array
 *                   items:
 *                     $ref: '#/components/schemas/Documento'
 *                 total:
 *                   type: integer
 *                   description: Total de documentos que coinciden con el filtro
 *                 pages:
 *                   type: integer
 *                 currentPage:
 *                   type: integer
 *       500:
 *         description: Error interno del servidor
 */
router.get('/', DocumentoController.getAll);

/**
 * @swagger
 * /api/documentos/{id}:
 *   get:
 *     summary: Obtener documento por ID
 *     tags: [Documentos]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *         description: ID del documento
 *     responses:
 *       200:
 *         description: Documento encontrado
 *       404:
 *         description: Documento no encontrado
 *       500:
 *         description: Error interno del servidor
 */
router.get('/:id', DocumentoController.getById);

/**
 * @swagger
 * /api/documentos/{id}:
 *   put:
 *     summary: Actualizar documento
 *     tags: [Documentos]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *         description: ID del documento
 *     requestBody:
 *       required: true
 *       content:
 *         multipart/form-data:
 *           schema:
 *             type: object
 *             properties:
 *               nombre:
 *                 type: string
 *               descripcion:
 *                 type: string
 *               gestion_id:
 *                 type: integer
 *               convencion:
 *                 type: string
 *               estado:
 *                 type: string
 *               usuario_id:
 *                 type: integer
 *               archivo_fuente:
 *                 type: string
 *                 format: binary
 *               archivo_pdf:
 *                 type: string
 *                 format: binary
 *     responses:
 *       200:
 *         description: Documento actualizado exitosamente
 *       400:
 *         description: Datos inválidos
 *       404:
 *         description: Documento no encontrado
 *       500:
 *         description: Error interno del servidor
 */
router.put(
  '/:id',
  uploadDocumentFiles,
  handleMulterError,
  DocumentoController.update
);

/**
 * @swagger
 * /api/documentos/{id}:
 *   delete:
 *     summary: Eliminar documento
 *     tags: [Documentos]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *         description: ID del documento
 *     responses:
 *       200:
 *         description: Documento eliminado exitosamente
 *       400:
 *         description: No se puede eliminar (tiene documentos vinculados)
 *       404:
 *         description: Documento no encontrado
 *       500:
 *         description: Error interno del servidor
 */
router.delete('/:id', DocumentoController.delete);

/**
 * @swagger
 * /api/documentos/{id}/historico:
 *   get:
 *     summary: Obtener histórico de versiones del documento
 *     tags: [Documentos]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *         description: ID del documento
 *     responses:
 *       200:
 *         description: Histórico de versiones
 *       404:
 *         description: Documento no encontrado
 *       500:
 *         description: Error interno del servidor
 */
router.get('/:id/historico', DocumentoController.getHistorico);

/**
 * @swagger
 * /api/documentos/{id}/revision:
 *   patch:
 *     summary: Marcar documento como revisado
 *     tags: [Documentos]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *         description: ID del documento
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - usuario_revisor
 *             properties:
 *               usuario_revisor:
 *                 type: integer
 *               comentarios:
 *                 type: string
 *     responses:
 *       200:
 *         description: Documento marcado como revisado
 *       400:
 *         description: Datos inválidos
 *       404:
 *         description: Documento no encontrado
 *       500:
 *         description: Error interno del servidor
 */
router.patch('/:id/revision', DocumentoController.marcarRevisado);

/**
 * @swagger
 * /api/documentos/{id}/aprobacion:
 *   patch:
 *     summary: Marcar documento como aprobado
 *     tags: [Documentos]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *         description: ID del documento
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - usuario_aprobador
 *             properties:
 *               usuario_aprobador:
 *                 type: integer
 *               comentarios:
 *                 type: string
 *     responses:
 *       200:
 *         description: Documento aprobado exitosamente
 *       400:
 *         description: Datos inválidos
 *       404:
 *         description: Documento no encontrado
 *       500:
 *         description: Error interno del servidor
 */
router.patch('/:id/aprobacion', DocumentoController.marcarAprobado);

/**
 * @swagger
 * /api/documentos/{id}/rechazar:
 *   patch:
 *     summary: Rechazar documento
 *     tags: [Documentos]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *         description: ID del documento
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - usuario_id
 *             properties:
 *               usuario_id:
 *                 type: integer
 *               comentarios:
 *                 type: string
 *     responses:
 *       200:
 *         description: Documento rechazado
 *       400:
 *         description: Datos inválidos
 *       404:
 *         description: Documento no encontrado
 *       500:
 *         description: Error interno del servidor
 */
router.patch('/:id/rechazar', DocumentoController.rechazar);

/**
 * @swagger
 * /api/documentos/pendientes/revision:
 *   get:
 *     summary: Obtener documentos pendientes de revisión con paginación
 *     tags: [Documentos]
 *     parameters:
 *       - in: query
 *         name: page
 *         schema:
 *           type: integer
 *           default: 1
 *         description: Número de página
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *           default: 10
 *         description: Límite de resultados por página
 *     responses:
 *       200:
 *         description: Lista de documentos pendientes de revisión con paginación
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 data:
 *                   type: array
 *                   items:
 *                     $ref: '#/components/schemas/Documento'
 *                 pagination:
 *                   type: object
 *                   properties:
 *                     total:
 *                       type: integer
 *                     pages:
 *                       type: integer
 *                     currentPage:
 *                       type: integer
 *                     limit:
 *                       type: integer
 *                     offset:
 *                       type: integer
 *                     hasNext:
 *                       type: boolean
 *                     hasPrev:
 *                       type: boolean
 *       500:
 *         description: Error interno del servidor
 */
router.get('/pendientes/revision', DocumentoController.getPendientesRevision);

/**
 * @swagger
 * /api/documentos/pendientes/aprobacion:
 *   get:
 *     summary: Obtener documentos pendientes de aprobación con paginación
 *     tags: [Documentos]
 *     parameters:
 *       - in: query
 *         name: page
 *         schema:
 *           type: integer
 *           default: 1
 *         description: Número de página
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *           default: 10
 *         description: Límite de resultados por página
 *     responses:
 *       200:
 *         description: Lista de documentos pendientes de aprobación con paginación
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 data:
 *                   type: array
 *                   items:
 *                     $ref: '#/components/schemas/Documento'
 *                 pagination:
 *                   type: object
 *                   properties:
 *                     total:
 *                       type: integer
 *                     pages:
 *                       type: integer
 *                     currentPage:
 *                       type: integer
 *                     limit:
 *                       type: integer
 *                     offset:
 *                       type: integer
 *                     hasNext:
 *                       type: boolean
 *                     hasPrev:
 *                       type: boolean
 *       500:
 *         description: Error interno del servidor
 */
router.get(
  '/pendientes/aprobacion',
  DocumentoController.getPendientesAprobacion
);

/**
 * @swagger
 * /api/documentos/{id}/download/{tipo}:
 *   get:
 *     summary: Descargar archivo del documento
 *     tags: [Documentos]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *         description: ID del documento
 *       - in: path
 *         name: tipo
 *         required: true
 *         schema:
 *           type: string
 *           enum: [fuente, pdf, signed]
 *         description: Tipo de archivo a descargar
 *     responses:
 *       200:
 *         description: Archivo descargado
 *         content:
 *           application/octet-stream:
 *             schema:
 *               type: string
 *               format: binary
 *       404:
 *         description: Documento o archivo no encontrado
 *       500:
 *         description: Error interno del servidor
 */
router.get('/:id/download/:tipo', DocumentoController.downloadFile);

/**
 * @swagger
 * /api/documentos/{id}/convertir-pdf:
 *   post:
 *     summary: Convertir documento DOCX a PDF (solo documentos aprobados)
 *     tags: [Documentos]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *         description: ID del documento
 *     responses:
 *       200:
 *         description: Documento convertido a PDF exitosamente
 *       400:
 *         description: El documento no está aprobado o no es DOCX
 *       404:
 *         description: Documento no encontrado
 *       500:
 *         description: Error interno del servidor
 */
router.post('/:id/convertir-pdf', DocumentoController.convertirPdf);

/**
 * @swagger
 * /api/documentos/{id}/firmar:
 *   post:
 *     summary: Firmar documento Word o Excel
 *     tags: [Documentos]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *         description: ID del documento
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - signer_name
 *             properties:
 *               signer_name:
 *                 type: string
 *                 description: Nombre del firmante
 *               usuario_firmante:
 *                 type: integer
 *                 description: ID del usuario que firma (opcional, para usar su firma)
 *     responses:
 *       200:
 *         description: Documento firmado exitosamente
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 message:
 *                   type: string
 *                 signed_file_path:
 *                   type: string
 *                 download_url:
 *                   type: string
 *       400:
 *         description: Error de validación o documento no aprobado
 *       404:
 *         description: Documento no encontrado
 *       500:
 *         description: Error interno del servidor
 */
router.post('/:id/firmar', DocumentoController.firmarDocumento);

/**
 * @swagger
 * /api/documentos/{id}/download/signed:
 *   get:
 *     summary: Descargar documento firmado
 *     tags: [Documentos]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *         description: ID del documento
 *     responses:
 *       200:
 *         description: Archivo del documento firmado
 *         content:
 *           application/vnd.openxmlformats-officedocument.wordprocessingml.document:
 *             schema:
 *               type: string
 *               format: binary
 *           application/msword:
 *             schema:
 *               type: string
 *               format: binary
 *           application/vnd.openxmlformats-officedocument.spreadsheetml.sheet:
 *             schema:
 *               type: string
 *               format: binary
 *           application/vnd.ms-excel:
 *             schema:
 *               type: string
 *               format: binary
 *         headers:
 *           Content-Disposition:
 *             schema:
 *               type: string
 *             description: attachment; filename="documento_firmado.docx"
 *       404:
 *         description: Documento no encontrado o no ha sido firmado
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: false
 *                 message:
 *                   type: string
 *                   example: "Documento no ha sido firmado aún"
 *       500:
 *         description: Error interno del servidor
 */

/**
 * @swagger
 * /api/documentos/{id}/revisar:
 *   post:
 *     summary: Revisar documento Word o Excel
 *     tags: [Documentos]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *         description: ID del documento
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - revisor_name
 *             properties:
 *               revisor_name:
 *                 type: string
 *                 description: Nombre del revisor
 *               usuario_revisor:
 *                 type: integer
 *                 description: ID del usuario que revisa (opcional, para usar su firma)
 *     responses:
 *       200:
 *         description: Documento revisado exitosamente
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 message:
 *                   type: string
 *                 signed_file_path:
 *                   type: string
 *                 download_url:
 *                   type: string
 *       400:
 *         description: Error de validación o documento no aprobado
 *       404:
 *         description: Documento no encontrado
 *       500:
 *         description: Error interno del servidor
 */
router.post('/:id/revisar', DocumentoController.revisarDocumento);

module.exports = router;
