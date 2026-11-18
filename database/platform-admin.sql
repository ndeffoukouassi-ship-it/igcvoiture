
create table autowash_private.platform_admins(user_id uuid primary key references auth.users(id) on delete cascade,created_at timestamptz not null default now());
alter table autowash_private.platform_admins enable row level security;
revoke all on autowash_private.platform_admins from public,anon,authenticated;
insert into autowash_private.platform_admins(user_id)
 select id from auth.users where lower(email)='ndeffoukouassi@gmail.com' and email_confirmed_at is not null;
create function autowash_private.is_platform_admin() returns boolean language sql stable security definer set search_path='' as $$
select auth.uid() is not null and exists(select 1 from autowash_private.platform_admins a join auth.users u on u.id=a.user_id where a.user_id=auth.uid() and u.email_confirmed_at is not null);
$$;
revoke all on function autowash_private.is_platform_admin() from public;
grant execute on function autowash_private.is_platform_admin() to authenticated;
create function public.autowash_is_platform_admin() returns boolean language sql security invoker set search_path='' as $$select autowash_private.is_platform_admin();$$;
revoke all on function public.autowash_is_platform_admin() from public,anon;
grant execute on function public.autowash_is_platform_admin() to authenticated;

create table autowash_private.centre_licenses(
 owner_id uuid primary key references public.autowash_centres(owner_id) on delete cascade,
 status text not null default 'trial' check(status in ('trial','active','suspended')),
 expires_on date,
 monthly_amount integer not null default 0 check(monthly_amount>=0 and monthly_amount<=100000000),
 notes text not null default '' check(length(notes)<=2000),
 updated_at timestamptz not null default now()
);
alter table autowash_private.centre_licenses enable row level security;
revoke all on autowash_private.centre_licenses from public,anon,authenticated;
create table autowash_private.admin_audit(
 id bigint generated always as identity primary key,
 actor uuid not null references auth.users(id),centre_id uuid not null,
 action text not null,details jsonb not null,created_at timestamptz not null default now()
);
alter table autowash_private.admin_audit enable row level security;
revoke all on autowash_private.admin_audit from public,anon,authenticated;

create function autowash_private.centre_enabled(centre uuid) returns boolean language sql stable security definer set search_path='' as $$
select not exists(select 1 from autowash_private.centre_licenses l where l.owner_id=centre and (l.status='suspended' or (l.expires_on is not null and l.expires_on<current_date)));
$$;
revoke all on function autowash_private.centre_enabled(uuid) from public;
grant execute on function autowash_private.centre_enabled(uuid) to authenticated;

create function autowash_private.admin_centres() returns jsonb language plpgsql security definer set search_path='' as $$
begin
 if not autowash_private.is_platform_admin() then raise exception 'ADMIN_REQUIRED' using errcode='42501';end if;
 return (select coalesce(jsonb_agg(row),'[]') from(
 select c.owner_id,c.state->>'center' as name,u.email as owner_email,u.created_at,
 jsonb_array_length(c.state->'tickets') as tickets,
 (select count(*) from public.autowash_managers m where m.owner_id=c.owner_id and m.active) as managers,
 coalesce(l.status,'trial') as status,l.expires_on,coalesce(l.monthly_amount,0) as monthly_amount,coalesce(l.notes,'') as notes,
 autowash_private.centre_enabled(c.owner_id) as enabled,c.updated_at
 from public.autowash_centres c join auth.users u on u.id=c.owner_id left join autowash_private.centre_licenses l on l.owner_id=c.owner_id
 order by u.created_at desc)row);
end $$;
revoke all on function autowash_private.admin_centres() from public;
grant execute on function autowash_private.admin_centres() to authenticated;
create function public.autowash_admin_centres() returns jsonb language sql security invoker set search_path='' as $$select autowash_private.admin_centres();$$;
revoke all on function public.autowash_admin_centres() from public,anon;
grant execute on function public.autowash_admin_centres() to authenticated;

