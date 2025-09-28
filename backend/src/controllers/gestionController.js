const Gestion = require('../models/gestion');
const Joi = require('joi');

// Validation schemas
const createGestionSchema = Joi.object({
  nombre: Joi.string().min(1).max(255).required(),
  descripcion: Joi.string().allow('').max(1000).optional()
});

const updateGestionSchema = Joi.object({
  nombre: Joi.string().min(1).max(255).required(),
  descripcion: Joi.string().allow('').max(1000).optional()
});

class GestionController {
  // Get all gestiones
  static async getAll(req, res) {
    try {
      const gestiones = await Gestion.getAll();
      
      res.json({
        success: true,
        data: gestiones,
        total: gestiones.length
      });
    } catch (error) {
      console.error('Error getting gestiones:', error);
      res.status(500).json({
        success: false,
        message: 'Error al obtener las gestiones',
        error: error.message
      });
    }
  }

  // Get gestion by ID
  static async getById(req, res) {
    try {
      const { id } = req.params;
      const gestion = await Gestion.getById(parseInt(id));
      
      if (!gestion) {
        return res.status(404).json({
          success: false,
          message: 'Gestión no encontrada'
        });
      }

      res.json({
        success: true,
        data: gestion
      });
    } catch (error) {
      console.error('Error getting gestion by ID:', error);
      res.status(500).json({
        success: false,
        message: 'Error al obtener la gestión',
        error: error.message
      });
    }
  }

  // Create new gestion
  static async create(req, res) {
    try {
      const { error, value } = createGestionSchema.validate(req.body);
      if (error) {
        return res.status(400).json({
          success: false,
          message: 'Datos de entrada inválidos',
          errors: error.details.map(detail => ({
            field: detail.path.join('.'),
            message: detail.message
          }))
        });
      }

      const gestion = await Gestion.create(value);
      res.status(201).json({
        success: true,
        message: 'Gestión creada exitosamente',
        data: gestion
      });
    } catch (error) {
      console.error('Error creating gestion:', error);
      
      if (error.code === '23505') {
        return res.status(400).json({
          success: false,
          message: 'Ya existe una gestión con ese nombre'
        });
      }

      res.status(500).json({
        success: false,
        message: 'Error al crear la gestión',
        error: error.message
      });
    }
  }

  // Update gestion
  static async update(req, res) {
    try {
      const { id } = req.params;
      const { error, value } = updateGestionSchema.validate(req.body);
      
      if (error) {
        return res.status(400).json({
          success: false,
          message: 'Datos de entrada inválidos',
          errors: error.details.map(detail => ({
            field: detail.path.join('.'),
            message: detail.message
          }))
        });
      }

      const gestion = await Gestion.update(parseInt(id), value);
      if (!gestion) {
        return res.status(404).json({
          success: false,
          message: 'Gestión no encontrada'
        });
      }

      res.json({
        success: true,
        message: 'Gestión actualizada exitosamente',
        data: gestion
      });
    } catch (error) {
      console.error('Error updating gestion:', error);
      res.status(500).json({
        success: false,
        message: 'Error al actualizar la gestión',
        error: error.message
      });
    }
  }

  // Delete gestion (soft delete)
  static async delete(req, res) {
    try {
      const { id } = req.params;
      const result = await Gestion.delete(parseInt(id));
      
      if (!result) {
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
        error: error.message
      });
    }
  }
}

module.exports = GestionController;
