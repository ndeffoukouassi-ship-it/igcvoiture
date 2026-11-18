
create table public.autowash_loyalty_links(
 token_hash text primary key check(token_hash ~ '^[a-f0-9]{64}$'),
 owner_id uuid not null references public.autowash_centres(owner_id) on delete cascade,
 plate text not null check(plate ~ '^[A-Z0-9]{4,25}$'),
 revoked boolean not null default false,
 created_at timestamptz not null default now()
);
create index autowash_loyalty_owner_idx on public.autowash_loyalty_links(owner_id);
alter table public.autowash_loyalty_links enable row level security;
revoke all on public.autowash_loyalty_links from anon,authenticated;
grant select,insert,update on public.autowash_loyalty_links to authenticated;
create policy loyalty_owner_select on public.autowash_loyalty_links for select to authenticated using((select auth.uid())=owner_id);
create policy loyalty_owner_insert on public.autowash_loyalty_links for insert to authenticated with check((select auth.uid())=owner_id);
create policy loyalty_owner_update on public.autowash_loyalty_links for update to authenticated using((select auth.uid())=owner_id) with check((select auth.uid())=owner_id);

create schema if not exists autowash_private;
revoke all on schema autowash_private from public;
grant usage on schema autowash_private to anon,authenticated;
-- This deliberately accepts a 256-bit capability instead of an account login.
-- It returns only the allowlisted loyalty fields, never the centre's private state.
create function autowash_private.read_loyalty(access_token text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare link public.autowash_loyalty_links; snapshot jsonb; t jsonb; count_paid int:=0; total int:=0; visits jsonb:='[]'; enabled boolean; gift_pending boolean:=false; eligible boolean;
begin
 if access_token is null or access_token !~ '^[a-f0-9]{64}$' then return null; end if;
 select * into link from public.autowash_loyalty_links
 where token_hash=pg_catalog.encode(pg_catalog.sha256(pg_catalog.convert_to(access_token,'UTF8')),'hex') and revoked=false;
 if not found then return null; end if;
 select state into snapshot from public.autowash_centres where owner_id=link.owner_id;
 if snapshot is null then return null; end if;
 enabled := coalesce((snapshot->>'loyaltyEnabled')::boolean,false);
 for t in select value from pg_catalog.jsonb_array_elements(snapshot->'tickets') loop
  if pg_catalog.regexp_replace(pg_catalog.upper(coalesce(t->>'plate','')),'[^A-Z0-9]','','g')<>link.plate then continue; end if;
  if t->>'gift'='true' then count_paid:=0; gift_pending:= t->>'status'<>'Terminé';
  elsif t->>'status'='Terminé' and coalesce(t->>'payment','')<>'' and (t->>'amount')::numeric>0 then count_paid:=count_paid+1; end if;
  if t->>'status'='Terminé' and (t->>'gift'='true' or (coalesce(t->>'payment','')<>'' and (t->>'amount')::numeric>0)) then
   total:=total+1; visits:=pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object('date',t->'created','gift',coalesce(t->>'gift','false')='true')) || visits;
  end if;
 end loop;
 select coalesce(pg_catalog.jsonb_agg(value),'[]') into visits from (select value from pg_catalog.jsonb_array_elements(visits) limit 50) last_visits;
 eligible:=enabled and count_paid>=9;
 return pg_catalog.jsonb_build_object('center',snapshot->>'center','plate',link.plate,'enabled',enabled,'paidCount',count_paid,'eligible',eligible,'remaining',greatest(0,9-count_paid),'totalVisits',total,'giftPending',gift_pending,'visits',visits);
end $$;
revoke all on function autowash_private.read_loyalty(text) from public;
grant execute on function autowash_private.read_loyalty(text) to anon,authenticated;
create function public.autowash_customer_loyalty(access_token text)
returns jsonb language sql security invoker set search_path='' as $$
 select autowash_private.read_loyalty(access_token);
$$;
revoke all on function public.autowash_customer_loyalty(text) from public;
grant execute on function public.autowash_customer_loyalty(text) to anon,authenticated;

