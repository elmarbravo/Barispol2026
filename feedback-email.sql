-- Importação automática do e-mail diário do inquérito (03-10-2026, Elmar:
-- «Use o zapier ou resend»).
--
-- O Zapier vê chegar à caixa do Elmar o e-mail «Respostas dos pacientes no
-- WhatsApp — DD-MM-AAAA» (info@barispol.ao) e chama, pelo endereço público
-- /rest/v1/rpc/bsp_feedback_email, esta função com o assunto, o texto e o
-- código guardado no cofre (bsp_feedback_codigo). O código nunca entra no
-- repositório. Sem o código certo, nada se grava.
--
-- O texto fica em feedback_email_entrada (só no servidor; ninguém o lê pela
-- aplicação). Cada linha da secção «INQUÉRITO PÓS-CONSULTA» vira uma
-- resposta em feedback_utentes por bsp_feedback_importar, sem o nome:
--   «N. Nome (telefone), consulta a DD-MM: nota X. "comentário"»
--   «N. Nome (telefone), consulta a DD-MM: sem nota. Diz que …»
-- Linhas sem nota nem «sem nota» (chamadas, respostas automáticas) não
-- entram. Nota 1–2 = reclamação (prazo de resposta); 4–5 fecham sozinhas;
-- o resto fica «Nova» para a Recepção tratar. A chave «email:AAAA-MM-DD:N»
-- é a mesma da importação manual: um e-mail repetido não duplica nada.

create table if not exists public.feedback_email_entrada (
  id bigint generated always as identity primary key,
  assunto text not null default '',
  texto text not null,
  dia date,
  importadas int not null default 0,
  erro text,
  recebido_em timestamptz not null default now()
);
alter table public.feedback_email_entrada enable row level security;
-- Sem regras: só as funções do servidor lhe tocam.

create or replace function public.bsp_feedback_do_texto(p_texto text, p_dia date)
returns jsonb language plpgsql immutable set search_path to 'public'
as $f$
declare
  linhas text[] := regexp_split_to_array(replace(coalesce(p_texto, ''), E'\r', ''), E'\n');
  l text; m text[]; resto text; nota int; dentro boolean := false; out jsonb := '[]'; consulta date;
  coment text;
begin
  foreach l in array linhas loop
    l := btrim(l);
    if l ~* '^INQU[ÉE]RITO P[ÓO]S-CONSULTA' then dentro := true; continue; end if;
    -- Outra secção (título em maiúsculas) fecha a do inquérito.
    if dentro and l <> '' and l = upper(l) and l ~ '^[A-ZÁÉÍÓÚÂÊÔÃÕÇ ]{4,}' then dentro := false; end if;
    if not dentro then continue; end if;
    m := regexp_match(l, '^(\d+)\.\s+.+?\(([^)]*)\),\s*consulta a (\d{1,2})-(\d{1,2}):\s*(.*)$');
    if m is null then continue; end if;
    resto := m[5];
    nota := null;
    if resto ~* '^nota [1-5]' then
      nota := substring(resto from '^[Nn]ota ([1-5])')::int;
      resto := regexp_replace(resto, '^[Nn]ota [1-5]\s*(\([^)]*\))?\s*[.,:;]?\s*', '');
    elsif resto ~* '^sem nota' then
      resto := regexp_replace(resto, '^[Ss]em nota\s*[.,:;]?\s*', '');
    else
      continue;
    end if;
    begin
      consulta := make_date(extract(year from p_dia)::int, m[4]::int, m[3]::int);
      if consulta > p_dia then consulta := consulta - interval '1 year'; end if;
    exception when others then consulta := null;
    end;
    coment := btrim(regexp_replace(resto, '"([^"]*)"', '«\1»', 'g'));
    coment := regexp_replace(coment, '^sem explicação\.?$', 'Sem explicação.', 'i');
    if coment = '' then coment := case when nota is not null then 'Nota ' || nota || ', sem comentário.' else 'Sem nota nem comentário.' end; end if;
    if nota is not null and coment = 'Sem explicação.' then coment := 'Nota ' || nota || ', sem explicação.'; end if;
    out := out || jsonb_build_object(
      'chave', 'email:' || p_dia || ':' || m[1],
      'recebido', p_dia::text,
      'consulta', consulta::text,
      'nota', nota,
      'tipo', case when nota <= 2 then 'reclamacao' else 'avaliacao' end,
      'comentario', coment,
      'contacto', btrim(m[2]),
      'estado', case when nota >= 4 then 'Fechada' else 'Nova' end,
      'quer_resposta', coalesce(nota <= 2, false));
  end loop;
  return out;
end $f$;

create or replace function public.bsp_feedback_email(p_codigo text, p_assunto text, p_texto text)
returns int language plpgsql security definer set search_path to 'public'
as $f$
declare dia date; lista jsonb; n int := 0; eid bigint; m text[];
begin
  if coalesce(p_codigo, '') = '' or p_codigo is distinct from
     (select decrypted_secret from vault.decrypted_secrets where name = 'bsp_feedback_codigo' limit 1) then
    raise exception 'Código inválido.';
  end if;
  if coalesce(p_assunto, '') !~* '^(re: |fw: |enc: )?respostas dos pacientes no whatsapp' then
    raise exception 'Assunto inesperado.';
  end if;
  if length(coalesce(p_texto, '')) > 200000 then raise exception 'Texto longo demais.'; end if;
  m := regexp_match(p_assunto || ' ' || p_texto, '(\d{2})-(\d{2})-(\d{4})');
  dia := case when m is not null then make_date(m[3]::int, m[2]::int, m[1]::int) else current_date end;
  insert into public.feedback_email_entrada (assunto, texto, dia) values (left(p_assunto, 300), p_texto, dia) returning id into eid;
  begin
    lista := public.bsp_feedback_do_texto(p_texto, dia);
    n := public.bsp_feedback_importar(lista);
    update public.feedback_email_entrada set importadas = n where id = eid;
  exception when others then
    update public.feedback_email_entrada set erro = sqlerrm where id = eid;
  end;
  return n;
end $f$;

do $$ begin
  revoke execute on function public.bsp_feedback_do_texto(text, date) from public, anon, authenticated;
  revoke execute on function public.bsp_feedback_email(text, text, text) from public, authenticated;
  -- O Zapier chama com a chave publicável: a protecção é o código do cofre.
  grant execute on function public.bsp_feedback_email(text, text, text) to anon;
end $$;

-- Código no cofre (uma vez, no servidor; nunca no repositório):
--   select vault.create_secret(encode(gen_random_bytes(24), 'hex'), 'bsp_feedback_codigo');
