-- Carburante — schema + RLS (Fase 9)
-- Rodar no Supabase: SQL Editor → New query → colar tudo → Run.
--
-- Decisões:
-- - PKs são UUID gerados no cliente (o app cria o id antes de enviar), então
--   o sync não precisa de round-trip pra descobrir o id atribuído.
-- - user_id é denormalizado em todas as tabelas de dados → RLS filtra direto,
--   sem join (ver plan-mvp.md).
-- - user_id referencia auth.users (a sessão anônima do Supabase Auth dá o id).
-- - Colunas espelham os @Model do app (camelCase no Swift → snake_case aqui).

-- ---------- users (perfil; 1:1 com auth.users) ----------
create table if not exists public.users (
    id          uuid primary key references auth.users (id) on delete cascade,
    name        text,
    country     text,
    created_at  timestamptz not null default now()
);

-- ---------- motorcycles ----------
create table if not exists public.motorcycles (
    id                        uuid primary key,
    user_id                   uuid not null references auth.users (id) on delete cascade,
    make                      text not null,
    model                     text not null,
    year                      integer not null,
    country                   text,
    current_odometer          double precision not null default 0,
    odometer_baseline         double precision not null default 0,
    category                  text,
    displacement_cc           integer,
    manufacturer_consumption  double precision,
    created_at                timestamptz not null default now()
);
create index if not exists motorcycles_user_id_idx on public.motorcycles (user_id);
-- Migração de tabelas já criadas (rodar uma vez; no-op se já existe):
alter table public.motorcycles add column if not exists displacement_cc integer;
alter table public.motorcycles add column if not exists odometer_baseline double precision not null default 0;
-- Exclusão lógica da moto (nil = viva): o delete propaga e o pull não ressuscita.
alter table public.motorcycles add column if not exists deleted_at timestamptz;
-- Situação da moto (2026-10-08): 'active' / 'for_sale' / 'sold' — chave
-- congelada de MotorcycleStatus no app. A data da mudança decide quem vence
-- (trigger keep_latest_motorcycle_status, abaixo).
alter table public.motorcycles add column if not exists status text not null default 'active';
alter table public.motorcycles add column if not exists status_changed_at timestamptz;

-- ---------- fuel_logs ----------
create table if not exists public.fuel_logs (
    id                uuid primary key,
    motorcycle_id     uuid not null references public.motorcycles (id) on delete cascade,
    user_id           uuid not null references auth.users (id) on delete cascade,
    date              timestamptz not null,
    odometer          double precision not null,
    liters            double precision not null,
    total_cost        double precision not null,
    fuel_type         text not null,
    is_full_tank      boolean not null default true,
    latitude          double precision,
    longitude         double precision,
    city              text,
    state             text,
    country           text,
    temperature_c     double precision,
    receipt_image_url text,
    odometer_photo_url text,
    ocr_processed     boolean not null default false,
    ocr_confidence    double precision,
    -- Proveniência / auditoria (base anti-burla dos desafios Iron Butt):
    -- marca se o usuário alterou manualmente a data ou o local auto-capturado.
    date_was_edited     boolean not null default false,
    location_was_edited boolean not null default false,
    -- Soft Revision (Fase 1 — ver PLAN/metadados-auditoria.md). Infra mínima de
    -- auditoria/sync, invisível ao usuário:
    --   updated_at → base do last-write-wins no pull (reconcilia edição/exclusão
    --                da mesma linha em dois devices);
    --   revision   → contador de edições (0 = nunca alterado);
    --   deleted_at → exclusão LÓGICA (linha some da UI mas persiste e propaga
    --                o delete a outros devices; nunca purgada no MVP).
    updated_at        timestamptz not null default now(),
    revision          integer not null default 0,
    deleted_at        timestamptz,
    created_at        timestamptz not null default now()
);

