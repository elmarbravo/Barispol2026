/* Barispol Workspace · service worker das notificações (02-10-2026)
 *
 * Recebe os avisos enviados pela Edge Function push-enviar (Web Push) e
 * mostra-os mesmo com o Workspace fechado. Ao tocar no aviso, abre o
 * Workspace no sítio certo (conversa, Feed, tarefas, agenda, documentos),
 * ou leva o separador já aberto até lá.
 *
 * Não guarda nada em cache: o Workspace continua a vir sempre do site.
 */
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', e => e.waitUntil(self.clients.claim()));

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
