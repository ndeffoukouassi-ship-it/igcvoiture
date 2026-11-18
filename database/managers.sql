
create table public.autowash_managers(
 user_id uuid primary key references auth.users(id) on delete cascade,
 owner_id uuid not null references public.autowash_centres(owner_id) on delete cascade,
 active boolean not null default true,
 created_at timestamptz not null default now(),check(user_id<>owner_id)
);
create index autowash_managers_owner_idx on public.autowash_managers(owner_id);
alter table public.autowash_managers enable row level security;
revoke all on public.autowash_managers from anon,authenticated;
grant select,update on public.autowash_managers to authenticated;
create policy managers_read on public.autowash_managers for select to authenticated using((select auth.uid())=owner_id or (select auth.uid())=user_id);
create policy managers_update on public.autowash_managers for update to authenticated using((select auth.uid())=owner_id) with check((select auth.uid())=owner_id);
create table public.autowash_manager_invites(
 token_hash text primary key check(token_hash~'^[a-f0-9]{64}$'),
 owner_id uuid not null references public.autowash_centres(owner_id) on delete cascade,
 expires_at timestamptz not null default now()+interval '7 days',
 used_by uuid references auth.users(id),
 created_at timestamptz not null default now()
);
create index autowash_manager_invites_owner_idx on public.autowash_manager_invites(owner_id);
alter table public.autowash_manager_invites enable row level security;
revoke all on public.autowash_manager_invites from anon,authenticated;
grant select,insert on public.autowash_manager_invites to authenticated;
create policy invites_read on public.autowash_manager_invites for select to authenticated using((select auth.uid())=owner_id);
create policy invites_insert on public.autowash_manager_invites for insert to authenticated with check((select auth.uid())=owner_id and used_by is null and expires_at<=now()+interval '7 days');

create function autowash_private.has_centre_access(target text) returns boolean language sql stable security definer set search_path='' as $$
select auth.uid() is not null and (auth.uid()::text=target or exists(select 1 from public.autowash_managers m where m.user_id=auth.uid() and m.owner_id::text=target and m.active));
$$;
revoke all on function autowash_private.has_centre_access(text) from public;
grant execute on function autowash_private.has_centre_access(text) to authenticated;

create function autowash_private.load_workspace() returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); target uuid; s public.autowash_centres;
begin
 if actor is null then raise exception 'AUTH_REQUIRED' using errcode='42501';end if;
 select owner_id into target from public.autowash_managers where user_id=actor and active;
 target:=coalesce(target,actor);
 if target=actor then insert into public.autowash_centres(owner_id) values(actor) on conflict do nothing;end if;
 select * into s from public.autowash_centres where owner_id=target;
 if not found then raise exception 'CENTRE_NOT_FOUND';end if;
 return jsonb_build_object('state',s.state,'revision',s.revision,'owner_id',target,'role',case when target=actor then 'owner' else 'manager' end);
end $$;
revoke all on function autowash_private.load_workspace() from public;
grant execute on function autowash_private.load_workspace() to authenticated;
create function public.autowash_workspace() returns jsonb language sql security invoker set search_path='' as $$ select autowash_private.load_workspace(); $$;
revoke all on function public.autowash_workspace() from public,anon;grant execute on function public.autowash_workspace() to authenticated;

create function autowash_private.save_workspace(centre_id uuid,expected_revision bigint,next_state jsonb) returns bigint language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); previous jsonb; revision_now bigint; result bigint; payload jsonb;
begin
 if actor is null or not autowash_private.has_centre_access(centre_id::text) then raise exception 'ACCESS_REVOKED' using errcode='42501';end if;
 select state,revision into previous,revision_now from public.autowash_centres where owner_id=centre_id for update;
 if revision_now<>expected_revision then raise exception 'CONCURRENT_EDIT' using errcode='40001';end if;
 payload:=next_state;
 if actor<>centre_id then
 if next_state->'center' is distinct from previous->'center' or next_state->'services' is distinct from previous->'services' or next_state->'loyaltyEnabled' is distinct from previous->'loyaltyEnabled' then raise exception 'OWNER_SETTINGS_ONLY' using errcode='42501';end if;
 payload:=previous||jsonb_build_object('tickets',next_state->'tickets','expenses',next_state->'expenses','loyaltyLinks',coalesce(next_state->'loyaltyLinks','{}'));
 end if;
 update public.autowash_centres set state=payload,revision=revision+1,updated_at=now() where owner_id=centre_id returning revision into result;
 return result;
