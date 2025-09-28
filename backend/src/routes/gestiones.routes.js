const express = require('express');
const router = express.Router();
const { query } = require('../config/database');

/**
 * @swagger
 * components:
 *   schemas:
 *     Gestion:
 *       type: object
 *       required:
 *         - nombre
 *         - activo
 *       properties:
 *         id:
 *           type: integer
 *           format: int64
 *           description: ID único de la gestión
 *           example: 1
 *         nombre:
 *           type: string
 *           maxLength: 255
 *           description: Nombre descriptivo de la gestión
 *           example: "Gestión 2023"
 *         descripcion:
 *           type: string
 *           nullable: true
 *           description: Descripción detallada de la gestión
 *           example: "Gestión del año fiscal 2023"
 *         activo:
 *           type: boolean
 *           description: Indica si la gestión está activa
 *           default: true
 *         fecha_creacion:
 *           type: string
 *           format: date-time
 *           description: Fecha de creación del registro
 *           readOnly: true
 *         fecha_actualizacion:
 *           type: string
 *           format: date-time
 *           description: Fecha de última actualización
 *           readOnly: true
 *       example:
 *         id: 1
 *         nombre: "Gestión 2023"
 *         descripcion: "Gestión del año fiscal 2023"
 *         activo: true
 *         fecha_creacion: "2023-01-01T00:00:00.000Z"
 *         fecha_actualizacion: "2023-01-01T00:00:00.000Z"
 *     
 *     Error:
 *       type: object
 *       properties:
 *         success:
 *           type: boolean
 *           example: false
 *         message:
 *           type: string
 *           example: "Error message"
 *         error:
 *           type: object
 *           nullable: true
 *           example: {}
 * 
 *     ValidationError:
 *       type: object
 *       properties:
 *         success:
 *           type: boolean
 *           example: false
 *         message:
 *           type: string
 *           example: "Validation error"
 *         errors:
 *           type: array
 *           items:
 *             type: object
 *             properties:
 *               field:
 *                 type: string
 *                 example: "nombre"
 *               message:
 *                 type: string
 *                 example: "El nombre es requerido"
 */

/**
 * @swagger
 * /api/gestiones:
 *   get:
 *     summary: Obtener todas las gestiones
 *     description: Retorna una lista de todas las gestiones, opcionalmente filtradas por estado
 *     tags: [Gestiones]
 *     parameters:
 *       - in: query
 *         name: activo
 *         schema:
 *           type: boolean
 *         description: Filtrar por estado activo/inactivo
 *         example: true
 *     responses:
 *       200:
 *         description: Lista de gestiones obtenida exitosamente
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 data:
 *                   type: array
 *                   items:
 *                     $ref: '#/components/schemas/Gestion'
 *                 total:
 *                   type: integer
 *                   description: Número total de gestiones
 *                   example: 5
 *       500:
 *         description: Error del servidor
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 */
router.get('/', async (req, res) => {
  try {
    const { activo } = req.query;
    
    let queryText = 'SELECT * FROM gestiones';
    let queryParams = [];
    
    if (activo !== undefined) {
      queryText += ' WHERE activo = $1';
      queryParams.push(activo === 'true');
    }
    
    queryText += ' ORDER BY nombre ASC';
    
    const result = await query(queryText, queryParams);
    
    res.json({
      success: true,
      data: result.rows
    });
  } catch (error) {
    console.error('Error fetching gestiones:', error);
    res.status(500).json({
      success: false,
      message: 'Error al obtener las gestiones',
      error: process.env.NODE_ENV === 'development' ? error.message : {}
    });
  }
});

/**
 * @swagger
 * /api/gestiones/{id}:
 *   get:
 *     summary: Obtener una gestión por ID
 *     description: Retorna los detalles de una gestión específica
 *     tags: [Gestiones]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *           format: int64
 *         description: ID de la gestión
 *         example: 1
 *     responses:
 *       200:
 *         description: Gestión encontrada
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 data:
 *                   $ref: '#/components/schemas/Gestion'
 *       404:
 *         description: Gestión no encontrada
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
 *                   example: "Gestión no encontrada"
 *       500:
 *         description: Error del servidor
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 */
router.get('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    
    const result = await query('SELECT * FROM gestiones WHERE id = $1', [parseInt(id)]);
    
    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'Gestión no encontrada'
      });
    }
    
    res.json({
      success: true,
      data: result.rows[0]
    });
  } catch (error) {
    console.error('Error fetching gestion:', error);
    res.status(500).json({
      success: false,
      message: 'Error al obtener la gestión',
      error: process.env.NODE_ENV === 'development' ? error.message : {}
    });
  }
});

