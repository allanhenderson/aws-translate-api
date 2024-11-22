const { TranslateClient, TranslateTextCommand } = require('@aws-sdk/client-translate');
const createError = require('http-errors');
const { validateInput } = require('../validator');
const logger = require('../utils/logger');

const translateClient = new TranslateClient();

const formatResponse = (statusCode, body) => ({
  statusCode,
  headers: {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': 'https://main.d1et0mhtohynii.amplifyapp.com/', // In production, specify your frontend domain
    'Access-Control-Allow-Credentials': true,
    'Access-Control-Allow-Headers': 'Content-Type,Authorization,X-Api-Key',
    'Access-Control-Allow-Methods': 'POST,OPTIONS'
  },
  body: JSON.stringify(body)
});

// Add OPTIONS handler for preflight requests
const handleOptions = () => ({
  statusCode: 200,
  headers: {
    'Access-Control-Allow-Origin': 'https://main.d1et0mhtohynii.amplifyapp.com/', // In production, specify your frontend domain
    'Access-Control-Allow-Credentials': true,
    'Access-Control-Allow-Headers': 'Content-Type,Authorization,X-Api-Key',
    'Access-Control-Allow-Methods': 'POST,OPTIONS',
    'Access-Control-Max-Age': '300'
  },
  body: ''
});

const translate = async (event) => {
  // Handle OPTIONS requests
  if (event.requestContext.http.method === 'OPTIONS') {
    return handleOptions();
  }

  try {
    let body;
    try {
      body = JSON.parse(event.body);
    } catch (e) {
      return formatResponse(400, {
        error: 'Invalid JSON in request body'
      });
    }

    // Validate required fields
    if (!body.text || !body.targetLanguage) {
      return formatResponse(400, {
        error: 'Missing required fields: text and targetLanguage are required'
      });
    }
    // Configure the translation request
    const command = new TranslateTextCommand({
      Text: body.text,
      SourceLanguageCode: body.sourceLanguage || 'auto',
      TargetLanguageCode: body.targetLanguage
    });
    // Rest of your existing handler code...
    const result = await translateClient.send(command);
    // All responses use formatResponse with CORS headers
    return formatResponse(200, {
      translatedText: result.TranslatedText,
      detectedSourceLanguage: result.SourceLanguageCode,
      targetLanguage: result.TargetLanguageCode,
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    // Error responses also include CORS headers
    return formatResponse(error.statusCode || 500, {
      error: error.message || 'Internal server error'
    });
  }
};

module.exports = {
  translate
};