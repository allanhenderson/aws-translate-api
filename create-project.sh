#!/bin/bash

# Create project directories
mkdir -p aws-translate-api/{src,config,tests,.github/workflows,docs}

# Create .gitignore
cat > aws-translate-api/.gitignore << 'EOL'
# Dependencies
node_modules/
.serverless/
package-lock.json

# Python
*.pyc
__pycache__/
.pytest_cache/
.coverage
.env
.venv/
venv/

# IDE
.idea/
.vscode/
*.swp
*.swo

# Serverless
.serverless
serverless.env.yml

# Environment variables
.env*
!.env.example

# Coverage reports
coverage/
htmlcov/
EOL

# Create package.json
cat > aws-translate-api/package.json << 'EOL'
{
  "name": "aws-translate-api",
  "version": "1.0.0",
  "description": "Serverless AWS Translate API",
  "scripts": {
    "deploy": "serverless deploy",
    "test": "pytest",
    "coverage": "pytest --cov=src tests/"
  },
  "devDependencies": {
    "serverless": "^4.0.0",
    "serverless-python-requirements": "^6.0.0"
  }
}
EOL

# Create requirements.txt
cat > aws-translate-api/requirements.txt << 'EOL'
boto3>=1.26.0
pytest>=7.0.0
pytest-cov>=4.0.0
pytest-mock>=3.10.0
requests>=2.28.0
python-dotenv>=1.0.0
EOL

# Create serverless.yml
cat > aws-translate-api/serverless.yml << 'EOL'
service: aws-translate-api

frameworkVersion: '4'

provider:
  name: aws
  runtime: python3.9
  stage: ${opt:stage, 'dev'}
  region: ${opt:region, 'us-east-1'}
  environment: ${file(./config/env.${self:provider.stage}.yml)}
  iam:
    role:
      statements:
        - Effect: Allow
          Action:
            - translate:TranslateText
          Resource: "*"

plugins:
  - serverless-python-requirements

custom:
  pythonRequirements:
    dockerizePip: true
    layer:
      name: python-deps
      description: Python dependencies for translate API

functions:
  translate:
    handler: src/lambda_function.lambda_handler
    events:
      - http:
          path: translate
          method: post
          cors: true
    environment:
      STAGE: ${self:provider.stage}
      POWERTOOLS_SERVICE_NAME: translate-api
      LOG_LEVEL: ${self:provider.environment.LOG_LEVEL}

package:
  patterns:
    - '!**/*.md'
    - '!tests/**'
    - '!docs/**'
    - '!.github/**'
    - '!.git/**'
    - '!.env*'
EOL

# Create lambda_function.py with enhanced logging and error handling
cat > aws-translate-api/src/lambda_function.py << 'EOL'
import json
import boto3
import os
import logging
from typing import Optional, Dict, Any, Tuple
from datetime import datetime

# Configure logging
logger = logging.getLogger()
logger.setLevel(os.environ.get('LOG_LEVEL', 'INFO'))

# Initialize AWS Translate client
translate = boto3.client('translate')

class TranslationError(Exception):
    """Custom exception for translation errors"""
    pass