end $$;
revoke all on function autowash_private.save_workspace(uuid,bigint,jsonb) from public;
grant execute on function autowash_private.save_workspace(uuid,bigint,jsonb) to authenticated;
create function public.autowash_save_workspace(centre_id uuid,expected_revision bigint,next_state jsonb) returns bigint language sql security invoker set search_path='' as $$ select autowash_private.save_workspace(centre_id,expected_revision,next_state);$$;
revoke all on function public.autowash_save_workspace(uuid,bigint,jsonb) from public,anon;grant execute on function public.autowash_save_workspace(uuid,bigint,jsonb) to authenticated;

create function autowash_private.join_manager(invitation text) returns void language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); target uuid; digest text;
begin
 if actor is null or invitation!~'^[a-f0-9]{64}$' then raise exception 'INVITATION_INVALID' using errcode='42501';end if;
 digest:=encode(sha256(convert_to(invitation,'UTF8')),'hex');
 select owner_id into target from public.autowash_manager_invites where token_hash=digest and used_by is null and expires_at>now() for update;
 if not found or target=actor then raise exception 'INVITATION_INVALID' using errcode='42501';end if;
 if exists(select 1 from public.autowash_managers where user_id=actor and active) then raise exception 'ALREADY_MANAGER';end if;
 insert into public.autowash_managers(user_id,owner_id) values(actor,target) on conflict(user_id) do update set owner_id=excluded.owner_id,active=true,created_at=now();
 update public.autowash_manager_invites set used_by=actor where token_hash=digest;
end $$;
revoke all on function autowash_private.join_manager(text) from public;
grant execute on function autowash_private.join_manager(text) to authenticated;
create function public.autowash_join_manager(invitation text) returns void language sql security invoker set search_path='' as $$select autowash_private.join_manager(invitation);$$;
revoke all on function public.autowash_join_manager(text) from public,anon;grant execute on function public.autowash_join_manager(text) to authenticated;

create function autowash_private.list_managers() returns jsonb language sql security definer set search_path='' as $$
select coalesce(jsonb_agg(jsonb_build_object('user_id',m.user_id,'email',u.email,'active',m.active)),'[]') from public.autowash_managers m join auth.users u on u.id=m.user_id where auth.uid() is not null and m.owner_id=auth.uid();
$$;
revoke all on function autowash_private.list_managers() from public;
grant execute on function autowash_private.list_managers() to authenticated;
create function public.autowash_list_managers() returns jsonb language sql security invoker set search_path='' as $$ select autowash_private.list_managers();$$;
revoke all on function public.autowash_list_managers() from public,anon;grant execute on function public.autowash_list_managers() to authenticated;

drop policy receipt_read on storage.objects;
drop policy receipt_insert on storage.objects;
create policy receipt_read on storage.objects for select to authenticated using(bucket_id='autowash-receipts' and autowash_private.has_centre_access((storage.foldername(name))[1]));
create policy receipt_insert on storage.objects for insert to authenticated with check(bucket_id='autowash-receipts' and autowash_private.has_centre_access((storage.foldername(name))[1]));
drop policy loyalty_owner_select on public.autowash_loyalty_links;
drop policy loyalty_owner_insert on public.autowash_loyalty_links;
drop policy loyalty_owner_update on public.autowash_loyalty_links;
create policy loyalty_centre_select on public.autowash_loyalty_links for select to authenticated using(autowash_private.has_centre_access(owner_id::text));
create policy loyalty_centre_insert on public.autowash_loyalty_links for insert to authenticated with check(autowash_private.has_centre_access(owner_id::text));
create policy loyalty_centre_update on public.autowash_loyalty_links for update to authenticated using(autowash_private.has_centre_access(owner_id::text)) with check(autowash_private.has_centre_access(owner_id::text));

