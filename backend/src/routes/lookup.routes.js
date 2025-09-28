const express = require('express');
const router = express.Router();
const pool = require('../config/database');

/**
 * @swagger
 * tags:
 *   - name: Lookup
 *     description: Endpoints for document filtering lookups
 */

/**
 * Lookup endpoints for document filtering
 * These endpoints return data in the format expected by the lookup.dart widget
 * Format: [{ iddato: id, datonombre: name }, ...]
 * Only supports the 5 filterable fields: estado, gestionId, codigo, nombre, convencion
 */

/**
 * @swagger
 * /api/documentos/lookup/codigo:
 *   post:
 *     summary: Lookup document codes (códigos)
 *     tags: [Lookup]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               codigo:
 *                 type: string
 *                 description: Search term for document code (optional)
 *     responses:
 *       200:
 *         description: List of document codes matching the search term
 *         content:
 *           application/json:
 *             schema:
 *               type: array
 *               items:
 *                 type: object
 *                 properties:
 *                   iddato:
 *                     type: string
 *                     description: Document code
 *                   datonombre:
 *                     type: string
 *                     description: Document code (same as iddato)
 *       500:
 *         description: Server error
 */
router.post('/documentos/lookup/codigo', async (req, res) => {
  try {
    const { codigo } = req.body;
    const searchTerm = codigo || '';

    let query, params;

    if (!searchTerm || searchTerm === '0') {
      query = `
        SELECT DISTINCT codigo as iddato, codigo as datonombre 
        FROM documentos 
        WHERE codigo IS NOT NULL
        AND estado != 'eliminado'
        ORDER BY codigo 
        LIMIT 100
      `;
      params = [];
    } else {
      query = `
        SELECT DISTINCT codigo as iddato, codigo as datonombre 
        FROM documentos 
        WHERE codigo ILIKE $1
        AND estado != 'eliminado'
        ORDER BY codigo 
        LIMIT 100
      `;
      params = [`%${searchTerm}%`];
    }

    console.log('Fetching códigos for filter, search term:', searchTerm);
    const result = await pool.query(query, params);
    console.log(`Found ${result.rows.length} códigos`);

    res.json(result.rows);
  } catch (error) {
    console.error('Error in codigo lookup:', error);
    res.status(500).json({ error: 'Error fetching codigo data' });
  }
});

/**
 * @swagger
 * /api/documentos/lookup/nombre:
 *   post:
 *     summary: Lookup document names (nombres)
 *     tags: [Lookup]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               codigo:
 *                 type: string
 *                 description: Search term for document name (optional)
 *     responses:
 *       200:
 *         description: List of document names matching the search term
 *         content:
 *           application/json:
 *             schema:
 *               type: array
 *               items:
 *                 type: object
 *                 properties:
 *                   iddato:
 *                     type: string
 *                     description: Document ID
 *                   datonombre:
 *                     type: string
 *                     description: Document name
 *       500:
 *         description: Server error
 */
router.post('/documentos/lookup/nombre', async (req, res) => {
  try {
    const { codigo } = req.body;
    const searchTerm = codigo || '';

    let query, params;

    if (!searchTerm || searchTerm === '0') {
      query = `
        SELECT DISTINCT nombre as iddato, nombre as datonombre 
        FROM documentos 
        WHERE nombre IS NOT NULL
        AND estado != 'eliminado'
        ORDER BY nombre 
        LIMIT 100
      `;
      params = [];
    } else {
      query = `
        SELECT DISTINCT nombre as iddato, nombre as datonombre 
        FROM documentos 
        WHERE nombre ILIKE $1
        AND estado != 'eliminado'
        ORDER BY nombre 
        LIMIT 100
      `;
      params = [`%${searchTerm}%`];
    }

    console.log('Fetching nombres for filter, search term:', searchTerm);
    const result = await pool.query(query, params);
    console.log(`Found ${result.rows.length} nombres`);

    res.json(result.rows);
  } catch (error) {
    console.error('Error in nombre lookup:', error);
    res.status(500).json({ error: 'Error fetching nombre data' });
  }
});

/**
 * @swagger
 * /api/documentos/lookup/estado:
 *   post:
 *     summary: Lookup document states (estados)
 *     tags: [Lookup]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               codigo:
 *                 type: string
 *                 description: Search term for document state (optional)
 *     responses:
 *       200:
 *         description: List of document states matching the search term
 *         content:
 *           application/json:
 *             schema:
 *               type: array
 *               items:
 *                 type: object
 *                 properties:
 *                   iddato:
 *                     type: string
 *                     description: Document state
 *                   datonombre:
 *                     type: string
 *                     description: Document state (same as iddato)
 *       500:
 *         description: Server error
 */