-- Migração de tabelas já criadas (rodar uma vez; no-op se já existem):
alter table public.fuel_logs add column if not exists odometer_photo_url text;
alter table public.fuel_logs add column if not exists date_was_edited boolean not null default false;
alter table public.fuel_logs add column if not exists location_was_edited boolean not null default false;
alter table public.fuel_logs add column if not exists updated_at timestamptz not null default now();
alter table public.fuel_logs add column if not exists revision integer not null default 0;
alter table public.fuel_logs add column if not exists deleted_at timestamptz;
-- Lacuna: abastecimentos não registrados antes deste → quebra a medição de
-- consumo (ver PLAN/lacuna-abastecimento.md). Marcado pelo usuário.
alter table public.fuel_logs add column if not exists missed_previous boolean not null default false;
-- Backfill: linhas antigas nunca foram "atualizadas" → updated_at = created_at
-- (o default now() da migração colocaria a data da migração, não a real).
update public.fuel_logs set updated_at = created_at where updated_at > created_at;
create index if not exists fuel_logs_deleted_at_idx on public.fuel_logs (deleted_at);
create index if not exists fuel_logs_user_id_idx on public.fuel_logs (user_id);
create index if not exists fuel_logs_motorcycle_id_idx on public.fuel_logs (motorcycle_id);

-- ---------- maintenance_logs ----------
-- user_id incluído (a nota do schema pede; a lista de colunas tinha omitido) p/ RLS sem join.
create table if not exists public.maintenance_logs (
    id             uuid primary key,
    motorcycle_id  uuid not null references public.motorcycles (id) on delete cascade,
    user_id        uuid not null references auth.users (id) on delete cascade,
    type           text not null,
    date           timestamptz not null,
    mileage        double precision not null,
    cost           double precision not null default 0,
    notes          text not null default '',
    -- Intervalos genéricos por tipo (ver PLAN/manutencao-programada.md):
    interval_km            double precision,
    interval_months        integer,
    part_of_maintenance_id uuid,
    -- Soft Revision (Fase 1) — mesma tripla do fuel_logs.
    updated_at     timestamptz not null default now(),
    revision       integer not null default 0,
    deleted_at     timestamptz,
    created_at     timestamptz not null default now()
);
alter table public.maintenance_logs add column if not exists oil_change_interval_km double precision;
-- Generalização do agendamento (óleo → todos os tipos): colunas aditivas +
-- backfill do intervalo de óleo legado. `oil_change_interval_km` fica órfã por
-- um release e pode ser dropada depois.
alter table public.maintenance_logs add column if not exists interval_km double precision;
alter table public.maintenance_logs add column if not exists interval_months integer;
alter table public.maintenance_logs add column if not exists part_of_maintenance_id uuid;
-- Posição do pneu (dianteiro/traseiro): contadores independentes por eixo.
-- Nulo em não-pneus e em registros de pneu antigos.
alter table public.maintenance_logs add column if not exists tire_position text;
-- Soft Revision (Fase 1): colunas aditivas + backfill de updated_at.
alter table public.maintenance_logs add column if not exists updated_at timestamptz not null default now();
alter table public.maintenance_logs add column if not exists revision integer not null default 0;
alter table public.maintenance_logs add column if not exists deleted_at timestamptz;
update public.maintenance_logs set updated_at = created_at where updated_at > created_at;
create index if not exists maintenance_logs_deleted_at_idx on public.maintenance_logs (deleted_at);
-- Backfill guardado: só roda se a coluna legada existir (ambientes que nunca
-- aplicaram a feature de intervalo de óleo não têm `oil_change_interval_km`).
do $$
begin
  if exists (
    select 1 from information_schema.columns
     where table_schema = 'public'
       and table_name = 'maintenance_logs'
       and column_name = 'oil_change_interval_km'
  ) then
    update public.maintenance_logs
       set interval_km = oil_change_interval_km
     where interval_km is null and oil_change_interval_km is not null;
  end if;
end $$;
create index if not exists maintenance_logs_user_id_idx on public.maintenance_logs (user_id);
create index if not exists maintenance_logs_motorcycle_id_idx on public.maintenance_logs (motorcycle_id);

-- ---------- badge_awards ----------
-- Data em que cada medalha foi conquistada (estilo Garmin). O estado
-- locked/unlocked continua DERIVADO no app (motor puro `BadgeEvaluator`); aqui
-- só persiste o carimbo da PRIMEIRA conquista. badge_id é o id do catálogo
-- (Badge.id) — único por usuário.
create table if not exists public.badge_awards (
    id          uuid primary key,
    user_id     uuid not null references auth.users (id) on delete cascade,
    badge_id    text not null,
    earned_at   timestamptz not null,
    created_at  timestamptz not null default now(),
    unique (user_id, badge_id)
);
create index if not exists badge_awards_user_id_idx on public.badge_awards (user_id);

