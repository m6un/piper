/*
 * readability.js — Mozilla Readability stub for Piper Share Extension
 *
 * PRODUCTION NOTE: Replace this stub with the real Mozilla Readability library.
 * Source: https://github.com/mozilla/readability
 * File to bundle: Readability.js from the mozilla/readability repository.
 *
 * This stub implements the same public API as the real library so that
 * Swift tests and integration code can be written against it without
 * requiring a network download during development.
 *
 * API contract (matches mozilla/readability):
 *   const reader = new Readability(document);
 *   const article = reader.parse();
 *   // article is null if content could not be extracted
 *   // article.title — string
 *   // article.content — HTML string
 */

/* global document */
(function (global) {
  'use strict';

  /**
   * Readability constructor.
   * @param {Document} doc - A DOM Document object.
   * @param {Object} [options] - Optional configuration (ignored in stub).
   */
  function Readability(doc, options) {
    if (!doc) {
      throw new Error('Readability: first argument must be a Document node');
    }
    this._doc = doc;
    this._options = options || {};
  }

  /**
   * Attempt to extract article content from the document.
   *
   * Returns an object with at minimum { title, content } on success,
   * or null if the page does not appear to contain article content.
   *
   * This stub uses a simple heuristic:
   * - title: document.title (trimmed)
   * - content: the innerHTML of the first <article>, <main>, or <body> element found
   *
   * The real Mozilla Readability performs much more sophisticated analysis.
   *
   * @returns {{ title: string, content: string }|null}
   */
  Readability.prototype.parse = function () {
    try {
      var doc = this._doc;

      // Require a document with a body.
      if (!doc || !doc.body) {
        return null;
      }

      var title = (doc.title || '').trim();

      // Prefer semantic article containers; fall back to body.
      var contentNode =
        doc.querySelector('article') ||
        doc.querySelector('[role="main"]') ||
        doc.querySelector('main') ||
        doc.body;

      var content = contentNode ? contentNode.innerHTML : '';

      // If neither title nor content is non-trivially present, signal failure.
      if (!title && (!content || content.trim().length < 10)) {
        return null;
      }

      return {
        title: title,
        content: content,
        textContent: contentNode ? (contentNode.textContent || '').trim() : '',
        length: content.length,
        excerpt: '',
        byline: '',
        dir: null,
        siteName: '',
        lang: '',
        publishedTime: null
      };
    } catch (e) {
      // parse() must never throw — return null to indicate extraction failure.
      return null;
    }
  };

  // Export for both CommonJS (tests) and browser/WKWebView global scope.
  if (typeof module !== 'undefined' && module.exports) {
    module.exports = { Readability: Readability };
  } else {
    global.Readability = Readability;
  }
}(typeof globalThis !== 'undefined' ? globalThis : this));
