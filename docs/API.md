# API Documentation

## Endpoints

### POST /translate

Translates text from one language to another using AWS Translate.

#### Request Body

```json
{
  "text": "Text to translate",
  "targetLanguage": "es",
  "sourceLanguage": "auto"  // optional
}
```

#### Response

Success (200):
```json
{
  "translatedText": "Texto traducido",
  "detectedSourceLanguage": "en",
  "targetLanguage": "es",
  "timestamp": "2024-10-24T12:00:00.000Z"
}
```

Error (400):
```json
{
  "error": "Error message",
  "detail": "Additional error details"  // optional
}
```

#### Request Limits
- Maximum text length: 5000 characters
- Language codes must be 2 characters (ISO 639-1)

#### Supported Languages
Refer to [AWS Translate documentation](https://docs.aws.amazon.com/translate/latest/dg/what-is.html) for supported language codes.