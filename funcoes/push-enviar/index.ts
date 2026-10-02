// Barispol Workspace · notificações com o Workspace fechado (Web Push)
//
// Pedido do Elmar, 02-10-2026: «as 3 ideias implementa» (A: pedir a
// permissão logo à entrada; B: notificações reais com o Workspace fechado,
// no computador e no iPhone; C: na app Android). Esta função é a B.
//
// Envia um aviso a cada aparelho registado em push_subscricoes, pela norma
// Web Push (RFC 8030), com o conteúdo cifrado (RFC 8291, aes128gcm) e a
// identificação do servidor (VAPID, RFC 8292). Quem entrega é o serviço do
// navegador (Google, Apple, Mozilla); o conteúdo vai cifrado e só o
// aparelho o lê.
//
// As chaves VAPID nascem aqui, no servidor, na primeira chamada com
// {"gerar_chaves": true}, e ficam no cofre (bsp_vapid_publica,
// bsp_vapid_privada). A privada nunca sai do servidor e nunca entra no
// repositório. O Workspace lê só a pública (bsp_vapid_publica()).
//
// Corpo: {"para": ["u1", ...] ou "todos", "exceto": "u5", "titulo": "...",
//         "corpo": "...", "url": "#/chat/dm-u1_u5", "tag": "conv-..."}
// Aparelhos que o serviço diz que já não existem (404/410) saem da lista.
//
// SEGURANÇA: só o código do agendamento (x-bsp-agendamento, conferido pela
// base de dados) ou a chave do servidor. Os gatilhos da base de dados
// chamam-na por bsp_push_post (notificacoes-push.sql).

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const PREFIXO = /^(sb_secret_|eyJ)/;
const valoresDe = (nome: string): string[] => {
  const cru = (Deno.env.get(nome) || "").trim();
  if (!cru) return [];
  if (!cru.startsWith("{") && !cru.startsWith("[")) return PREFIXO.test(cru) ? [cru] : [];
  const rec = (v: unknown): string[] => typeof v === "string" ? [v] : Array.isArray(v) ? v.flatMap(rec)
    : v && typeof v === "object" ? [...Object.keys(v as object), ...Object.values(v as object)].flatMap(rec) : [];
  try { return rec(JSON.parse(cru)).filter((s) => PREFIXO.test(s)); } catch { return []; }
};
const chavesServidor = () => [...valoresDe("SUPABASE_SECRET_KEYS"), ...valoresDe("SUPABASE_SECRET_KEY"), ...valoresDe("SUPABASE_SERVICE_ROLE_KEY")];
const json = (o: unknown, s = 200) => new Response(JSON.stringify(o), { status: s, headers: { "Content-Type": "application/json" } });