-- ---------- motorcycle_ownerships ----------
-- Propriedade moto↔usuário modelada À PARTE da moto: a moto é a entidade
-- permanente (`motorcycles.id` nunca muda), quem a possui (e quando) vive aqui.
-- No MVP existe sempre 1 linha ativa (ended_at null) por moto, mas a estrutura
-- já suporta troca de dono / histórico de proprietários sem remodelar (venda =
-- fecha a linha ativa, abre outra). FONTE DE VERDADE de propriedade — a coluna
-- legada `motorcycles.user_id` fica só por compat + performance de RLS.
create table if not exists public.motorcycle_ownerships (
    id             uuid primary key,
    motorcycle_id  uuid not null references public.motorcycles (id) on delete cascade,
    user_id        uuid not null references auth.users (id) on delete cascade,
    started_at     timestamptz not null,
    ended_at       timestamptz,
    is_active      boolean not null default true,
    created_at     timestamptz not null default now()
);
create index if not exists motorcycle_ownerships_motorcycle_id_idx on public.motorcycle_ownerships (motorcycle_id);
create index if not exists motorcycle_ownerships_user_id_idx on public.motorcycle_ownerships (user_id);
-- Busca rápida do dono ATUAL de uma moto (a linha ativa).
create index if not exists motorcycle_ownerships_active_idx
    on public.motorcycle_ownerships (motorcycle_id) where ended_at is null;

-- ---------- RLS ----------
alter table public.users            enable row level security;
alter table public.motorcycles      enable row level security;
alter table public.fuel_logs        enable row level security;
alter table public.maintenance_logs enable row level security;
alter table public.badge_awards     enable row level security;
alter table public.motorcycle_ownerships enable row level security;

-- users: dono lê/escreve só a própria linha (id = auth.uid()).
create policy "users self access" on public.users
    for all using (auth.uid() = id) with check (auth.uid() = id);

-- demais tabelas: dono filtra por user_id.
create policy "motorcycles owner" on public.motorcycles
    for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "fuel_logs owner" on public.fuel_logs
    for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "maintenance_logs owner" on public.maintenance_logs
    for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "badge_awards owner" on public.badge_awards
    for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Propriedade: dono filtra por user_id (mesmo one-liner das demais). Quando a
-- transferência chegar, revisitar p/ ex-dono LER (não mutar) a moto vendida.
create policy "motorcycle_ownerships owner" on public.motorcycle_ownerships
    for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Exclusão de conta in-app (App Store Guideline 5.1.1(v)). O cliente só tem a
-- chave publishable (não pode usar a Admin API p/ apagar usuários), então esta
-- função SECURITY DEFINER apaga a linha do PRÓPRIO usuário em auth.users. O
-- `on delete cascade` de todas as FKs para auth.users (motorcycles/fuel_logs/
-- maintenance_logs/badge_awards/motorcycle_ownerships/users) remove os dados.
-- Chamada via client.rpc("delete_current_user") — ver SyncService.deleteAccount.
create or replace function public.delete_current_user()
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
begin
    -- auth.uid() é o id da sessão que chamou; guard evita apagar sem sessão.
    if auth.uid() is null then
        raise exception 'no authenticated user';
    end if;
    delete from auth.users where id = auth.uid();
end;
$$;

-- Só usuários autenticados podem chamar (não o role anon público sem sessão).
revoke all on function public.delete_current_user() from public, anon;
grant execute on function public.delete_current_user() to authenticated;

-- `created_at` dos logs é FATO IMUTÁVEL (quando o registro entrou no app) e base
-- da regra "histórico vs na hora" (app: EventProvenance). O app passou a enviá-lo
-- no upsert; como a ordem dos pushes entre devices não é garantida (um device
-- que puxou o log antes do campo sincronizar tem `created_at` = hora do pull),
-- o servidor só aceita valor MENOR — o mais antigo sempre vence. Build antigo
-- que não manda a coluna não é afetado (new.created_at = old.created_at).
create or replace function public.keep_earliest_created_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    new.created_at := least(old.created_at, new.created_at);
    return new;
end;
$$;

drop trigger if exists fuel_logs_keep_earliest_created_at on public.fuel_logs;
create trigger fuel_logs_keep_earliest_created_at
    before update on public.fuel_logs
    for each row execute function public.keep_earliest_created_at();

