-- Testes dos desafios (D1, D7, D8): regra do km, funções do app, policies das
-- fotos, comentários, reações, votos e moderação.
-- Roda numa transação que termina em ROLLBACK — nada fica no banco. Use
-- supabase/tests/run.sh (com --migrate testa a migração antes de aplicar).
-- Falhou = exceção com o caso que quebrou. Passou = última linha "ok".
begin;

-- ---------- ajudantes (morrem no rollback) ----------
create function public.zz_login(p_uid uuid, p_anon boolean default false)
returns void language plpgsql as $$
begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims',
        json_build_object('sub', p_uid, 'role', 'authenticated', 'is_anonymous', p_anon)::text, true);
    perform set_config('role', 'authenticated', true);
end $$;

create function public.zz_admin()
returns void language plpgsql as $$
begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
end $$;

create function public.zz_expect_error(p_sql text, p_err text)
returns void language plpgsql as $$
begin
    execute p_sql;
    raise exception 'não deu erro';
exception when others then
    if sqlerrm is distinct from p_err then
        raise exception 'esperava "%" em [%], veio: %', p_err, p_sql, sqlerrm;
    end if;
end $$;

-- ---------- pessoas e motos ----------
-- A: 1 moto · B: 2 motos · C: sai do desafio · D: sem registro · E: fora · N: anônima
insert into auth.users (id, aud, role, email, is_anonymous) values
    ('a0000000-0000-4000-8000-000000000001', 'authenticated', 'authenticated', 'a@test.invalid', false),
    ('b0000000-0000-4000-8000-000000000001', 'authenticated', 'authenticated', 'b@test.invalid', false),
    ('c0000000-0000-4000-8000-000000000001', 'authenticated', 'authenticated', 'c@test.invalid', false),
    ('d0000000-0000-4000-8000-000000000001', 'authenticated', 'authenticated', 'd@test.invalid', false),
    ('e0000000-0000-4000-8000-000000000001', 'authenticated', 'authenticated', 'e@test.invalid', false),
    ('f0000000-0000-4000-8000-000000000001', 'authenticated', 'authenticated', null, true);

insert into public.motorcycles (id, user_id, make, model, year) values
    ('a1000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000001', 'Yamaha', 'MT-07', 2022),
    ('b1000000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000001', 'Honda', 'CB 500X', 2021),
    ('b2000000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000001', 'BMW', 'G 310 GS', 2020),
    ('c1000000-0000-4000-8000-000000000001', 'c0000000-0000-4000-8000-000000000001', 'Honda', 'CG 160', 2023),
    ('d1000000-0000-4000-8000-000000000001', 'd0000000-0000-4000-8000-000000000001', 'Triumph', 'Tiger 900', 2024);

-- ---------- desafio fixo, já encerrado ----------
-- Período 05/10 00:00 → 12/10 00:00 (BRT); classificação fecha 15/10 00:00.
insert into public.challenges (id, name, starts_at, ends_at, created_by, invite_code) values
    ('11111111-1111-4111-8111-111111111111', 'Turma da serra',
     '2026-10-05 03:00+00', '2026-10-12 03:00+00', 'a0000000-0000-4000-8000-000000000001', 'K7QM4XPR');
insert into public.challenge_members (challenge_id, user_id, display_name, left_at) values
    ('11111111-1111-4111-8111-111111111111', 'a0000000-0000-4000-8000-000000000001', 'Ana Souza', null),
    ('11111111-1111-4111-8111-111111111111', 'b0000000-0000-4000-8000-000000000001', 'Bruno', null),
    ('11111111-1111-4111-8111-111111111111', 'c0000000-0000-4000-8000-000000000001', 'Carla', '2026-10-07 12:00+00'),
    ('11111111-1111-4111-8111-111111111111', 'd0000000-0000-4000-8000-000000000001', 'Diego', null);

-- Foto 'remote' = "<moto>/<LOG>.jpg" (como o app grava), 'local' = upload pendente.
insert into public.fuel_logs (id, motorcycle_id, user_id, date, odometer, liters, total_cost, fuel_type,
                              created_at, missed_previous, deleted_at, odometer_photo_url)
