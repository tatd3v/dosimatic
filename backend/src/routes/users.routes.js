const express = require('express');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const { query, getClient } = require('../config/database');
const bcrypt = require('bcryptjs');
const { v4: uuidv4 } = require('uuid');

const router = express.Router();

// Centralized logging utilities
const logger = {
  success: msg => console.log(`✅ ${msg}`),
  error: msg => console.error(`❌ ${msg}`),
  info: msg => console.log(`ℹ️ ${msg}`),
  warning: msg => console.log(`⚠️ ${msg}`)
};

// Common response helpers
const responses = {
  success: (res, data, message = 'Success') => {
    res.json({ success: true, message, data });
  },
  error: (res, status, message, details = null) => {
    const response = { success: false, message };
    if (details && process.env.NODE_ENV === 'development') {
      response.error = details;
    }
    res.status(status).json(response);
  },
  notFound: (res, resource = 'Resource') => {
    res
      .status(404)
      .json({ success: false, message: `${resource} no encontrado` });
  }
};

// Common validation helpers
const validators = {
  async userExists(id) {
    const result = await query(
      'SELECT id, nombre as name FROM usuarios WHERE id = $1',
      [id]
    );
    return result.rows.length > 0 ? result.rows[0] : null;
  },
  async emailExists(email) {
    const result = await query('SELECT id FROM usuarios WHERE email = $1', [
      email
    ]);
    return result.rows.length > 0;
  }
};

// Configuración de multer para subida de imágenes de firma
const signatureDir = path.join(
  process.env.SIGNATURES_PATH || path.join(__dirname, '../../signatures')
);

// Asegurarse de que el directorio existe
if (!fs.existsSync(signatureDir)) {
  fs.mkdirSync(signatureDir, { recursive: true });
  console.log(`✅ Directorio de firmas creado en: ${signatureDir}`);
}

const signatureStorage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, signatureDir);
  },
  filename: (req, file, cb) => {
    const userId = req.params.id;
    const ext = path.extname(file.originalname).toLowerCase();
    const filename = `user_${userId}_signature${ext}`;
    logger.info(`Guardando firma como: ${filename}`);
    cb(null, filename);
  }
});

const uploadSignature = multer({
  storage: signatureStorage,
  limits: {
    fileSize: 5 * 1024 * 1024 // 5MB
  },
  fileFilter: (req, file, cb) => {
    const allowedTypes = /jpeg|jpg|png/;
    const extname = allowedTypes.test(
      path.extname(file.originalname).toLowerCase()
    );
    const mimetype = allowedTypes.test(file.mimetype);

    if (mimetype && extname) {
      return cb(null, true);
    } else {
      cb(new Error('Solo se permiten imágenes PNG, JPG y JPEG'));
    }
  }
});

/**
 * @swagger
 * /api/users/{id}/signature:
 *   post:
 *     summary: Subir imagen de firma para un usuario
 *     tags: [Users]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *         description: ID del usuario
 *     requestBody:
 *       required: true
 *       content:
 *         multipart/form-data:
 *           schema:
 *             type: object
 *             properties:
 *               signature:
 *                 type: string
 *                 format: binary
 *                 description: Imagen de firma (PNG, JPG, JPEG)
 *     responses:
 *       200:
 *         description: Imagen de firma subida exitosamente
 *       400:
 *         description: Error en la validación
 *       404:
 *         description: Usuario no encontrado
 */
