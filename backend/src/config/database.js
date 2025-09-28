const { Pool } = require('pg');
require('dotenv').config();

// Configuration constants
const CONFIG = {
  CONNECTION_TIMEOUT: 10000,
  IDLE_TIMEOUT: 30000,
  MAX_RETRIES: 5,
  RETRY_DELAY: 2000,
  MAX_CONNECTIONS: 20
};

// Validate required environment variables
const requiredEnvVars = [
  'DB_USER',
  'DB_HOST',
  'DB_NAME',
  'DB_PASSWORD',
  'DB_PORT'
];
const missingVars = requiredEnvVars.filter(varName => !process.env[varName]);

if (missingVars.length > 0) {
  console.error(
    '❌ Missing required environment variables:',
    missingVars.join(', ')
  );
  process.exit(1);
}

// Centralized logging utilities
const logger = {
  success: msg => console.log(`✅ ${msg}`),
  error: msg => console.error(`❌ ${msg}`),
  info: msg => console.log(`ℹ️ ${msg}`),
  warning: msg => console.log(`⚠️ ${msg}`)
};

// Database pool configuration
const pool = new Pool({
  host: process.env.DB_HOST || 'localhost',
  port: process.env.DB_PORT || 5432,
  user: process.env.DB_USER || 'secwin_user',
  password: process.env.DB_PASSWORD || 'secwin_password',
  database: process.env.DB_NAME || 'secwin_db',
  max: CONFIG.MAX_CONNECTIONS,
  idleTimeoutMillis: CONFIG.IDLE_TIMEOUT,
  connectionTimeoutMillis: CONFIG.CONNECTION_TIMEOUT
});

// Log configuration (without sensitive data)
console.log('📊 Database connection config:', {
  host: process.env.DB_HOST,
  port: process.env.DB_PORT,
  user: process.env.DB_USER,
  database: process.env.DB_NAME,
  password: '***',
  max: CONFIG.MAX_CONNECTIONS
});

// Handle connection events
pool.on('connect', () => logger.success('Database connection established'));
pool.on('error', err => {
  logger.error(`Unexpected error on idle client: ${err.message}`);
  process.exit(-1);
});

// Enhanced query function with better logging
const query = async (text, params = []) => {
  const start = Date.now();
  try {
    const result = await pool.query(text, params);
    const duration = Date.now() - start;

    console.log('📝 Query executed:', {
      duration: `${duration}ms`,
      rows: result.rowCount,
      command: text.split(' ')[0].toUpperCase()
    });

    return result;
  } catch (error) {
    const duration = Date.now() - start;
    logger.error(`Query failed after ${duration}ms: ${error.message}`);
    throw error;
  }
};

// Función para obtener un cliente del pool (para transacciones)
const getClient = async () => {
  const client = await pool.connect();
  const query = client.query;
  const release = client.release;

  // Monitorear queries del cliente
  const timeout = setTimeout(() => {
    console.error('Un cliente ha estado activo por más de 5 segundos!');
    console.error(`La última query ejecutada fue: ${client.lastQuery}`);
  }, 5000);

  // Wrapper para queries del cliente
  client.query = (...args) => {
    client.lastQuery = args;
    return query.apply(client, args);
  };

  // Wrapper para release del cliente
  client.release = () => {
    clearTimeout(timeout);
    client.query = query;
    client.release = release;
    return release.apply(client);
  };

  return client;
};

// Unified connection test with retries
const testConnection = async () => {
  for (let attempt = 1; attempt <= CONFIG.MAX_RETRIES; attempt++) {
    try {
      const client = await pool.connect();
      const { rows } = await client.query(
        'SELECT NOW() as current_time, version() as db_version'
      );

      logger.success('PostgreSQL database connection successful');
      logger.info(`Database time: ${rows[0].current_time}`);
      logger.info(`Database version: ${rows[0].db_version.split(' ')[0]}`);

      client.release();
      return true;
    } catch (error) {
      logger.error(
        `Connection attempt ${attempt}/${CONFIG.MAX_RETRIES} failed: ${error.message}`
      );

      if (attempt < CONFIG.MAX_RETRIES) {
        const waitTime = CONFIG.RETRY_DELAY / 1000;
        logger.info(`Retrying in ${waitTime} seconds...`);
        await new Promise(resolve => setTimeout(resolve, CONFIG.RETRY_DELAY));
      }
    }
  }

  logger.error('Failed to connect to database after multiple attempts');
  return false;
};

// Función para cerrar el pool
const closePool = async () => {
  try {
    await pool.end();
    console.log('Pool de conexiones cerrado');
  } catch (error) {
    console.error('Error cerrando pool:', error.message);
  }
};

module.exports = {
  query,
  getClient,
  testConnection,
  closePool,
  pool
};