select v.id::uuid, v.moto::uuid, mo.user_id, v.date::timestamptz, v.odo, v.liters, v.liters * 6, 'gasoline',
       coalesce(v.created::timestamptz, v.date::timestamptz + interval '5 minutes'),
       v.missed, v.deleted::timestamptz,
       case v.photo when 'remote' then v.moto || '/' || upper(v.id) || '.jpg'
                    when 'local' then upper(v.id) || '.jpg' end
  from (values
    -- A (MT-07)
    ('a3000000-0000-4000-8000-000000000000', 'a1000000-0000-4000-8000-000000000001', '2026-10-01 12:00+00', 10000::float8, 10::float8, null::text, false, null::text, 'remote'),
    ('a3000000-0000-4000-8000-000000000001', 'a1000000-0000-4000-8000-000000000001', '2026-10-05 12:00+00', 10100, 5, '2026-10-14 12:00+00', false, null, 'remote'),
    ('a3000000-0000-4000-8000-000000000002', 'a1000000-0000-4000-8000-000000000001', '2026-10-06 12:00+00', 10300, 10, null, false, null, 'remote'),
    ('a3000000-0000-4000-8000-000000000003', 'a1000000-0000-4000-8000-000000000001', '2026-10-07 12:00+00', 10600, 1, null, false, '2026-10-07 13:00+00', 'remote'),
    ('a3000000-0000-4000-8000-000000000004', 'a1000000-0000-4000-8000-000000000001', '2026-10-08 12:00+00', 10500, 8, null, false, null, null),
    ('a3000000-0000-4000-8000-000000000005', 'a1000000-0000-4000-8000-000000000001', '2026-10-09 12:00+00', 10700, 4, null, false, null, 'remote'),
    ('a3000000-0000-4000-8000-000000000006', 'a1000000-0000-4000-8000-000000000001', '2026-10-10 12:00+00', 10900, 2, null, false, null, 'local'),
    ('a3000000-0000-4000-8000-000000000007', 'a1000000-0000-4000-8000-000000000001', '2026-10-13 12:00+00', 11300, 10, null, false, null, 'remote'),
    ('a3000000-0000-4000-8000-000000000008', 'a1000000-0000-4000-8000-000000000001', '2026-10-14 12:00+00', 11500, 5, '2026-10-16 12:00+00', false, null, 'remote'),
    -- B (CB 500X)
    ('b3000000-0000-4000-8000-000000000000', 'b1000000-0000-4000-8000-000000000001', '2026-10-05 06:00+00', 5000, 5, null, false, null, 'remote'),
    ('b3000000-0000-4000-8000-000000000001', 'b1000000-0000-4000-8000-000000000001', '2026-10-06 06:00+00', 5200, 5, null, false, null, 'remote'),
    ('b3000000-0000-4000-8000-000000000002', 'b1000000-0000-4000-8000-000000000001', '2026-10-07 06:00+00', 5400, 5, null, true, null, null),
    ('b3000000-0000-4000-8000-000000000003', 'b1000000-0000-4000-8000-000000000001', '2026-10-08 06:00+00', 5600, 5, null, false, null, 'remote'),
    ('b3000000-0000-4000-8000-000000000004', 'b1000000-0000-4000-8000-000000000001', '2026-10-09 06:00+00', 9000, 5, null, false, null, 'remote'),
    ('b3000000-0000-4000-8000-000000000005', 'b1000000-0000-4000-8000-000000000001', '2026-10-10 06:00+00', 9100, 5, null, false, null, 'remote'),
    -- B (G 310 GS)
    ('b4000000-0000-4000-8000-000000000000', 'b2000000-0000-4000-8000-000000000001', '2026-10-06 00:00+00', 20000, 6, null, false, null, 'remote'),
    ('b4000000-0000-4000-8000-000000000001', 'b2000000-0000-4000-8000-000000000001', '2026-10-07 00:00+00', 20150, 6, null, false, null, 'remote'),
    -- C (saiu do desafio)
    ('c3000000-0000-4000-8000-000000000000', 'c1000000-0000-4000-8000-000000000001', '2026-10-06 00:00+00', 1000, 5, null, false, null, 'remote'),
    ('c3000000-0000-4000-8000-000000000001', 'c1000000-0000-4000-8000-000000000001', '2026-10-07 00:00+00', 1200, 5, null, false, null, 'remote')
  ) v(id, moto, date, odo, liters, created, missed, deleted, photo)
  join public.motorcycles mo on mo.id = v.moto::uuid;

-- Foto do desafio no b1 (a turma vê junto com o hodômetro).
update public.fuel_logs
   set challenge_photo_url = 'b1000000-0000-4000-8000-000000000001/B3000000-0000-4000-8000-000000000001-challenge.jpg'
 where id = 'b3000000-0000-4000-8000-000000000001';

-- ---------- regra do km, registro por registro ----------
create temp table expected_scores (id uuid, status text, km numeric);
insert into expected_scores values
    -- A: âncora antes do período (só início)
    ('a3000000-0000-4000-8000-000000000000', 'start', 0),
    -- registrado 9 dias depois: histórico, nem ponta de trecho
    ('a3000000-0000-4000-8000-000000000001', 'historical', 0),
    -- trecho 01/10 12h → 06/10 12h (120 h) cruza o início: 33 h dentro → 300 × 33/120
    ('a3000000-0000-4000-8000-000000000002', 'counted', 82.5),
    -- sem foto: os km passam para a próxima foto
    ('a3000000-0000-4000-8000-000000000004', 'no_photo', 0),
    -- 400 km com 8 + 4 L (litros do registro sem foto entram no teto); só com 4 L passaria de 80 km/l
    ('a3000000-0000-4000-8000-000000000005', 'counted', 400),
    -- foto ainda no aparelho (upload pendente) = sem foto
    ('a3000000-0000-4000-8000-000000000006', 'no_photo', 0),
    -- depois do fim, dentro do fechamento: trecho 09/10 12h → 13/10 12h (96 h), 63 h dentro → 600 × 63/96
    ('a3000000-0000-4000-8000-000000000007', 'counted', 393.75),
    -- B, moto 1: 1ª ponta = início; lacuna no registro sem foto quebra o trecho seguinte;
    -- 3.400 km com 5 L = impossível; depois dele a contagem segue normal
    ('b3000000-0000-4000-8000-000000000000', 'start', 0),
    ('b3000000-0000-4000-8000-000000000001', 'counted', 200),
    ('b3000000-0000-4000-8000-000000000002', 'no_photo', 0),
    ('b3000000-0000-4000-8000-000000000003', 'gap', 0),
    ('b3000000-0000-4000-8000-000000000004', 'impossible', 0),
    ('b3000000-0000-4000-8000-000000000005', 'counted', 100),
    -- B, moto 2: as duas motos somam
    ('b4000000-0000-4000-8000-000000000000', 'start', 0),
    ('b4000000-0000-4000-8000-000000000001', 'counted', 150);

do $$
declare
    v_bad text;
begin
    select string_agg(format('%s: esperado %s/%s, veio %s/%s', e.id, e.status, e.km, s.status, round(s.km::numeric, 2)), '; ')
      into v_bad
      from expected_scores e
      left join public.challenge_scores('11111111-1111-4111-8111-111111111111') s on s.fuel_log_id = e.id
     where s.status is distinct from e.status or round(s.km::numeric, 2) is distinct from e.km;
    assert v_bad is null, 'regra do km: ' || v_bad;

    -- Fora do desafio: registro apagado, criado depois do fechamento, de quem saiu.
    assert not exists (
        select 1 from public.challenge_scores('11111111-1111-4111-8111-111111111111') s
         where s.fuel_log_id in ('a3000000-0000-4000-8000-000000000003', 'a3000000-0000-4000-8000-000000000008',
                                 'c3000000-0000-4000-8000-000000000000', 'c3000000-0000-4000-8000-000000000001')
    ), 'apagado / depois do fechamento / quem saiu não podiam aparecer';
