begin;
insert into auth.users(id,aud,role,email) values
('40000000-0000-4000-8000-000000000001','authenticated','authenticated','worker-owner-test@example.invalid'),
('40000000-0000-4000-8000-000000000002','authenticated','authenticated','worker-manager-test@example.invalid');
insert into public.autowash_centres(owner_id) values('40000000-0000-4000-8000-000000000001');
insert into public.autowash_managers(user_id,owner_id) values('40000000-0000-4000-8000-000000000002','40000000-0000-4000-8000-000000000001');
select set_config('request.jwt.claims','{"sub":"40000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
set local role authenticated;
do $$ declare s jsonb;begin
 s:=public.autowash_workspace()->'state';
 s:=jsonb_set(s,'{workers}','[{"id":"worker-a","name":"Koffi","rate":500,"active":true}]');
 perform public.autowash_save_workspace('40000000-0000-4000-8000-000000000001',0,s);
end $$;
select set_config('request.jwt.claims','{"sub":"40000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
do $$ declare s jsonb;begin
 s:=public.autowash_workspace()->'state';
 -- Invalid new commission must be rejected even when sent directly to RPC.
 begin
 perform public.autowash_save_workspace('40000000-0000-4000-8000-000000000001',1,jsonb_set(s,'{tickets}','[{"id":"ticket-a","workerId":"worker-a","worker":"Koffi","workerFee":999,"status":"Terminé"}]'));
 raise exception 'FAIL invalid rate accepted';
 exception when others then if sqlerrm<>'INVALID_WORKER_ASSIGNMENT' then raise;end if;end;
 s:=jsonb_set(s,'{tickets}','[{"id":"ticket-a","workerId":"worker-a","worker":"Koffi","workerFee":500,"status":"Terminé"}]');
 perform public.autowash_save_workspace('40000000-0000-4000-8000-000000000001',1,s);
end $$;
reset role;
-- Direct updates cannot bypass owner-only settings.
do $$ begin
 begin update public.autowash_centres set state=jsonb_set(state,'{workers,0,rate}','900') where owner_id='40000000-0000-4000-8000-000000000001';raise exception 'FAIL manager changed rate';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claims','{"sub":"40000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
update public.autowash_centres set state=jsonb_set(state,'{workers,0,rate}','700') where owner_id='40000000-0000-4000-8000-000000000001';
do $$ declare fee int;begin
 select (state#>>'{tickets,0,workerFee}')::int into fee from public.autowash_centres where owner_id='40000000-0000-4000-8000-000000000001';
 if fee<>500 then raise exception 'FAIL historical rate changed';end if;
end $$;
select 'PASS: manager assignments, rate enforcement, owner-only settings, historical fees' result;
rollback;