def validate_input(body: Dict[str, Any]) -> Tuple[bool, Optional[Dict[str, str]]]:
    """Validate the input request body."""
    required_fields = ['text', 'target_language']
    
    if not body:
        return False, {
            'statusCode': 400,
            'body': json.dumps({
                'error': 'Request body is empty'
            })
        }
    
    for field in required_fields:
        if field not in body:
            return False, {
                'statusCode': 400,
                'body': json.dumps({
                    'error': f'Missing required field: {field}'
                })
            }
    
    if not isinstance(body['text'], str) or not body['text'].strip():
        return False, {
            'statusCode': 400,
            'body': json.dumps({
                'error': 'Text field must be a non-empty string'
            })
        }
    
    return True, None

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Lambda handler for translation requests
    """
    logger.info(f"Processing translation request at {datetime.utcnow().isoformat()}")
    
    try:
        # Parse the body from API Gateway event
        body = json.loads(event['body']) if isinstance(event['body'], str) else event['body']
        
        # Validate input
        is_valid, error_response = validate_input(body)
        if not is_valid:
            logger.warning(f"Invalid input received: {body}")
            return error_response
        
        # Extract parameters
        text = body['text']
        target_language = body['target_language']
        source_language = body.get('source_language', 'auto')
        
        logger.info(f"Translating text from {source_language} to {target_language}")
        
        # Call AWS Translate
        response = translate.translate_text(
            Text=text,
            SourceLanguageCode=source_language,
            TargetLanguageCode=target_language
        )
        
        result = {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'translated_text': response['TranslatedText'],
                'detected_source_language': response['SourceLanguageCode'],
                'target_language': response['TargetLanguageCode'],
                'timestamp': datetime.utcnow().isoformat()
            })
        }
        
        logger.info("Translation completed successfully")
        return result
        
    except translate.exceptions.UnsupportedLanguagePairException as e:
        logger.error(f"Unsupported language pair: {str(e)}")
        return {
            'statusCode': 400,
            'body': json.dumps({
                'error': 'Unsupported language pair',
                'detail': str(e)
            })
        }
    except translate.exceptions.InvalidRequestException as e:
        logger.error(f"Invalid request: {str(e)}")
        return {
            'statusCode': 400,
            'body': json.dumps({
                'error': str(e)
            })
        }
    except json.JSONDecodeError as e:
        logger.error(f"Invalid JSON in request: {str(e)}")
        return {
            'statusCode': 400,
            'body': json.dumps({
                'error': 'Invalid JSON in request body'
            })
        }
    except Exception as e:
        logger.error(f"Unexpected error: {str(e)}", exc_info=True)
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': 'Internal server error',
                'request_id': context.aws_request_id if context else None
            })
        }
EOL

# Create enhanced test file
cat > aws-translate-api/tests/test_lambda_function.py << 'EOL'
import pytest
import json
from src.lambda_function import lambda_handler
from unittest.mock import MagicMock, patch
from datetime import datetime

@pytest.fixture
def mock_translate():
    with patch('src.lambda_function.translate') as mock:
        mock.translate_text.return_value = {
            'TranslatedText': '¡Hola mundo!',
            'SourceLanguageCode': 'en',
            'TargetLanguageCode': 'es'
        }
        yield mock

@pytest.fixture
def valid_event():
    return {
        'body': json.dumps({
            'text': 'Hello world!',
            'target_language': 'es'
        })
    }

@pytest.fixture
def invalid_event():
    return {
        'body': json.dumps({
            'text': 'Hello world!'
            # missing target_language
        })
    }

@pytest.fixture
def empty_text_event():
    return {
        'body': json.dumps({
            'text': '',
            'target_language': 'es'
        })
    }

@pytest.fixture
def malformed_json_event():
    return {
        'body': '{"text": "Hello world!", "target_language": "es"'  # invalid JSON
    }

def test_successful_translation(valid_event, mock_translate):
    response = lambda_handler(valid_event, None)
    assert response['statusCode'] == 200
    body = json.loads(response['body'])
    assert 'translated_text' in body
    assert 'detected_source_language' in body
    assert 'target_language' in body
    assert 'timestamp' in body
    
    # Verify timestamp format
    datetime.fromisoformat(body['timestamp'])

def test_missing_required_field(invalid_event):
    response = lambda_handler(invalid_event, None)
    assert response['statusCode'] == 400
    body = json.loads(response['body'])
    assert 'error' in body
    assert 'Missing required field' in body['error']

def test_empty_text(empty_text_event):
    response = lambda_handler(empty_text_event, None)
    assert response['statusCode'] == 400
    body = json.loads(response['body'])
    assert 'error' in body
    assert 'Text field must be a non-empty string' in body['error']

def test_malformed_json(malformed_json_event):
    response = lambda_handler(malformed_json_event, None)
    assert response['statusCode'] == 400
    body = json.loads(response['body'])
    assert 'error' in body
    assert 'Invalid JSON in request body' in body['error']

def test_translate_service_error(valid_event, mock_translate):
    mock_translate.translate_text.side_effect = Exception('AWS Translate service error')
    response = lambda_handler(valid_event, MagicMock(aws_request_id='test-request-id'))
    assert response['statusCode'] == 500
    body = json.loads(response['body'])
    assert 'error' in body
    assert 'request_id' in body

def test_unsupported_language_pair(valid_event, mock_translate):
    mock_translate.translate_text.side_effect = mock_translate.exceptions.UnsupportedLanguagePairException(
        error_response={'Error': {'Message': 'Unsupported language pair'}}
    )
    response = lambda_handler(valid_event, None)
    assert response['statusCode'] == 400
    body = json.loads(response['body'])
    assert 'error' in body
    assert 'Unsupported language pair' in body['error']
EOL

# Create GitHub Actions workflow
cat > aws-translate-api/.github/workflows/main.yml << 'EOL'
name: CI/CD Pipeline

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        python-version: [3.9]

    steps:
    - uses: actions/checkout@v3
    
    - name: Set up Python ${{ matrix.python-version }}
      uses: actions/setup-python@v4
      with:
        python-version: ${{ matrix.python-version }}
    
    - name: Cache pip packages
      uses: actions/cache@v3
      with:
        path: ~/.cache/pip
        key: ${{ runner.os }}-pip-${{ hashFiles('**/requirements.txt') }}
        restore-keys: |
          ${{ runner.os }}-pip-
    
    - name: Install dependencies
      run: |
        python -m pip install --upgrade pip
        pip install -r requirements.txt
    
    - name: Run tests with coverage
      run: |
        pytest --cov=src tests/ --cov-report=xml
    
    - name: Upload coverage to Codecov
      uses: codecov/codecov-action@v3
      with:
        file: ./coverage.xml
        flags: unittests
        fail_ci_if_error: true

  deploy:
    needs: test
    if: github.ref == 'refs/heads/main' && github.event_name == 'push'
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Setup Node.js
      uses: actions/setup-node@v3
      with:
        node-version: '18'
    
    - name: Install Serverless Framework
      run: npm install -g serverless
    
    - name: Install dependencies
      run: |
        npm install
        pip install -r requirements.txt
    
    - name: Deploy
      env:
        AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
        AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
      run: serverless deploy --stage prod
EOL

# Create environment variable templates
cat > aws-translate-api/config/env.example.yml << 'EOL'
LOG_LEVEL: INFO
POWERTOOLS_SERVICE_NAME: translate-api
EOL

cat > aws-translate-api/config/env.dev.yml << 'EOL'
LOG_LEVEL: DEBUG
POWERTOOLS_SERVICE_NAME: translate-api-dev
EOL

cat > aws-translate-api/config/env.prod.yml << 'EOL'
LOG_LEVEL: INFO
POWERTOOLS_SERVICE_NAME: translate-api-prod
EOL

# Create enhanced documentation
cat > aws-translate-api/docs/API.md << 'EOL'
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
EOL

cat > aws-translate-api/docs/DEVELOPMENT.md << 'EOL'
# Development Guide

## Setup

1. Install dependencies:
```bash
npm install
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install -r requirements.txt
```

2. Configure environment:
- Copy `config/env.example.yml` to `config/env.dev.yml`
- Update values as needed

## Testing

Run tests:
```bash
npm test
```

Run tests with coverage:
```bash
npm run coverage
```

## Deployment

### Local Testing
```bash
serverless invoke local --function translate --path examples/event.