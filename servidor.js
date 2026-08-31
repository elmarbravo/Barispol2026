/* Ligação ao servidor, definida UMA vez para toda a gente.
 *
 * Preencha os dois campos abaixo com os dados do vosso projecto Supabase,
 * guarde, e envie para o GitHub. A partir daí qualquer telemóvel ou
 * computador que abra o barispol.com entra já ligado: ninguém tem de
 * escrever endereços nem chaves.
 *
 * Onde encontrar: no Supabase, Project Settings -> API.
 *   url  = Project URL          (https://xxxxxxxx.supabase.co)
 *   key  = anon public          (começa por eyJ)
 *
 * A chave anon public PODE ficar aqui à vista. É assim que todas as
 * aplicações Supabase funcionam: ela não dá acesso a nada por si só, só
 * permite falar com o servidor. Quem decide o que cada pessoa vê são as
 * regras de segurança da base de dados, e essas exigem sessão iniciada.
 *
 * A chave service_role NUNCA entra aqui. Essa contorna todas as regras.
 */
window.BSP_SERVIDOR = {
  url: "",
  key: ""
};
