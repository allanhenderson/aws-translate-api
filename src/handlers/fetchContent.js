// src/handlers/fetchContent.js
const axios = require('axios');
const { JSDOM } = require('jsdom');
const createError = require('http-errors');

const formatResponse = (statusCode, body) => ({
  statusCode,
  headers: {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Credentials': true,
    'Access-Control-Allow-Headers': 'Content-Type,Authorization,X-Api-Key',
    'Access-Control-Allow-Methods': 'POST,OPTIONS'
  },
  body: JSON.stringify(body)
});

const extractContent = (html) => {
  const dom = new JSDOM(html);
  const document = dom.window.document;

  // Remove unwanted elements
  const elementsToRemove = [
    'script', 'style', 'iframe', 'nav', 'footer', 
    'header', 'aside', 'noscript', 'link', 'meta'
  ];
  
  elementsToRemove.forEach(tag => {
    document.querySelectorAll(tag).forEach(el => el.remove());
  });

  // Get main content
  const mainContent = 
    document.querySelector('article') || 
    document.querySelector('main') || 
    document.querySelector('.content') ||
    document.querySelector('#content') ||
    document.body;

  // Count images
  const imageCount = mainContent.getElementsByTagName('img').length;

  // Process content
  const processNode = (node) => {
    if (node.nodeType === 3) { // Text node
      return node.textContent.trim();
    }

    const children = Array.from(node.childNodes)
      .map(child => processNode(child))
      .filter(text => text.length > 0);

    switch (node.nodeName.toLowerCase()) {
      case 'h1':
      case 'h2':
      case 'h3':
      case 'h4':
      case 'h5':
      case 'h6':
        return `\n# ${children.join(' ')}\n`;
      case 'p':
        return `\n${children.join(' ')}\n`;
      case 'br':
        return '\n';
      case 'div':
        return `\n${children.join(' ')}\n`;
      case 'li':
        return `\n• ${children.join(' ')}`;
      case 'a':
        const href = node.getAttribute('href');
        return href ? `${children.join(' ')} [${href}]` : children.join(' ');
      case 'strong':
      case 'b':
        return `**${children.join(' ')}**`;
      case 'em':
      case 'i':
        return `*${children.join(' ')}*`;
      case 'blockquote':
        return `\n> ${children.join(' ')}\n`;
      case 'code':
        return `\`${children.join(' ')}\``;
      default:
        return children.join(' ');
    }
  };

  const content = processNode(mainContent)
    .replace(/\n\s+\n/g, '\n\n')
    .replace(/\n{3,}/g, '\n\n')
    .trim();

  return {
    content,
    metadata: {
      wordCount: content.split(/\s+/).length,
      paragraphCount: (content.match(/\n\n/g) || []).length + 1,
      hasImages: imageCount > 0
    },
    title: document.title || ''
  };
};

const fetchContent = async (event) => {
  // Handle CORS preflight request
  if (event.requestContext?.http?.method === 'OPTIONS') {
    return formatResponse(200, {});
  }

  try {
    let body;
    try {
      body = JSON.parse(event.body);
    } catch (e) {
      return formatResponse(400, {
        error: 'Invalid JSON in request body'
      });
    }

    const { url, preserveFormatting = true } = body;

    if (!url) {
      return formatResponse(400, {
        error: 'URL is required'
      });
    }

    // Validate URL
    try {
      new URL(url);
    } catch (e) {
      return formatResponse(400, {
        error: 'Invalid URL format'
      });
    }

    // Fetch webpage content
    const response = await axios.get(url, {
      timeout: 10000,
      headers: {
        'User-Agent': 'Mozilla/5.0 (compatible; WebContentFetcher/1.0)',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.5'
      },
      maxRedirects: 5
    });

    // Check content type
    const contentType = response.headers['content-type'] || '';
    if (!contentType.includes('text/html')) {
      return formatResponse(400, {
        error: 'URL must point to an HTML page'
      });
    }

    // Extract and format content
    const extracted = extractContent(response.data);

    return formatResponse(200, {
      content: extracted.content,
      metadata: extracted.metadata,
      title: extracted.title
    });

  } catch (error) {
    console.error('Error fetching content:', error);

    if (error.response) {
      // HTTP error responses
      switch (error.response.status) {
        case 404:
          return formatResponse(404, { error: 'Page not found' });
        case 403:
          return formatResponse(403, { error: 'Access forbidden' });
        case 500:
          return formatResponse(500, { error: 'Target server error' });
        default:
          return formatResponse(error.response.status, { 
            error: `Server responded with status: ${error.response.status}` 
          });
      }
    }

    if (error.code === 'ECONNABORTED') {
      return formatResponse(408, { error: 'Request timeout' });
    }

    if (error.code === 'ENOTFOUND') {
      return formatResponse(400, { error: 'Domain not found' });
    }

    return formatResponse(500, {
      error: 'Failed to fetch content'
    });
  }
};

module.exports = {
  fetchContent
};