end $$;

-- ---------- classificação, mural, registros ----------
do $$
declare
    r record;
    v_rows integer;
    v_b uuid;
begin
    perform public.zz_login('a0000000-0000-4000-8000-000000000001');

    select count(*) into v_rows from public.challenge_leaderboard('11111111-1111-4111-8111-111111111111');
    assert v_rows = 3, format('classificação: 3 ativos (Carla saiu), veio %s', v_rows);

    select * into r from public.challenge_leaderboard('11111111-1111-4111-8111-111111111111') where rank = 1;
    assert r.display_name = 'Ana Souza' and r.is_me and r.km = 876.3 and r.fuel_ups = 2,
        format('1º lugar: %s', row_to_json(r));
    assert r.bikes = '[{"make": "Yamaha", "model": "MT-07"}]'::jsonb, format('motos da Ana: %s', r.bikes);
    assert r.last_entry_at = '2026-10-10 12:00+00', format('último registro da Ana: %s', r.last_entry_at);

    select * into r from public.challenge_leaderboard('11111111-1111-4111-8111-111111111111') where rank = 2;
    assert r.display_name = 'Bruno' and not r.is_me and r.km = 450 and r.fuel_ups = 7,
        format('2º lugar: %s', row_to_json(r));
    assert r.bikes = '[{"make": "Honda", "model": "CB 500X"}, {"make": "BMW", "model": "G 310 GS"}]'::jsonb,
        format('motos do Bruno: %s', r.bikes);
    v_b := r.member_id;

    -- Sem registro no período: 0 km e as motos atuais.
    select * into r from public.challenge_leaderboard('11111111-1111-4111-8111-111111111111') where rank = 3;
    assert r.display_name = 'Diego' and r.km = 0 and r.fuel_ups = 0
       and r.bikes = '[{"make": "Triumph", "model": "Tiger 900"}]'::jsonb,
        format('3º lugar: %s', row_to_json(r));

    -- Mural: período + o registro depois do fim que trouxe km.
    select count(*) into v_rows from public.challenge_entries('11111111-1111-4111-8111-111111111111');
    assert v_rows = 14, format('mural: 6 da Ana + 8 do Bruno, veio %s', v_rows);
    select count(*) into v_rows from public.challenge_entries('11111111-1111-4111-8111-111111111111', v_b);
    assert v_rows = 8, format('registros do Bruno: 8, veio %s', v_rows);
    select * into r from public.challenge_entries('11111111-1111-4111-8111-111111111111')
     where fuel_log_id = 'a3000000-0000-4000-8000-000000000007';
    assert r.km = 393.8 and r.status = 'counted' and r.model = 'MT-07', format('registro depois do fim: %s', row_to_json(r));
    select * into r from public.challenge_entries('11111111-1111-4111-8111-111111111111')
     where fuel_log_id = 'b3000000-0000-4000-8000-000000000001';
    assert r.challenge_photo_path like 'b1000000-%-challenge.jpg', format('foto do desafio: %s', r.challenge_photo_path);
    assert r.odometer_photo_path = 'b1000000-0000-4000-8000-000000000001/B3000000-0000-4000-8000-000000000001.jpg',
        format('foto do hodômetro: %s', r.odometer_photo_path);

    -- Fechou (passou de fim + 3 dias): a classificação congelou.
    perform public.zz_admin();
    assert (select finalized_at is not null from public.challenges
             where id = '11111111-1111-4111-8111-111111111111'), 'classificação não fechou';
    insert into public.fuel_logs (id, motorcycle_id, user_id, date, odometer, liters, total_cost, fuel_type, created_at, odometer_photo_url)
    values ('b3000000-0000-4000-8000-000000000006', 'b1000000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000001',
            '2026-10-11 06:00+00', 9300, 5, 30, 'gasoline', '2026-10-11 06:05+00',
            'b1000000-0000-4000-8000-000000000001/B3000000-0000-4000-8000-000000000006.jpg');
    perform public.zz_login('a0000000-0000-4000-8000-000000000001');
    select km into r from public.challenge_leaderboard('11111111-1111-4111-8111-111111111111') where display_name = 'Bruno';
    assert r.km = 450, format('depois de fechar, registro novo não muda nada: %s', r.km);

    -- Quem não está no desafio não vê nada.
    perform public.zz_login('e0000000-0000-4000-8000-000000000001');
    perform public.zz_expect_error($q$select * from public.challenge_leaderboard('11111111-1111-4111-8111-111111111111')$q$, 'not_a_member');
    perform public.zz_expect_error($q$select * from public.challenge_entries('11111111-1111-4111-8111-111111111111')$q$, 'not_a_member');
    perform public.zz_login('f0000000-0000-4000-8000-000000000001', true);
    perform public.zz_expect_error($q$select * from public.challenge_leaderboard('11111111-1111-4111-8111-111111111111')$q$, 'apple_account_required');
    perform public.zz_admin();
end $$;

