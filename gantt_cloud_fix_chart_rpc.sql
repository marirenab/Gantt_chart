create or replace function public.create_chart_with_defaults(
  chart_title text,
  chart_description text default ''
)
returns public.charts
language plpgsql
security definer
set search_path = public
as $$
declare
  new_chart public.charts;
begin
  if auth.uid() is null then
    raise exception 'You must be signed in to create a chart.';
  end if;

  insert into public.charts (owner_id, title, description)
  values (auth.uid(), chart_title, coalesce(chart_description, ''))
  returning * into new_chart;

  insert into public.projects (chart_id, name, color, bg, position)
  values
    (new_chart.id, 'Project 1', '#3b82f6', '#1d4ed8', 0),
    (new_chart.id, 'Project 2', '#10b981', '#047857', 1),
    (new_chart.id, 'Project 3', '#f59e0b', '#d97706', 2),
    (new_chart.id, 'Admin', '#94a3b8', '#64748b', 3),
    (new_chart.id, 'Personal', '#8b5cf6', '#7c3aed', 4),
    (new_chart.id, 'Milestones', '#ef4444', '#dc2626', 5);

  return new_chart;
end;
$$;

revoke all on function public.create_chart_with_defaults(text, text) from public;
grant execute on function public.create_chart_with_defaults(text, text) to authenticated;
