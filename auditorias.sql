-- Auditorias clínicas com lista de verificação (03-10-2026, Elmar: «Faz as
-- auditorias, porque completam a parte clínica pedida pela JCI»).
--
-- auditoria_modelos: cada lista (higiene das mãos, carro de emergência,
-- cadeia de frio, resíduos, limpeza, identificação do doente, incêndio), com
-- a área, a periodicidade em dias e os itens. A gestão muda os modelos.
-- auditorias: cada auditoria feita: modelo, área, dia, quem auditou,
-- respostas por item (sim / nao / na, com nota) e a conformidade
-- (sim ÷ (sim + não) × 100).
-- Quem faz e quem vê: a gestão, a Direcção Clínica (bsp_ve_qualidade) e o
-- chefe da área (bsp_edita_escala). Uma auditoria com falhas avisa logo
-- (novidade à gestão, Direcção Clínica e área) e cada falha pode passar a
-- incidente em Qualidade. bsp_auditorias_alertar avisa as auditorias em
-- atraso (uma vez por semana e modelo).

create table if not exists public.auditoria_modelos (
  id bigint generated always as identity primary key,
  nome text not null,
  area text not null default '',
  periodicidade int not null default 30,
  descricao text not null default '',
  itens jsonb not null default '[]',
  activo boolean not null default true,
  ordem int not null default 0
);
alter table public.auditoria_modelos enable row level security;

create table if not exists public.auditorias (
  id bigint generated always as identity primary key,
  modelo_id bigint not null references public.auditoria_modelos (id),
  area text not null default '',
  dia date not null default (now() at time zone 'Africa/Luanda')::date,
  auditor text not null default public.bsp_meu_id(),
  respostas jsonb not null default '{}',
  conformidade numeric,
  falhas int not null default 0,
  notas text not null default '',
  criado_em timestamptz not null default now()
);
create index if not exists auditorias_modelo_dia on public.auditorias (modelo_id, dia desc);
alter table public.auditorias enable row level security;

create or replace function public.bsp_faz_auditorias(p_area text)
returns boolean language sql stable security definer set search_path to 'public'
as $f$ select coalesce(public.bsp_ve_qualidade(), false) or (coalesce(p_area, '') <> '' and coalesce(public.bsp_edita_escala(p_area), false)) $f$;

drop policy if exists aud_modelos_ler on public.auditoria_modelos;
create policy aud_modelos_ler on public.auditoria_modelos for select to authenticated using (public.bsp_meu_id() is not null);
drop policy if exists aud_modelos_mudar on public.auditoria_modelos;
create policy aud_modelos_mudar on public.auditoria_modelos for all to authenticated
  using ((select public.bsp_e_gestor())) with check ((select public.bsp_e_gestor()));
drop policy if exists aud_ler on public.auditorias;
create policy aud_ler on public.auditorias for select to authenticated using (public.bsp_faz_auditorias(area));
drop policy if exists aud_criar on public.auditorias;
create policy aud_criar on public.auditorias for insert to authenticated
  with check (public.bsp_faz_auditorias(area) and auditor = (select public.bsp_meu_id()));

-- Conformidade e falhas calculadas no servidor; aviso quando há falhas.
create or replace function public.bsp_auditoria_calcular()
returns trigger language plpgsql security definer set search_path to 'public'
as $f$
declare m record; s int; n int; lista text;
begin
  select * into m from public.auditoria_modelos where id = new.modelo_id;
  select count(*) filter (where v->>'r' = 'sim'), count(*) filter (where v->>'r' = 'nao'),
         string_agg(it->>'texto', '; ') filter (where v->>'r' = 'nao')
    into s, n, lista
    from jsonb_array_elements(m.itens) it left join lateral (select new.respostas->(it->>'id') v) x on true;
  new.falhas := coalesce(n, 0);
  new.conformidade := case when coalesce(s, 0) + coalesce(n, 0) > 0 then round(100.0 * s / (s + n), 1) end;
  if new.area = '' then new.area := m.area; end if;
  if new.falhas > 0 then
    insert into public.novidades (titulo, texto, grupos, destino)
    values ('Auditoria com falhas: ' || m.nome,
            to_char(new.dia, 'DD-MM-YYYY') || ' · conformidade ' || replace(coalesce(new.conformidade, 0)::text, '.', ',') || '% (' || new.falhas
            || case when new.falhas = 1 then ' falha' else ' falhas' end || '): ' || coalesce(lista, '') || '.',
            array['gestao', 'direccao-clinica'] || case when new.area <> '' then array[new.area] else '{}' end, 'qualidade');
  end if;
  return new;
