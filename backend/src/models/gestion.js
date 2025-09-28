const { query } = require('../config/database');

class Gestion {
  // Get all gestiones
  static async getAll() {
    try {
      const sql = `
        SELECT id, nombre, descripcion, activo, fecha_creacion, fecha_actualizacion
        FROM gestiones 
        WHERE activo = true
        ORDER BY nombre ASC
      `;
      
      const result = await query(sql);
      return result.rows;
    } catch (error) {
      console.error('Error getting gestiones:', error);
      throw error;
    }
  }

  // Get gestion by ID
  static async getById(id) {
    try {
      const sql = `
        SELECT id, nombre, descripcion, activo, fecha_creacion, fecha_actualizacion
        FROM gestiones 
        WHERE id = $1 AND activo = true
      `;
      
      const result = await query(sql, [id]);
      return result.rows[0];
    } catch (error) {
      console.error('Error getting gestion by ID:', error);
      throw error;
    }
  }

  // Create new gestion
  static async create(gestionData) {
    try {
      const { nombre, descripcion } = gestionData;
      const sql = `
        INSERT INTO gestiones (nombre, descripcion, activo, fecha_creacion, fecha_actualizacion)
        VALUES ($1, $2, true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
        RETURNING id, nombre, descripcion, activo, fecha_creacion, fecha_actualizacion
      `;
      
      const result = await query(sql, [nombre, descripcion]);
      return result.rows[0];
    } catch (error) {
      console.error('Error creating gestion:', error);
      throw error;
    }
  }

  // Update gestion
  static async update(id, gestionData) {
    try {
      const { nombre, descripcion } = gestionData;
      const sql = `
        UPDATE gestiones 
        SET nombre = $1, descripcion = $2, fecha_actualizacion = CURRENT_TIMESTAMP
        WHERE id = $3 AND activo = true
        RETURNING id, nombre, descripcion, activo, fecha_creacion, fecha_actualizacion
      `;
      
      const result = await query(sql, [nombre, descripcion, id]);
      return result.rows[0];
    } catch (error) {
      console.error('Error updating gestion:', error);
      throw error;
    }
  }

  // Soft delete gestion
  static async delete(id) {
    try {
      const sql = `
        UPDATE gestiones 
        SET activo = false, fecha_actualizacion = CURRENT_TIMESTAMP
        WHERE id = $1
        RETURNING id
      `;
      
      const result = await query(sql, [id]);
      return result.rows[0];
    } catch (error) {
      console.error('Error deleting gestion:', error);
      throw error;
    }
  }
}

module.exports = Gestion;
