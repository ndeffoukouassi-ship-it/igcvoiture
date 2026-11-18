create or replace function autowash_private.load_workspace() returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); target uuid; s public.autowash_centres;
begin
 if actor is null then raise exception 'AUTH_REQUIRED' using errcode='42501';end if;
 select owner_id into target from public.autowash_managers where user_id=actor and active;
 target:=coalesce(target,actor);
 if target=actor then insert into public.autowash_centres(owner_id) values(actor) on conflict do nothing;end if;
 if not autowash_private.has_centre_access(target::text) then raise exception 'CENTRE_SUSPENDED' using errcode='42501';end if;
 select * into s from public.autowash_centres where owner_id=target;
 if not found then raise exception 'CENTRE_NOT_FOUND';end if;
 return jsonb_build_object('state',s.state,'revision',s.revision,'owner_id',target,'role',case when target=actor then 'owner' else 'manager' end);
end $$;

create or replace function autowash_private.read_loyalty(access_token text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare link public.autowash_loyalty_links; snapshot jsonb; t jsonb; count_paid int:=0; total int:=0; visits jsonb:='[]'; enabled boolean; gift_pending boolean:=false; eligible boolean;
begin
 if access_token is null or access_token !~ '^[a-f0-9]{64}$' then return null; end if;
 select * into link from public.autowash_loyalty_links
 where token_hash=pg_catalog.encode(pg_catalog.sha256(pg_catalog.convert_to(access_token,'UTF8')),'hex') and revoked=false;
 if not found then return null; end if;
 if not autowash_private.centre_enabled(link.owner_id) then return null; end if;
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
