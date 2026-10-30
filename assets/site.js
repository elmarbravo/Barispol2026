/* Site do Centro Médico Barispol: comportamento comum a todas as páginas
   (31-10-2026). Modo escuro, menu do telemóvel, página activa no menu e
   carrossel dos cartões de serviço. */

/* Botão do modo escuro. */
(function () {
  var bt = document.querySelector('.tema');
  if (!bt) return;
  var rotular = function () {
    var e = document.documentElement.getAttribute('data-tema') === 'escuro';
    bt.setAttribute('aria-label', e ? 'Mudar para modo claro' : 'Mudar para modo escuro');
    bt.title = e ? 'Modo claro' : 'Modo escuro';
  };
  rotular();
  bt.addEventListener('click', function () {
    var e = document.documentElement.getAttribute('data-tema') !== 'escuro';
    if (e) document.documentElement.setAttribute('data-tema', 'escuro'); else document.documentElement.removeAttribute('data-tema');
    try { localStorage.setItem('bsp-site-tema', e ? 'escuro' : 'claro'); } catch (x) {}
    rotular();
  });
})();

/* Menu do telemóvel. */
(function () {
  var b = document.querySelector('.abrir-menu'), menu = document.getElementById('menu');
  if (!b || !menu) return;
  b.addEventListener('click', function () {
    var aberto = menu.classList.toggle('aberto');
    b.setAttribute('aria-expanded', aberto ? 'true' : 'false');
    b.textContent = aberto ? 'Fechar' : 'Menu';
  });
  menu.addEventListener('click', function (e) {
    if (e.target.tagName === 'A') { menu.classList.remove('aberto'); b.setAttribute('aria-expanded', 'false'); b.textContent = 'Menu'; }
  });
})();

/* Página activa no menu. */
(function () {
  var aqui = (location.pathname.split('/').pop() || 'index.html').toLowerCase();
  document.querySelectorAll('#menu a').forEach(function (a) {
    if ((a.getAttribute('href') || '').toLowerCase() === aqui) a.setAttribute('aria-current', 'page');
  });
})();

/* Carrossel dos cartões no telemóvel: setas e pontos. No computador os
   cartões ficam em grelha e as setas escondem-se (CSS). */
(function () {
  document.querySelectorAll('[data-carrossel]').forEach(function (lista) {
    var setas = lista.parentNode.querySelector('.carrossel-setas');
    if (!setas) return;
    var ant = setas.querySelector('[data-ant]'), seg = setas.querySelector('[data-seg]'), pontos = setas.querySelector('.carrossel-pontos');
    var itens = Array.prototype.slice.call(lista.children);
    itens.forEach(function () { pontos.appendChild(document.createElement('span')); });
    var actual = function () {
      var x = lista.scrollLeft, melhor = 0, dist = Infinity;
      itens.forEach(function (it, i) { var d = Math.abs(it.offsetLeft - lista.offsetLeft - x - 24); if (d < dist) { dist = d; melhor = i; } });
      return melhor;
    };
    var pintar = function () {
      var i = actual();
      Array.prototype.forEach.call(pontos.children, function (p, k) { p.className = k === i ? 'activo' : ''; });
      ant.disabled = lista.scrollLeft < 8;
      seg.disabled = lista.scrollLeft + lista.clientWidth >= lista.scrollWidth - 8;
    };
    var ir = function (i) {
      i = Math.max(0, Math.min(itens.length - 1, i));
      lista.scrollTo({ left: itens[i].offsetLeft - lista.offsetLeft - 24, behavior: 'smooth' });
    };
    ant.addEventListener('click', function () { ir(actual() - 1); });
    seg.addEventListener('click', function () { ir(actual() + 1); });
    lista.addEventListener('scroll', function () { window.requestAnimationFrame(pintar); }, { passive: true });
    window.addEventListener('resize', pintar);
    pintar();
  });
})();

/* Logotipos das seguradoras: sem ficheiro, ficam as iniciais. */
(function () {
  document.querySelectorAll('.seguro-logo img').forEach(function (img) {
    var falhou = function () { img.parentNode.classList.add('sem-logo'); };
    if (img.complete && !img.naturalWidth) falhou(); else img.addEventListener('error', falhou);
  });
})();

/* Separadores da página: marca a parte que está à vista. */
(function () {
  var nav = document.querySelector('.separadores');
  if (!nav || !('IntersectionObserver' in window)) return;
  var ligacoes = Array.prototype.slice.call(nav.querySelectorAll('a'));
  var marcar = function (id) {
    ligacoes.forEach(function (a) { if (a.getAttribute('href') === '#' + id) a.setAttribute('aria-current', 'true'); else a.removeAttribute('aria-current'); });
  };
  var obs = new IntersectionObserver(function (es) {
    es.forEach(function (e) { if (e.isIntersecting) marcar(e.target.id); });
  }, { rootMargin: '-45% 0px -50% 0px' });
  ligacoes.forEach(function (a) { var alvo = document.getElementById(a.getAttribute('href').slice(1)); if (alvo) obs.observe(alvo); });
})();
