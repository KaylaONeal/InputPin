'use strict';
const copy = document.getElementById('copy');
const status = document.getElementById('copy-status');
copy.addEventListener('click', async () => {
  try {
    await navigator.clipboard.writeText('brew install kaylaoneal/tap/inputpin');
    status.textContent = 'Copied. Paste into Terminal to install.';
  } catch {
    status.textContent = 'Copy unavailable. Select the command above instead.';
  }
});