/* ---- base64url e bytes ---- */
export const b64u = (b: Uint8Array) => {
  let s = "";
  for (let i = 0; i < b.length; i++) s += String.fromCharCode(b[i]);
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
};
export const deb64u = (s: string) => {
  const t = s.replace(/-/g, "+").replace(/_/g, "/");
  const bin = atob(t + "=".repeat((4 - (t.length % 4)) % 4));
  return Uint8Array.from(bin, (c) => c.charCodeAt(0));
};
const juntar = (...partes: (Uint8Array | number[])[]) => {
  const total = partes.reduce((a, p) => a + p.length, 0);
  const r = new Uint8Array(total);
  let i = 0;
  for (const p of partes) { r.set(p, i); i += p.length; }
  return r;
};
const txt = (s: string) => new TextEncoder().encode(s);
const hmac = async (chave: Uint8Array, dados: Uint8Array) => {
  const k = await crypto.subtle.importKey("raw", chave as BufferSource, { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  return new Uint8Array(await crypto.subtle.sign("HMAC", k, dados as BufferSource));
};

/* ---- cifra aes128gcm (RFC 8291) ---- */
export async function cifrar(conteudo: Uint8Array, p256dh: string, auth: string): Promise<Uint8Array> {
  const uaPub = deb64u(p256dh);
  const segredo = deb64u(auth);
  const par = await crypto.subtle.generateKey({ name: "ECDH", namedCurve: "P-256" }, true, ["deriveBits"]) as CryptoKeyPair;
  const asPub = new Uint8Array(await crypto.subtle.exportKey("raw", par.publicKey));
  const uaChave = await crypto.subtle.importKey("raw", uaPub as BufferSource, { name: "ECDH", namedCurve: "P-256" }, false, []);
  const ecdh = new Uint8Array(await crypto.subtle.deriveBits({ name: "ECDH", public: uaChave } as any, par.privateKey, 256));
  const prkChave = await hmac(segredo, ecdh);
  const ikm = await hmac(prkChave, juntar(txt("WebPush: info\0"), uaPub, asPub, [1]));
  const sal = crypto.getRandomValues(new Uint8Array(16));
  const prk = await hmac(sal, ikm);
  const cek = (await hmac(prk, juntar(txt("Content-Encoding: aes128gcm\0"), [1]))).slice(0, 16);
  const nonce = (await hmac(prk, juntar(txt("Content-Encoding: nonce\0"), [1]))).slice(0, 12);
  const k = await crypto.subtle.importKey("raw", cek as BufferSource, "AES-GCM", false, ["encrypt"]);
  const cifrado = new Uint8Array(await crypto.subtle.encrypt({ name: "AES-GCM", iv: nonce as BufferSource }, k, juntar(conteudo, [2]) as BufferSource));
  const cab = new Uint8Array(16 + 4 + 1 + asPub.length);
  cab.set(sal, 0);
  new DataView(cab.buffer).setUint32(16, 4096);
  cab[20] = asPub.length;
  cab.set(asPub, 21);
  return juntar(cab, cifrado);
}

/* ---- VAPID (RFC 8292): JWT ES256 assinado com a chave privada ---- */
export async function vapid(endpoint: string, privadaJwk: { x: string; y: string; d: string }, contacto: string) {
  const k = await crypto.subtle.importKey("jwk", { kty: "EC", crv: "P-256", x: privadaJwk.x, y: privadaJwk.y, d: privadaJwk.d, ext: true },
    { name: "ECDSA", namedCurve: "P-256" }, false, ["sign"]);
  const cab = b64u(txt(JSON.stringify({ typ: "JWT", alg: "ES256" })));
  const dados = b64u(txt(JSON.stringify({ aud: new URL(endpoint).origin, exp: Math.floor(Date.now() / 1000) + 12 * 3600, sub: contacto })));
  const ass = new Uint8Array(await crypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, k, txt(cab + "." + dados) as BufferSource));
  const publica = b64u(juntar([4], deb64u(privadaJwk.x), deb64u(privadaJwk.y)));
  return "vapid t=" + cab + "." + dados + "." + b64u(ass) + ", k=" + publica;
}

Deno.serve(async (req: Request) => {
  const URL_SB = Deno.env.get("SUPABASE_URL") || "";
  const SERVICO = chavesServidor()[0] || "";
  if (!URL_SB || !SERVICO) return json({ erro: "sem chaves do projecto" }, 500);
  const admin = createClient(URL_SB, SERVICO, { auth: { persistSession: false } });

  const testemunho = (req.headers.get("Authorization") || "").replace(/^Bearer\s+/i, "");
  const codigo = (req.headers.get("x-bsp-agendamento") || "").trim();
  let autorizado = !!testemunho && chavesServidor().includes(testemunho);
  if (!autorizado && codigo) {
    const { data } = await admin.rpc("bsp_resumo_codigo_confere", { codigo });
    autorizado = data === true;
  }
  if (!autorizado) return json({ erro: "sem autorizacao" }, 401);

  const corpo = await req.json().catch(() => ({} as any));

  /* Chaves VAPID: criadas uma vez, aqui, e guardadas no cofre. */
  const { data: privadaTxt } = await admin.rpc("bsp_vapid_privada");
  if (corpo && corpo.gerar_chaves) {
    if (privadaTxt) return json({ ok: true, ja_existiam: true });
    const par = await crypto.subtle.generateKey({ name: "ECDSA", namedCurve: "P-256" }, true, ["sign", "verify"]) as CryptoKeyPair;
    const jwk = await crypto.subtle.exportKey("jwk", par.privateKey) as any;
    const publica = b64u(juntar([4], deb64u(jwk.x), deb64u(jwk.y)));
    const { error } = await admin.rpc("bsp_vapid_guardar", { p_publica: publica, p_privada: JSON.stringify({ x: jwk.x, y: jwk.y, d: jwk.d }) });
    if (error) return json({ erro: error.message }, 500);
    return json({ ok: true, criadas: true });
  }
  if (!privadaTxt) return json({ erro: "sem chaves VAPID: chamar com gerar_chaves" }, 500);
  const privada = JSON.parse(String(privadaTxt));

  const para = corpo.para === "todos" ? null : (Array.isArray(corpo.para) ? corpo.para.map(String).filter(Boolean) : []);
  if (para && !para.length) return json({ ok: true, enviados: 0 });
  let q = admin.from("push_subscricoes").select("endpoint, user_id, p256dh, auth");
  if (para) q = q.in("user_id", para);
  const { data: subs, error } = await q;
  if (error) return json({ erro: error.message }, 500);
  const exceto = String(corpo.exceto || "");
  const lista = ((subs || []) as any[]).filter((s) => s.user_id !== exceto);

  const conteudo = txt(JSON.stringify({
    titulo: String(corpo.titulo || "Barispol Workspace").slice(0, 120),
    corpo: String(corpo.corpo || "").slice(0, 300),
    url: String(corpo.url || ""),
    tag: String(corpo.tag || ""),
  }));
  const res = await Promise.all(lista.map(async (s) => {
    try {
      const r = await fetch(s.endpoint, {
        method: "POST",
        headers: {
          "Authorization": await vapid(s.endpoint, privada, "mailto:geral@barispol.com"),
          "Content-Encoding": "aes128gcm",
          "Content-Type": "application/octet-stream",
          "TTL": "86400",
          "Urgency": "high",
        },
        body: (await cifrar(conteudo, s.p256dh, s.auth)) as BodyInit,
      });
      if (r.status === 404 || r.status === 410) {
        await admin.from("push_subscricoes").delete().eq("endpoint", s.endpoint);
        return { user: s.user_id, estado: r.status, removido: true };
      }
      if (r.ok) await admin.from("push_subscricoes").update({ ultimo_ok: new Date().toISOString(), falhas: 0 }).eq("endpoint", s.endpoint);
      else await admin.rpc("bsp_push_falhou", { p_endpoint: s.endpoint });
      return { user: s.user_id, estado: r.status, erro: r.ok ? undefined : (await r.text()).slice(0, 200) };
    } catch (e) {
      return { user: s.user_id, erro: String(e).slice(0, 200) };
    }
  }));
  return json({ ok: true, enviados: res.filter((x: any) => x.estado >= 200 && x.estado < 300).length, total: res.length, res });
});
