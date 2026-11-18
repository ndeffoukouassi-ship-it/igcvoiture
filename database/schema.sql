
create table public.autowash_centres (
 owner_id uuid primary key references auth.users(id) on delete cascade,
 state jsonb not null default '{"center":"Mon centre de lavage","loyaltyEnabled":false,"services":[{"name":"Lavage extérieur","price":1500},{"name":"Lavage complet","price":3000},{"name":"Intérieur premium","price":5000}],"tickets":[],"expenses":[]}'::jsonb,
 revision bigint not null default 0 check(revision >= 0),
 updated_at timestamptz not null default now(),
 constraint autowash_state_shape check (
 jsonb_typeof(state) = 'object'
 and jsonb_typeof(state->'tickets') = 'array'
 and jsonb_typeof(state->'expenses') = 'array'
 and jsonb_typeof(state->'services') = 'array'
 and jsonb_typeof(state->'center') = 'string'
 and octet_length(state::text) < 12000000)
);
alter table public.autowash_centres enable row level security;
revoke all on public.autowash_centres from anon, authenticated;
grant select, insert, update on public.autowash_centres to authenticated;
create policy centre_read on public.autowash_centres for select to authenticated
 using ((select auth.uid()) = owner_id);
create policy centre_create on public.autowash_centres for insert to authenticated
 with check ((select auth.uid()) = owner_id);
create policy centre_update on public.autowash_centres for update to authenticated
 using ((select auth.uid()) = owner_id) with check ((select auth.uid()) = owner_id);

create function public.autowash_save(expected_revision bigint, next_state jsonb)
returns bigint language plpgsql security invoker set search_path='' as $$
declare new_revision bigint;
begin
 if auth.uid() is null then raise exception 'AUTH_REQUIRED' using errcode='42501'; end if;
 update public.autowash_centres set state=next_state, revision=revision+1, updated_at=now()
 where owner_id=auth.uid() and revision=expected_revision returning revision into new_revision;
 if new_revision is null then raise exception 'CONCURRENT_EDIT' using errcode='40001'; end if;
 return new_revision;
end $$;
revoke all on function public.autowash_save(bigint,jsonb) from public,anon;
grant execute on function public.autowash_save(bigint,jsonb) to authenticated;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('autowash-receipts','autowash-receipts',false,2000000,array['image/jpeg','image/png','image/webp']);
create policy receipt_read on storage.objects for select to authenticated
 using(bucket_id='autowash-receipts' and (storage.foldername(name))[1]=(select auth.uid())::text);
create policy receipt_insert on storage.objects for insert to authenticated
 with check(bucket_id='autowash-receipts' and (storage.foldername(name))[1]=(select auth.uid())::text);

