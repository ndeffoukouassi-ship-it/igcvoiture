
begin;
insert into auth.users(id,aud,role,email,raw_user_meta_data) values
('40000000-0000-4000-8000-000000000001','authenticated','authenticated','admin-test-owner@example.invalid','{"admin":true}'),
('40000000-0000-4000-8000-000000000002','authenticated','authenticated','admin-test-manager@example.invalid','{}');
insert into public.autowash_centres(owner_id) values('40000000-0000-4000-8000-000000000001');
insert into public.autowash_managers(user_id,owner_id) values('40000000-0000-4000-8000-000000000002','40000000-0000-4000-8000-000000000001');
insert into public.autowash_loyalty_links(token_hash,owner_id,plate) values(encode(sha256(convert_to(repeat('d',64),'UTF8')),'hex'),'40000000-0000-4000-8000-000000000001','TEST123');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"40000000-0000-4000-8000-000000000001","role":"authenticated","user_metadata":{"admin":true}}',true);
do $$begin
 if public.autowash_is_platform_admin() then raise exception 'FAIL metadata privilege escalation';end if;
 begin perform public.autowash_admin_centres();raise exception 'FAIL centre list access';exception when insufficient_privilege then null;end;
 begin perform public.autowash_admin_set_license('40000000-0000-4000-8000-000000000001','active',null,0,'');raise exception 'FAIL billing write';exception when insufficient_privilege then null;end;
 begin perform * from autowash_private.platform_admins;raise exception 'FAIL role table exposure';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claims','{"sub":"245f7915-1c2d-4e50-a96b-6083512dc55d","role":"authenticated"}',true);
do $$begin
 if not public.autowash_is_platform_admin() then raise exception 'FAIL designated administrator';end if;
 if jsonb_array_length(public.autowash_admin_centres())<2 then raise exception 'FAIL admin listing';end if;
 perform public.autowash_admin_set_license('40000000-0000-4000-8000-000000000001','suspended',null,10000,'TEST ONLY');
end $$;
select set_config('request.jwt.claims','{"sub":"40000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
do $$declare n int;begin
 begin perform public.autowash_workspace();raise exception 'FAIL suspended workspace';exception when insufficient_privilege then null;end;
 if autowash_private.has_centre_access('40000000-0000-4000-8000-000000000001') then raise exception 'FAIL suspended storage';end if;
 select count(*) into n from public.autowash_centres;if n<>0 then raise exception 'FAIL legacy read bypass';end if;
end $$;
select set_config('request.jwt.claims','{"sub":"40000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
do $$begin
 begin perform public.autowash_workspace();raise exception 'FAIL suspended manager';exception when insufficient_privilege then null;end;
end $$;
set local role anon;
do $$begin if public.autowash_customer_loyalty(repeat('d',64)) is not null then raise exception 'FAIL suspended customer link';end if;end $$;
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"245f7915-1c2d-4e50-a96b-6083512dc55d","role":"authenticated"}',true);
select public.autowash_admin_set_license('40000000-0000-4000-8000-000000000001','active',current_date-1,10000,'TEST EXPIRY');
select set_config('request.jwt.claims','{"sub":"40000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
do $$begin if autowash_private.has_centre_access('40000000-0000-4000-8000-000000000001') then raise exception 'FAIL expired license';end if;end $$;
select set_config('request.jwt.claims','{"sub":"245f7915-1c2d-4e50-a96b-6083512dc55d","role":"authenticated"}',true);
select public.autowash_admin_set_license('40000000-0000-4000-8000-000000000001','active',current_date+30,10000,'TEST RESTORE');
select set_config('request.jwt.claims','{"sub":"40000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
do $$declare w jsonb;begin w:=public.autowash_workspace();if w->>'role'<>'owner' then raise exception 'FAIL restored access';end if;end $$;
reset role;
select 'PASS: designated admin, metadata spoofing denial, private role table, manual license updates, suspension, expiry and reactivation' result;
rollback;

