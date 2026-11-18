
begin;
insert into auth.users(id,aud,role,email) values('20000000-0000-4000-8000-000000000001','authenticated','authenticated','loyalty-test@example.invalid');
insert into public.autowash_centres(owner_id,state)
select '20000000-0000-4000-8000-000000000001',
jsonb_build_object('center','Centre Test','loyaltyEnabled',true,'services','[]'::jsonb,'expenses',jsonb_build_array(jsonb_build_object('label','PRIVATE EXPENSE','amount',999999)),'tickets',
(select jsonb_agg(jsonb_build_object('plate','AB 123 CD','amount',1500,'payment','Espèces','status','Terminé','created',1794950000000+i*1000,'phone','PRIVATE PHONE')) from generate_series(1,9) i));
insert into public.autowash_loyalty_links(token_hash,owner_id,plate) values(encode(sha256(convert_to(repeat('a',64),'UTF8')),'hex'),'20000000-0000-4000-8000-000000000001','AB123CD');
set local role anon;
do $$ declare r jsonb; begin
r:=public.autowash_customer_loyalty(repeat('a',64));
if r->>'paidCount'<>'9' or r->>'eligible'<>'true' or r->>'remaining'<>'0' then raise exception 'FAIL reward 9 paid washes'; end if;
if jsonb_array_length(r->'visits')<>9 then raise exception 'FAIL visit history'; end if;
if r::text like '%PRIVATE%' or r ? 'expenses' or r ? 'owner_id' then raise exception 'FAIL private data leak'; end if;
if public.autowash_customer_loyalty(repeat('b',64)) is not null then raise exception 'FAIL wrong link'; end if;
if public.autowash_customer_loyalty('AB123CD') is not null then raise exception 'FAIL plate lookup'; end if;
begin perform * from public.autowash_loyalty_links; raise exception 'FAIL anonymous link list';
exception when insufficient_privilege then null; end;
end $$;
reset role;
update public.autowash_centres set state=jsonb_set(state,'{tickets}',(state->'tickets')||jsonb_build_array(jsonb_build_object('plate','AB123CD','gift',true,'status','En attente','created',1794960000000,'amount',0,'payment','Offert'))) where owner_id='20000000-0000-4000-8000-000000000001';
set local role anon;
do $$ declare r jsonb; begin r:=public.autowash_customer_loyalty(repeat('a',64));if r->>'paidCount'<>'0' or r->>'eligible'<>'false' or r->>'giftPending'<>'true' then raise exception 'FAIL reward reset'; end if;end $$;
reset role;
update public.autowash_loyalty_links set revoked=true where owner_id='20000000-0000-4000-8000-000000000001';
set local role anon;
do $$ begin if public.autowash_customer_loyalty(repeat('a',64)) is not null then raise exception 'FAIL revoked link'; end if; end $$;
reset role;
select 'PASS: gift eligibility, history, private fields, invalid links, anonymous denial, gift reset, revocation' as result;
rollback;