/**
 * @swagger
 * /api/gestiones:
 *   post:
 *     summary: Crear una nueva gestión
 *     description: Crea un nuevo registro de gestión con los datos proporcionados
 *     tags: [Gestiones]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - nombre
 *             properties:
 *               nombre:
 *                 type: string
 *                 minLength: 1
 *                 maxLength: 255
 *                 example: "Gestión 2024"
 *               descripcion:
 *                 type: string
 *                 nullable: true
 *                 example: "Gestión del año fiscal 2024"
 *               activo:
 *                 type: boolean
 *                 default: true
 *     responses:
 *       201:
 *         description: Gestión creada exitosamente
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 message:
 *                   type: string
 *                   example: "Gestión creada exitosamente"
 *                 data:
 *                   $ref: '#/components/schemas/Gestion'
 *       400:
 *         description: Error de validación
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ValidationError'
 *       409:
 *         description: Conflicto - Ya existe una gestión con el mismo nombre
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
 *                   example: "Ya existe una gestión con ese nombre"
 *       500:
 *         description: Error del servidor
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 */
router.post('/', async (req, res) => {
  try {
    const { nombre, descripcion, activo = true } = req.body;
    
    if (!nombre || nombre.trim() === '') {
      return res.status(400).json({
        success: false,
        message: 'El nombre es requerido'
      });
    }
    
    const result = await query(
      'INSERT INTO gestiones (nombre, descripcion, activo) VALUES ($1, $2, $3) RETURNING *',
      [nombre.trim(), descripcion || null, activo]
    );
    
    res.status(201).json({
      success: true,
      message: 'Gestión creada exitosamente',
      data: result.rows[0]
    });
  } catch (error) {
    console.error('Error creating gestion:', error);
    
    if (error.code === '23505') { // Unique constraint violation
      return res.status(409).json({
        success: false,
        message: 'Ya existe una gestión con ese nombre'
      });
    }
    
    res.status(500).json({
      success: false,
      message: 'Error al crear la gestión',
      error: process.env.NODE_ENV === 'development' ? error.message : {}
    });
  }
});

/**
 * @swagger
 * /api/gestiones/{id}:
 *   put:
 *     summary: Actualizar una gestión existente
 *     description: Actualiza los datos de una gestión específica
 *     tags: [Gestiones]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *           format: int64
 *         description: ID de la gestión a actualizar
 *         example: 1
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - nombre
 *             properties:
 *               nombre:
 *                 type: string
 *                 minLength: 1
 *                 maxLength: 255
 *                 example: "Gestión 2024 Actualizada"
 *               descripcion:
 *                 type: string
 *                 nullable: true
 *                 example: "Gestión actualizada del año fiscal 2024"
 *               activo:
 *                 type: boolean
 *                 example: true
 *     responses:
 *       200:
 *         description: Gestión actualizada exitosamente
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 message:
 *                   type: string
 *                   example: "Gestión actualizada exitosamente"
 *                 data:
 *                   $ref: '#/components/schemas/Gestion'
 *       400:
 *         description: Error de validación
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ValidationError'
 *       404:
 *         description: Gestión no encontrada
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
 *                   example: "Gestión no encontrada"
 *       409:
 *         description: Conflicto - Ya existe otra gestión con el mismo nombre
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
 *                   example: "Ya existe una gestión con ese nombre"
 *       500:
 *         description: Error del servidor
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 */
router.put('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { nombre, descripcion, activo } = req.body;
    
    if (!nombre || nombre.trim() === '') {
      return res.status(400).json({
        success: false,
        message: 'El nombre es requerido'
      });
    }
    
    const result = await query(
      'UPDATE gestiones SET nombre = $1, descripcion = $2, activo = $3, fecha_actualizacion = CURRENT_TIMESTAMP WHERE id = $4 RETURNING *',
      [nombre.trim(), descripcion || null, activo !== undefined ? activo : true, parseInt(id)]
    );
    
    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'Gestión no encontrada'
      });
    }
    
    res.json({
      success: true,
      message: 'Gestión actualizada exitosamente',
      data: result.rows[0]
    });
  } catch (error) {
    console.error('Error updating gestion:', error);
    
    if (error.code === '23505') { // Unique constraint violation
      return res.status(409).json({
        success: false,
        message: 'Ya existe una gestión con ese nombre'
      });
    }
    
    res.status(500).json({
      success: false,
      message: 'Error al actualizar la gestión',
      error: process.env.NODE_ENV === 'development' ? error.message : {}
    });
  }
});

/**
 * @swagger
 * /api/gestiones/{id}:
 *   delete:
 *     summary: Eliminar una gestión
 *     description: Elimina una gestión específica por su ID
 *     tags: [Gestiones]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *           format: int64
 *         description: ID de la gestión a eliminar
 *         example: 1
 *     responses:
 *       200:
 *         description: Gestión eliminada exitosamente
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 message:
 *                   type: string
 *                   example: "Gestión eliminada exitosamente"
 *       404:
 *         description: Gestión no encontrada
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
 *                   example: "Gestión no encontrada"
 *       500:
 *         description: Error del servidor
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 */
router.delete('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    
    // Check if there are documents using this gestion
    const documentsCheck = await query('SELECT COUNT(*) as count FROM documentos WHERE gestion_id = $1', [parseInt(id)]);
    
    if (parseInt(documentsCheck.rows[0].count) > 0) {
      return res.status(400).json({
        success: false,
        message: 'No se puede eliminar la gestión porque tiene documentos asociados'
      });
    }
    
    const result = await query('DELETE FROM gestiones WHERE id = $1 RETURNING *', [parseInt(id)]);
    
    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'Gestión no encontrada'
      });
    }
    
    res.json({
      success: true,
      message: 'Gestión eliminada exitosamente'
    });
  } catch (error) {
    console.error('Error deleting gestion:', error);
    res.status(500).json({
      success: false,
      message: 'Error al eliminar la gestión',
      error: process.env.NODE_ENV === 'development' ? error.message : {}
    });
  }
});

module.exports = router;
