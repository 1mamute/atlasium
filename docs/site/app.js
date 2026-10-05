'use strict';
const language = document.documentElement.lang;
const themeButton = document.querySelector('#theme');

function setTheme(theme) {
  const dark = theme === 'dark';
  document.documentElement.dataset.theme = dark ? 'dark' : 'light';
  document.querySelector('#moon-icon').toggleAttribute('hidden', dark);
  document.querySelector('#sun-icon').toggleAttribute('hidden', !dark);
  const label = language === 'pt-BR'
    ? (dark ? 'Modo claro' : 'Modo escuro') : (dark ? 'Light mode' : 'Dark mode');
  document.querySelector('#theme-label').textContent = label;
  themeButton.setAttribute('aria-label', label);
  themeButton.setAttribute('aria-pressed', String(dark));
  try { localStorage.setItem('atlasium-theme', dark ? 'dark' : 'light'); } catch (_) { /* Storage is optional. */ }
}

let theme = 'light';
try { theme = localStorage.getItem('atlasium-theme') || theme; } catch (_) { /* Use the default. */ }
setTheme(theme);
themeButton.addEventListener('click', () => {
  setTheme(document.documentElement.dataset.theme === 'dark' ? 'light' : 'dark');
});
document.querySelector('#language').addEventListener('change', event => {
  const selected = event.target.value;
  try { localStorage.setItem('atlasium-language', selected); } catch (_) { /* Storage is optional. */ }
  const filename = location.pathname.split('/').pop() || 'index.html';
  location.href = '../' + selected + '/' + filename + location.hash;
});
