-- Stonks — schema Supabase
-- Esegui questo nel SQL Editor del tuo progetto Supabase

-- Profili utente (extends auth.users)
create table if not exists public.profiles (
  id          uuid references auth.users on delete cascade primary key,
  username    text unique not null,
  currency    text not null default 'EUR',
  created_at  timestamptz default now()
);

-- Holdings
create table if not exists public.holdings (
  id          uuid default gen_random_uuid() primary key,
  user_id     uuid references auth.users on delete cascade not null,
  symbol      text not null,
  name        text not null,
  type        text not null default 'stock',
  currency    text not null default 'EUR',
  shares      double precision not null default 0,
  avg_cost    double precision not null default 0,
  created_at  timestamptz default now(),
  unique (user_id, symbol)
);

-- Transactions
create table if not exists public.transactions (
  id          uuid default gen_random_uuid() primary key,
  user_id     uuid references auth.users on delete cascade not null,
  symbol      text not null,
  name        text not null,
  type        text not null,  -- buy | sell | dividend
  shares      double precision not null default 0,
  price       double precision not null default 0,
  currency    text not null default 'EUR',
  fees        double precision not null default 0,
  date        timestamptz not null,
  created_at  timestamptz default now()
);

-- Watchlist
create table if not exists public.watchlist (
  id           uuid default gen_random_uuid() primary key,
  user_id      uuid references auth.users on delete cascade not null,
  symbol       text not null,
  name         text not null,
  currency     text not null default 'EUR',
  target_price double precision,
  created_at   timestamptz default now(),
  unique (user_id, symbol)
);

-- Wallet connections (exchange API + indirizzi pubblici)
create table if not exists public.wallet_connections (
  id          uuid default gen_random_uuid() primary key,
  user_id     uuid references auth.users on delete cascade not null,
  type        text not null,      -- exchange | address
  name        text not null,
  exchange    text,               -- binance | coinbase | kraken
  api_key     text,
  api_secret  text,               -- encrypted client-side
  chain       text,               -- bitcoin | ethereum | solana
  address     text,
  created_at  timestamptz default now()
);

-- RLS
alter table public.profiles          enable row level security;
alter table public.holdings          enable row level security;
alter table public.transactions      enable row level security;
alter table public.watchlist         enable row level security;
alter table public.wallet_connections enable row level security;

-- Policies: ogni utente vede/modifica solo i propri dati
create policy "own profile"   on public.profiles          for all using (auth.uid() = id);
create policy "own holdings"  on public.holdings          for all using (auth.uid() = user_id);
create policy "own tx"        on public.transactions      for all using (auth.uid() = user_id);
create policy "own watchlist" on public.watchlist         for all using (auth.uid() = user_id);
create policy "own wallets"   on public.wallet_connections for all using (auth.uid() = user_id);

-- Trigger: crea profilo automaticamente dopo signup
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer as $$
begin
  insert into public.profiles (id, username)
  values (new.id, coalesce(new.raw_user_meta_data->>'username', split_part(new.email, '@', 1)));
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();
