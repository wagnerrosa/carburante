-- Carburante — Desafios em grupo (D1, ver PLAN/desafios.md)
-- Rodar DEPOIS do schema.sql (usa fuel_logs/motorcycles e as colunas
-- fuel_logs.odometer_photo_source/challenge_photo_url). Idempotente: pode
-- rodar de novo. Testes: supabase/tests/challenges_test.sql.
--
-- Decisões:
-- - Desafio é ONLINE (sem SwiftData): o app lê e escreve só por funções (RPC).
--   As tabelas têm RLS ligado e NENHUMA policy → acesso direto negado; as
--   funções SECURITY DEFINER validam e devolvem só o que a turma pode ver.
-- - Ninguém lê fuel_logs de outra pessoa. Classificação, mural e registros do
--   participante saem de `challenge_scores` (regra do km) — nunca litros,
--   valor nem local.
-- - O participante é identificado por `challenge_members.id` (member_id),
--   nunca pelo user_id (a turma não vê o id da conta).
-- - Tudo exige conta Apple (sessão anônima recusada), menos a prévia do
--   convite (quem chega pelo link ainda é anônimo).
-- - Erros: `raise exception '<chave>'`, chaves ASCII congeladas que o app
--   traduz: no_session, apple_account_required, invalid_name, invalid_period,
--   challenge_not_found, not_a_member, not_the_creator, challenge_full,
--   challenge_ended, removed_from_challenge, cannot_remove_self,
--   too_many_attempts, invalid_cover_path; D7: entry_not_found,
--   invalid_comment, too_many_comments, comment_not_found,
--   cannot_delete_comment, cannot_react_own, invalid_reaction,
--   cannot_vote_own, no_photo_to_check, invalid_vote; D8: inappropriate_text,
--   member_not_found, cannot_block_self, invalid_report, too_many_reports.
--   Código de convite errado NÃO é
--   exceção: devolve null (a exceção desfaria o registro da tentativa, e o
--   limite contra força bruta conta as tentativas).

-- ---------- challenges ----------
-- Período = [starts_at, ends_at): o app manda o início do 1º dia e o início do
-- dia seguinte ao último, no fuso `time_zone`. A classificação fecha 3 dias
-- depois do fim (tempo de registrar o abastecimento que cobre os últimos dias)
-- e congela em challenge_members.final_* (`finalized_at`).
create table if not exists public.challenges (
    id            uuid primary key default gen_random_uuid(),
    name          text not null check (char_length(name) between 1 and 40),
    -- Chave congelada; só 'km' na v1.
    metric        text not null default 'km',
    starts_at     timestamptz not null,
    ends_at       timestamptz not null,
    time_zone     text not null default 'America/Sao_Paulo',
    -- Conta apagada: o desafio segue sem dono.
    created_by    uuid references auth.users (id) on delete set null,
    -- 8 caracteres sem vogais (não forma palavra) e sem 0/1/L (InviteCode no app).
    invite_code   text not null unique check (invite_code ~ '^[BCDFGHJKMNPQRSTVWXYZ2-9]{8}$'),
    -- Path no bucket challenge-covers ("<challenge_id>/cover.jpg"); nulo = capa padrão.
    cover_path    text,
    max_members   integer not null default 50,
    finalized_at  timestamptz,
    created_at    timestamptz not null default now(),
    deleted_at    timestamptz,
    check (ends_at > starts_at)
);
create index if not exists challenges_created_by_idx on public.challenges (created_by);

-- ---------- challenge_members ----------
-- Saiu = left_at; removido por quem criou = left_at + removed_at (não volta).
-- Voltar depois de sair reusa a linha (mesmo member_id).
create table if not exists public.challenge_members (
    challenge_id    uuid not null references public.challenges (id) on delete cascade,
    user_id         uuid not null references auth.users (id) on delete cascade,
    id              uuid not null unique default gen_random_uuid(),
    display_name    text not null check (char_length(display_name) between 1 and 30),
    joined_at       timestamptz not null default now(),
    left_at         timestamptz,
    removed_at      timestamptz,
    removed_by      uuid references auth.users (id) on delete set null,
    -- Classificação congelada no fechamento (edição/exclusão depois não mexe).
    final_km        double precision,
    final_fuel_ups  integer,
    primary key (challenge_id, user_id)
);
create index if not exists challenge_members_user_id_idx on public.challenge_members (user_id);

-- ---------- challenge_code_attempts ----------
-- Cada código tentado (prévia ou entrada). Errado = challenge_id nulo → conta
-- para o limite. Certo = guarda o desafio → libera ver a capa antes de entrar.
create table if not exists public.challenge_code_attempts (
    id            bigint generated always as identity primary key,
    user_id       uuid not null references auth.users (id) on delete cascade,
    challenge_id  uuid references public.challenges (id) on delete cascade,
    attempted_at  timestamptz not null default now()
);
create index if not exists challenge_code_attempts_user_idx
    on public.challenge_code_attempts (user_id, attempted_at);
create index if not exists challenge_code_attempts_failed_idx
    on public.challenge_code_attempts (attempted_at) where challenge_id is null;
create index if not exists challenge_code_attempts_challenge_idx
    on public.challenge_code_attempts (challenge_id, user_id) where challenge_id is not null;

alter table public.challenges              enable row level security;
alter table public.challenge_members       enable row level security;
alter table public.challenge_code_attempts enable row level security;
-- Sem policies de propósito: só as funções abaixo leem e escrevem.

-- ---------- funções internas (não expostas ao app) ----------

-- Id da conta que chamou; recusa sem sessão e sessão anônima.
create or replace function public.challenge_require_account()
returns uuid
language plpgsql
stable
set search_path = ''
as $$
declare
    v_uid uuid := auth.uid();
begin
    if v_uid is null then
        raise exception 'no_session';
    end if;
    if coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) then
        raise exception 'apple_account_required';
    end if;
    return v_uid;
end;
$$;

-- member_id de quem chamou, se está no desafio (e o desafio existe).
create or replace function public.challenge_require_member(p_challenge_id uuid, p_uid uuid)
returns uuid
language plpgsql
stable
set search_path = ''
as $$
declare
    v_member uuid;
begin
    if not exists (select 1 from public.challenges
                    where id = p_challenge_id and deleted_at is null) then
        raise exception 'challenge_not_found';
    end if;
    select id into v_member from public.challenge_members
     where challenge_id = p_challenge_id and user_id = p_uid and left_at is null;
    if v_member is null then
        raise exception 'not_a_member';
    end if;
    return v_member;
end;
$$;

-- Nome do desafio ou do participante: sem espaço sobrando, dentro do limite.
create or replace function public.challenge_clean_name(p_text text, p_max integer)
returns text
language plpgsql
immutable
set search_path = ''
as $$
declare
    v text := btrim(regexp_replace(coalesce(p_text, ''), '\s+', ' ', 'g'));
begin
    if char_length(v) not between 1 and p_max then
        raise exception 'invalid_name';
    end if;
    if public.challenge_is_offensive(v) then
        raise exception 'inappropriate_text';
    end if;
    return v;
end;
$$;

