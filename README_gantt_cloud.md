# Cloud Gantt Planner

This is the hosted/collaborative version of the planner:

- [gantt_cloud_app.html](/Users/meb22/Desktop/PhD planning/gantt_cloud_app.html)
- [gantt_cloud_schema.sql](/Users/meb22/Desktop/PhD planning/gantt_cloud_schema.sql)
- [index.html](/Users/meb22/Desktop/PhD planning/index.html)

## What it adds

- email + password login
- multiple charts per person
- per-chart sharing by collaborator email
- owner / editor / viewer access model
- cloud storage for tasks, descriptions, outputs, done-state, and projects

## Setup

1. Create a Supabase project.
2. Run the SQL in [gantt_cloud_schema.sql](/Users/meb22/Desktop/PhD planning/gantt_cloud_schema.sql) in the Supabase SQL editor.
   - If chart creation gives an RLS error, also run [gantt_cloud_fix_owner.sql](/Users/meb22/Desktop/PhD planning/gantt_cloud_fix_owner.sql).
   - If it still complains on chart creation, run [gantt_cloud_fix_chart_rpc.sql](/Users/meb22/Desktop/PhD planning/gantt_cloud_fix_chart_rpc.sql) and refresh the app.
3. In Supabase Auth:
   - keep Email auth enabled
   - set your Site URL / Redirect URL to the public app URL you will host
4. Host this folder on Railway static hosting.
   - `index.html` redirects to the cloud app automatically.
5. Open the hosted app and paste:
   - Supabase project URL
   - Supabase publishable / anon key

## Sharing behavior

- Sharing is email-based.
- The owner enters a collaborator's email and gives `viewer` or `editor` access.
- The collaborator signs in with that same email address to see the chart.
- This version stores the access rule, but it does **not** send invitation emails automatically yet.

## Notes

- Keep local file paths in `Outputs / paths` only as notes.
- If you want actual downloadable figures or PowerPoints, the next step is adding private cloud file uploads.
- The original local planners are still untouched:
  - [phd_gantt.html](/Users/meb22/Desktop/PhD planning/phd_gantt.html)
  - [gantt_template.html](/Users/meb22/Desktop/PhD planning/gantt_template.html)