router.post('/documentos/lookup/estado', async (req, res) => {
  try {
    const { codigo } = req.body;
    const searchTerm = codigo || '';

    // Get distinct estados from documentos table, EXCLUDING eliminado
    const query = `
      SELECT DISTINCT estado as iddato
      FROM documentos
      WHERE estado IS NOT NULL
      AND estado != 'eliminado'
      ORDER BY estado
    `;

    console.log(
      'Fetching all distinct estados for filter (excluding eliminado)'
    );
    const result = await pool.query(query);

    // Map database values to display names
    const displayNames = {
      borrador: 'Borrador',
      pendiente_aprobacion: 'Pendiente Aprobación',
      pendiente_revision: 'Pendiente Revisión',
      aprobado: 'Aprobado',
      rechazado: 'Rechazado'
    };

    let estados = result.rows.map(row => ({
      iddato: row.iddato,
      datonombre: displayNames[row.iddato] || row.iddato
    }));

    // Filter by search term if provided (for search functionality in modal)
    if (searchTerm && searchTerm !== '0') {
      const searchLower = searchTerm.toLowerCase();
      estados = estados.filter(
        estado =>
          estado.datonombre.toLowerCase().includes(searchLower) ||
          estado.iddato.toLowerCase().includes(searchLower)
      );
    }

    console.log(
      `Found ${estados.length} distinct estados (excluding eliminado)`
    );
    res.json(estados);
  } catch (error) {
    console.error('Error in estado lookup:', error);
    res.status(500).json({ error: 'Error fetching estado data' });
  }
});

/**
 * @swagger
 * /api/documentos/lookup/convencion:
 *   post:
 *     summary: Lookup document types (convenciones)
 *     tags: [Lookup]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               codigo:
 *                 type: string
 *                 description: Search term for document type (optional)
 *     responses:
 *       200:
 *         description: List of document types matching the search term
 *         content:
 *           application/json:
 *             schema:
 *               type: array
 *               items:
 *                 type: object
 *                 properties:
 *                   iddato:
 *                     type: string
 *                     description: Document type
 *                   datonombre:
 *                     type: string
 *                     description: Document type (same as iddato)
 *       500:
 *         description: Server error
 */
router.post('/documentos/lookup/convencion', async (req, res) => {
  try {
    const { codigo } = req.body;
    const searchTerm = codigo || '';

    let query, params;

    if (!searchTerm || searchTerm === '0') {
      query = `
        SELECT DISTINCT convencion as iddato, convencion as datonombre 
        FROM documentos 
        WHERE convencion IS NOT NULL
        AND estado != 'eliminado'
        ORDER BY convencion 
        LIMIT 100
      `;
      params = [];
    } else {
      query = `
        SELECT DISTINCT convencion as iddato, convencion as datonombre 
        FROM documentos 
        WHERE convencion ILIKE $1
        AND estado != 'eliminado'
        ORDER BY convencion 
        LIMIT 100
      `;
      params = [`%${searchTerm}%`];
    }

    console.log('Fetching convenciones for filter, search term:', searchTerm);
    const result = await pool.query(query, params);
    console.log(`Found ${result.rows.length} convenciones`);

    res.json(result.rows);
  } catch (error) {
    console.error('Error in convencion lookup:', error);
    res.status(500).json({ error: 'Error fetching convencion data' });
  }
});

// Lookup for management areas (gestiones) - returns gestionId
router.post('/documentos/lookup/gestion', async (req, res) => {
  try {
    const { codigo } = req.body;
    const searchTerm = codigo || '';

    console.log('Fetching gestiones for filter, search term:', searchTerm);

    // First try to get from gestiones table
    try {
      let query, params;

      if (!searchTerm || searchTerm === '0') {
        query = `
          SELECT g.id as iddato, g.nombre as datonombre 
          FROM gestiones g
          ORDER BY g.nombre 
          LIMIT 100
        `;
        params = [];
      } else {
        query = `
          SELECT g.id as iddato, g.nombre as datonombre 
          FROM gestiones g
          WHERE g.nombre ILIKE $1
          ORDER BY g.nombre 
          LIMIT 100
        `;
        params = [`%${searchTerm}%`];
      }

      const result = await pool.query(query, params);
      console.log(`Found ${result.rows.length} gestiones from gestiones table`);
      res.json(result.rows);
    } catch (tableError) {
      // Fallback: get distinct gestion values from documentos table
      console.log('Gestiones table not found, using documentos table fallback');

      let query, params;

      if (!searchTerm || searchTerm === '0') {
        query = `
          SELECT DISTINCT gestion as iddato, gestion as datonombre 
          FROM documentos 
          WHERE gestion IS NOT NULL
          AND estado != 'eliminado'
          ORDER BY gestion 
          LIMIT 100
        `;
        params = [];
      } else {
        query = `
          SELECT DISTINCT gestion as iddato, gestion as datonombre 
          FROM documentos 
          WHERE gestion ILIKE $1
          AND estado != 'eliminado'
          ORDER BY gestion 
          LIMIT 100
        `;
        params = [`%${searchTerm}%`];
      }

      const result = await pool.query(query, params);
      console.log(
        `Found ${result.rows.length} distinct gestiones from documentos table`
      );
      res.json(result.rows);
    }
  } catch (error) {
    console.error('Error in gestion lookup:', error);
    res.status(500).json({ error: 'Error fetching gestion data' });
  }
});

module.exports = router;