-- ---------- fotos do abastecimento para a turma ----------
do $$
begin
    -- Bruno vê a foto da Ana no período (nome do arquivo em maiúsculas, como o app grava).
    perform public.zz_login('b0000000-0000-4000-8000-000000000001');
    assert public.can_view_challenge_photo('a1000000-0000-4000-8000-000000000001/A3000000-0000-4000-8000-000000000002.jpg'),
        'membro vê a foto do período';
    assert not public.can_view_challenge_photo('a1000000-0000-4000-8000-000000000001/A3000000-0000-4000-8000-000000000000.jpg'),
        'foto de antes do período fica fechada';
    assert not public.can_view_challenge_photo('b1000000-0000-4000-8000-000000000001/A3000000-0000-4000-8000-000000000002.jpg'),
        'pasta de outra moto não libera';
    assert not public.can_view_challenge_photo('a1000000-0000-4000-8000-000000000001/../x.jpg'), 'nome estranho = não (sem erro)';
    assert not public.can_view_challenge_photo('qualquer-coisa'), 'nome sem pasta = não (sem erro)';
    -- Ana vê a foto do desafio do Bruno.
    perform public.zz_login('a0000000-0000-4000-8000-000000000001');
    assert public.can_view_challenge_photo('b1000000-0000-4000-8000-000000000001/B3000000-0000-4000-8000-000000000001-challenge.jpg'),
        'membro vê a foto do desafio';
    -- Quem saiu e quem nunca entrou não veem.
    perform public.zz_login('c0000000-0000-4000-8000-000000000001');
    assert not public.can_view_challenge_photo('a1000000-0000-4000-8000-000000000001/A3000000-0000-4000-8000-000000000002.jpg'),
        'quem saiu não vê';
    perform public.zz_login('e0000000-0000-4000-8000-000000000001');
    assert not public.can_view_challenge_photo('a1000000-0000-4000-8000-000000000001/A3000000-0000-4000-8000-000000000002.jpg'),
        'quem não está no desafio não vê';

    -- Ponta a ponta nas policies do Storage: o dono segue lendo, a turma
    -- passa a ler, o resto não.
    perform public.zz_admin();
    insert into storage.objects (bucket_id, name) values
        ('fuel-log-photos', 'a1000000-0000-4000-8000-000000000001/A3000000-0000-4000-8000-000000000002.jpg'),
        ('fuel-log-photos', 'a1000000-0000-4000-8000-000000000001/A3000000-0000-4000-8000-000000000000.jpg'),
        ('challenge-covers', '11111111-1111-4111-8111-111111111111/cover.jpg');
    perform public.zz_login('a0000000-0000-4000-8000-000000000001');
    assert (select count(*) from storage.objects where bucket_id = 'fuel-log-photos'
             and name like 'a1000000-0000-4000-8000-000000000001/%') = 2, 'dono lê as duas fotos';
    perform public.zz_login('b0000000-0000-4000-8000-000000000001');
    assert (select count(*) from storage.objects where bucket_id = 'fuel-log-photos'
             and name like 'a1000000-0000-4000-8000-000000000001/%') = 1, 'turma lê só a do período';
    assert (select count(*) from storage.objects where bucket_id = 'challenge-covers') = 1, 'membro lê a capa';
    perform public.zz_login('e0000000-0000-4000-8000-000000000001');
    assert (select count(*) from storage.objects where bucket_id in ('fuel-log-photos', 'challenge-covers')
             and name like any (array['a1000000-%', '11111111-%'])) = 0, 'estranho não lê nada';
    perform public.zz_admin();
end $$;

-- ---------- D7: comentários, reações, votos ----------
do $$
declare
    v_social jsonb;
    v_post jsonb;
    v_b_member uuid;
    v_rows integer;
