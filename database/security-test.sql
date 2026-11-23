
begin;
insert into auth.users(id,aud,role,email) values
 ('10000000-0000-4000-8000-000000000001','authenticated','authenticated','autowash-test-a@example.invalid'),
 ('10000000-0000-4000-8000-000000000002','authenticated','authenticated','autowash-test-b@example.invalid');
insert into public.autowash_centres(owner_id) values
 ('10000000-0000-4000-8000-000000000001'),('10000000-0000-4000-8000-000000000002');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
do $$ declare n int; r bigint; begin
 select count(*) into n from public.autowash_centres;
 if n<>1 then raise exception 'FAIL tenant isolation select'; end if;
 update public.autowash_centres set revision=7 where owner_id='10000000-0000-4000-8000-000000000002';
 get diagnostics n=row_count;
 if n<>0 then raise exception 'FAIL tenant isolation update'; end if;
 begin
 update public.autowash_centres set owner_id='10000000-0000-4000-8000-000000000003';
 raise exception 'FAIL reassign owner';
 exception when insufficient_privilege then null;
 end;
 select public.autowash_save(0,state) into r from public.autowash_centres;
 if r<>1 then raise exception 'FAIL save'; end if;
 begin
 perform public.autowash_save(0,state) from public.autowash_centres;
 raise exception 'FAIL concurrent edit';
 exception when sqlstate 'PT409' then null;
 end;
 insert into storage.objects(bucket_id,name) values('autowash-receipts','10000000-0000-4000-8000-000000000001/test.jpg');
 begin
 insert into storage.objects(bucket_id,name) values('autowash-receipts','10000000-0000-4000-8000-000000000002/test.jpg');
 raise exception 'FAIL receipt tenant isolation';
 exception when insufficient_privilege then null;
 end;
end $$;
set local role anon;
do $$ begin
 begin perform * from public.autowash_centres; raise exception 'FAIL anonymous access';
 exception when insufficient_privilege then null; end;
end $$;
reset role;
select 'PASS: owner isolation, owner reassignment, optimistic concurrency, private storage and anonymous denial' as result;
rollback;

