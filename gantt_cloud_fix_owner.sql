alter table public.charts
alter column owner_id set default auth.uid();

drop policy if exists "charts_insert_owner" on public.charts;
create policy "charts_insert_owner"
on public.charts
for insert
to authenticated
with check (owner_id = auth.uid());
