// Barispol Workspace para computador (Windows e Mac), 14-10-2026.
//
// É só um invólucro, como a app Android (app/): a janela abre
// https://barispol.com/workspace.html e o conteúdo vem sempre do site, por
// isso a app actualiza-se sozinha com cada publicação em main.
//
// Segurança (nunca mudar sem pensar): a página não tem acesso ao sistema
// (contextIsolation, sandbox, sem nodeIntegration nem preload). A janela só
// navega no Workspace e no Supabase; qualquer outra ligação abre no
// navegador do sistema. Câmara, microfone e notificações só para barispol.com.
// A sessão segue a regra do Workspace: fica no separador (sessionStorage) e
// termina quando a app fecha.

const { app, BrowserWindow, Menu, shell, session } = require('electron');
const path = require('path');
const fs = require('fs');

const INICIO = 'https://barispol.com/workspace.html';
const PERMITIDOS = /^(barispol\.com|www\.barispol\.com|ws\.barispol\.com|[a-z0-9-]+\.supabase\.co)$/i;
const ORIGEM_APP = 'https://barispol.com';
const PERMISSOES = new Set(['media', 'notifications', 'fullscreen', 'clipboard-read', 'clipboard-sanitized-write', 'display-capture']);

let janela = null;

const hostDe = (url) => { try { return new URL(url).hostname; } catch (e) { return ''; } };
const protocoloDe = (url) => { try { return new URL(url).protocol; } catch (e) { return ''; } };
const dentro = (url) => protocoloDe(url) === 'https:' && PERMITIDOS.test(hostDe(url));
const daApp = (url) => { try { const u = new URL(url); return u.origin === ORIGEM_APP || u.origin === 'https://www.barispol.com'; } catch (e) { return false; } };

function abrirFora(url) {
  // Só ligações web e de e-mail/telefone saem para o sistema; o resto é recusado.
  if (/^(https?:|mailto:|tel:)/i.test(url)) shell.openExternal(url);
}

function semLigacao() {
  const ficheiro = path.join(__dirname, 'sem-ligacao.html');
  if (fs.existsSync(ficheiro)) return janela.loadFile(ficheiro);
  return janela.loadURL('data:text/html;charset=utf-8,' + encodeURIComponent(
    '<!doctype html><meta charset="utf-8"><body style="font-family:Segoe UI,Arial;text-align:center;padding:60px;color:#292F58">' +
    '<h1>Sem ligação à internet</h1><p>O Workspace precisa de internet.</p>' +
    '<a href="' + INICIO + '">Tentar de novo</a></body>'));
}

function criarJanela() {
  janela = new BrowserWindow({
    width: 1280,
    height: 800,
    minWidth: 900,
    minHeight: 600,
    title: 'Barispol Workspace',
    backgroundColor: '#FFFFFF',
    icon: path.join(__dirname, 'build', 'icon.png'),
    autoHideMenuBar: true,
    show: false,
    webPreferences: {
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true,
      webSecurity: true,
      spellcheck: true,
      devTools: !app.isPackaged
    }
  });

  janela.once('ready-to-show', () => janela.show());
  janela.on('page-title-updated', (e) => { e.preventDefault(); janela.setTitle('Barispol Workspace'); });

  const wc = janela.webContents;

  // Navegação: só dentro do Workspace e do Supabase; o resto vai para o navegador.
  wc.on('will-navigate', (e, url) => {
    if (url.startsWith('file:') || dentro(url)) return;
    e.preventDefault();
    abrirFora(url);
  });
  wc.on('will-redirect', (e, url) => {
    if (!dentro(url)) { e.preventDefault(); abrirFora(url); }
  });
  wc.setWindowOpenHandler(({ url }) => {
    // O Workspace abre imagens, PDF e Word nos seus próprios visores; uma
    // janela nova é quase sempre uma ligação para fora.
    abrirFora(url);
    return { action: 'deny' };
  });

  // Sem internet ou servidor em baixo: página local com «Tentar de novo».
  wc.on('did-fail-load', (e, codigo, descricao, url, principal) => {
    if (principal && codigo !== -3 && dentro(url)) semLigacao();
  });

  janela.loadURL(INICIO);
}

function permissoes() {
  const s = session.defaultSession;
  s.setPermissionRequestHandler((wc, permissao, responder, detalhes) => {
    responder(PERMISSOES.has(permissao) && daApp(detalhes.requestingUrl || wc.getURL()));
  });
  s.setPermissionCheckHandler((wc, permissao, origem) => PERMISSOES.has(permissao) && daApp(origem || ''));
}

function menu() {
  const mac = process.platform === 'darwin';
  Menu.setApplicationMenu(Menu.buildFromTemplate([
    ...(mac ? [{ label: 'Barispol', submenu: [{ role: 'about', label: 'Sobre o Barispol' }, { type: 'separator' }, { role: 'hide', label: 'Esconder' }, { role: 'quit', label: 'Sair' }] }] : []),
    { label: 'Editar', submenu: [
      { role: 'undo', label: 'Anular' }, { role: 'redo', label: 'Refazer' }, { type: 'separator' },
      { role: 'cut', label: 'Cortar' }, { role: 'copy', label: 'Copiar' }, { role: 'paste', label: 'Colar' },
      { role: 'selectAll', label: 'Seleccionar tudo' }] },
    { label: 'Ver', submenu: [
      { label: 'Início do Workspace', accelerator: 'CmdOrCtrl+Shift+H', click: () => janela && janela.loadURL(INICIO) },
      { role: 'reload', label: 'Recarregar' }, { type: 'separator' },
      { role: 'resetZoom', label: 'Tamanho normal' }, { role: 'zoomIn', label: 'Aumentar' }, { role: 'zoomOut', label: 'Diminuir' },
      { type: 'separator' }, { role: 'togglefullscreen', label: 'Ecrã inteiro' }] },
    { label: 'Janela', submenu: [{ role: 'minimize', label: 'Minimizar' }, ...(mac ? [] : [{ role: 'quit', label: 'Sair' }])] }
  ]));
}

// Uma só janela: abrir a app outra vez traz a que já está aberta.
if (!app.requestSingleInstanceLock()) {
  app.quit();
} else {
  app.on('second-instance', () => {
    if (!janela) return;
    if (janela.isMinimized()) janela.restore();
    janela.show();
    janela.focus();
  });
  app.setAppUserModelId('com.barispol.workspace'); // nome certo nas notificações do Windows
  app.whenReady().then(() => {
    permissoes();
    menu();
    criarJanela();
    app.on('activate', () => { if (BrowserWindow.getAllWindows().length === 0) criarJanela(); });
  });
  app.on('window-all-closed', () => { app.quit(); });
}
