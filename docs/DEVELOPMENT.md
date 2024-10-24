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
