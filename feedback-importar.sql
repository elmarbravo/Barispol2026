-- Respostas do inquérito pós-consulta que chegam por e-mail (03-10-2026,
-- Elmar: «Tens inquéritos também no meu drive, lá recebe todos dias quando
-- pacientes respondem»).
--
-- O inquérito sai por um WhatsApp que o servidor não copia; as respostas
-- chegam todos os dias por e-mail de info@barispol.ao («Respostas dos
-- pacientes no WhatsApp — DD-MM-AAAA», à Recepção com a Direcção em cópia).
-- Uma tarefa diária (Routine na nuvem) lê esse e-mail, arruma cada resposta
-- e chama bsp_feedback_importar com uma lista JSON:
--   [{ "chave": "email:2026-10-02:1", "consulta": "2026-09-26", "recebido": "2026-10-02",
--      "nota": 5, "tipo": "avaliacao", "area": "", "comentario": "…", "contacto": "244…" }]
-- O comentário nunca leva o nome do utente. «chave» evita repetidos.
-- bsp.sem_aviso = '1' grava sem avisos (para o histórico já tratado).
-- Só o servidor chama esta função (sem permissão para quem entra).

create or replace function public.bsp_feedback_importar(p jsonb)
returns int language plpgsql security definer set search_path to 'public'
as $f$
declare n int;
begin
  insert into public.feedback_utentes (origem, tipo, nota, area, dia_atendimento, comentario, contacto, quer_resposta,
                                       estado, prazo, whatsapp_msg, criado_por, criado_em)
  select coalesce(nullif(x->>'origem', ''), 'whatsapp'),
         case when x->>'tipo' in ('avaliacao', 'elogio', 'reclamacao', 'sugestao') then x->>'tipo' else 'avaliacao' end,
         case when (x->>'nota') ~ '^[1-5]$' then (x->>'nota')::int end,
         coalesce(x->>'area', ''), nullif(x->>'consulta', '')::date, left(coalesce(x->>'comentario', ''), 2000),
         left(coalesce(x->>'contacto', ''), 120), coalesce((x->>'quer_resposta')::boolean, false),
         case when x->>'estado' in ('Nova', 'Em tratamento', 'Respondida', 'Fechada') then x->>'estado' else 'Nova' end,
         case when x->>'tipo' = 'reclamacao' then coalesce(nullif(x->>'recebido', '')::date, current_date) + 15 end,
         x->>'chave', null, coalesce(nullif(x->>'recebido', '')::date::timestamptz + interval '17 hours', now())
    from jsonb_array_elements(p) x
   where coalesce(x->>'chave', '') <> ''
  on conflict (whatsapp_msg) do nothing;
  get diagnostics n = row_count;
  return n;
end $f$;
revoke execute on function public.bsp_feedback_importar(jsonb) from public, anon, authenticated;

-- Os avisos de qualidade respeitam bsp.sem_aviso (importação do histórico).
-- (bsp_qualidade_aviso: primeira linha «if current_setting('bsp.sem_aviso',
-- true) = '1' then return null; end if;», aplicada no servidor.)
