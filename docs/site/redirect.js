'use strict';
let language = 'en';
try {
  if (localStorage.getItem('atlasium-language') === 'pt-BR') language = 'pt-BR';
} catch (_) { /* English is the default when storage is unavailable. */ }
location.replace(language + '/index.html' + location.hash);
