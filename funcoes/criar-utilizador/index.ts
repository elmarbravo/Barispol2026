// Barispol Workspace · criar e actualizar logins
//
// PORQUE EXISTE: o ecrã Admin → Utilizadores tem um campo de palavra-passe
// e prometia "já pode entrar com o e-mail e palavra-passe definidos". Não
// criava conta nenhuma: a palavra-passe era recolhida e deitada fora. Quem
// fosse acrescentado ficava no directório, com camada e canais definidos,
// e não conseguia entrar de todo.
//
// Criar contas exige a chave service_role, que contorna todas as regras da
// base de dados e por isso NUNCA pode estar no navegador. Vive aqui, do
// lado do servidor, onde ninguém lhe chega.
//
// COMO INSTALAR (uma vez):
//   1. No Supabase: Edge Functions → Deploy a new function
//   2. Nome exacto: criar-utilizador
//   3. Cole este ficheiro
//   4. Em Settings → Edge Functions, confirme que SUPABASE_URL e
//      SUPABASE_SERVICE_ROLE_KEY estão disponíveis (são automáticos)
//
// SEGURANÇA: a função recusa qualquer pedido que não venha de alguém que a
// própria plataforma reconheça como gestor. Não basta ter a chave anónima —
// essa toda a gente tem.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cabecalhos = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Content-Type": "application/json",
};

const responder = (corpo: unknown, estado = 200) =>
  new Response(JSON.stringify(corpo), { status: estado, headers: cabecalhos });

/* Onde estao as chaves do projecto.

   O Supabase injecta SUPABASE_SECRET_KEYS e SUPABASE_PUBLISHABLE_KEYS —
   no plural, e com um dicionario JSON la dentro. As antigas
   SUPABASE_SERVICE_ROLE_KEY e SUPABASE_ANON_KEY ainda existem, marcadas
   como obsoletas, e desaparecem no dia em que se desligarem as chaves
   JWT. O singular SUPABASE_SECRET_KEY nunca existiu: quem procurasse so
   por ele tinha uma funcao que parecia instalada hoje e devolvia 500
   amanha.

   Le-se tudo, pela mesma razao por que se aceita um e-mail antigo e um
   novo durante uma mudanca: para nada parar no intervalo. */
const PREFIXO_DE_CHAVE = /^(sb_secret_|sb_publishable_|eyJ)/;

const valoresDe = (nome: string): string[] => {
  const cru = (Deno.env.get(nome) || "").trim();
  if (!cru) return [];
  if (!cru.startsWith("{") && !cru.startsWith("[")) {
    return PREFIXO_DE_CHAVE.test(cru) ? [cru] : [];
  }
  /* Le chaves e valores: nao esta escrito em lado nenhum se a chave em si
     e a etiqueta do dicionario ou o valor guardado nela. */
  const recolher = (v: unknown): string[] =>
    typeof v === "string"
      ? [v]
      : Array.isArray(v)
        ? v.flatMap(recolher)
        : v && typeof v === "object"
          ? [...Object.keys(v as object), ...Object.values(v as object)].flatMap(recolher)
          : [];
  try {
    return recolher(JSON.parse(cru)).filter((s) => PREFIXO_DE_CHAVE.test(s));
  } catch {
    return [];
  }
};

const chavesServidor = (): string[] => [
  ...valoresDe("SUPABASE_SECRET_KEYS"),
  ...valoresDe("SUPABASE_SECRET_KEY"),
  ...valoresDe("SUPABASE_SERVICE_ROLE_KEY"),
];
const chavesPublicas = (): string[] => [
  ...valoresDe("SUPABASE_PUBLISHABLE_KEYS"),
  ...valoresDe("SUPABASE_PUBLISHABLE_KEY"),
  ...valoresDe("SUPABASE_ANON_KEY"),
];

const chaveServidor = () => chavesServidor()[0] || "";
const chavePublica = () => chavesPublicas()[0] || "";
/* Quem se apresenta com uma chave de servidor — a nova ou a antiga —
   e o proprio servidor. */
