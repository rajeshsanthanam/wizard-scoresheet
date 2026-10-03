-- Run once in Supabase: SQL Editor -> New query -> paste -> Run.
-- The table is locked down (RLS on, no policies). The app can only reach it
-- through the two functions below, and both require the sync code.

create table if not exists sheets (
  code text not null,
  id text not null,
  data jsonb not null,
  updated_at bigint not null,
  deleted boolean not null default false,
  primary key (code, id)
);
alter table sheets enable row level security;

create or replace function get_sheets(p_code text)
returns table (id text, data jsonb, updated_at bigint, deleted boolean)
language sql security definer set search_path = public as $$
  select s.id, s.data, s.updated_at, s.deleted from sheets s
  where s.code = p_code and length(p_code) >= 8;
$$;

create or replace function put_sheet(p_code text, p_id text, p_data jsonb, p_updated bigint, p_deleted boolean)
returns void
language plpgsql security definer set search_path = public as $$
begin
  if length(p_code) < 8 then raise exception 'sync code too short'; end if;
  insert into sheets (code, id, data, updated_at, deleted)
  values (p_code, p_id, p_data, p_updated, p_deleted)
  on conflict (code, id) do update
    set data = excluded.data, updated_at = excluded.updated_at, deleted = excluded.deleted
    where sheets.updated_at <= excluded.updated_at;
end;
$$;

grant execute on function get_sheets(text) to anon;
grant execute on function put_sheet(text, text, jsonb, bigint, boolean) to anon;