-- Filtro de palavrão (D8, diretriz 1.2 da Apple) para nomes e comentários:
-- palavrões fortes, ofensas e termos preconceituosos, PT e EN. Compara palavra
-- inteira depois de tirar acento, trocar número/símbolo por letra (p0rr4) e
-- juntar letra repetida (porraaa → pora; a lista já vem assim). Palavra comum
-- que só lembra um palavrão (macaco, veado, pica-pau) fica de fora — o resto é
-- com a denúncia.
create or replace function public.challenge_is_offensive(p_text text)
returns boolean
language plpgsql
immutable
set search_path = ''
as $$
declare
    v text := lower(coalesce(p_text, ''));
    words constant text[] := array[
        'pora', 'porinha', 'caralh\w*', 'caraio', 'krl', 'buceta', 'boceta', 'xoxota', 'xota',
        'xereca', 'piroca', 'fod[aeiou]\w*', 'fdp', 'vsf', 'tnc', 'pqp', 'puta', 'putaria',
        'puteiro', 'cu', 'cuzao', 'cuzinho', 'arombad[ao]', 'viad[ao]', 'viadinho', 'bicha',
        'sapatao', 'traveco', 'boiola', 'crioul[ao]', 'retardad[ao]', 'vagabund[ao]', 'vadia',
        'corno', 'merda',
        'fuck\w*', 'motherfuck\w*', 'shit\w*', 'bitch\w*', 'cunt', 'nig(ers?|as?)',
        'fagot\w*', 'whore', 'slut'];
begin
    v := translate(v, 'áàâãäéèêëíìîïóòôõöúùûüç', 'aaaaaeeeeiiiiooooouuuuc');
    v := translate(v, '0134578@$!', 'oieastbasi');
    v := regexp_replace(v, '(.)\1+', '\1', 'g');
    return v ~ ('\m(' || array_to_string(words, '|') || ')\M');
end;
$$;

-- Código novo: 8 sorteios com gerador criptográfico, sem viés (descarta byte
-- ≥ 252 = 9 × 28). 28⁸ ≈ 380 bilhões de combinações.
create or replace function public.challenge_new_invite_code()
returns text
language plpgsql
volatile
set search_path = ''
as $$
declare
    alphabet constant text := 'BCDFGHJKMNPQRSTVWXYZ23456789';
    v_code text;
    v_byte integer;
begin
    loop
        v_code := '';
        while char_length(v_code) < 8 loop
            v_byte := get_byte(extensions.gen_random_bytes(1), 0);
            if v_byte < 252 then
                v_code := v_code || substr(alphabet, 1 + v_byte % 28, 1);
            end if;
        end loop;
        exit when not exists (select 1 from public.challenges where invite_code = v_code);
    end loop;
    return v_code;
end;
$$;

-- Acha o desafio pelo código digitado (minúsculas, hífen e espaço valem) e
-- registra a tentativa. Limite: 10 erradas por hora por conta e 300 por minuto
-- no total (sessão anônima se cria à vontade). Errado = null.
create or replace function public.challenge_lookup_code(p_code text, p_uid uuid)
returns uuid
language plpgsql
volatile
set search_path = ''
as $$
declare
    v_code text := upper(regexp_replace(coalesce(p_code, ''), '[^A-Za-z0-9]', '', 'g'));
    v_id uuid;
begin
    if (select count(*) from public.challenge_code_attempts
         where user_id = p_uid and challenge_id is null
           and attempted_at > now() - interval '1 hour') >= 10
       or (select count(*) from public.challenge_code_attempts
            where challenge_id is null
              and attempted_at > now() - interval '1 minute') >= 300 then
        raise exception 'too_many_attempts';
    end if;
    select id into v_id from public.challenges
     where invite_code = v_code and deleted_at is null;
    insert into public.challenge_code_attempts (user_id, challenge_id) values (p_uid, v_id);
    -- Faxina: tentativa errada só importa na última hora.
    delete from public.challenge_code_attempts
     where challenge_id is null and attempted_at < now() - interval '1 day';
    return v_id;
end;
$$;

-- ---------- regra do km (o coração — PLAN/desafios.md §"Regra do km") ----------
-- Um registro por abastecimento dos participantes ativos, com o km que ele
-- somou ao desafio e o porquê. Cada moto do participante é uma fila por
-- hodômetro (como o ConsumptionCalculator do app):
-- - Histórico (registrado mais de 7 dias de calendário depois, a partir de
--   28/09/2026 — EventProvenance) fica de fora, nem como ponta de trecho.
-- - Ponta de trecho = registro na hora COM foto do hodômetro já no Storage
--   (referência remota "<moto>/<log>.jpg"; local pendente não tem "/").
-- - Trecho = de uma ponta à seguinte. Registro sem foto no meio não é ponta:
--   os km passam para a próxima foto e os litros dele entram no teto.
-- - Lacuna (missed_previous) em qualquer registro do trecho → não conta.
-- - Mais de 80 km por litro abastecido no trecho → impossível, não conta.
-- - Toda ponta vira a âncora do trecho seguinte (contando ou não).
-- - Primeira ponta da moto = só início.
-- - O km do trecho é espalhado em linha reta entre as duas datas e só conta a
--   parte dentro do período (como spreadDistance). Datas fora de ordem: o km
--   inteiro cai na data do fim.
-- - Registro criado depois do fechamento (fim + 3 dias) não existe para o desafio.
-- - Moto apagada e registro apagado ficam de fora. Todas as motos somam.
-- Status (chaves congeladas): start, counted, no_photo, historical, gap, impossible.
create or replace function public.challenge_scores(p_challenge_id uuid)
returns table (
    member_id              uuid,
    fuel_log_id            uuid,
    motorcycle_id          uuid,
    date                   timestamptz,
    odometer               double precision,
    status                 text,
    km                     double precision,
    in_period              boolean,
    eligible               boolean,
    odometer_photo_path    text,
    odometer_photo_source  text,
    challenge_photo_path   text
)
language sql
stable
security definer
set search_path = ''
as $$
    with c as (
        select ch.starts_at, ch.ends_at, ch.ends_at + interval '3 days' as closes_at, ch.time_zone
          from public.challenges ch
         where ch.id = p_challenge_id
    ),
    logs as (
        select cm.id as member_id, fl.id, fl.motorcycle_id, fl.date, fl.odometer, fl.liters,
               fl.missed_previous, fl.odometer_photo_source,
               case when fl.odometer_photo_url like '%/%' then fl.odometer_photo_url end as photo,
               case when fl.challenge_photo_url like '%/%' then fl.challenge_photo_url end as challenge_photo,
               (fl.created_at >= timestamptz '2026-09-28 03:00:00+00'
                and (fl.created_at at time zone c.time_zone)::date
                    - (fl.date at time zone c.time_zone)::date > 7) as historical,
               (fl.date >= c.starts_at and fl.date < c.ends_at) as in_period,
               c.starts_at, c.ends_at
          from c
          join public.challenge_members cm
            on cm.challenge_id = p_challenge_id and cm.left_at is null
          join public.fuel_logs fl
            on fl.user_id = cm.user_id and fl.deleted_at is null and fl.created_at < c.closes_at
          join public.motorcycles mo
            on mo.id = fl.motorcycle_id and mo.deleted_at is null
    ),
    -- Só registros na hora formam trechos. grp = quantas pontas vêm antes:
    -- a ponta P(i) e os registros sem foto entre P(i-1) e P(i) dividem o grp.
    live as (
        select l.*,
               coalesce(count(*) filter (where l.photo is not null) over (
                   partition by l.member_id, l.motorcycle_id
                   order by l.odometer, l.date, l.id
                   rows between unbounded preceding and 1 preceding), 0) as grp
          from logs l
         where not l.historical
    ),
    segs as (
        select s.member_id, s.motorcycle_id, s.grp,
               sum(s.liters) as liters, bool_or(s.missed_previous) as gap
          from live s
         group by s.member_id, s.motorcycle_id, s.grp
    ),
    points as (
        select p.*,
               lag(p.odometer) over w as prev_odometer,
               lag(p.date) over w as prev_date
          from live p
         where p.photo is not null
        window w as (partition by p.member_id, p.motorcycle_id order by p.odometer, p.date, p.id)
    ),
    judged as (
        select p.id,
               p.odometer - p.prev_odometer as distance,
               p.prev_date, p.date, p.in_period, p.starts_at, p.ends_at,
               case
                   when p.prev_odometer is null then 'start'
                   when s.gap then 'gap'
                   when p.odometer - p.prev_odometer > 80 * s.liters then 'impossible'
                   else 'counted'
               end as status
          from points p
          join segs s
            on s.member_id = p.member_id and s.motorcycle_id = p.motorcycle_id and s.grp = p.grp
    ),
    scored as (
        select j.id, j.status,
               case
                   when j.status <> 'counted' then 0::double precision
                   when j.date <= j.prev_date then
                       case when j.in_period then j.distance else 0 end
                   else j.distance * greatest(0::double precision,
                            extract(epoch from least(j.date, j.ends_at) - greatest(j.prev_date, j.starts_at))::double precision)
                        / extract(epoch from j.date - j.prev_date)::double precision
               end as km
          from judged j
    )
    select l.member_id, l.id, l.motorcycle_id, l.date, l.odometer,
           case when l.historical then 'historical'
                when l.photo is null then 'no_photo'
                else s.status end,
           coalesce(s.km, 0),
           l.in_period,
           (not l.historical and l.photo is not null),
           l.photo, l.odometer_photo_source, l.challenge_photo
      from logs l
      left join scored s on s.id = l.id;