begin
    select id into v_b_member from public.challenge_members
     where challenge_id = '11111111-1111-4111-8111-111111111111' and user_id = 'b0000000-0000-4000-8000-000000000001';

    -- Bruno comenta no registro da Ana (do período).
    perform public.zz_login('b0000000-0000-4000-8000-000000000001');
    v_post := public.post_challenge_comment('11111111-1111-4111-8111-111111111111',
        'a3000000-0000-4000-8000-000000000002', E'  Que vista! 😍\n ');
    assert v_post ? 'id' and v_post ? 'created_at', format('resposta do comentário: %s', v_post);
    perform public.zz_expect_error($q$select public.post_challenge_comment('11111111-1111-4111-8111-111111111111', 'a3000000-0000-4000-8000-000000000002', '   ')$q$, 'invalid_comment');
    perform public.zz_expect_error(format($q$select public.post_challenge_comment('11111111-1111-4111-8111-111111111111', 'a3000000-0000-4000-8000-000000000002', %L)$q$, repeat('a', 401)), 'invalid_comment');
    -- Antes do período, de quem saiu, apagado: fora do mural.
    perform public.zz_expect_error($q$select public.post_challenge_comment('11111111-1111-4111-8111-111111111111', 'a3000000-0000-4000-8000-000000000000', 'oi')$q$, 'entry_not_found');
    perform public.zz_expect_error($q$select public.post_challenge_comment('11111111-1111-4111-8111-111111111111', 'c3000000-0000-4000-8000-000000000001', 'oi')$q$, 'entry_not_found');
    perform public.zz_expect_error($q$select public.post_challenge_comment('11111111-1111-4111-8111-111111111111', 'a3000000-0000-4000-8000-000000000003', 'oi')$q$, 'entry_not_found');

    -- A Ana vê o comentário com o member_id do Bruno, texto sem espaço nas pontas.
    perform public.zz_login('a0000000-0000-4000-8000-000000000001');
    v_social := public.challenge_social('11111111-1111-4111-8111-111111111111');
    assert jsonb_array_length(v_social->'comments') = 1, format('comentários: %s', v_social);
    assert v_social->'comments'->0->>'member_id' = v_b_member::text
       and v_social->'comments'->0->>'body' = 'Que vista! 😍'
       and v_social->'comments'->0->>'fuel_log_id' = 'a3000000-0000-4000-8000-000000000002',
        format('comentário: %s', v_social->'comments'->0);

    -- Reações: troca, tira; nunca no próprio.
    perform public.zz_login('b0000000-0000-4000-8000-000000000001');
    perform public.set_challenge_reaction('11111111-1111-4111-8111-111111111111', 'a3000000-0000-4000-8000-000000000002', '🔥');
    perform public.set_challenge_reaction('11111111-1111-4111-8111-111111111111', 'a3000000-0000-4000-8000-000000000002', '🏍️');
    v_social := public.challenge_social('11111111-1111-4111-8111-111111111111');
    assert jsonb_array_length(v_social->'reactions') = 1 and v_social->'reactions'->0->>'emoji' = '🏍️',
        format('1 reação por pessoa, a última vale: %s', v_social->'reactions');
    perform public.zz_expect_error($q$select public.set_challenge_reaction('11111111-1111-4111-8111-111111111111', 'b3000000-0000-4000-8000-000000000001', '🔥')$q$, 'cannot_react_own');
    perform public.zz_expect_error(format($q$select public.set_challenge_reaction('11111111-1111-4111-8111-111111111111', 'a3000000-0000-4000-8000-000000000002', %L)$q$, repeat('x', 17)), 'invalid_reaction');
    perform public.set_challenge_reaction('11111111-1111-4111-8111-111111111111', 'a3000000-0000-4000-8000-000000000002', null);
    v_social := public.challenge_social('11111111-1111-4111-8111-111111111111');
    assert jsonb_array_length(v_social->'reactions') = 0, 'nulo tira a reação';

    -- Votos: só em foto que está no Storage, nunca na própria.
    perform public.set_challenge_photo_vote('11111111-1111-4111-8111-111111111111', 'a3000000-0000-4000-8000-000000000002', 'suspect');
    perform public.zz_expect_error($q$select public.set_challenge_photo_vote('11111111-1111-4111-8111-111111111111', 'a3000000-0000-4000-8000-000000000004', 'ok')$q$, 'no_photo_to_check');
    perform public.zz_expect_error($q$select public.set_challenge_photo_vote('11111111-1111-4111-8111-111111111111', 'b3000000-0000-4000-8000-000000000001', 'ok')$q$, 'cannot_vote_own');
    perform public.zz_expect_error($q$select public.set_challenge_photo_vote('11111111-1111-4111-8111-111111111111', 'a3000000-0000-4000-8000-000000000002', 'talvez')$q$, 'invalid_vote');
    perform public.zz_login('d0000000-0000-4000-8000-000000000001');
    perform public.set_challenge_photo_vote('11111111-1111-4111-8111-111111111111', 'a3000000-0000-4000-8000-000000000002', 'ok');
    v_social := public.challenge_social('11111111-1111-4111-8111-111111111111');
    assert jsonb_array_length(v_social->'votes') = 2, format('votos: %s', v_social->'votes');

    -- Apagar: o Diego não apaga o do Bruno; a Ana (criou) apaga.
    perform public.zz_expect_error(format($q$select public.delete_challenge_comment(%L)$q$, v_post->>'id'), 'cannot_delete_comment');
    perform public.zz_login('a0000000-0000-4000-8000-000000000001');
    perform public.delete_challenge_comment((v_post->>'id')::uuid);
    v_social := public.challenge_social('11111111-1111-4111-8111-111111111111');
    assert jsonb_array_length(v_social->'comments') = 0, 'comentário apagado some';
    perform public.zz_expect_error(format($q$select public.delete_challenge_comment(%L)$q$, v_post->>'id'), 'comment_not_found');

    -- Quem saiu não aparece; quem está fora não lê nem escreve.
    perform public.zz_admin();
    insert into public.challenge_comments (challenge_id, fuel_log_id, user_id, body)
    values ('11111111-1111-4111-8111-111111111111', 'a3000000-0000-4000-8000-000000000002',
            'c0000000-0000-4000-8000-000000000001', 'da Carla, que saiu');
    perform public.zz_login('a0000000-0000-4000-8000-000000000001');
    v_social := public.challenge_social('11111111-1111-4111-8111-111111111111');
    assert jsonb_array_length(v_social->'comments') = 0, 'comentário de quem saiu não aparece';
    perform public.zz_login('e0000000-0000-4000-8000-000000000001');
    perform public.zz_expect_error($q$select public.challenge_social('11111111-1111-4111-8111-111111111111')$q$, 'not_a_member');
    perform public.zz_expect_error($q$select public.post_challenge_comment('11111111-1111-4111-8111-111111111111', 'a3000000-0000-4000-8000-000000000002', 'oi')$q$, 'not_a_member');
    perform public.zz_login('f0000000-0000-4000-8000-000000000001', true);
    perform public.zz_expect_error($q$select public.challenge_social('11111111-1111-4111-8111-111111111111')$q$, 'apple_account_required');

    -- Limite: 30 comentários na última hora.
    perform public.zz_admin();
    insert into public.challenge_comments (challenge_id, fuel_log_id, user_id, body)
    select '11111111-1111-4111-8111-111111111111', 'a3000000-0000-4000-8000-000000000002',
           'b0000000-0000-4000-8000-000000000001', 'oi ' || g
      from generate_series(1, 29) g;
    perform public.zz_login('b0000000-0000-4000-8000-000000000001');
    perform public.zz_expect_error($q$select public.post_challenge_comment('11111111-1111-4111-8111-111111111111', 'a3000000-0000-4000-8000-000000000002', 'mais um')$q$, 'too_many_comments');

    -- Tabelas fechadas.
    select count(*) into v_rows from public.challenge_comments;
    assert v_rows = 0, 'leitura direta de challenge_comments tinha que vir vazia';
    select count(*) into v_rows from public.challenge_reactions;
    assert v_rows = 0, 'leitura direta de challenge_reactions tinha que vir vazia';

    -- Quem criou aparece para a turma na lista.
    assert (select created_by_name from public.my_challenges()
             where id = '11111111-1111-4111-8111-111111111111') = 'Ana Souza', 'Criado por: Ana Souza';
    perform public.zz_admin();
end $$;

-- ---------- D8: palavrão, bloquear, esconder foto, trocar código, denunciar ----------
do $$
declare
    r record;
    v_social jsonb;
    v_post jsonb;
    v_a_member uuid;
    v_d_member uuid;
    v_b_member uuid;
    v_code text;
    v_rows integer;