end $f$;
drop trigger if exists bsp_auditoria_calcular on public.auditorias;
create trigger bsp_auditoria_calcular before insert on public.auditorias
  for each row execute function public.bsp_auditoria_calcular();

-- Estado de cada modelo: última auditoria, próxima devida, média de 90 dias.
create or replace function public.bsp_auditorias_estado()
returns table (modelo_id bigint, nome text, area text, periodicidade int, ultima date, proxima date,
               em_atraso boolean, conformidade_ultima numeric, conformidade_90 numeric, feitas_90 int)
language sql stable security definer set search_path to 'public'
as $f$
  with hoje as (select (now() at time zone 'Africa/Luanda')::date d),
  vis as (select m.* from public.auditoria_modelos m where m.activo and public.bsp_faz_auditorias(m.area) offset 0)
  select m.id, m.nome, m.area, m.periodicidade, u.dia, coalesce(u.dia + m.periodicidade, (select d from hoje)),
         coalesce(u.dia + m.periodicidade, (select d from hoje)) < (select d from hoje),
         u.conformidade,
         (select round(avg(a.conformidade), 1) from public.auditorias a where a.modelo_id = m.id and a.dia >= (select d from hoje) - 90),
         (select count(*)::int from public.auditorias a where a.modelo_id = m.id and a.dia >= (select d from hoje) - 90)
    from vis m
    left join lateral (select a.dia, a.conformidade from public.auditorias a where a.modelo_id = m.id order by a.dia desc, a.id desc limit 1) u on true
   order by m.ordem, m.nome
$f$;

create or replace function public.bsp_auditorias_alertar()
returns int language plpgsql security definer set search_path to 'public'
as $f$
declare r record; n int := 0; hoje date := (now() at time zone 'Africa/Luanda')::date;
begin
  -- Às segundas-feiras: um aviso por modelo em atraso.
  if extract(dow from hoje) <> 1 then return 0; end if;
  for r in
    select m.id, m.nome, m.area, m.periodicidade, (select max(a.dia) from public.auditorias a where a.modelo_id = m.id) ultima
      from public.auditoria_modelos m where m.activo
  loop
    if r.ultima is null or r.ultima + r.periodicidade < hoje then
      insert into public.novidades (titulo, texto, grupos, destino)
      values ('Auditoria em atraso: ' || r.nome,
              case when r.ultima is null then 'Ainda não foi feita nenhuma.' else 'A última foi a ' || to_char(r.ultima, 'DD-MM-YYYY') || '; devia repetir-se a cada ' || r.periodicidade || ' dias.' end
              || ' Faça-a em Qualidade → Auditorias.',
              array['gestao', 'direccao-clinica'] || case when r.area <> '' then array[r.area] else '{}' end, 'qualidade');
      n := n + 1;
    end if;
  end loop;
  return n;
end $f$;

do $$ begin
  revoke execute on function public.bsp_auditorias_alertar() from public, anon, authenticated;
  revoke execute on function public.bsp_auditoria_calcular() from public, anon, authenticated;
  revoke execute on function public.bsp_faz_auditorias(text) from public, anon;
  revoke execute on function public.bsp_auditorias_estado() from public, anon;
  grant execute on function public.bsp_faz_auditorias(text) to authenticated;
  grant execute on function public.bsp_auditorias_estado() to authenticated;
end $$;
select cron.schedule('bsp-auditorias', '10 4 * * *', 'select public.bsp_auditorias_alertar();');

