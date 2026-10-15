-- Execute in Supabase SQL Editor. Internal demo CLP credits only.
create extension if not exists pgcrypto;
create table public.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 display_name text not null default 'Usuario',
 qr_token uuid not null unique default gen_random_uuid(),
 role text not null default 'user' check(role in ('user','admin')),
 created_at timestamptz not null default now()
);
create table public.wallets (
 user_id uuid primary key references public.profiles(id) on delete cascade,
 balance bigint not null default 0 check(balance>=0)
);
create table public.transfers (
 id uuid primary key default gen_random_uuid(),
 sender_id uuid references public.profiles(id),
 recipient_id uuid not null references public.profiles(id),
 amount bigint not null check(amount>0),
 request_key uuid not null unique,
 created_at timestamptz not null default now(),
 check(sender_id is distinct from recipient_id)
);
create table public.admin_adjustments (
 id uuid primary key default gen_random_uuid(),
 admin_id uuid not null references public.profiles(id),
 target_id uuid not null references public.profiles(id),
 amount bigint not null check(amount<>0),
 created_at timestamptz not null default now()
);
create function public.on_signup() returns trigger language plpgsql security definer set search_path='' as $$
begin
 insert into public.profiles(id,display_name) values(new.id,coalesce(nullif(left(new.raw_user_meta_data->>'name',80),''),'Usuario'));
 insert into public.wallets(user_id) values(new.id);
 return new;
end $$;
create trigger create_wallet after insert on auth.users for each row execute function public.on_signup();
alter table public.profiles enable row level security;
alter table public.wallets enable row level security;
alter table public.transfers enable row level security;
alter table public.admin_adjustments enable row level security;
create policy profile_self on public.profiles for select to authenticated using(id=auth.uid());
create policy wallet_self on public.wallets for select to authenticated using(user_id=auth.uid());
create policy transfer_self on public.transfers for select to authenticated using(sender_id=auth.uid() or recipient_id=auth.uid());
create function public.resolve_qr(p_token uuid) returns table(id uuid,display_name text) language sql security definer set search_path='' stable as $$
 select p.id,p.display_name from public.profiles p where p.qr_token=p_token and auth.uid() is not null limit 1
$$;
create function public.send_credits(p_token uuid,p_amount bigint,p_request_key uuid) returns uuid language plpgsql security definer set search_path='' as $$
declare v_from uuid:=auth.uid(); v_to uuid; v_id uuid; v_balance bigint;
begin
 if v_from is null then raise exception 'Sesión requerida'; end if;
 if p_amount is null or p_amount<=0 or p_amount>10000000 then raise exception 'Monto inválido'; end if;
 if p_request_key is null then raise exception 'Identificador requerido'; end if;
 select t.id into v_id from public.transfers t where t.request_key=p_request_key;
 if found then
  if exists(select 1 from public.transfers where id=v_id and sender_id=v_from and amount=p_amount and recipient_id=(select id from public.profiles where qr_token=p_token)) then return v_id; end if;
  raise exception 'Identificador duplicado';
 end if;
 select id into v_to from public.profiles where qr_token=p_token;
 if v_to is null or v_to=v_from then raise exception 'Destinatario inválido'; end if;
 -- Serialize all transfers with a transaction-scoped advisory lock; safe but limits throughput.
 perform pg_advisory_xact_lock(772244);
 select t.id into v_id from public.transfers t where t.request_key=p_request_key;
 if found then
  if exists(select 1 from public.transfers where id=v_id and sender_id=v_from and recipient_id=v_to and amount=p_amount) then return v_id; end if;
  raise exception 'Identificador duplicado';
 end if;
 select balance into v_balance from public.wallets where user_id=v_from for update;
 if v_balance is null or v_balance<p_amount then raise exception 'Saldo insuficiente'; end if;
 update public.wallets set balance=balance-p_amount where user_id=v_from;
 update public.wallets set balance=balance+p_amount where user_id=v_to;
 insert into public.transfers(sender_id,recipient_id,amount,request_key) values(v_from,v_to,p_amount,p_request_key) returning id into v_id;
 return v_id;
end $$;
create function public.admin_adjust(p_target uuid,p_amount bigint) returns void language plpgsql security definer set search_path='' as $$
declare v_admin uuid:=auth.uid();
begin
 if not exists(select 1 from public.profiles where id=v_admin and role='admin') then raise exception 'No autorizado'; end if;
 if p_amount is null or p_amount=0 or abs(p_amount)>10000000 then raise exception 'Monto inválido'; end if;
 perform pg_advisory_xact_lock(772244);
 update public.wallets set balance=balance+p_amount where user_id=p_target and balance+p_amount>=0;
 if not found then raise exception 'Usuario inexistente o saldo insuficiente'; end if;
 insert into public.admin_adjustments(admin_id,target_id,amount) values(v_admin,p_target,p_amount);
end $$;
revoke all on function public.resolve_qr(uuid) from public;
revoke all on function public.send_credits(uuid,bigint,uuid) from public;
revoke all on function public.admin_adjust(uuid,bigint) from public;
grant execute on function public.resolve_qr(uuid) to authenticated;
grant execute on function public.send_credits(uuid,bigint,uuid) to authenticated;
grant execute on function public.admin_adjust(uuid,bigint) to authenticated;
-- Promote one known account manually AFTER signing up:
-- update public.profiles set role='admin' where id='AUTH-USER-UUID-HERE';