begin
    -- Filtro: pega palavrão disfarçado, deixa palavra comum passar.
    assert public.challenge_is_offensive('P0rr4 véi'), 'p0rr4';
    assert public.challenge_is_offensive('CARALHOOO'), 'caralhooo';
    assert public.challenge_is_offensive('seu arrombado'), 'arrombado';
    assert public.challenge_is_offensive('Fodase'), 'fodase';
    assert public.challenge_is_offensive('what the fuck'), 'fuck';
    assert not public.challenge_is_offensive('Turma da serra'), 'turma da serra';
    assert not public.challenge_is_offensive('Cuidado com o carro, computador e macaco hidráulico'), 'palavras comuns';
    assert not public.challenge_is_offensive('Ana Paula'), 'nome';

    select id into v_a_member from public.challenge_members
     where challenge_id = '11111111-1111-4111-8111-111111111111' and user_id = 'a0000000-0000-4000-8000-000000000001';
    select id into v_d_member from public.challenge_members
     where challenge_id = '11111111-1111-4111-8111-111111111111' and user_id = 'd0000000-0000-4000-8000-000000000001';
    select id into v_b_member from public.challenge_members
     where challenge_id = '11111111-1111-4111-8111-111111111111' and user_id = 'b0000000-0000-4000-8000-000000000001';

    perform public.zz_login('e0000000-0000-4000-8000-000000000001');
    perform public.zz_expect_error($q$select public.create_challenge('Turma do caralho', now(), now() + interval '7 days', 'Edu', 'America/Sao_Paulo')$q$, 'inappropriate_text');
    perform public.zz_expect_error($q$select public.create_challenge('Turma da serra', now(), now() + interval '7 days', 'Fdp', 'America/Sao_Paulo')$q$, 'inappropriate_text');
    perform public.zz_login('d0000000-0000-4000-8000-000000000001');
    perform public.zz_expect_error($q$select public.post_challenge_comment('11111111-1111-4111-8111-111111111111', 'a3000000-0000-4000-8000-000000000002', 'que merda')$q$, 'inappropriate_text');
    v_post := public.post_challenge_comment('11111111-1111-4111-8111-111111111111', 'a3000000-0000-4000-8000-000000000002', 'Foto linda');

    -- Bloqueio: o Bruno bloqueia a Ana → fotos e comentários dela somem para ele.
    perform public.zz_login('a0000000-0000-4000-8000-000000000001');
    perform public.set_challenge_reaction('11111111-1111-4111-8111-111111111111', 'b3000000-0000-4000-8000-000000000001', '🔥');
    perform public.zz_login('b0000000-0000-4000-8000-000000000001');
    perform public.set_member_blocked('11111111-1111-4111-8111-111111111111', v_a_member, true);
    select * into r from public.challenge_entries('11111111-1111-4111-8111-111111111111')
     where fuel_log_id = 'a3000000-0000-4000-8000-000000000002';
    assert r.odometer_photo_path is null and r.km is not null, format('bloqueado: sem foto, km fica: %s', row_to_json(r));
    assert not public.can_view_challenge_photo('a1000000-0000-4000-8000-000000000001/A3000000-0000-4000-8000-000000000002.jpg'),
        'bloqueou = não baixa a foto';
    v_social := public.challenge_social('11111111-1111-4111-8111-111111111111');
    assert v_social->'blocked_members' = jsonb_build_array(v_a_member), format('bloqueados: %s', v_social->'blocked_members');
    assert jsonb_array_length(v_social->'reactions') = 0, 'reação de quem bloqueou some';
    assert (select count(*) from public.challenge_leaderboard('11111111-1111-4111-8111-111111111111')) = 3,
        'classificação não muda';
    perform public.zz_expect_error(format($q$select public.set_member_blocked('11111111-1111-4111-8111-111111111111', %L, true)$q$,
        v_b_member), 'cannot_block_self');
    perform public.zz_expect_error($q$select public.set_member_blocked('11111111-1111-4111-8111-111111111111', gen_random_uuid(), true)$q$, 'member_not_found');
    -- A Ana (bloqueada) segue vendo tudo do Bruno.
    perform public.zz_login('a0000000-0000-4000-8000-000000000001');
    assert public.can_view_challenge_photo('b1000000-0000-4000-8000-000000000001/B3000000-0000-4000-8000-000000000001-challenge.jpg'),
        'bloqueio é de mão única';
    perform public.zz_login('b0000000-0000-4000-8000-000000000001');
    perform public.set_member_blocked('11111111-1111-4111-8111-111111111111', v_a_member, false);
    assert public.can_view_challenge_photo('a1000000-0000-4000-8000-000000000001/A3000000-0000-4000-8000-000000000002.jpg'),
        'desbloqueou = vê de novo';

    -- Esconder foto: só quem criou (Ana); some para a turma, o dono vê a dele.
    perform public.zz_expect_error($q$select public.set_challenge_photo_hidden('11111111-1111-4111-8111-111111111111', 'b3000000-0000-4000-8000-000000000001', true)$q$, 'not_the_creator');
    perform public.zz_login('a0000000-0000-4000-8000-000000000001');
    perform public.set_challenge_photo_hidden('11111111-1111-4111-8111-111111111111', 'b3000000-0000-4000-8000-000000000001', true);
    perform public.zz_login('d0000000-0000-4000-8000-000000000001');
    select * into r from public.challenge_entries('11111111-1111-4111-8111-111111111111')
     where fuel_log_id = 'b3000000-0000-4000-8000-000000000001';
    assert r.challenge_photo_path is null and r.odometer_photo_path is not null, format('escondida: %s', row_to_json(r));
    assert not public.can_view_challenge_photo('b1000000-0000-4000-8000-000000000001/B3000000-0000-4000-8000-000000000001-challenge.jpg'),
        'escondida = não baixa';
    assert public.can_view_challenge_photo('b1000000-0000-4000-8000-000000000001/B3000000-0000-4000-8000-000000000001.jpg'),
        'o hodômetro continua';
    v_social := public.challenge_social('11111111-1111-4111-8111-111111111111');
    assert v_social->'hidden_photos' = '["b3000000-0000-4000-8000-000000000001"]'::jsonb, format('escondidas: %s', v_social->'hidden_photos');
    perform public.zz_login('b0000000-0000-4000-8000-000000000001');
    select * into r from public.challenge_entries('11111111-1111-4111-8111-111111111111')
     where fuel_log_id = 'b3000000-0000-4000-8000-000000000001';
    assert r.challenge_photo_path is not null, 'o dono segue vendo a foto dele';
    perform public.zz_login('a0000000-0000-4000-8000-000000000001');
    perform public.set_challenge_photo_hidden('11111111-1111-4111-8111-111111111111', 'b3000000-0000-4000-8000-000000000001', false);

    -- Trocar código: só quem criou; o antigo para de valer.
    perform public.zz_login('b0000000-0000-4000-8000-000000000001');
    perform public.zz_expect_error($q$select public.rotate_invite_code('11111111-1111-4111-8111-111111111111')$q$, 'not_the_creator');
    perform public.zz_login('a0000000-0000-4000-8000-000000000001');
    v_code := public.rotate_invite_code('11111111-1111-4111-8111-111111111111');
    assert v_code <> 'K7QM4XPR' and v_code ~ '^[BCDFGHJKMNPQRSTVWXYZ2-9]{8}$', format('código novo: %s', v_code);
    assert public.challenge_preview('K7QM4XPR') is null, 'código antigo não acha mais';
    assert (public.challenge_preview(v_code))->>'name' = 'Turma da serra', 'código novo acha';

    -- Denunciar: nome, foto, comentário; nunca o próprio; sem capa = inválido.
    perform public.zz_login('b0000000-0000-4000-8000-000000000001');
    perform public.report_challenge_content('11111111-1111-4111-8111-111111111111', 'name', v_d_member);
    perform public.report_challenge_content('11111111-1111-4111-8111-111111111111', 'comment', (v_post->>'id')::uuid);
    perform public.zz_login('a0000000-0000-4000-8000-000000000001');
    perform public.report_challenge_content('11111111-1111-4111-8111-111111111111', 'photo', 'b3000000-0000-4000-8000-000000000001');
    perform public.zz_expect_error(format($q$select public.report_challenge_content('11111111-1111-4111-8111-111111111111', 'name', %L)$q$, v_a_member), 'invalid_report');
    perform public.zz_expect_error($q$select public.report_challenge_content('11111111-1111-4111-8111-111111111111', 'cover', null)$q$, 'invalid_report');
    perform public.zz_expect_error($q$select public.report_challenge_content('11111111-1111-4111-8111-111111111111', 'spam', null)$q$, 'invalid_report');
    perform public.zz_admin();
    select count(*) into v_rows from public.challenge_reports where challenge_id = '11111111-1111-4111-8111-111111111111';
    assert v_rows = 3, format('3 denúncias, veio %s', v_rows);
    assert (select snapshot from public.challenge_reports where kind = 'comment') = 'Foto linda', 'guarda o texto denunciado';
    assert (select snapshot from public.challenge_reports where kind = 'name') = 'Diego', 'guarda o nome denunciado';
    -- Limite: 20 por hora.
    insert into public.challenge_reports (challenge_id, reporter_id, kind, snapshot)
    select '11111111-1111-4111-8111-111111111111', 'b0000000-0000-4000-8000-000000000001', 'cover', 'x'
      from generate_series(1, 18);
    perform public.zz_login('b0000000-0000-4000-8000-000000000001');
    perform public.zz_expect_error(format($q$select public.report_challenge_content('11111111-1111-4111-8111-111111111111', 'name', %L)$q$, v_d_member), 'too_many_reports');

    -- Tabelas fechadas.
    select count(*) into v_rows from public.challenge_reports;
    assert v_rows = 0, 'leitura direta de challenge_reports tinha que vir vazia';
    select count(*) into v_rows from public.challenge_blocks;
    assert v_rows = 0, 'leitura direta de challenge_blocks tinha que vir vazia';
    -- Os testes seguintes usam o código original.
    perform public.zz_admin();
    update public.challenges set invite_code = 'K7QM4XPR' where id = '11111111-1111-4111-8111-111111111111';
