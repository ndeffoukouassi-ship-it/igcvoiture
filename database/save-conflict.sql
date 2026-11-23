-- Optimistic revision conflicts are business conflicts, never serialization retries.
CREATE OR REPLACE FUNCTION public.autowash_save(expected_revision bigint, next_state jsonb)
 RETURNS bigint
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$;
declare new_revision bigint;
begin
 if auth.uid() is null then raise exception 'AUTH_REQUIRED' using errcode='42501'; end if;
 update public.autowash_centres set state=next_state, revision=revision+1, updated_at=now()
 where owner_id=auth.uid() and revision=expected_revision returning revision into new_revision;
 if new_revision is null then raise exception 'CONCURRENT_EDIT' using errcode='PT409'; end if;
 return new_revision;
end $function$;

CREATE OR REPLACE FUNCTION autowash_private.save_workspace(centre_id uuid, expected_revision bigint, next_state jsonb)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$;
declare actor uuid:=auth.uid(); previous jsonb; revision_now bigint; result bigint; payload jsonb;
begin
 if actor is null or not autowash_private.has_centre_access(centre_id::text) then raise exception 'ACCESS_REVOKED' using errcode='42501';end if;
 select state,revision into previous,revision_now from public.autowash_centres where owner_id=centre_id for update;
 if revision_now<>expected_revision then raise exception 'CONCURRENT_EDIT' using errcode='PT409';end if;
 payload:=next_state;
 if actor<>centre_id then
 if next_state->'center' is distinct from previous->'center' or next_state->'services' is distinct from previous->'services' or next_state->'loyaltyEnabled' is distinct from previous->'loyaltyEnabled' then raise exception 'OWNER_SETTINGS_ONLY' using errcode='42501';end if;
 payload:=previous||jsonb_build_object('tickets',next_state->'tickets','expenses',next_state->'expenses','loyaltyLinks',coalesce(next_state->'loyaltyLinks','{}'));
 end if;
 update public.autowash_centres set state=payload,revision=revision+1,updated_at=now() where owner_id=centre_id returning revision into result;
 return result;
end $function$;

