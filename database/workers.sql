-- Protect owner-set worker rates on every state update, including legacy APIs.
create or replace function autowash_private.guard_workers() returns trigger
language plpgsql set search_path='' as $$
declare t jsonb; old_ticket jsonb; w jsonb; seen text[]:='{}';
begin
 if jsonb_typeof(coalesce(new.state->'workers','[]'::jsonb)) <> 'array' then raise exception 'INVALID_WORKERS';end if;
 if auth.uid() is distinct from new.owner_id and coalesce(new.state->'workers','[]'::jsonb) is distinct from coalesce(old.state->'workers','[]'::jsonb) then raise exception 'OWNER_SETTINGS_ONLY' using errcode='42501';end if;
 for w in select value from jsonb_array_elements(coalesce(new.state->'workers','[]'::jsonb)) loop
  if coalesce(w->>'id','')='' or w->>'id'=any(seen) or length(coalesce(w->>'name','')) not between 1 and 50 or coalesce(w->>'rate','')!~'^[0-9]{1,7}$' or (w->>'rate')::numeric>1000000 or coalesce(w->>'active','') not in ('true','false') then raise exception 'INVALID_WORKER';end if;
  seen:=array_append(seen,w->>'id');
 end loop;
 for t in select value from jsonb_array_elements(new.state->'tickets') loop
  select value into old_ticket from jsonb_array_elements(old.state->'tickets') where value->>'id'=t->>'id';
  if old_ticket->>'workerPaidAt' is not null and (t->'workerId' is distinct from old_ticket->'workerId' or t->'workerFee' is distinct from old_ticket->'workerFee' or t->'workerPaidAt' is distinct from old_ticket->'workerPaidAt' or t->>'status'<>'Terminé') then raise exception 'WORKER_PAYMENT_LOCKED';end if;
  if t->>'workerId' is not null then
   if coalesce(t->>'workerFee','')!~'^[0-9]{1,7}$' or (t->>'workerFee')::numeric>1000000 then raise exception 'INVALID_WORKER_FEE';end if;
   if old_ticket is null or t->'workerId' is distinct from old_ticket->'workerId' or t->'workerFee' is distinct from old_ticket->'workerFee' then
    select value into w from jsonb_array_elements(coalesce(new.state->'workers','[]'::jsonb)) where value->>'id'=t->>'workerId' and value->>'active'='true';
    if w is null or t->'workerFee' is distinct from w->'rate' or t->'worker' is distinct from w->'name' then raise exception 'INVALID_WORKER_ASSIGNMENT';end if;
   end if;
  end if;
 end loop;
 for old_ticket in select value from jsonb_array_elements(old.state->'tickets') where value->>'workerPaidAt' is not null loop
  if not exists(select 1 from jsonb_array_elements(new.state->'tickets') x where x->>'id'=old_ticket->>'id') then raise exception 'WORKER_PAYMENT_LOCKED';end if;
 end loop;
 return new;
end $$;
drop trigger if exists autowash_workers_guard on public.autowash_centres;
create trigger autowash_workers_guard before update of state on public.autowash_centres for each row execute function autowash_private.guard_workers();
revoke all on function autowash_private.guard_workers() from public;