router.post(
  '/:id/signature',
  uploadSignature.single('signature'),
  async (req, res) => {
    try {
      const { id } = req.params;

      if (!req.file) {
        return res.status(400).json({
          success: false,
          message: 'No se proporcionó archivo de imagen'
        });
      }

      // Verificar que el usuario existe
      const user = await validators.userExists(id);
      if (!user) {
        // Eliminar archivo subido si el usuario no existe
        fs.unlinkSync(req.file.path);
        return responses.notFound(res, 'Usuario');
      }

      // Actualizar ruta de imagen de firma en la base de datos
      const signaturePath = path.join('signatures', req.file.filename);
      logger.info(
        `Actualizando firma en DB para usuario ${id}: ${signaturePath}`
      );

      await query(
        'UPDATE usuarios SET signature_image = $1 WHERE id = $2 RETURNING *',
        [signaturePath, id]
      );

      responses.success(
        res,
        {
          signature_path: signaturePath,
          user: user.name
        },
        'Imagen de firma subida exitosamente'
      );
    } catch (error) {
      logger.error(`Error subiendo imagen de firma: ${error.message}`);

      // Eliminar archivo si hubo error
      if (req.file && fs.existsSync(req.file.path)) {
        fs.unlinkSync(req.file.path);
      }

      responses.error(res, 500, 'Error interno del servidor', error.message);
    }
  }
);

/**
 * @swagger
 * /api/users/{id}:
 *   get:
 *     summary: Obtener información de un usuario
 *     tags: [Users]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *         description: ID del usuario
 *     responses:
 *       200:
 *         description: Información del usuario
 *       404:
 *         description: Usuario no encontrado
 */
router.get('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const fs = require('fs').promises;
    const path = require('path');

    logger.info(`Fetching user with id: ${id}`);
    const result = await query(
      'SELECT id, nombre, email, rol, activo, fecha_creacion, signature_image FROM usuarios WHERE id = $1',
      [id]
    );

    if (result.rows.length === 0) {
      return responses.notFound(res, 'Usuario');
    }

    // Get the user data
    const userData = { ...result.rows[0] };
    
    // If there's a signature image path, read the file and convert to base64
    if (userData.signature_image) {
      try {
        const signaturePath = path.join(process.cwd(), userData.signature_image);
        logger.info(`Reading signature file from: ${signaturePath}`);
        
        // Read the file as base64
        const fileData = await fs.readFile(signaturePath);
        const base64Data = fileData.toString('base64');
        
        // Determine the MIME type from the file extension
        const ext = path.extname(signaturePath).toLowerCase().substring(1);
        const mimeType = `image/${ext === 'jpg' ? 'jpeg' : ext}`;
        
        // Create a data URL
        userData.signature_image = `data:${mimeType};base64,${base64Data}`;
        
        logger.info(`Successfully read and encoded signature image (${fileData.length} bytes)`);
      } catch (error) {
        logger.error(`Error reading signature file: ${error.message}`);
        // Keep the original path if we can't read the file
        userData.signature_image = null;
      }
    }
    
    // Log the response data (without the potentially large base64 string)
    const logData = {
      ...userData,
      signature_image: userData.signature_image ? '[base64 image data]' : null
    };
    
    logger.info('User data prepared for response:', {
      ...logData,
      hasSignature: !!userData.signature_image,
      signatureType: typeof userData.signature_image,
      signatureLength: userData.signature_image ? userData.signature_image.length : 0
    });

    // Send the complete response with base64-encoded image
    responses.success(res, userData);
  } catch (error) {
    logger.error(`Error obteniendo usuario: ${error.message}`);
    responses.error(res, 500, 'Error interno del servidor', error.message);
  }
});

/**
 * @swagger
 * /api/users:
 *   get:
 *     summary: Obtener lista de usuarios
 *     tags: [Users]
 *     responses:
 *       200:
 *         description: Lista de usuarios
 */
router.get('/', async (req, res) => {
  try {
    logger.info('Fetching users from database...');

    const result = await query(
      'SELECT id, nombre, email, rol, activo, fecha_creacion FROM usuarios WHERE activo = true ORDER BY nombre'
    );

    logger.info(`Found ${result.rows.length} users`);

    responses.success(res, result.rows);
  } catch (error) {
    logger.error(`Error obteniendo usuarios: ${error.message}`);
    responses.error(res, 500, 'Error interno del servidor', error.message);
  }
});