create function autowash_private.admin_set_license(centre uuid,new_status text,expiry date,amount integer,admin_notes text) returns void language plpgsql security definer set search_path='' as $$
declare before_row jsonb;
begin
 if not autowash_private.is_platform_admin() then raise exception 'ADMIN_REQUIRED' using errcode='42501';end if;
 if new_status not in ('trial','active','suspended') or amount is null or amount<0 or amount>100000000 or admin_notes is null or length(admin_notes)>2000 then raise exception 'INVALID_LICENSE';end if;
 if not exists(select 1 from public.autowash_centres where owner_id=centre) then raise exception 'CENTRE_NOT_FOUND';end if;
 select to_jsonb(l) into before_row from autowash_private.centre_licenses l where l.owner_id=centre;
 insert into autowash_private.centre_licenses(owner_id,status,expires_on,monthly_amount,notes)
 values(centre,new_status,expiry,amount,admin_notes)
 on conflict(owner_id) do update set status=excluded.status,expires_on=excluded.expires_on,monthly_amount=excluded.monthly_amount,notes=excluded.notes,updated_at=now();
 insert into autowash_private.admin_audit(actor,centre_id,action,details) values(auth.uid(),centre,'set_license',jsonb_build_object('before',before_row,'after',jsonb_build_object('status',new_status,'expires_on',expiry,'monthly_amount',amount,'notes',admin_notes)));
end $$;
revoke all on function autowash_private.admin_set_license(uuid,text,date,integer,text) from public;
grant execute on function autowash_private.admin_set_license(uuid,text,date,integer,text) to authenticated;
create function public.autowash_admin_set_license(centre uuid,new_status text,expiry date,amount integer,admin_notes text) returns void language sql security invoker set search_path='' as $$select autowash_private.admin_set_license(centre,new_status,expiry,amount,admin_notes);$$;
revoke all on function public.autowash_admin_set_license(uuid,text,date,integer,text) from public,anon;
grant execute on function public.autowash_admin_set_license(uuid,text,date,integer,text) to authenticated;

create function autowash_private.admin_history() returns jsonb language plpgsql security definer set search_path='' as $$
begin if not autowash_private.is_platform_admin() then raise exception 'ADMIN_REQUIRED' using errcode='42501';end if;
return (select coalesce(jsonb_agg(r),'[]') from(select a.centre_id,c.state->>'center' as name,a.action,a.details,a.created_at from autowash_private.admin_audit a left join public.autowash_centres c on c.owner_id=a.centre_id order by a.created_at desc limit 30)r);
end $$;
revoke all on function autowash_private.admin_history() from public;
grant execute on function autowash_private.admin_history() to authenticated;
create function public.autowash_admin_history() returns jsonb language sql security invoker set search_path='' as $$select autowash_private.admin_history();$$;
revoke all on function public.autowash_admin_history() from public,anon;
grant execute on function public.autowash_admin_history() to authenticated;

create or replace function autowash_private.has_centre_access(target text) returns boolean language sql stable security definer set search_path='' as $$
select auth.uid() is not null and exists(select 1 from public.autowash_centres c where c.owner_id::text=target
 and (autowash_private.centre_enabled(c.owner_id) or (c.owner_id=auth.uid() and autowash_private.is_platform_admin()))
 and (c.owner_id=auth.uid() or exists(select 1 from public.autowash_managers m where m.user_id=auth.uid() and m.owner_id=c.owner_id and m.active)));
$$;

drop policy centre_read on public.autowash_centres;
drop policy centre_update on public.autowash_centres;
create policy centre_read on public.autowash_centres for select to authenticated using((select auth.uid())=owner_id and autowash_private.has_centre_access(owner_id::text));
create policy centre_update on public.autowash_centres for update to authenticated using((select auth.uid())=owner_id and autowash_private.has_centre_access(owner_id::text)) with check((select auth.uid())=owner_id and autowash_private.has_centre_access(owner_id::text));


create policy admins_deny_direct_clients on autowash_private.platform_admins as restrictive for all to anon,authenticated using(false) with check(false);
create policy licenses_deny_direct_clients on autowash_private.centre_licenses as restrictive for all to anon,authenticated using(false) with check(false);
create policy audit_deny_direct_clients on autowash_private.admin_audit as restrictive for all to anon,authenticated using(false) with check(false);
