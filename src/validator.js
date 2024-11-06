const Joi = require('joi');

const inputSchema = Joi.object({
  text: Joi.string().required().trim().min(1).max(5000),
  targetLanguage: Joi.string().required().length(2),
  sourceLanguage: Joi.string().length(2),
});

const validateInput = (input) => inputSchema.validate(input, { abortEarly: false });

module.exports = {
  validateInput,
};