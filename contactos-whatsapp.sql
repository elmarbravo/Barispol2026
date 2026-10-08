-- Contactos do WhatsApp na base de utentes (08-10-2026, Elmar: «importar todos
-- os dias os que contactam pelo SendPulse, mesmo os que não chegam até ao
-- centro, para o CRM base de dados»). Corre-se depois de crm-seguimento.sql e
-- segmentos.sql. Sem «drop».
--
-- Fonte: crm.caixa (conversas da SendPulse, já sem os números de
-- crm.contactos_excluidos), que se actualiza de 15 em 15 min. Uma vez por dia:
--   · quem já é utente (mesmo telemóvel) fica com o primeiro e o último
--     contacto, o último pedido e o número de conversas;
--   · quem nunca veio entra em utentes com origem «whatsapp» e chave
--     «wa:<9 dígitos>» (sem ultima_visita, por isso fora de «Não voltam»);
--   · quando esse telemóvel aparece no MetaGest, o contacto fica «convertido».
-- crm.actualizar_utentes (MetaGest) só acrescenta e actualiza pela chave:
-- nunca apaga estes contactos. Nomes nunca no repositório.

alter table public.utentes add column if not exists origem text not null default 'metagest';
alter table public.utentes add column if not exists primeiro_contacto timestamptz;
alter table public.utentes add column if not exists ultimo_contacto timestamptz;
alter table public.utentes add column if not exists pedido text;
alter table public.utentes add column if not exists conversas int;
alter table public.utentes add column if not exists convertido_em date;
create index if not exists utentes_origem_idx on public.utentes (origem);

create or replace function crm.actualizar_contactos_whatsapp()
returns jsonb language plpgsql security definer set search_path to 'public'
as $f$
declare n_pac int; n_novos int; n_conv int;
begin
  create temporary table if not exists _wa (tel9 text primary key, pri timestamptz, ult timestamptz, n int, nome text, servico text, telefone text) on commit delete rows;
  insert into _wa
  select c.tel9, min(c.inicio), max(c.inicio), count(*),
         (array_agg(btrim(c.nome_whatsapp) order by c.inicio desc) filter (where coalesce(btrim(c.nome_whatsapp), '') not in ('', '.')))[1],
         (array_agg(c.servico order by c.inicio desc) filter (where coalesce(c.servico, '') not in ('', 'Não identificado')))[1],
         (array_agg(c.telefone order by c.inicio desc))[1]
    from crm.caixa c where c.tel9 ~ '^\d{9}$'
   group by c.tel9;

  -- Utentes do MetaGest com o mesmo telemóvel.
  update public.utentes u set primeiro_contacto = w.pri, ultimo_contacto = w.ult, pedido = w.servico, conversas = w.n
    from _wa w
   where u.origem = 'metagest' and right(regexp_replace(coalesce(u.telefone, ''), '\D', '', 'g'), 9) = w.tel9
     and (u.ultimo_contacto is distinct from w.ult or u.conversas is distinct from w.n);
  get diagnostics n_pac = row_count;

  -- Quem nunca veio: contacto novo (ou actualizado).
  insert into public.utentes as u (chave, nome, telefone, origem, primeiro_contacto, ultimo_contacto, pedido, conversas, visitas, criado_em, actualizado_em)
  select 'wa:' || w.tel9, coalesce(w.nome, 'WhatsApp ' || w.tel9), coalesce(w.telefone, w.tel9), 'whatsapp', w.pri, w.ult, w.servico, w.n, 0, w.pri, now()
    from _wa w
   where not exists (select 1 from public.utentes p where p.origem = 'metagest'
                       and right(regexp_replace(coalesce(p.telefone, ''), '\D', '', 'g'), 9) = w.tel9)
  on conflict (chave) do update set nome = excluded.nome, telefone = excluded.telefone, ultimo_contacto = excluded.ultimo_contacto,
     pedido = coalesce(excluded.pedido, u.pedido), conversas = excluded.conversas, actualizado_em = now()
   where u.ultimo_contacto is distinct from excluded.ultimo_contacto or u.conversas is distinct from excluded.conversas;
  get diagnostics n_novos = row_count;

  -- Contactos que entretanto vieram (o telemóvel está num utente do MetaGest).
  update public.utentes l set convertido_em = (now() at time zone 'Africa/Luanda')::date, actualizado_em = now()
   where l.origem = 'whatsapp' and l.convertido_em is null
     and exists (select 1 from public.utentes p where p.origem = 'metagest'
                   and right(regexp_replace(coalesce(p.telefone, ''), '\D', '', 'g'), 9) = substr(l.chave, 4));
  get diagnostics n_conv = row_count;

  return jsonb_build_object('utentes_com_contacto', n_pac, 'contactos', n_novos, 'convertidos', n_conv);
end $f$;
revoke all on function crm.actualizar_contactos_whatsapp() from public, anon, authenticated;

-- 05h30 de Luanda, depois da cópia do MetaGest (crm-metagest-diario, 05h00).
select cron.schedule('crm-contactos-whatsapp', '30 4 * * *', 'set statement_timeout to ''5min''; select crm.actualizar_contactos_whatsapp();');

-- Aplicado a 08-10-2026: 2752 contactos novos, 514 utentes com os dados do
-- WhatsApp; a segunda corrida mudou 1 (idempotente). «Não identificado» (serviço
-- que a SendPulse não percebeu) não conta como pedido:
update public.utentes set pedido = null where pedido = 'Não identificado';