drop trigger if exists maintenance_logs_keep_earliest_created_at on public.maintenance_logs;
create trigger maintenance_logs_keep_earliest_created_at
    before update on public.maintenance_logs
    for each row execute function public.keep_earliest_created_at();

-- Moto (2026-10-08): o app passou a enviar `created_at` da moto — base da regra
-- do Premium "moto cadastrada antes do lançamento nunca conta para o limite".
-- Até aqui a coluna era a hora do 1º push (default now()); o valor do device é
-- menor e passa; um device que puxou a moto antes (hora do pull) não sobrescreve.
drop trigger if exists motorcycles_keep_earliest_created_at on public.motorcycles;
create trigger motorcycles_keep_earliest_created_at
    before update on public.motorcycles
    for each row execute function public.keep_earliest_created_at();

-- Situação da moto (2026-10-08): a moto não tem updated_at, e o push sobe a
-- linha inteira — um device que ainda não puxou a venda desfaria "vendida".
-- O servidor só aceita a situação com status_changed_at MAIS RECENTE; sem data
-- (build antigo ou situação nunca mudada) mantém a que já está.
create or replace function public.keep_latest_motorcycle_status()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    if new.status_changed_at is null
       or (old.status_changed_at is not null and new.status_changed_at < old.status_changed_at) then
        new.status := old.status;
        new.status_changed_at := old.status_changed_at;
    end if;
    return new;
end;
$$;

drop trigger if exists motorcycles_keep_latest_status on public.motorcycles;
create trigger motorcycles_keep_latest_status
    before update on public.motorcycles
    for each row execute function public.keep_latest_motorcycle_status();

-- Foto do hodômetro (comprovante do km rodado — base da auditoria anti-burla e,
-- no futuro, de uma checagem por IA). Bucket PRIVADO: nada de URL pública (não
-- dá para revogar); o app baixa autenticado.
-- Path = "{motorcycle_id}/{fuel_log_id}.jpg" — a pasta é a MOTO, não o usuário:
-- a foto é prova da procedência do km e segue a moto numa transferência
-- (passaporte digital). As policies liberam a pasta para quem é dono da moto;
-- hoje "dono" = motorcycles.user_id (mesma regra das tabelas). Na Fase 2 (RLS
-- por ownership) esta função muda junto com as policies das tabelas — o novo
-- dono passa a ler as fotos sem mover arquivo nenhum.
-- `fuel_logs.odometer_photo_url` guarda o PATH no bucket, não uma URL.
-- Exclusão de conta: o cascade do Postgres NÃO alcança o Storage — o app apaga
-- as pastas das motos antes de chamar delete_current_user().
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('fuel-log-photos', 'fuel-log-photos', false, 5242880, array['image/jpeg'])
on conflict (id) do update
    set public = excluded.public,
        file_size_limit = excluded.file_size_limit,
        allowed_mime_types = excluded.allowed_mime_types;

-- Dono da moto cuja pasta é a 1ª do path. SECURITY INVOKER: a consulta passa
-- pelo RLS de motorcycles (só enxerga as próprias). id::text sai minúsculo — o
-- app grava a pasta em minúsculas (PhotoReference.folder).
create or replace function public.owns_photo_folder(object_name text)
returns boolean
language sql
stable
set search_path = ''
as $$
  select exists (
    select 1 from public.motorcycles m
    where m.id::text = (storage.foldername(object_name))[1]
      and m.user_id = (select auth.uid())
  );
$$;

drop policy if exists "fuel_log_photos_insert_own" on storage.objects;
create policy "fuel_log_photos_insert_own"
on storage.objects for insert to authenticated
with check (bucket_id = 'fuel-log-photos' and public.owns_photo_folder(name));

drop policy if exists "fuel_log_photos_update_own" on storage.objects;
create policy "fuel_log_photos_update_own"
on storage.objects for update to authenticated
using (bucket_id = 'fuel-log-photos' and public.owns_photo_folder(name));

drop policy if exists "fuel_log_photos_select_own" on storage.objects;
create policy "fuel_log_photos_select_own"
on storage.objects for select to authenticated
using (bucket_id = 'fuel-log-photos' and public.owns_photo_folder(name));

drop policy if exists "fuel_log_photos_delete_own" on storage.objects;
create policy "fuel_log_photos_delete_own"
on storage.objects for delete to authenticated
using (bucket_id = 'fuel-log-photos' and public.owns_photo_folder(name));
