
begin;
insert into auth.users(id,aud,role,email) values
('30000000-0000-4000-8000-000000000001','authenticated','authenticated','owner-test@example.invalid'),
('30000000-0000-4000-8000-000000000002','authenticated','authenticated','manager-test@example.invalid'),
('30000000-0000-4000-8000-000000000003','authenticated','authenticated','outsider-test@example.invalid');
insert into public.autowash_centres(owner_id) values('30000000-0000-4000-8000-000000000001'),('30000000-0000-4000-8000-000000000003');
insert into public.autowash_manager_invites(token_hash,owner_id) values(encode(sha256(convert_to(repeat('c',64),'UTF8')),'hex'),'30000000-0000-4000-8000-000000000001');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"30000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
select public.autowash_join_manager(repeat('c',64));
do $$ declare w jsonb;r bigint;s jsonb;begin
w:=public.autowash_workspace();if w->>'role'<>'manager' or w->>'owner_id'<>'30000000-0000-4000-8000-000000000001' then raise exception 'FAIL workspace';end if;
s:=w->'state';
select public.autowash_save_workspace('30000000-0000-4000-8000-000000000001',0,jsonb_set(s,'{expenses}','[{"label":"Eau","amount":500}]')) into r;
if r<>1 then raise exception 'FAIL manager operations';end if;
begin perform public.autowash_save_workspace('30000000-0000-4000-8000-000000000001',1,jsonb_set(s,'{center}','"Hacked"'));raise exception 'FAIL owner settings';
exception when insufficient_privilege then null;end;
begin perform public.autowash_save_workspace('30000000-0000-4000-8000-000000000003',0,s);raise exception 'FAIL other centre';
exception when insufficient_privilege then null;end;
begin perform public.autowash_join_manager(repeat('c',64));raise exception 'FAIL reuse invite';
exception when insufficient_privilege then null;end;
if not autowash_private.has_centre_access('30000000-0000-4000-8000-000000000001') then raise exception 'FAIL receipt grant';end if;
if autowash_private.has_centre_access('30000000-0000-4000-8000-000000000003') then raise exception 'FAIL receipt isolation';end if;
if jsonb_array_length(public.autowash_list_managers())<>0 then raise exception 'FAIL manager cannot manage access';end if;
end $$;
reset role;
update public.autowash_managers set active=false where user_id='30000000-0000-4000-8000-000000000002';
set local role authenticated;
do $$ declare w jsonb;begin
w:=public.autowash_workspace();
if w->>'role'<>'owner' then raise exception 'FAIL revoked workspace';end if;
if autowash_private.has_centre_access('30000000-0000-4000-8000-000000000001') then raise exception 'FAIL revoked receipts';end if;
begin perform public.autowash_save_workspace('30000000-0000-4000-8000-000000000001',1,w->'state');raise exception 'FAIL revoked writes';exception when insufficient_privilege then null;end;
end $$;
reset role;
select 'PASS: separate accounts, manager operations, owner settings, tenant isolation, invite replay and access revocation' result;
rollback;

