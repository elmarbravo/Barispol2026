/* Copia os ficheiros do sítio para dentro da app.
   O workspace.html continua a ser a fonte única: edita-se na raiz do
   repositório, corre-se `npm run sincronizar`, e a app leva a versão nova.
   Nada aqui duplica código — só o transporta. */
const fs = require('fs');
const path = require('path');

const RAIZ = path.resolve(__dirname, '..');
const DESTINO = path.join(__dirname, 'www');

/* O que entra na app: a página da equipa e as bibliotecas que carrega.
   Verificado: o workspace.html não referencia nenhuma imagem local — as
   pastas assets/, images/ e media/ pertencem ao sítio público e ficam de
   fora, senão a app levava 4 MB de fotografias que nunca mostra. */
const FICHEIROS = ['workspace.html'];
/* O servidor.js leva a ligacao comum; sem ele a app pedia-a outra vez. */
const SOLTOS = ['servidor.js'];
const PASTAS = ['vendor'];

function limpar(dir) {
  if (fs.existsSync(dir)) fs.rmSync(dir, { recursive: true, force: true });
  fs.mkdirSync(dir, { recursive: true });
}

function copiarPasta(de, para) {
  if (!fs.existsSync(de)) return 0;
  fs.mkdirSync(para, { recursive: true });
  let n = 0;
  for (const nome of fs.readdirSync(de)) {
    const a = path.join(de, nome), b = path.join(para, nome);
    if (fs.statSync(a).isDirectory()) n += copiarPasta(a, b);
    else { fs.copyFileSync(a, b); n++; }
  }
  return n;
}

limpar(DESTINO);
let total = 0;
/* O Capacitor arranca no index.html, por isso o workspace entra já com
   esse nome — copiar os dois seria carregar 468 KB repetidos. */
for (const f of FICHEIROS) {
  const de = path.join(RAIZ, f);
  if (!fs.existsSync(de)) { console.error('EM FALTA: ' + f); process.exit(1); }
  fs.copyFileSync(de, path.join(DESTINO, 'index.html'));
  total++;
}
for (const p of PASTAS) total += copiarPasta(path.join(RAIZ, p), path.join(DESTINO, p));
for (const f of SOLTOS) {
  const de = path.join(RAIZ, f);
  if (fs.existsSync(de)) { fs.copyFileSync(de, path.join(DESTINO, f)); total++; }
}

/* Numa app instalada nao faz sentido pedir ao utilizador o endereco e a
   chave do servidor: isso e configuracao de quem monta, nao de quem usa.
   Se o servidor.json estiver preenchido, semeamos a ligacao antes de a
   aplicacao arrancar — sem sobrepor uma que ja exista no aparelho. */
const cfg = JSON.parse(fs.readFileSync(path.join(__dirname, 'servidor.json'), 'utf8'));
if (cfg.url && cfg.key) {
  if (!/^https:\/\/.+\.supabase\.co$/.test(cfg.url.trim().replace(/\/+$/, ''))) {
    console.error('servidor.json: o url deve ser https://xxxx.supabase.co, sem barra no fim.');
    process.exit(1);
  }
  if (cfg.key.trim().indexOf('eyJ') !== 0) {
    console.error('servidor.json: a chave deve ser a anon public, que comeca por eyJ. Nao use a service_role.');
    process.exit(1);
  }
  const semente = '<script>(function(){try{if(!localStorage.getItem("bsp_supabase_cfg"))' +
    'localStorage.setItem("bsp_supabase_cfg",' + JSON.stringify(JSON.stringify({
      url: cfg.url.trim().replace(/\/+$/, ''),
      key: cfg.key.trim()
    })) + ');}catch(e){}})();</script>';
  const alvo = path.join(DESTINO, 'index.html');
  let html = fs.readFileSync(alvo, 'utf8');
  html = html.replace('<script src="vendor/supabase.js"></script>', semente + '\n<script src="vendor/supabase.js"></script>');
  fs.writeFileSync(alvo, html);
  console.log('ligacao ao servidor semeada a partir do servidor.json');
} else {
  console.log('servidor.json vazio — a app vai pedir a ligacao no primeiro arranque');
}

console.log(total + ' ficheiros copiados para www/');
