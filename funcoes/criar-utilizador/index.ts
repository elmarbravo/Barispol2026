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

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cabecalhos });
  if (req.method !== "POST") return responder({ erro: "Método não permitido." }, 405);

  const URL_SB = Deno.env.get("SUPABASE_URL")!;
  const SERVICE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const ANON = Deno.env.get("SUPABASE_ANON_KEY")!;

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