end $$;

-- ---------- criar, prévia, entrar, sair, remover, capa ----------
do $$
declare
    v_new jsonb;
    v_id uuid;
    v_code text;
    v_preview jsonb;
    v_member_b uuid;
    v_member_a uuid;
    v_rows integer;
    v_i integer;
begin
    -- Sessão anônima não cria nem entra.
    perform public.zz_login('f0000000-0000-4000-8000-000000000001', true);
    perform public.zz_expect_error($q$select public.create_challenge('X', now(), now() + interval '7 days', 'N')$q$, 'apple_account_required');

    -- Criar: nome limpo, código no formato, quem cria entra.
    perform public.zz_login('a0000000-0000-4000-8000-000000000001');
    v_new := public.create_challenge('  Turma   do   litoral ', now(), now() + interval '7 days', ' Ana ');
    v_id := (v_new ->> 'id')::uuid;
    v_code := v_new ->> 'invite_code';
    assert v_code ~ '^[BCDFGHJKMNPQRSTVWXYZ2-9]{8}$', 'código fora do padrão: ' || v_code;
    assert (select name from public.my_challenges() where id = v_id) = 'Turma do litoral', 'nome não foi limpo';
    assert (select created_by_me and member_count = 1 from public.my_challenges() where id = v_id), 'quem cria entra';
    perform public.zz_expect_error($q$select public.create_challenge('   ', now(), now() + interval '7 days', 'Ana')$q$, 'invalid_name');
    perform public.zz_expect_error($q$select public.create_challenge('X', now(), now() - interval '1 day', 'Ana')$q$, 'invalid_period');
    perform public.zz_expect_error($q$select public.create_challenge('X', now() - interval '10 days', now(), 'Ana')$q$, 'invalid_period');
    perform public.zz_expect_error($q$select public.create_challenge('X', now(), now() + interval '7 days', 'Ana', 'Marte/Olimpo')$q$, 'invalid_period');

    -- Prévia com sessão anônima; o código aceita minúsculas e hífen.
    perform public.zz_login('f0000000-0000-4000-8000-000000000001', true);
    v_preview := public.challenge_preview(lower(substr(v_code, 1, 4) || '-' || substr(v_code, 5)));
    assert v_preview ->> 'name' = 'Turma do litoral' and v_preview ->> 'created_by_name' = 'Ana'
       and (v_preview ->> 'member_count')::int = 1 and not (v_preview ->> 'is_member')::boolean,
        format('prévia: %s', v_preview);
    assert public.challenge_preview('BBBBBBBB') is null, 'código errado = null';
    assert public.can_view_challenge_cover(v_id::text || '/cover.jpg'), 'quem acertou o código vê a capa';
    perform public.zz_expect_error(format('select public.join_challenge(%L, %L)', v_code, 'N'), 'apple_account_required');

    -- Entrar (de novo = mesmo resultado).
    perform public.zz_login('b0000000-0000-4000-8000-000000000001');
    assert (public.join_challenge(v_code, 'Bruno') ->> 'id')::uuid = v_id, 'entrar';
    assert (public.join_challenge(v_code, 'Bruno') ->> 'id')::uuid = v_id, 'entrar de novo';
    assert (select member_count from public.my_challenges() where id = v_id) = 2, 'duas pessoas';
    select member_id into v_member_b from public.challenge_leaderboard(v_id) where is_me;

    -- Cheio.
    perform public.zz_admin();
    update public.challenges set max_members = 2 where id = v_id;
    perform public.zz_login('d0000000-0000-4000-8000-000000000001');
    perform public.zz_expect_error(format('select public.join_challenge(%L, %L)', v_code, 'Diego'), 'challenge_full');
    perform public.zz_admin();
    update public.challenges set max_members = 50 where id = v_id;

    -- Sair e voltar: mesmo participante.
    perform public.zz_login('b0000000-0000-4000-8000-000000000001');
    perform public.leave_challenge(v_id);
    assert not exists (select 1 from public.my_challenges() where id = v_id), 'saiu = some da lista';
    perform public.zz_expect_error(format('select public.leave_challenge(%L)', v_id), 'not_a_member');
    perform public.join_challenge(v_code, 'Bruno B.');
    assert (select member_id from public.challenge_leaderboard(v_id) where is_me) = v_member_b, 'voltou com o mesmo id';
    assert (select display_name from public.challenge_leaderboard(v_id) where is_me) = 'Bruno B.', 'nome novo ao voltar';

    -- Remover: só quem criou, nunca a si mesmo; removido não volta.
    perform public.zz_login('a0000000-0000-4000-8000-000000000001');
    select member_id into v_member_a from public.challenge_leaderboard(v_id) where is_me;
    perform public.zz_login('b0000000-0000-4000-8000-000000000001');
    perform public.zz_expect_error(format('select public.remove_member(%L, %L)', v_id, v_member_a), 'not_the_creator');
    perform public.zz_login('a0000000-0000-4000-8000-000000000001');
    perform public.zz_expect_error(format('select public.remove_member(%L, %L)', v_id, v_member_a), 'cannot_remove_self');
    perform public.remove_member(v_id, v_member_b);
    select count(*) into v_rows from public.challenge_leaderboard(v_id);
    assert v_rows = 1, 'removido sai da classificação';
    perform public.zz_login('b0000000-0000-4000-8000-000000000001');
    perform public.zz_expect_error(format('select public.join_challenge(%L, %L)', v_code, 'Bruno'), 'removed_from_challenge');

    -- Capa: só quem criou, path na pasta do desafio.
    perform public.zz_expect_error(format('select public.set_challenge_cover(%L, %L)', v_id, v_id::text || '/cover.jpg'), 'not_the_creator');
    assert not public.can_edit_challenge_cover(v_id::text || '/cover.jpg'), 'só quem criou grava a capa';
    perform public.zz_login('a0000000-0000-4000-8000-000000000001');
    perform public.set_challenge_cover(v_id, v_id::text || '/cover.jpg');
    assert (select cover_path from public.my_challenges() where id = v_id) = v_id::text || '/cover.jpg', 'capa gravada';
    perform public.zz_expect_error(format('select public.set_challenge_cover(%L, %L)', v_id, 'outro/cover.jpg'), 'invalid_cover_path');
    assert public.can_edit_challenge_cover(v_id::text || '/cover.jpg'), 'quem criou grava a capa';
    assert public.can_view_challenge_cover(v_id::text || '/cover.jpg'), 'membro vê a capa';
    perform public.zz_login('e0000000-0000-4000-8000-000000000001');
    assert not public.can_view_challenge_cover(v_id::text || '/cover.jpg'), 'sem código não vê a capa';

    -- Desafio encerrado não aceita entrada.
    perform public.zz_expect_error($q$select public.join_challenge('K7QM4XPR', 'Eva')$q$, 'challenge_ended');

    -- Força bruta: 10 códigos errados por hora, depois trava.
    for v_i in 1..10 loop
        assert public.challenge_preview('BBBBBBB' || v_i % 8 + 2) is null, 'código errado = null';
    end loop;
    perform public.zz_expect_error($q$select public.challenge_preview('CCCCCCCC')$q$, 'too_many_attempts');

    -- Tabelas fechadas: nem membro lê direto (só pelas funções).
    perform public.zz_login('a0000000-0000-4000-8000-000000000001');
    select count(*) into v_rows from public.challenge_members;
    assert v_rows = 0, 'leitura direta de challenge_members tinha que vir vazia';
    select count(*) into v_rows from public.challenges;
    assert v_rows = 0, 'leitura direta de challenges tinha que vir vazia';
    -- Funções internas não abrem para o app.
    perform public.zz_expect_error($q$select * from public.challenge_scores('11111111-1111-4111-8111-111111111111')$q$,
        'permission denied for function challenge_scores');

    -- Apagar a conta tira a pessoa do desafio.
    perform public.zz_admin();
    delete from auth.users where id = 'a0000000-0000-4000-8000-000000000001';
    assert (select created_by from public.challenges where id = v_id) is null, 'desafio segue sem dono';
    assert not exists (select 1 from public.challenge_members
                        where user_id = 'a0000000-0000-4000-8000-000000000001'), 'participação apagada';
end $$;

-- Código: 500 sorteios, todos no alfabeto.
do $$
begin
    assert (select bool_and(c ~ '^[BCDFGHJKMNPQRSTVWXYZ2-9]{8}$') and count(distinct c) = 500
              from (select public.challenge_new_invite_code() as c from generate_series(1, 500)) s),
        'código sorteado fora do padrão ou repetido';
end $$;

select 'ok' as result;
rollback;
