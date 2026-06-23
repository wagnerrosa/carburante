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
    created_at        timestamptz not null default now()
);

-- Migração de tabelas já criadas (rodar uma vez; no-op se já existem):
alter table public.fuel_logs add column if not exists odometer_photo_url text;
alter table public.fuel_logs add column if not exists date_was_edited boolean not null default false;
alter table public.fuel_logs add column if not exists location_was_edited boolean not null default false;
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
    created_at     timestamptz not null default now()
);
alter table public.maintenance_logs add column if not exists oil_change_interval_km double precision;
-- Generalização do agendamento (óleo → todos os tipos): colunas aditivas +
-- backfill do intervalo de óleo legado. `oil_change_interval_km` fica órfã por
-- um release e pode ser dropada depois.
alter table public.maintenance_logs add column if not exists interval_km double precision;
alter table public.maintenance_logs add column if not exists interval_months integer;
alter table public.maintenance_logs add column if not exists part_of_maintenance_id uuid;
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

-- ---------- RLS ----------
alter table public.users            enable row level security;
alter table public.motorcycles      enable row level security;
alter table public.fuel_logs        enable row level security;
alter table public.maintenance_logs enable row level security;

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