const ehChaveDoServidor = (t: string) => !!t && chavesServidor().includes(t);
const ehChavePublica = (t: string) => !!t && chavesPublicas().includes(t);

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cabecalhos });
  if (req.method !== "POST") return responder({ erro: "Método não permitido." }, 405);

  const URL_SB = Deno.env.get("SUPABASE_URL")!;
  const SERVICE = chaveServidor();
  const ANON = chavePublica();
  if (!SERVICE || !ANON) {
    return responder({ erro: "A função não tem as chaves do projecto." }, 500);
  }

  // 1. Quem está a pedir? O testemunho vem do navegador de quem clicou.
  const auth = req.headers.get("Authorization") || "";
  const testemunho = auth.replace(/^Bearer\s+/i, "");
  if (!testemunho) return responder({ erro: "Sem sessão." }, 401);

  const comoUtilizador = createClient(URL_SB, ANON, {
    global: { headers: { Authorization: `Bearer ${testemunho}` } },
  });
  const { data: sessao, error: erroSessao } = await comoUtilizador.auth.getUser();
  const emailPedinte = sessao?.user?.email?.toLowerCase();
  if (erroSessao || !emailPedinte) return responder({ erro: "Sessão inválida." }, 401);

  const admin = createClient(URL_SB, SERVICE);

  // 2. É gestor? A resposta está nas camadas gravadas, tal como a aplicação
  //    as vê — não numa lista de nomes escrita aqui, que ficaria desalinhada
  //    assim que alguém criasse ou renomeasse uma camada.
  const { data: estado } = await admin
    .from("shared_state").select("team, camadas").eq("id", 1).maybeSingle();

  const equipa = (estado?.team ?? []) as Array<Record<string, unknown>>;
  const camadas = (estado?.camadas ?? {}) as Record<string, Record<string, unknown>>;
  const pedinte = equipa.find(
    (p) => String(p.email ?? "").toLowerCase() === emailPedinte,
  );
  const nivel = String(pedinte?.accessLevel ?? "");
  const eGestor = camadas[nivel]
    ? camadas[nivel].podeGerirUtilizadores === true
    : nivel === "Direcção" || nivel === "Coordenação"; // instalação ainda sem camadas gravadas

  if (!eGestor) {
    return responder({ erro: "Só quem pode gerir utilizadores cria contas." }, 403);
  }

  // 3. Fazer o trabalho.
  let corpo: { email?: string; password?: string; apagar?: boolean };
  try {
    corpo = await req.json();
  } catch {
    return responder({ erro: "Pedido mal formado." }, 400);
  }

  const email = String(corpo.email ?? "").trim().toLowerCase();
  const password = String(corpo.password ?? "");
  if (!email || !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) {
    return responder({ erro: "E-mail inválido." }, 400);
  }

  // Já existe? Nesse caso muda-se a palavra-passe em vez de rebentar.
  const { data: lista } = await admin.auth.admin.listUsers({ page: 1, perPage: 1000 });
  const existente = lista?.users?.find(
    (u) => (u.email ?? "").toLowerCase() === email,
  );

  if (corpo.apagar) {
    if (!existente) return responder({ ok: true, nota: "Não havia conta para apagar." });
    if (email === emailPedinte) {
      return responder({ erro: "Não pode apagar a sua própria conta." }, 400);
    }
    const { error } = await admin.auth.admin.deleteUser(existente.id);
    if (error) return responder({ erro: error.message }, 400);
    return responder({ ok: true, accao: "apagada" });
  }

  if (password && password.length < 8) {
    return responder({ erro: "A palavra-passe deve ter pelo menos 8 caracteres." }, 400);
  }

  if (existente) {
    if (!password) return responder({ ok: true, accao: "ja-existia" });
    const { error } = await admin.auth.admin.updateUserById(existente.id, { password });
    if (error) return responder({ erro: error.message }, 400);
    return responder({ ok: true, accao: "senha-alterada" });
  }

  if (!password) {
    return responder({ erro: "Defina uma palavra-passe para criar a conta." }, 400);
  }

  const { error } = await admin.auth.admin.createUser({
    email,
    password,
    email_confirm: true, // sem isto a pessoa fica à espera de um e-mail de confirmação
  });
  if (error) return responder({ erro: error.message }, 400);
  return responder({ ok: true, accao: "criada" });
});
