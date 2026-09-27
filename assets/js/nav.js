/* Menú desplegable de la capçalera per a pantalles estretes.
   S'utilitza a index.html i a les pàgines de /legal. */
(function () {
  'use strict';

  var DESKTOP_MIN_WIDTH = 768;

  var toggle = document.querySelector('.nav-toggle');
  var nav = document.getElementById('site-nav');

  if (!toggle || !nav) return;

  function setOpen(open) {
    nav.classList.toggle('is-open', open);
    toggle.setAttribute('aria-expanded', open ? 'true' : 'false');
    toggle.setAttribute('aria-label', open ? 'Tanca el menú' : 'Obre el menú');
  }

  function isOpen() {
    return nav.classList.contains('is-open');
  }

  toggle.addEventListener('click', function () {
    setOpen(!isOpen());
  });

  // Escape tanca el menú i retorna el focus al botó.
  document.addEventListener('keydown', function (event) {
    if (event.key === 'Escape' && isOpen()) {
      setOpen(false);
      toggle.focus();
    }
  });

  // Clic fora del menú el tanca.
  document.addEventListener('click', function (event) {
    if (!isOpen()) return;
    if (nav.contains(event.target) || toggle.contains(event.target)) return;
    setOpen(false);
  });

  // Seguir un enllaç o un botó del menú el tanca.
  nav.addEventListener('click', function (event) {
    if (event.target.closest('a, button')) setOpen(false);
  });

  // En tornar a ample pantalla, el menú torna a ser horitzontal.
  window.addEventListener('resize', function () {
    if (window.innerWidth > DESKTOP_MIN_WIDTH) setOpen(false);
  });
})();
