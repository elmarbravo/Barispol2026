-- Pedidos do Elmar de 07-10-2026 (aplicado a 07-10-2026: acesso da Rosa e 4
-- mensagens, ids 5570 a 5573). Preparados quando o Supabase recusava as
-- ligações. Correr de uma vez quando a ligação voltar. Sem «drop» nem «truncate».
--
-- 1. «Dou à Rosa acesso ao Stock do Laboratório?» → sim. A Rosa Queirós (u13,
--    chefe do Laboratório) vê o armazém LABORATÓRIO - CBL, como a Solange vê a
--    Farmácia. No ecrã: BSP_STOCK_RESPONSAVEIS (mudar os dois lados juntos).
insert into public.stock_responsaveis (user_id, armazem)
values ('u13', 'LABORATÓRIO - CBL')
on conflict do nothing;

-- 2. «Da presença dos médicos faz uma mensagem para a recepção e para cada
--    recepcionista». Uma mensagem no canal #recepção e uma directa a cada pessoa
--    da Recepção (área recepcao, sem inactivos), enviadas pelo Elmar (u1).
--    O cid impede que saiam duas vezes se o ficheiro correr de novo.
do $$
declare
  canal text := E'📋 Presenças dos médicos: a Recepção marca\n\n'
    || E'A Recepção regista no Workspace a chegada e a saída de cada médico. Estas horas vão directamente para o pagamento dos médicos: cada marcação conta.\n\n'
    || E'Onde: Utentes → «Presenças dos médicos», ou o cartão dos médicos no Início.\n'
    || E'1. O médico chegou: procure o nome e carregue em «Chegou». Fica a hora do servidor.\n'
    || E'2. O médico saiu: carregue em «Saiu».\n'
    || E'3. Esqueceu-se na hora? Use «Outra hora» ou «Corrigir chegada/saída». A correcção fica registada com o seu nome.\n'
    || E'4. Aviso a vermelho: médico com facturas hoje e sem chegada marcada. Marque logo.\n\n'
    || E'Só se corrige até ao dia anterior. Dúvidas: falem comigo ou com a Arlete.';
  r record;
  txt text;
begin
  if not exists (select 1 from public.messages where cid = 'presencas-2026-10-07-canal') then
    insert into public.messages (conv_key, user_id, text, cid) values ('c-rececao', 'u1', canal, 'presencas-2026-10-07-canal');
  end if;
  for r in
    select e->>'id' id, split_part(e->>'name', ' ', 1) nome
      from shared_state s, jsonb_array_elements(coalesce(s.team, '[]'::jsonb)) e
     where s.id = 1 and public.bsp_area_chave(e->>'dept') = 'recepcao'
       and not coalesce((e->>'inactivo')::boolean, false) and e->>'id' <> 'u1'
  loop
    txt := 'Olá, ' || r.nome || E'. As presenças dos médicos passam pela Recepção: quando um médico chega, carregue em «Chegou»; quando sai, em «Saiu» (Utentes → «Presenças dos médicos», ou no Início). '
      || E'Se se esquecer, use «Outra hora» ou «Corrigir»: fica registado com o seu nome. Estas horas contam para o pagamento dos médicos. Expliquei tudo no canal #recepção. Obrigado.';
    if not exists (select 1 from public.messages where cid = 'presencas-2026-10-07-' || r.id) then
      insert into public.messages (conv_key, user_id, text, cid)
      values ('dm-' || least('u1' collate "C", r.id collate "C") || '_' || greatest('u1' collate "C", r.id collate "C"), 'u1', txt, 'presencas-2026-10-07-' || r.id);
    end if;
  end loop;
end $$;
