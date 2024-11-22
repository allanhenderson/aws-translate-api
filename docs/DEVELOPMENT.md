# Development Guide

## Setup

1. Install dependencies:
```bash
npm install
```

2. Configure environment:
- Copy `env_example.yml` to `config/env.dev.yml`
- Update values as needed

## Local Development

Run the API locally:
```bash
npm run start:offline
```

## Testing

Run tests:
```bash
npm test
```

Run linter:
```bash
npm run lint
```

## Deployment

### Development
```bash
npm run deploy
```

### Production
```bash
npm run deploy:prod
```

## Adding New Features

1. Add new function to `src/handler.js`
2. Update tests in `tests/`
3. Update API documentation in `docs/API.md`
4. Run tests and linting
5. Create pull request

## Best Practices

1. Always write tests for new features
2. Use async/await for asynchronous operations
3. Validate input using Joi schemas
4. Use proper error handling
5. Add appropriate logging
6. Follow ESLint rules