$$;

-- Fecha a classificação na 1ª leitura depois de fim + 3 dias: grava o km e os
-- abastecimentos de cada um em challenge_members.final_*. Daí em diante editar
-- ou apagar registro antigo não muda o resultado.
create or replace function public.challenge_finalize_if_closed(p_challenge_id uuid)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
begin
    -- Trava a linha: duas leituras ao mesmo tempo não fecham duas vezes.
    perform 1 from public.challenges
      where id = p_challenge_id and finalized_at is null
        and now() >= ends_at + interval '3 days'
      for update;
    if not found then
        return;
    end if;
    update public.challenge_members cm
       set final_km = coalesce(t.km, 0), final_fuel_ups = coalesce(t.fuel_ups, 0)
      from public.challenge_members m
      left join (
          select s.member_id,
                 round(sum(s.km)::numeric, 1)::double precision as km,
                 (count(*) filter (where s.in_period and s.eligible))::integer as fuel_ups
            from public.challenge_scores(p_challenge_id) s
           group by s.member_id
      ) t on t.member_id = m.id
     where cm.id = m.id and m.challenge_id = p_challenge_id and m.left_at is null;
    update public.challenges set finalized_at = now() where id = p_challenge_id;
end;
$$;

-- ---------- funções do app ----------

-- Cria o desafio; quem cria entra junto. Devolve {id, invite_code}.
-- Limite de criação (grátis = 1 ativo) é checado no app (Premium só no aparelho).
create or replace function public.create_challenge(
    p_name          text,
    p_starts_at     timestamptz,
    p_ends_at       timestamptz,
    p_display_name  text,
    p_time_zone     text default 'America/Sao_Paulo'
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
    v_uid uuid := public.challenge_require_account();
    v_name text := public.challenge_clean_name(p_name, 40);
    v_display text := public.challenge_clean_name(p_display_name, 30);
    v_id uuid;
    v_code text;
begin
    -- Começa hoje (em qualquer fuso) ou numa data escolhida; até 1 ano.
    if p_starts_at is null or p_ends_at is null
       or p_ends_at <= p_starts_at
       or p_starts_at < now() - interval '2 days'
       or p_starts_at > now() + interval '1 year'
       or p_ends_at - p_starts_at > interval '366 days'
       or not exists (select 1 from pg_catalog.pg_timezone_names where name = p_time_zone) then
        raise exception 'invalid_period';
    end if;
    v_code := public.challenge_new_invite_code();
    insert into public.challenges (name, starts_at, ends_at, time_zone, created_by, invite_code)
    values (v_name, p_starts_at, p_ends_at, p_time_zone, v_uid, v_code)
    returning id into v_id;
    insert into public.challenge_members (challenge_id, user_id, display_name)
    values (v_id, v_uid, v_display);
    return jsonb_build_object('id', v_id, 'invite_code', v_code);
end;
$$;

-- Prévia do convite (roda com sessão anônima: quem chega pelo link ainda não
-- tem conta Apple). Código errado = null. Mostra o que convence a entrar:
-- nome, capa, quem criou, quantos e os 3 primeiros nomes, datas.
create or replace function public.challenge_preview(p_code text)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
    v_uid uuid := auth.uid();
    v_id uuid;
    v_result jsonb;
begin
    if v_uid is null then
        raise exception 'no_session';
    end if;
    v_id := public.challenge_lookup_code(p_code, v_uid);
    if v_id is null then
        return null;
    end if;
    select jsonb_build_object(
               'id', ch.id,
               'name', ch.name,
               'starts_at', ch.starts_at,
               'ends_at', ch.ends_at,
               'time_zone', ch.time_zone,
               'cover_path', ch.cover_path,
               'created_by_name', (select m.display_name from public.challenge_members m
                                    where m.challenge_id = ch.id and m.user_id = ch.created_by
                                      and m.left_at is null),
               'member_count', (select count(*) from public.challenge_members m
                                 where m.challenge_id = ch.id and m.left_at is null),
               'member_names', coalesce((select jsonb_agg(n.display_name order by n.joined_at)
                                           from (select m.display_name, m.joined_at
                                                   from public.challenge_members m
                                                  where m.challenge_id = ch.id and m.left_at is null
                                                    and m.user_id is distinct from ch.created_by
                                                  order by m.joined_at
                                                  limit 3) n), '[]'::jsonb),
               'max_members', ch.max_members,
               'is_member', exists (select 1 from public.challenge_members m
                                     where m.challenge_id = ch.id and m.user_id = v_uid
                                       and m.left_at is null),
               'is_removed', exists (select 1 from public.challenge_members m
                                      where m.challenge_id = ch.id and m.user_id = v_uid
                                        and m.removed_at is not null),
               'has_ended', now() >= ch.ends_at)
      into v_result
      from public.challenges ch
     where ch.id = v_id;
    return v_result;
end;
$$;

-- Entra pelo código. Devolve {id} (já estava dentro = mesmo resultado);
-- código errado = null. Sair e voltar reusa a linha; removido não volta.
create or replace function public.join_challenge(p_code text, p_display_name text)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
    v_uid uuid := public.challenge_require_account();
    v_display text := public.challenge_clean_name(p_display_name, 30);
    v_id uuid;
    v_ch public.challenges;
    v_member public.challenge_members;
begin
    v_id := public.challenge_lookup_code(p_code, v_uid);
    if v_id is null then
        return null;
    end if;
    -- Trava o desafio: duas entradas ao mesmo tempo não furam o teto.
    select * into v_ch from public.challenges where id = v_id for update;
    select * into v_member from public.challenge_members
     where challenge_id = v_id and user_id = v_uid;
    if v_member.removed_at is not null then
        raise exception 'removed_from_challenge';
    end if;
    if v_member.user_id is not null and v_member.left_at is null then
        return jsonb_build_object('id', v_id);
    end if;
    if now() >= v_ch.ends_at then
        raise exception 'challenge_ended';
    end if;
    if (select count(*) from public.challenge_members
         where challenge_id = v_id and left_at is null) >= v_ch.max_members then
        raise exception 'challenge_full';
    end if;
    if v_member.user_id is not null then
        update public.challenge_members
           set left_at = null, display_name = v_display, joined_at = now()
         where challenge_id = v_id and user_id = v_uid;
    else
        insert into public.challenge_members (challenge_id, user_id, display_name)
        values (v_id, v_uid, v_display);
    end if;
    return jsonb_build_object('id', v_id);
end;
$$;

create or replace function public.leave_challenge(p_challenge_id uuid)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
    v_uid uuid := public.challenge_require_account();
begin
    perform public.challenge_require_member(p_challenge_id, v_uid);
    update public.challenge_members set left_at = now()
     where challenge_id = p_challenge_id and user_id = v_uid;
end;
$$;

-- Quem criou tira alguém da turma (removido não volta pelo código).
create or replace function public.remove_member(p_challenge_id uuid, p_member_id uuid)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
    v_uid uuid := public.challenge_require_account();
    v_me uuid := public.challenge_require_member(p_challenge_id, v_uid);
begin
    if not exists (select 1 from public.challenges
                    where id = p_challenge_id and created_by = v_uid) then
        raise exception 'not_the_creator';
    end if;
    if p_member_id = v_me then
        raise exception 'cannot_remove_self';
    end if;
    update public.challenge_members
       set left_at = coalesce(left_at, now()), removed_at = now(), removed_by = v_uid
     where challenge_id = p_challenge_id and id = p_member_id;
    if not found then
        raise exception 'not_a_member';
    end if;
end;
$$;

-- Quem criou põe, troca ou tira a capa (o arquivo sobe antes pelo Storage).
create or replace function public.set_challenge_cover(p_challenge_id uuid, p_cover_path text)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
    v_uid uuid := public.challenge_require_account();
begin
    if p_cover_path is not null
       and p_cover_path !~ ('^' || p_challenge_id::text || '/[A-Za-z0-9_-]+\.jpg$') then
        raise exception 'invalid_cover_path';
    end if;
    update public.challenges set cover_path = p_cover_path
     where id = p_challenge_id and created_by = v_uid and deleted_at is null;
    if not found then
        raise exception 'not_the_creator';
    end if;
end;
$$;

-- Meus desafios (aba Desafios): os que estou dentro, mais novo primeiro.
-- Sessão anônima = lista vazia (não é erro: a aba mostra o estado vazio).
-- created_by_name = nome de quem criou na turma (nulo se saiu ou apagou a
-- conta). D7 acrescentou a coluna: mudar o retorno exige drop + create.
drop function if exists public.my_challenges();
create function public.my_challenges()
returns table (
    id              uuid,
    name            text,
    starts_at       timestamptz,
    ends_at         timestamptz,
    time_zone       text,
    cover_path      text,
    invite_code     text,
    created_by_me   boolean,
    member_count    integer,
    finalized_at    timestamptz,
    created_by_name text
)
language sql
stable
security definer
set search_path = ''
as $$
    select ch.id, ch.name, ch.starts_at, ch.ends_at, ch.time_zone, ch.cover_path,
           ch.invite_code, coalesce(ch.created_by = auth.uid(), false),
           (select count(*) from public.challenge_members o
             where o.challenge_id = ch.id and o.left_at is null)::integer,
           ch.finalized_at,
           (select cr.display_name from public.challenge_members cr
             where cr.challenge_id = ch.id and cr.user_id = ch.created_by and cr.left_at is null)
      from public.challenge_members me
      join public.challenges ch on ch.id = me.challenge_id and ch.deleted_at is null
     where me.user_id = auth.uid() and me.left_at is null
     order by ch.ends_at desc, ch.created_at desc;
$$;

-- Classificação. Empate em km = mesma posição. bikes = motos com registro no
-- período (sem registro: as motos atuais, para a turma saber quem é quem).
create or replace function public.challenge_leaderboard(p_challenge_id uuid)
returns table (
    member_id      uuid,
    rank           integer,
    display_name   text,
    is_me          boolean,
    km             double precision,
    fuel_ups       integer,
    bikes          jsonb,
    last_entry_at  timestamptz
)
language plpgsql
volatile
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
    v_uid uuid := public.challenge_require_account();
begin
    perform public.challenge_require_member(p_challenge_id, v_uid);
    perform public.challenge_finalize_if_closed(p_challenge_id);
    return query
    with s as (
        select * from public.challenge_scores(p_challenge_id)
    ),
    totals as (
        select m.id as mid, m.display_name as dname, m.user_id = v_uid as me,
               case when ch.finalized_at is not null then coalesce(m.final_km, 0)
                    else round(coalesce((select sum(s.km) from s where s.member_id = m.id), 0)::numeric, 1)::double precision
               end as total_km,
               case when ch.finalized_at is not null then coalesce(m.final_fuel_ups, 0)
                    else (select count(*) from s where s.member_id = m.id and s.in_period and s.eligible)::integer
               end as total_fuel_ups,
               coalesce(
                   (select jsonb_agg(jsonb_build_object('make', b.make, 'model', b.model) order by b.n desc, b.model)
                      from (select mo.make, mo.model, count(*) as n
                              from s join public.motorcycles mo on mo.id = s.motorcycle_id
                             where s.member_id = m.id and s.in_period and s.status <> 'historical'
                             group by mo.id, mo.make, mo.model) b),
                   (select jsonb_agg(jsonb_build_object('make', mo.make, 'model', mo.model) order by mo.created_at)
                      from public.motorcycles mo
                     where mo.user_id = m.user_id and mo.deleted_at is null and mo.status <> 'sold'),
                   '[]'::jsonb) as bike_list,
               (select max(s.date) from s
                 where s.member_id = m.id and s.in_period and s.status <> 'historical') as last_at
          from public.challenge_members m
          join public.challenges ch on ch.id = m.challenge_id
         where m.challenge_id = p_challenge_id and m.left_at is null
    )
    select t.mid, (rank() over (order by t.total_km desc))::integer, t.dname, t.me,
           t.total_km, t.total_fuel_ups, t.bike_list, t.last_at
      from totals t
     order by 2, t.total_fuel_ups desc, t.dname;
end;
$$;

-- Abastecimentos da turma no período (mural; p_member_id nulo) ou de um
-- participante (registros dele). Inclui o abastecimento logo depois do fim que
-- fechou um trecho com km dentro do período. Mais novo primeiro.
create or replace function public.challenge_entries(p_challenge_id uuid, p_member_id uuid default null)
returns table (
    fuel_log_id            uuid,
    member_id              uuid,
    date                   timestamptz,
    make                   text,
    model                  text,
    odometer               double precision,
    status                 text,
    km                     double precision,
    odometer_photo_path    text,
    odometer_photo_source  text,
    challenge_photo_path   text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
    v_uid uuid := public.challenge_require_account();
    v_me uuid;
begin
    v_me := public.challenge_require_member(p_challenge_id, v_uid);
    -- D8: de quem você bloqueou, nenhuma foto; foto do desafio escondida por
    -- quem criou some para a turma (o dono segue vendo a dele).
    return query
    select s.fuel_log_id, s.member_id, s.date, mo.make, mo.model, s.odometer, s.status,
           round(s.km::numeric, 1)::double precision,
           case when blk.blocked then null else s.odometer_photo_path end,
           s.odometer_photo_source,
           case when blk.blocked or (hid.hidden and s.member_id <> v_me) then null
                else s.challenge_photo_path end
      from public.challenge_scores(p_challenge_id) s
      join public.motorcycles mo on mo.id = s.motorcycle_id
      join public.challenge_members om on om.id = s.member_id
      cross join lateral (select exists (select 1 from public.challenge_blocks b
                                          where b.blocker_id = v_uid and b.blocked_id = om.user_id)) blk(blocked)
      cross join lateral (select exists (select 1 from public.challenge_hidden_photos h
                                          where h.challenge_id = p_challenge_id
                                            and h.fuel_log_id = s.fuel_log_id)) hid(hidden)
     where (p_member_id is null or s.member_id = p_member_id)
       and (s.in_period or s.km > 0)
     order by s.date desc;
end;
$$;

-- ---------- D7: comentários, reações e votos na foto ----------
-- Por desafio: o mesmo abastecimento aparece em vários desafios e cada turma
-- vê só a sua conversa. Fechadas como as outras (RLS sem policy, só RPC).
-- Valem para o que a turma vê no mural: registro não apagado de quem está no
-- desafio, com data no período (até o fechamento) — a mesma janela das fotos.
create table if not exists public.challenge_comments (
    id            uuid primary key default gen_random_uuid(),
    challenge_id  uuid not null references public.challenges (id) on delete cascade,
    fuel_log_id   uuid not null references public.fuel_logs (id) on delete cascade,
    user_id       uuid not null references auth.users (id) on delete cascade,
    -- O app corta em 200 caracteres visíveis; um emoji de família são vários
    -- code points — a folga evita recusar o que o app aceitou.
    body          text not null check (char_length(body) between 1 and 400),
    created_at    timestamptz not null default now(),
    -- Apagar = sumir para a turma (quem escreveu ou quem criou o desafio).
    deleted_at    timestamptz,
    deleted_by    uuid references auth.users (id) on delete set null
);
create index if not exists challenge_comments_entry_idx
    on public.challenge_comments (challenge_id, fuel_log_id, created_at);
create index if not exists challenge_comments_user_idx
    on public.challenge_comments (user_id, created_at);

-- 1 reação por pessoa por abastecimento; emoji livre (o app confere que é um
-- emoji só; aqui só o tamanho).
create table if not exists public.challenge_reactions (
    challenge_id  uuid not null references public.challenges (id) on delete cascade,
    fuel_log_id   uuid not null references public.fuel_logs (id) on delete cascade,
    user_id       uuid not null references auth.users (id) on delete cascade,
    emoji         text not null check (char_length(emoji) between 1 and 16),
    created_at    timestamptz not null default now(),
    primary key (challenge_id, fuel_log_id, user_id)
);

-- "A foto do hodômetro confere?" — 1 voto por pessoa; NÃO mexe no km.
create table if not exists public.challenge_photo_votes (
    challenge_id  uuid not null references public.challenges (id) on delete cascade,
    fuel_log_id   uuid not null references public.fuel_logs (id) on delete cascade,
    user_id       uuid not null references auth.users (id) on delete cascade,
    -- Chave congelada: ok, suspect.
    vote          text not null check (vote in ('ok', 'suspect')),
    created_at    timestamptz not null default now(),
    primary key (challenge_id, fuel_log_id, user_id)
);

alter table public.challenge_comments    enable row level security;
alter table public.challenge_reactions   enable row level security;
alter table public.challenge_photo_votes enable row level security;

-- Dono do abastecimento, se ele está no mural do desafio; senão entry_not_found.
create or replace function public.challenge_entry_owner(p_challenge_id uuid, p_fuel_log_id uuid)
returns uuid
language plpgsql
stable
set search_path = ''
as $$
declare
    v_owner uuid;
begin
    select fl.user_id into v_owner
      from public.fuel_logs fl
      join public.challenges ch on ch.id = p_challenge_id and ch.deleted_at is null
      join public.challenge_members m
        on m.challenge_id = ch.id and m.user_id = fl.user_id and m.left_at is null
     where fl.id = p_fuel_log_id
       and fl.deleted_at is null
       and fl.date >= ch.starts_at
       and fl.date < ch.ends_at + interval '3 days';
    if v_owner is null then
        raise exception 'entry_not_found';
    end if;
    return v_owner;
end;
$$;

-- Comentários, reações e votos do desafio inteiro (uma chamada junto com a
-- classificação e o mural). Só de quem ainda está no desafio.
create or replace function public.challenge_social(p_challenge_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
    v_uid uuid := public.challenge_require_account();
begin
    perform public.challenge_require_member(p_challenge_id, v_uid);
    -- D8: o que quem você bloqueou escreveu, reagiu ou votou não aparece.
    return jsonb_build_object(
        'hidden_photos', coalesce((
            select jsonb_agg(h.fuel_log_id order by h.hidden_at)
              from public.challenge_hidden_photos h
             where h.challenge_id = p_challenge_id), '[]'::jsonb),
        'blocked_members', coalesce((
            select jsonb_agg(m.id order by b.created_at)
              from public.challenge_blocks b
              join public.challenge_members m
                on m.challenge_id = p_challenge_id and m.user_id = b.blocked_id
             where b.blocker_id = v_uid), '[]'::jsonb),
        'comments', coalesce((
            select jsonb_agg(jsonb_build_object(
                       'id', c.id, 'fuel_log_id', c.fuel_log_id, 'member_id', m.id,
                       'body', c.body, 'created_at', c.created_at) order by c.created_at)
              from public.challenge_comments c
              join public.challenge_members m
                on m.challenge_id = c.challenge_id and m.user_id = c.user_id and m.left_at is null
             where c.challenge_id = p_challenge_id and c.deleted_at is null
               and not exists (select 1 from public.challenge_blocks b
                                where b.blocker_id = v_uid and b.blocked_id = c.user_id)), '[]'::jsonb),
        'reactions', coalesce((
            select jsonb_agg(jsonb_build_object(
                       'fuel_log_id', r.fuel_log_id, 'member_id', m.id, 'emoji', r.emoji)
                       order by r.created_at)
              from public.challenge_reactions r
              join public.challenge_members m
                on m.challenge_id = r.challenge_id and m.user_id = r.user_id and m.left_at is null
             where r.challenge_id = p_challenge_id
               and not exists (select 1 from public.challenge_blocks b
                                where b.blocker_id = v_uid and b.blocked_id = r.user_id)), '[]'::jsonb),
        'votes', coalesce((
            select jsonb_agg(jsonb_build_object(
                       'fuel_log_id', v.fuel_log_id, 'member_id', m.id, 'vote', v.vote)
                       order by v.created_at)
              from public.challenge_photo_votes v
              join public.challenge_members m
                on m.challenge_id = v.challenge_id and m.user_id = v.user_id and m.left_at is null
             where v.challenge_id = p_challenge_id
               and not exists (select 1 from public.challenge_blocks b
                                where b.blocker_id = v_uid and b.blocked_id = v.user_id)), '[]'::jsonb)
    );
end;
$$;

-- Comenta num abastecimento do mural. Até 30 comentários por hora por pessoa.
create or replace function public.post_challenge_comment(p_challenge_id uuid, p_fuel_log_id uuid, p_body text)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
    v_uid uuid := public.challenge_require_account();
    v_body text := btrim(coalesce(p_body, ''), E' \t\r\n');
    v_id uuid;
    v_at timestamptz;
begin
    perform public.challenge_require_member(p_challenge_id, v_uid);
    perform public.challenge_entry_owner(p_challenge_id, p_fuel_log_id);
    if char_length(v_body) not between 1 and 400 then
        raise exception 'invalid_comment';
    end if;
    if public.challenge_is_offensive(v_body) then
        raise exception 'inappropriate_text';
    end if;
    if (select count(*) from public.challenge_comments
         where user_id = v_uid and created_at > now() - interval '1 hour') >= 30 then
        raise exception 'too_many_comments';
    end if;
    insert into public.challenge_comments (challenge_id, fuel_log_id, user_id, body)
    values (p_challenge_id, p_fuel_log_id, v_uid, v_body)
    returning id, created_at into v_id, v_at;
    return jsonb_build_object('id', v_id, 'created_at', v_at);
end;
$$;

-- Apaga (some para a turma): quem escreveu ou quem criou o desafio.
create or replace function public.delete_challenge_comment(p_comment_id uuid)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
    v_uid uuid := public.challenge_require_account();
    v_comment public.challenge_comments;
    v_creator uuid;
begin
    select * into v_comment from public.challenge_comments
     where id = p_comment_id and deleted_at is null;
    if v_comment.id is null then
        raise exception 'comment_not_found';
    end if;
    perform public.challenge_require_member(v_comment.challenge_id, v_uid);
    select created_by into v_creator from public.challenges where id = v_comment.challenge_id;
    if v_comment.user_id <> v_uid and v_creator is distinct from v_uid then
        raise exception 'cannot_delete_comment';
    end if;
    update public.challenge_comments set deleted_at = now(), deleted_by = v_uid
     where id = p_comment_id;
end;
$$;

-- Reage (emoji) ou tira a reação (nulo). Ninguém reage ao próprio.
create or replace function public.set_challenge_reaction(p_challenge_id uuid, p_fuel_log_id uuid, p_emoji text)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
    v_uid uuid := public.challenge_require_account();
begin
    perform public.challenge_require_member(p_challenge_id, v_uid);
    if public.challenge_entry_owner(p_challenge_id, p_fuel_log_id) = v_uid then
        raise exception 'cannot_react_own';
    end if;
    if p_emoji is null then
        delete from public.challenge_reactions
         where challenge_id = p_challenge_id and fuel_log_id = p_fuel_log_id and user_id = v_uid;
        return;
    end if;
    if char_length(p_emoji) not between 1 and 16 then
        raise exception 'invalid_reaction';
    end if;
    insert into public.challenge_reactions (challenge_id, fuel_log_id, user_id, emoji)
    values (p_challenge_id, p_fuel_log_id, v_uid, p_emoji)
    on conflict (challenge_id, fuel_log_id, user_id)
    do update set emoji = excluded.emoji, created_at = now();
end;
$$;

-- Vota na foto do hodômetro (ok/suspect) ou tira o voto (nulo). Ninguém vota
-- na própria; sem foto no Storage, nada a conferir.
create or replace function public.set_challenge_photo_vote(p_challenge_id uuid, p_fuel_log_id uuid, p_vote text)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
    v_uid uuid := public.challenge_require_account();
begin
    perform public.challenge_require_member(p_challenge_id, v_uid);
    if public.challenge_entry_owner(p_challenge_id, p_fuel_log_id) = v_uid then
        raise exception 'cannot_vote_own';
    end if;
    if not exists (select 1 from public.fuel_logs
                    where id = p_fuel_log_id and odometer_photo_url like '%/%') then
        raise exception 'no_photo_to_check';
    end if;
    if p_vote is null then
        delete from public.challenge_photo_votes
         where challenge_id = p_challenge_id and fuel_log_id = p_fuel_log_id and user_id = v_uid;
        return;
    end if;
    if p_vote not in ('ok', 'suspect') then
        raise exception 'invalid_vote';
    end if;
    insert into public.challenge_photo_votes (challenge_id, fuel_log_id, user_id, vote)
    values (p_challenge_id, p_fuel_log_id, v_uid, p_vote)
    on conflict (challenge_id, fuel_log_id, user_id)
    do update set vote = excluded.vote, created_at = now();
end;
$$;

-- ---------- D8: moderação (diretriz 1.2 da Apple) ----------
-- Denunciar (nome, capa, foto do desafio, comentário) com alerta por e-mail,
-- bloquear piloto, quem criou esconde foto do mural e troca o código, filtro
-- de palavrão (challenge_is_offensive). A equipe age pelo SQL (runbook em
-- PLAN/desafios.md §D8).

-- O e-mail de alerta sai pelo pg_net (HTTP do banco) para o Resend.
create extension if not exists pg_net with schema extensions;

-- Bloqueio vale em todos os desafios: quem bloqueou não vê fotos, comentários,
-- reações nem votos do outro. A classificação não muda (km é km).
create table if not exists public.challenge_blocks (
    blocker_id  uuid not null references auth.users (id) on delete cascade,
    blocked_id  uuid not null references auth.users (id) on delete cascade,
    created_at  timestamptz not null default now(),
    primary key (blocker_id, blocked_id),
    check (blocker_id <> blocked_id)
);

-- Foto do desafio que quem criou tirou do mural (só daquele desafio).
create table if not exists public.challenge_hidden_photos (
    challenge_id  uuid not null references public.challenges (id) on delete cascade,
    fuel_log_id   uuid not null references public.fuel_logs (id) on delete cascade,
    hidden_by     uuid references auth.users (id) on delete set null,
    hidden_at     timestamptz not null default now(),
    primary key (challenge_id, fuel_log_id)
);

-- Denúncias. Ficam mesmo se o desafio ou a conta sumirem (registro da
-- moderação). snapshot = o conteúdo como estava (pode mudar ou ser apagado).
create table if not exists public.challenge_reports (
    id                uuid primary key default gen_random_uuid(),
    challenge_id      uuid references public.challenges (id) on delete set null,
    reporter_id       uuid references auth.users (id) on delete set null,
    -- Chave congelada: name, cover, photo, comment.
    kind              text not null check (kind in ('name', 'cover', 'photo', 'comment')),
    -- member_id (name), fuel_log_id (photo), id do comentário (comment); nulo (cover).
    target_id         uuid,
    snapshot          text,
    created_at        timestamptz not null default now(),
    alert_request_id  bigint,
    resolved_at       timestamptz,
    resolution        text
);
create index if not exists challenge_reports_reporter_idx on public.challenge_reports (reporter_id, created_at);

-- Denúncia com mais de 12 meses sai sozinha (prazo da Política de Privacidade,
-- carburante.motorcycles/privacidade). Job com nome: rodar de novo só atualiza.
create extension if not exists pg_cron with schema pg_catalog;
select cron.schedule('challenge-reports-retention', '15 4 * * *',
    $job$delete from public.challenge_reports where created_at < now() - interval '12 months'$job$);

alter table public.challenge_blocks        enable row level security;
alter table public.challenge_hidden_photos enable row level security;
alter table public.challenge_reports       enable row level security;

-- Quem criou troca o código: o link e o código antigos param de valer (quem
-- está dentro continua). Quem só tinha aberto a prévia perde a capa.
create or replace function public.rotate_invite_code(p_challenge_id uuid)
returns text
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
    v_uid uuid := public.challenge_require_account();
    v_code text := public.challenge_new_invite_code();
begin
    update public.challenges set invite_code = v_code
     where id = p_challenge_id and created_by = v_uid and deleted_at is null;
    if not found then
        raise exception 'not_the_creator';
    end if;
    delete from public.challenge_code_attempts where challenge_id = p_challenge_id;
    return v_code;
end;
$$;

-- Quem criou esconde (ou mostra de novo) a foto do desafio de um abastecimento.
create or replace function public.set_challenge_photo_hidden(p_challenge_id uuid, p_fuel_log_id uuid, p_hidden boolean)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
    v_uid uuid := public.challenge_require_account();
begin
    perform public.challenge_require_member(p_challenge_id, v_uid);
    if not exists (select 1 from public.challenges where id = p_challenge_id and created_by = v_uid) then
        raise exception 'not_the_creator';
    end if;
    perform public.challenge_entry_owner(p_challenge_id, p_fuel_log_id);
    if coalesce(p_hidden, false) then
        insert into public.challenge_hidden_photos (challenge_id, fuel_log_id, hidden_by)
        values (p_challenge_id, p_fuel_log_id, v_uid)
        on conflict (challenge_id, fuel_log_id) do nothing;
    else
        delete from public.challenge_hidden_photos
         where challenge_id = p_challenge_id and fuel_log_id = p_fuel_log_id;
    end if;
end;
$$;

-- Bloqueia (ou desbloqueia) um piloto do desafio. Vale em todos os desafios.
create or replace function public.set_member_blocked(p_challenge_id uuid, p_member_id uuid, p_blocked boolean)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
    v_uid uuid := public.challenge_require_account();
    v_target uuid;
begin
    perform public.challenge_require_member(p_challenge_id, v_uid);
    select user_id into v_target from public.challenge_members
     where challenge_id = p_challenge_id and id = p_member_id;
    if v_target is null then
        raise exception 'member_not_found';
    end if;
    if v_target = v_uid then
        raise exception 'cannot_block_self';
    end if;
    if coalesce(p_blocked, false) then
        insert into public.challenge_blocks (blocker_id, blocked_id) values (v_uid, v_target)
        on conflict do nothing;
    else
        delete from public.challenge_blocks where blocker_id = v_uid and blocked_id = v_target;
    end if;
end;
$$;

-- Alerta da denúncia por e-mail (Resend). Sem a chave no Vault, só grava.
-- Nunca derruba a denúncia: erro aqui vira aviso no log.
create or replace function public.challenge_report_alert(p_report_id uuid)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
    v_key text;
    v_to text;
    r record;
    v_kind text;
    v_request bigint;
begin
    select decrypted_secret into v_key from vault.decrypted_secrets where name = 'resend_api_key';
    select decrypted_secret into v_to from vault.decrypted_secrets where name = 'report_alert_email';
    if v_key is null or v_to is null then
        return;
    end if;
    select rep.*, ch.name as challenge_name,
           (select m.display_name from public.challenge_members m
             where m.challenge_id = rep.challenge_id and m.user_id = rep.reporter_id) as reporter_name
      into r
      from public.challenge_reports rep
      left join public.challenges ch on ch.id = rep.challenge_id
     where rep.id = p_report_id;
    v_kind := case r.kind when 'name' then 'nome de piloto' when 'cover' then 'capa'
                          when 'photo' then 'foto do desafio' else 'comentário' end;
    select net.http_post(
        url := 'https://api.resend.com/emails',
        headers := jsonb_build_object('Authorization', 'Bearer ' || v_key, 'Content-Type', 'application/json'),
        body := jsonb_build_object(
            'from', 'Carburante <onboarding@resend.dev>',
            'to', jsonb_build_array(v_to),
            'subject', 'Denúncia no Carburante: ' || v_kind,
            'text', format(E'Denúncia de %s\n\nDesafio: %s (%s)\nConteúdo: %s\nAlvo: %s\nQuem denunciou: %s\nQuando: %s\n\nDenúncia %s. Agir em até 24 h (runbook: PLAN/desafios.md §D8).',
                           v_kind, coalesce(r.challenge_name, '?'), r.challenge_id, coalesce(r.snapshot, '-'),
                           coalesce(r.target_id::text, '-'), coalesce(r.reporter_name, '?'), r.created_at, r.id)
        )
    ) into v_request;
    update public.challenge_reports set alert_request_id = v_request where id = p_report_id;
exception when others then
    raise warning 'challenge_report_alert %: %', p_report_id, sqlerrm;
end;
$$;

-- Denuncia o nome de um piloto (alvo = member_id), a capa (alvo nulo), a foto
-- do desafio de um abastecimento (alvo = fuel_log_id) ou um comentário (alvo =
-- id). Até 20 por hora por pessoa.
create or replace function public.report_challenge_content(p_challenge_id uuid, p_kind text, p_target uuid)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
    v_uid uuid := public.challenge_require_account();
    v_snapshot text;
    v_id uuid;
begin
    perform public.challenge_require_member(p_challenge_id, v_uid);
    if (select count(*) from public.challenge_reports
         where reporter_id = v_uid and created_at > now() - interval '1 hour') >= 20 then
        raise exception 'too_many_reports';
    end if;
    case p_kind
    when 'name' then
        select display_name into v_snapshot from public.challenge_members
         where challenge_id = p_challenge_id and id = p_target and user_id <> v_uid;
    when 'cover' then
        select cover_path into v_snapshot from public.challenges where id = p_challenge_id;
    when 'photo' then
        perform public.challenge_entry_owner(p_challenge_id, p_target);
        select challenge_photo_url into v_snapshot from public.fuel_logs
         where id = p_target and user_id <> v_uid;
    when 'comment' then
        select body into v_snapshot from public.challenge_comments
         where challenge_id = p_challenge_id and id = p_target and deleted_at is null and user_id <> v_uid;
    else
        raise exception 'invalid_report';
    end case;
    if v_snapshot is null then
        raise exception 'invalid_report';
    end if;
    insert into public.challenge_reports (challenge_id, reporter_id, kind, target_id, snapshot)
    values (p_challenge_id, v_uid, p_kind, case when p_kind = 'cover' then null else p_target end, v_snapshot)
    returning id into v_id;
    perform public.challenge_report_alert(v_id);
end;
$$;

-- ---------- Storage ----------

-- Fotos do abastecimento (hodômetro e foto do desafio) para a turma: libera
-- "<moto>/<log>.jpg" e "<moto>/<log>-challenge.jpg" se quem pede e o dono do
-- registro estão no mesmo desafio e o registro é do período (até o fechamento).
-- Fora de desafio nada muda (as policies do dono seguem em schema.sql).
create or replace function public.can_view_challenge_photo(object_name text)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
    v_uid uuid := auth.uid();
    v_folder text := lower((storage.foldername(object_name))[1]);
    v_file text := storage.filename(object_name);
begin
    -- Valida antes do cast: um nome fora do padrão nunca pode dar erro aqui
    -- (a policy roda em toda leitura do bucket, inclusive as do dono).
    if v_uid is null
       or v_file !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}(-challenge)?\.jpg$' then
        return false;
    end if;
    return exists (
        select 1
          from public.fuel_logs fl
          join public.challenge_members owner
            on owner.user_id = fl.user_id and owner.left_at is null
          join public.challenge_members viewer
            on viewer.challenge_id = owner.challenge_id
           and viewer.user_id = v_uid and viewer.left_at is null
          join public.challenges ch
            on ch.id = owner.challenge_id and ch.deleted_at is null
         where fl.id = substr(v_file, 1, 36)::uuid
           and fl.motorcycle_id::text = v_folder
           and fl.deleted_at is null
           and fl.date >= ch.starts_at
           and fl.date < ch.ends_at + interval '3 days'
           -- D8: bloqueou o dono = não vê as fotos dele; foto do desafio
           -- escondida por quem criou = a turma daquele desafio não vê.
           and not exists (select 1 from public.challenge_blocks b
                            where b.blocker_id = v_uid and b.blocked_id = fl.user_id)
           and not (v_file ~* '-challenge\.jpg$'
                    and exists (select 1 from public.challenge_hidden_photos h
                                 where h.challenge_id = ch.id and h.fuel_log_id = fl.id))
    );
end;
$$;

drop policy if exists "fuel_log_photos_select_challenge" on storage.objects;
create policy "fuel_log_photos_select_challenge"
on storage.objects for select to authenticated
using (bucket_id = 'fuel-log-photos' and public.can_view_challenge_photo(name));

-- Capa do desafio: bucket PRIVADO, "<challenge_id>/cover.jpg" (JPEG reduzido
-- como a foto do hodômetro). Grava quem criou; lê quem está no desafio e quem
-- acertou o código (prévia antes de entrar).
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('challenge-covers', 'challenge-covers', false, 5242880, array['image/jpeg'])
on conflict (id) do update
    set public = excluded.public,
        file_size_limit = excluded.file_size_limit,
        allowed_mime_types = excluded.allowed_mime_types;

-- Id do desafio da pasta, ou nulo se o nome não é de capa.
create or replace function public.challenge_cover_folder(object_name text)
returns uuid
language plpgsql
stable
set search_path = ''
as $$
declare
    v_folder text := (storage.foldername(object_name))[1];
begin
    if v_folder ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
        return v_folder::uuid;
    end if;
    return null;
end;
$$;

create or replace function public.can_edit_challenge_cover(object_name text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
    select coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) = false
       and exists (select 1 from public.challenges ch
                    where ch.id = public.challenge_cover_folder(object_name)
                      and ch.created_by = auth.uid() and ch.deleted_at is null);
$$;

create or replace function public.can_view_challenge_cover(object_name text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
    select exists (select 1 from public.challenge_members m
                    where m.challenge_id = public.challenge_cover_folder(object_name)
                      and m.user_id = auth.uid() and m.left_at is null)
        or exists (select 1 from public.challenge_code_attempts a
                    where a.challenge_id = public.challenge_cover_folder(object_name)
                      and a.user_id = auth.uid());
$$;

drop policy if exists "challenge_covers_select" on storage.objects;
create policy "challenge_covers_select"
on storage.objects for select to authenticated
using (bucket_id = 'challenge-covers' and public.can_view_challenge_cover(name));

drop policy if exists "challenge_covers_insert" on storage.objects;
create policy "challenge_covers_insert"
on storage.objects for insert to authenticated
with check (bucket_id = 'challenge-covers' and public.can_edit_challenge_cover(name));

drop policy if exists "challenge_covers_update" on storage.objects;
create policy "challenge_covers_update"
on storage.objects for update to authenticated
using (bucket_id = 'challenge-covers' and public.can_edit_challenge_cover(name));

drop policy if exists "challenge_covers_delete" on storage.objects;
create policy "challenge_covers_delete"
on storage.objects for delete to authenticated
using (bucket_id = 'challenge-covers' and public.can_edit_challenge_cover(name));

-- ---------- permissões ----------
-- O Supabase dá EXECUTE a anon/authenticated em toda função nova do public:
-- internas ficam só com o dono; as do app, só com sessão (authenticated —
-- inclui a anônima, que as próprias funções recusam quando precisa).
revoke all on function public.challenge_require_account() from public, anon, authenticated;
revoke all on function public.challenge_require_member(uuid, uuid) from public, anon, authenticated;
revoke all on function public.challenge_clean_name(text, integer) from public, anon, authenticated;
revoke all on function public.challenge_new_invite_code() from public, anon, authenticated;
revoke all on function public.challenge_lookup_code(text, uuid) from public, anon, authenticated;
revoke all on function public.challenge_scores(uuid) from public, anon, authenticated;
revoke all on function public.challenge_finalize_if_closed(uuid) from public, anon, authenticated;
revoke all on function public.challenge_entry_owner(uuid, uuid) from public, anon, authenticated;
revoke all on function public.challenge_is_offensive(text) from public, anon, authenticated;
revoke all on function public.challenge_report_alert(uuid) from public, anon, authenticated;

revoke all on function public.create_challenge(text, timestamptz, timestamptz, text, text) from public, anon;
revoke all on function public.challenge_preview(text) from public, anon;
revoke all on function public.join_challenge(text, text) from public, anon;
revoke all on function public.leave_challenge(uuid) from public, anon;
revoke all on function public.remove_member(uuid, uuid) from public, anon;
revoke all on function public.set_challenge_cover(uuid, text) from public, anon;
revoke all on function public.my_challenges() from public, anon;
revoke all on function public.challenge_leaderboard(uuid) from public, anon;
revoke all on function public.challenge_entries(uuid, uuid) from public, anon;
revoke all on function public.can_view_challenge_photo(text) from public, anon;
revoke all on function public.challenge_cover_folder(text) from public, anon;
revoke all on function public.can_edit_challenge_cover(text) from public, anon;
revoke all on function public.can_view_challenge_cover(text) from public, anon;
revoke all on function public.challenge_social(uuid) from public, anon;
revoke all on function public.post_challenge_comment(uuid, uuid, text) from public, anon;
revoke all on function public.delete_challenge_comment(uuid) from public, anon;
revoke all on function public.set_challenge_reaction(uuid, uuid, text) from public, anon;
revoke all on function public.set_challenge_photo_vote(uuid, uuid, text) from public, anon;
revoke all on function public.rotate_invite_code(uuid) from public, anon;
revoke all on function public.set_challenge_photo_hidden(uuid, uuid, boolean) from public, anon;
revoke all on function public.set_member_blocked(uuid, uuid, boolean) from public, anon;
revoke all on function public.report_challenge_content(uuid, text, uuid) from public, anon;

grant execute on function public.create_challenge(text, timestamptz, timestamptz, text, text) to authenticated;
grant execute on function public.challenge_preview(text) to authenticated;
grant execute on function public.join_challenge(text, text) to authenticated;
grant execute on function public.leave_challenge(uuid) to authenticated;
grant execute on function public.remove_member(uuid, uuid) to authenticated;
grant execute on function public.set_challenge_cover(uuid, text) to authenticated;
grant execute on function public.my_challenges() to authenticated;
grant execute on function public.challenge_leaderboard(uuid) to authenticated;
grant execute on function public.challenge_entries(uuid, uuid) to authenticated;
grant execute on function public.can_view_challenge_photo(text) to authenticated;
grant execute on function public.challenge_cover_folder(text) to authenticated;
grant execute on function public.can_edit_challenge_cover(text) to authenticated;
grant execute on function public.can_view_challenge_cover(text) to authenticated;
grant execute on function public.challenge_social(uuid) to authenticated;
grant execute on function public.post_challenge_comment(uuid, uuid, text) to authenticated;
grant execute on function public.delete_challenge_comment(uuid) to authenticated;
grant execute on function public.set_challenge_reaction(uuid, uuid, text) to authenticated;
grant execute on function public.set_challenge_photo_vote(uuid, uuid, text) to authenticated;
grant execute on function public.rotate_invite_code(uuid) to authenticated;
grant execute on function public.set_challenge_photo_hidden(uuid, uuid, boolean) to authenticated;
grant execute on function public.set_member_blocked(uuid, uuid, boolean) to authenticated;
grant execute on function public.report_challenge_content(uuid, text, uuid) to authenticated;
