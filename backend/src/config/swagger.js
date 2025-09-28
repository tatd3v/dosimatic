const swaggerJsdoc = require('swagger-jsdoc');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../../.env.local') });

const options = {
  definition: {
    openapi: '3.0.0',
    info: {
      title: 'SecWin API Documentation',
      version: '1.0.0',
      description:
        'API documentation for SecWin system including user authentication and contact management'
    },
    servers: [
      {
        url: `http://localhost:${process.env.PORT || 3501}`,
        description: 'Servidor de desarrollo'
      }
    ],
    // Tags will be auto-populated from route files
    tags: [],
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
  apis: [
    path.join(__dirname, '../routes/*.js'),
    path.join(__dirname, '../routes/**/*.js')
  ]
};

// Generate the base Swagger specification
const swaggerSpec = swaggerJsdoc(options);

// Ensure all operations have tags
Object.values(swaggerSpec.paths || {}).forEach(pathItem => {
  Object.values(pathItem).forEach(operation => {
    if (operation.tags && operation.tags.length === 0) {
      operation.tags = ['Other'];
    } else if (!operation.tags) {
      operation.tags = ['Other'];
    }
  });
});

// Extract all unique tags from paths and sort them alphabetically
const allTags = new Set();

// First pass: collect all unique tags
Object.values(swaggerSpec.paths || {}).forEach(pathItem => {
  Object.values(pathItem).forEach(operation => {
    if (operation.tags && Array.isArray(operation.tags)) {
      operation.tags.forEach(tag => allTags.add(tag));
    }
  });
});

// Convert Set to array of tag objects, sorted alphabetically
swaggerSpec.tags = Array.from(allTags)
  .sort((a, b) => a.localeCompare(b, 'en', {sensitivity: 'base'}))
  .map(tag => ({
    name: tag,
    description: `${tag.charAt(0).toUpperCase() + tag.slice(1)} related endpoints`
  }));

// Sort paths alphabetically
if (swaggerSpec.paths) {
  const sortedPaths = {};
  Object.keys(swaggerSpec.paths)
    .sort((a, b) => a.localeCompare(b))
    .forEach(key => {
      sortedPaths[key] = swaggerSpec.paths[key];
    });
  swaggerSpec.paths = sortedPaths;
}

// Swagger UI options are configured in the main server file

// Ensure all operations have tags from our sorted list
Object.values(swaggerSpec.paths || {}).forEach(pathItem => {
  Object.values(pathItem).forEach(operation => {
    if (operation.tags && operation.tags.length > 0) {
      // Sort operation tags to maintain consistent order
      operation.tags.sort((a, b) => a.localeCompare(b, 'en', {sensitivity: 'base'}));
    }
  });
});

module.exports = swaggerSpec;
