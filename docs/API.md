# API Documentation

## Endpoints

### POST /translate

Translates text from one language to another using AWS Translate.

#### Request Body

```json
{
  "text": "Text to translate",
  "target_language": "es",
  "source_language": "auto"  // optional
}
```

#### Response

Success (200):
```json
{
  "translated_text": "Texto traducido",
  "detected_source_language": "en",
  "target_language": "es",
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

#### Supported Languages

Refer to [AWS Translate documentation](https://docs.aws.amazon.com/translate/latest/dg/what-is.html) for supported language codes.
