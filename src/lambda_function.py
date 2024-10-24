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
