const { TranslateClient, TranslateTextCommand } = require('@aws-sdk/client-translate');
const createError = require('http-errors');
const { validateInput } = require('./validator');
const logger = require('./utils/logger');

const translateClient = new TranslateClient();

const formatResponse = (statusCode, body) => ({
  statusCode,
  headers: {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Credentials': true,
  },
  body: JSON.stringify(body),
});

const translate = async (event) => {
  try {
    logger.info('Processing translation request', { timestamp: new Date().toISOString() });

    const body = JSON.parse(event.body);
    
    // Validate input
    const { error, value } = validateInput(body);
    if (error) {
      logger.warn('Invalid input received', { error: error.details });
      throw new createError.BadRequest(error.details[0].message);
    }

    const { text, targetLanguage, sourceLanguage = 'auto' } = value;

    logger.info('Translating text', {
      sourceLanguage,
      targetLanguage,
      textLength: text.length,
    });

    const command = new TranslateTextCommand({
      Text: text,
      SourceLanguageCode: sourceLanguage,
      TargetLanguageCode: targetLanguage,
    });

    const result = await translateClient.send(command);

    logger.info('Translation completed successfully');

    return formatResponse(200, {
      translatedText: result.TranslatedText,
      detectedSourceLanguage: result.SourceLanguageCode,
      targetLanguage: result.TargetLanguageCode,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error('Error processing request', { error });

    if (error.name === 'UnsupportedLanguagePairException') {
      return formatResponse(400, {
        error: 'Unsupported language pair',
        detail: error.message,
      });
    }

    if (error.name === 'InvalidRequestException') {
      return formatResponse(400, {
        error: error.message,
      });
    }

    if (error instanceof createError.BadRequest) {
      return formatResponse(400, {
        error: error.message,
      });
    }

    return formatResponse(500, {
      error: 'Internal server error',
      requestId: event.requestContext?.requestId,
    });
  }
};

module.exports = {
  translate,
};