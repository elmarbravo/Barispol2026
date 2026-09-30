-- E-mails automáticos para toda a equipa, e não só para @barispol.com
-- (decisão do Elmar, 30-09-2026: «Podes quebrar a regra de comunicar fora
-- da barispol.com, vou inserir agora os médicos todos»). Os médicos usam
-- endereços pessoais (Gmail, Hotmail).
--
-- Recebe quem está em shared_state.team com um e-mail válido, não é sócio
-- e não tem a marca semEmails (a conta de teste «Beb», beb@beb.com, que é
-- um domínio real de fora). A mesma regra está na resumo-matinal
-- (daClinica, versão 10).

create or replace function public.bsp_recebe_emails(e jsonb)
returns boolean
language sql
immutable
as $function$
  select coalesce(e->>'email', '') ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$'
     and coalesce((e->>'semEmails')::boolean, false) = false
$function$;

create or replace function public.bsp_novidades_reclamar()
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare novas jsonb;
begin
  with r as (
    update public.novidades set enviado_em = now()
     where enviado_em is null
    returning id, titulo, texto, grupos, destino, criado_em
  )
  select coalesce(jsonb_agg(to_jsonb(r) order by r.id), '[]'::jsonb) into novas from r;
  if jsonb_array_length(novas) = 0 then return '[]'::jsonb; end if;
  return (
    select coalesce(jsonb_agg(jsonb_build_object(
             'id', e->>'id', 'nome', e->>'name', 'email', e->>'email',
             'novidades', (select jsonb_agg(n order by (n->>'id')::bigint) from jsonb_array_elements(novas) n
                            where public.bsp_membro_nos_grupos(e, array(select jsonb_array_elements_text(n->'grupos')))))), '[]'::jsonb)
      from shared_state s, jsonb_array_elements(coalesce(s.team, '[]'::jsonb)) e
     where s.id = 1
       and public.bsp_recebe_emails(e)
       and exists (select 1 from jsonb_array_elements(novas) n
                    where public.bsp_membro_nos_grupos(e, array(select jsonb_array_elements_text(n->'grupos'))))
  );
end $function$;
revoke all on function public.bsp_novidades_reclamar() from public, anon, authenticated;
grant execute on function public.bsp_novidades_reclamar() to service_role;

-- Cargo da Dra. Luidmila (u6) e marca semEmails na conta de teste «Beb».
update public.shared_state s
   set team = (select jsonb_agg(case
                 when e->>'id' = 'u6' then e || jsonb_build_object('role', 'Médica clínica geral, interna de ginecologia e obstetrícia')
                 when lower(e->>'email') = 'beb@beb.com' then e || jsonb_build_object('semEmails', true)
                 else e end order by ord)
               from jsonb_array_elements(s.team) with ordinality t(e, ord)),
       updated_at = now()
 where s.id = 1;
