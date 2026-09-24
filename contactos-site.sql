-- Barispol · caixa de contacto do site (barispol.com)
-- Pedido do Elmar, 25-09-2026. Aplicado no projecto Barispol
-- (gnqleaxrtuerlcrriqqs) no mesmo dia. Pode correr-se mais do que uma vez.
--
-- O paciente escreve no site o que quiser. A funcao contacto-site guarda a
-- mensagem aqui e envia-a por e-mail para geral@barispol.com. Nunca envia
-- nada ao paciente.
--
-- Ninguem escreve nesta tabela pela chave publica: so a funcao, com a
-- chave do servidor. Lem a Direccao e a Coordenacao (bsp_e_gestor).

create table if not exists contactos_site (
  id         bigint generated always as identity primary key,
  criado_em  timestamptz not null default now(),
  origem_ip  text,              -- resumo (hash) da ligacao, para os limites
  nome       text not null,
  telefone   text,
  email      text,
  assunto    text,
  seguro     text,
  mensagem   text not null,
  origem     text,              -- ?origem= do endereco (facebook, tiktok...)
  enviado    boolean not null default false,
  erro       text
);
create index if not exists contactos_site_ip_idx on contactos_site (origem_ip, criado_em);

alter table contactos_site enable row level security;
drop policy if exists "bsp_contactos_ler" on contactos_site;
create policy "bsp_contactos_ler" on contactos_site for select to authenticated
  using (bsp_e_gestor());

-- Limpeza: as mensagens ficam 12 meses.
do $$
begin
  if exists (select 1 from cron.job where jobname = 'bsp-limpeza-contactos') then
    perform cron.unschedule('bsp-limpeza-contactos');
  end if;
  perform cron.schedule('bsp-limpeza-contactos', '15 3 * * 0',
    $cmd$ delete from contactos_site where criado_em < now() - interval '12 months'; $cmd$);
end $$;

notify pgrst, 'reload schema';
