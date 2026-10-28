/* Barispol Workspace · service worker das notificações (02-10-2026)
 *
 * Recebe os avisos enviados pela Edge Function push-enviar (Web Push) e
 * mostra-os mesmo com o Workspace fechado. Ao tocar no aviso, abre o
 * Workspace no sítio certo (conversa, Feed, tarefas, agenda, documentos),
 * ou leva o separador já aberto até lá.
 *
 * Sem internet (26-10-2026, Elmar: «Preciso que funcione sem rede»): guarda
 * só a casca do Workspace (a página e os ficheiros do programa: servidor.js,
 * vendor/, assets/, fontes), nunca dados. Primeiro a rede; a cópia só serve
 * quando não há ligação. Os pedidos ao Supabase (outro domínio) não passam
 * por aqui.
 */
const CASCA = 'bsp-casca-v1';
const CASCA_FICHEIROS = ['workspace.html', 'servidor.js', 'workspace.webmanifest', 'assets/logo-barispol.png',
  'vendor/react.production.min.js', 'vendor/react-dom.production.min.js', 'vendor/supabase.js'];
self.addEventListener('install', e => {
  self.skipWaiting();
  e.waitUntil(caches.open(CASCA).then(c => Promise.all(CASCA_FICHEIROS.map(f => c.add(self.registration.scope + f).catch(() => {})))));
});
self.addEventListener('activate', e => e.waitUntil((async () => {
  for (const k of await caches.keys()) if (k.indexOf('bsp-casca-') === 0 && k !== CASCA) await caches.delete(k);
  await self.clients.claim();
})()));

function guardavel(url) {
  if (url.origin !== self.location.origin) return false;
  const p = url.pathname.slice(new URL(self.registration.scope).pathname.length);
  return p === '' || p === 'workspace.html' || p === 'servidor.js' || p === 'workspace.webmanifest' ||
    /^(vendor|assets|fonts|guia)\//.test(p) || /\.(woff2?|ttf|css)$/.test(p);
}
self.addEventListener('fetch', e => {
  const r = e.request;
  if (r.method !== 'GET') return;
  let url;
  try { url = new URL(r.url); } catch (x) { return; }
  if (!guardavel(url)) return;
  e.respondWith((async () => {
    try {
      const resp = await fetch(r);
      if (resp && resp.ok && resp.type === 'basic') {
        const copia = resp.clone();
        caches.open(CASCA).then(c => c.put(url.origin + url.pathname, copia)).catch(() => {});
      }
      return resp;
    } catch (x) {
      const c = await caches.match(url.origin + url.pathname);
      if (c) return c;
      throw x;
    }
  })());
});

const BASE = self.registration.scope + 'workspace.html';
const ICONE = self.registration.scope + 'assets/logo-barispol.png';
/* O Safari retira a permissão a quem recebe avisos sem os mostrar. Os
   outros navegadores aceitam que se cale quando o Workspace está à frente. */
const SAFARI = /Safari/.test(self.navigator.userAgent) && !/Chrome|Chromium|Edg|Android/.test(self.navigator.userAgent);

self.addEventListener('push', e => {
  let d = {};
  try { d = e.data ? e.data.json() : {}; } catch (x) { d = { corpo: e.data ? e.data.text() : '' }; }
  e.waitUntil((async () => {
    const janelas = await self.clients.matchAll({ type: 'window', includeUncontrolled: true });
    const aFrente = janelas.some(c => c.visibilityState === 'visible' && c.focused && c.url.indexOf('workspace.html') !== -1);
    /* Mensagem nova: ponto no ícone da app (o número certo põe-o o
       Workspace quando abre). 04-10-2026. */
    if (/^(conv|mencao)-/.test(d.tag || '')) { try { if (self.navigator.setAppBadge) await self.navigator.setAppBadge(); } catch (x) {} }
    if (aFrente && !SAFARI) return;
    await self.registration.showNotification(d.titulo || 'Barispol Workspace', {
      body: d.corpo || '',
      icon: ICONE,
      badge: ICONE,
      tag: d.tag || undefined,
      renotify: !!d.tag,
      data: { url: d.url || '' }
    });
  })());
});

self.addEventListener('notificationclick', e => {
  e.notification.close();
  const destino = (e.notification.data && e.notification.data.url) || '';
  e.waitUntil((async () => {
    const janelas = await self.clients.matchAll({ type: 'window', includeUncontrolled: true });
    const ws = janelas.find(c => c.url.indexOf('workspace.html') !== -1);
    if (ws) {
      try { await ws.focus(); } catch (x) {}
      ws.postMessage({ tipo: 'bsp-abrir', url: destino });
      return;
    }
    await self.clients.openWindow(BASE + destino);
  })());
});

/* O navegador pode trocar a subscrição sozinho; o Workspace volta a
   registá-la na próxima vez que abrir (bspPushActivar). */
self.addEventListener('pushsubscriptionchange', () => {});