-- Modelos iniciais (boas práticas da OMS e normas JCI; a gestão ajusta).
insert into public.auditoria_modelos (nome, area, periodicidade, descricao, itens, ordem)
select * from (values
  ('Higiene das mãos (5 momentos da OMS)', 'enfermagem', 30,
   'Observe 10 oportunidades num turno. Marque «Não» se alguma falhou.',
   '[{"id":"m1","texto":"Antes do contacto com o doente"},{"id":"m2","texto":"Antes de procedimento limpo ou asséptico"},{"id":"m3","texto":"Após risco de exposição a fluidos orgânicos"},{"id":"m4","texto":"Após contacto com o doente"},{"id":"m5","texto":"Após contacto com o ambiente do doente"},{"id":"m6","texto":"Solução alcoólica disponível em cada ponto de cuidado"},{"id":"m7","texto":"Unhas curtas, sem verniz, anéis nem relógio"}]'::jsonb, 1),
  ('Carro de emergência', 'enfermagem', 7,
   'Verificação semanal e depois de cada utilização.',
   '[{"id":"c1","texto":"Lacre íntegro e número registado"},{"id":"c2","texto":"Desfibrilhador ligado à corrente e testado"},{"id":"c3","texto":"Garrafa de oxigénio cheia e com manómetro"},{"id":"c4","texto":"Medicamentos dentro da validade e nas quantidades da lista"},{"id":"c5","texto":"Insuflador manual (ambu) e máscaras de vários tamanhos"},{"id":"c6","texto":"Aspirador a funcionar"},{"id":"c7","texto":"Folha de verificação assinada"}]'::jsonb, 2),
  ('Cadeia de frio', 'farmacia', 7,
   'Frigoríficos de vacinas, medicamentos e reagentes.',
   '[{"id":"f1","texto":"Temperatura registada duas vezes por dia"},{"id":"f2","texto":"Todos os registos entre 2 e 8 °C"},{"id":"f3","texto":"Termómetro de máximas e mínimas a funcionar"},{"id":"f4","texto":"Sem alimentos nem bebidas no frigorífico"},{"id":"f5","texto":"Produtos arrumados, sem tocar nas paredes"},{"id":"f6","texto":"Plano para falha de energia conhecido pela equipa"}]'::jsonb, 3),
  ('Resíduos hospitalares', 'servicos gerais', 30,
   'Separação, acondicionamento e recolha.',
   '[{"id":"r1","texto":"Separação correcta por grupo e cor de saco"},{"id":"r2","texto":"Contentores de cortantes abaixo de 3/4"},{"id":"r3","texto":"Contentores fechados e identificados"},{"id":"r4","texto":"Local de armazenamento fechado e limpo"},{"id":"r5","texto":"Recolha registada com guia do operador"}]'::jsonb, 4),
  ('Limpeza e desinfecção', 'servicos gerais', 7,
   'Gabinetes, salas de colheita, sala de tratamentos e casas de banho.',
   '[{"id":"l1","texto":"Plano de limpeza afixado e assinado"},{"id":"l2","texto":"Superfícies de contacto desinfectadas"},{"id":"l3","texto":"Marquesas com lençol trocado entre doentes"},{"id":"l4","texto":"Casas de banho limpas e com sabão e papel"},{"id":"l5","texto":"Produtos de limpeza rotulados e guardados"}]'::jsonb, 5),
  ('Identificação do doente', 'clinica', 30,
   'Meta Internacional de Segurança 1 da JCI: dois identificadores.',
   '[{"id":"i1","texto":"Nome completo e data de nascimento confirmados antes de cada acto"},{"id":"i2","texto":"Amostras de laboratório identificadas à frente do doente"},{"id":"i3","texto":"Pedidos de exame com os dois identificadores"},{"id":"i4","texto":"Nunca se identifica pelo número da sala ou da cama"}]'::jsonb, 6),
  ('Segurança contra incêndio', 'servicos gerais', 30,
   'Meios de primeira intervenção e evacuação.',
   '[{"id":"s1","texto":"Extintores no lugar, com selo e dentro da validade"},{"id":"s2","texto":"Saídas e corredores livres"},{"id":"s3","texto":"Sinalização de emergência visível"},{"id":"s4","texto":"Quadro eléctrico fechado e acessível"}]'::jsonb, 7)
) v(nome, area, periodicidade, descricao, itens, ordem)
where not exists (select 1 from public.auditoria_modelos);
