const { translate } = require('../src/handler');
const { TranslateClient } = require('@aws-sdk/client-translate');

// Mock AWS SDK
jest.mock('@aws-sdk/client-translate');

describe('Translate Handler', () => {
  const mockTranslateResponse = {
    TranslatedText: '¡Hola mundo!',
    SourceLanguageCode: 'en',
    TargetLanguageCode: 'es',
  };

  beforeEach(() => {
    // Clear all mocks before each test
    jest.clearAllMocks();
    
    // Mock the send method
    TranslateClient.prototype.send = jest.fn().mockResolvedValue(mockTranslateResponse);
  });

  it('should successfully translate text', async () => {
    const event = {
      body: JSON.stringify({
        text: 'Hello world!',
        targetLanguage: 'es',
      }),
    };

    const response = await translate(event);
    
    expect(response.statusCode).toBe(200);
    const body = JSON.parse(response.body);
    expect(body.translatedText).toBe('¡Hola mundo!');
    expect(body.detectedSourceLanguage).toBe('en');
    expect(body.targetLanguage).toBe('es');
    expect(body.timestamp).toBeDefined();
  });

  it('should handle missing required fields', async () => {
    const event = {
      body: JSON.stringify({
        text: 'Hello world!',
        // missing targetLanguage
      }),
    };

    const response = await translate(event);
    
    expect(response.statusCode).toBe(400);
    const body = JSON.parse(response.body);
    expect(body.error).toBeDefined();
  });

  it('should handle empty text', async () => {
    const event = {
      body: JSON.stringify({
        text: '',
        targetLanguage: 'es',
      }),
    };

    const response = await translate(event);
    
    expect(response.statusCode).toBe(400);
    const body = JSON.parse(response.body);
    expect(body.error).toBeDefined();
  });

  it('should handle AWS translate service error', async () => {
    TranslateClient.prototype.send = jest.fn().mockRejectedValue(
      new Error('AWS Translate service error')
    );

    const event = {
      body: JSON.stringify({
        text: 'Hello world!',
        targetLanguage: 'es',
      }),
      requestContext: { requestId: 'test-request-id' },
    };

    const response = await translate(event);
    
    expect(response.statusCode).toBe(500);
    const body = JSON.parse(response.body);
    expect(body.error).toBe('Internal server error');
    expect(body.requestId).toBe('test-request-id');
  });
});