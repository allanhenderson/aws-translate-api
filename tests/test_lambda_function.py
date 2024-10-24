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
