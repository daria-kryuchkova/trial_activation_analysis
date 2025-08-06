---Trial goals---

WITH funnel_steps(activity_name, funnel_step) AS (
  VALUES
    ('Scheduling.Shift.Created', 1),
    ('Mobile.Schedule.Loaded', 2),
    ('Scheduling.Shift.Approved', 3),
    ('Scheduling.Shift.AssignmentChanged', 4),
    ('Scheduling.Template.ApplyModal.Applied', 5)
),

organizations AS (
  SELECT
    organization_id,
    MIN(trial_start) AS trial_start,
	DATEADD(dd, -(DATEPART(dw, WeddingDate)-1), MIN(trial_start)) AS trial_start_week,
	MAX(trial_end) AS trial_end,
  FROM raw_data r
  GROUP BY organization_id
),

---Trial goals: event table with multiple rows per org---

trial_goals AS (
  SELECT
    t.timestamp,
    t.organization_id,
    fs.funnel_step,
    t.activity_name
  FROM raw_data r
  INNER JOIN funnel_steps fs ON r.activity_name = fs.activity_name
),

trial_goals_mart AS (
  SELECT
    t.timestamp,
    t.organization_id,
    fs.funnel_step,
    t.activity_name,
	o.trial_start,
	o.trial_start_week
  FROM trial_goals tg
  INNER JOIN organizations o ON tg.organizations = o.organizations
),

---Trial activation: status table with one rows per org---

trial_activation AS (
  SELECT
	organization_id,
	MAX(timestamp) AS max_step_ts,						
	MAX(funnel_step) AS max_funnel_step,				-- if the steps are linear
	COUNT(DISTINCT tg.activity_name) AS total_stepts, 	-- if not
	CASE 
		WHEN MAX(tg.funnel_step) > 5 THEN 'Completed'
		ELSE 'Not Completed'
	AS trial_status,
  FROM trial_goals tg
  GROUP BY tg.organization_id
),

trial_activation_mart AS (
  SELECT
    ta.organization_id
	ta.max_step_ts AS updated_at,
	DATEDIFF(day, o.trial_start_real, ta.max_step_ts) AS days_since_trial_start_real,
	DATEDIFF(day, o.trial_start, ta.max_step_ts) AS days_since_trial_start
	ta.max_funnel_step AS last_trial_step,
	fs.activity_name AS last_trial_activity,
	ta.trial_status,
	o.trial_start,
	o.trial_start_real,
	o.trial_end,
	o.trial_start_week
  FROM trial_activation ta
  INNER JOIN organizations o ON tg.organizations = o.organizations
  INNER JOIN funnel_steps fs ON ta.funnel_step = fs.funnel_step
),

