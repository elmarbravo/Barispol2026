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
 *
 * 24-09-2026: projecto "Barispol" na organização da conta
 * elmar.bravo@barispol.com (antes: ferqkmfntcockmhviscf).
 */
window.BSP_SERVIDOR = {
  url: "https://gnqleaxrtuerlcrriqqs.supabase.co",
  key: "sb_publishable_z60zTAYUVEbDwn4TxBIr-g_5gYXthfL"
};

/* Mudança de servidor (24-09-2026). Um aparelho pode ter guardada a
 * ligação antiga (bsp_supabase_cfg), e essa manda mais do que este
 * ficheiro. Se apontar para o projecto antigo, apaga-se aqui, antes de a
 * aplicação arrancar, e o aparelho passa para o projecto novo. A sessão
 * antiga também se apaga: a pessoa entra outra vez com o mesmo e-mail e a
 * mesma palavra-passe. */
(function () {
  try {
    var ANTIGO = "ferqkmfntcockmhviscf";
    var s = JSON.parse(localStorage.getItem("bsp_supabase_cfg") || "null");
    if (s && s.url && String(s.url).indexOf(ANTIGO) !== -1) {
      localStorage.removeItem("bsp_supabase_cfg");
    }
    for (var i = localStorage.length - 1; i >= 0; i--) {
      var k = localStorage.key(i);
      if (k && k.indexOf("sb-" + ANTIGO) === 0) localStorage.removeItem(k);
    }
  } catch (e) {}
})();