/**
 * @swagger
 * /api/users:
 *   post:
 *     summary: Crear un nuevo usuario
 *     tags: [Users]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - name
 *               - email
 *               - password
 *               - role
 *             properties:
 *               name:
 *                 type: string
 *               email:
 *                 type: string
 *                 format: email
 *               password:
 *                 type: string
 *                 format: password
 *               role:
 *                 type: string
 *                 enum: [admin, user, reviewer, approver]
 *     responses:
 *       201:
 *         description: Usuario creado exitosamente
 *       400:
 *         description: Error de validación
 *       500:
 *         description: Error del servidor
 */
router.post('/', async (req, res) => {
  try {
    const { name, email, password, role = 'user' } = req.body;

    // Validación básica
    if (!name || !email || !password) {
      return res.status(400).json({
        success: false,
        message: 'Nombre, email y contraseña son requeridos'
      });
    }

    // Verificar si el email ya existe
    if (await validators.emailExists(email)) {
      return responses.error(
        res,
        400,
        'El correo electrónico ya está registrado'
      );
    }

    // Hash de la contraseña
    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(password, salt);

    // Crear usuario
    const result = await query(
      `INSERT INTO usuarios (nombre, email, password, rol, fecha_creacion)
       VALUES ($1, $2, $3, $4, NOW()) 
       RETURNING id, nombre as name, email, rol as role, fecha_creacion as created_at`,
      [name, email, hashedPassword, role || 'usuario']
    );

    // No devolver la contraseña
    const newUser = result.rows[0];
    delete newUser.password;

    res.status(201).json({
      success: true,
      message: 'Usuario creado exitosamente',
      data: newUser
    });
  } catch (error) {
    logger.error(`Error al crear usuario: ${error.message}`);
    responses.error(res, 500, 'Error al crear el usuario', error.message);
  }
});

/**
 * @swagger
 * /api/users/{id}/change-password:
 *   post:
 *     summary: Cambiar contraseña de usuario
 *     tags: [Users]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *         description: ID del usuario
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [currentPassword, newPassword]
 *             properties:
 *               currentPassword:
 *                 type: string
 *                 format: password
 *               newPassword:
 *                 type: string
 *                 format: password
 *                 minLength: 6
 *     responses:
 *       200:
 *         description: Contraseña actualizada correctamente
 *       400:
 *         description: Contraseña actual incorrecta o nueva contraseña inválida
 *       404:
 *         description: Usuario no encontrado
 *       500:
 *         description: Error del servidor
 */
router.post('/:id/change-password', async (req, res) => {
  try {
    const { id } = req.params;
    const { currentPassword, newPassword } = req.body;

    // Validar nueva contraseña
    if (!newPassword || newPassword.length < 6) {
      return responses.error(
        res,
        400,
        'La nueva contraseña debe tener al menos 6 caracteres'
      );
    }

    // Obtener usuario y verificar contraseña actual
    const userResult = await query(
      'SELECT id, password FROM usuarios WHERE id = $1',
      [id]
    );

    if (userResult.rows.length === 0) {
      return responses.notFound(res, 'Usuario');
    }

    const user = userResult.rows[0];
    const isMatch = await bcrypt.compare(currentPassword, user.password);

    if (!isMatch) {
      return responses.error(res, 400, 'La contraseña actual es incorrecta');
    }

    // Actualizar contraseña
    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(newPassword, salt);

    await query('UPDATE usuarios SET password = $1 WHERE id = $2', [
      hashedPassword,
      id
    ]);

    responses.success(res, null, 'Contraseña actualizada exitosamente');
  } catch (error) {
    logger.error(`Error al cambiar contraseña: ${error.message}`);
    responses.error(
      res,
      500,
      'Error al actualizar la contraseña',
      error.message
    );
  }
});

module.exports = router;
