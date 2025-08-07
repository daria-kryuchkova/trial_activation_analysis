--- saving raw data file ---

CREATE TABLE IF NOT EXISTS raw_data (
  organization_id TEXT,
  activity_name TEXT,
  timestamp DATETIME,
  converted INT,
  converted_at DATETIME,
  trial_start DATETIME,
  trial_end DATETIME
);

INSERT OR REPLACE INTO raw_data (organization_id, activity_name, timestamp, converted, converted_at, trial_start, trial_end)
SELECT
  TRIM(organization_id) as organization_id,
  TRIM(activity_name) as activity_name,
  DATETIME(timestamp) as timestamp,
  CAST(converted AS INTEGER) AS converted,
  DATETIME(converted_at) as converted_at,
  DATETIME(trial_start) as trial_start,
  DATETIME(trial_end) as trial_end
FROM raw;

---=== Creating dimension tables ===---

--- Funnel steps ---

CREATE TABLE IF NOT EXISTS funnel_steps (
  activity_name TEXT PRIMARY KEY,
  funnel_step INT
);

INSERT OR REPLACE INTO funnel_steps (activity_name, funnel_step)
VALUES
    ('First.Action', 0),
    ('Scheduling.Shift.Created', 1),
    ('Mobile.Schedule.Loaded', 2),
    ('Scheduling.Shift.Approved', 3),
    ('Scheduling.Shift.AssignmentChanged', 4),
    ('Scheduling.Template.ApplyModal.Applied', 5),
    ('Converted', 6);
	
--- Organizations ---

CREATE TABLE IF NOT EXISTS organizations (
  organization_id TEXT PRIMARY KEY,
  trial_start DATETIME,
  trial_start_week DATE,
  trial_end DATETIME
);

INSERT OR REPLACE INTO organizations (organization_id, trial_start, trial_start_week, trial_end)
  SELECT
    organization_id,
    DATETIME(MIN(trial_start)) AS trial_start,
    DATE(MIN(trial_start), '-' || strftime('%w', MIN(trial_start)) || ' days') AS trial_start_week,
	---DATE_SUB(MIN(trial_start), INTERVAL (DAYOFWEEK(MIN(trial_start)) - 1) DAY) AS trial_start_week,
    DATETIME(MAX(trial_end)) AS trial_end
  FROM raw_data
  GROUP BY organization_id;
  
---=== Trial goals fact table===---

CREATE TABLE IF NOT EXISTS trial_goals_fct (
  timestamp DATETIME,
  organization_id TEXT,
  funnel_step INT,
  activity_name TEXT
);


WITH trial_goals AS (
  SELECT
    MIN(r.timestamp) AS timestamp,
    r.organization_id,
    fs.funnel_step,
    r.activity_name
  FROM raw_data r
  INNER JOIN funnel_steps fs ON r.activity_name = fs.activity_name
  GROUP BY r.organization_id, r.activity_name
),

trial_start_act AS (
  SELECT
    MIN(timestamp) AS timestamp,
    organization_id,
    0 AS funnel_step,
    'First.Action' AS activity_name
  FROM raw_data
  GROUP BY organization_id
),

converted_act AS (
  SELECT
    MIN(trial_start) AS timestamp,
    organization_id,
    6 AS funnel_step,
    'Converted' AS activity_name
  FROM organizations
  WHERE converted = 1
  GROUP BY organization_id
),

tg_all_actions AS (
  SELECT
    timestamp,
    organization_id,
    funnel_step,
    activity_name
  FROM trial_goals

  UNION ALL

  SELECT
    timestamp,
    organization_id,
    funnel_step,
    activity_name
  FROM trial_start_act

  UNION ALL

  SELECT
    timestamp,
    organization_id,
    funnel_step,
    activity_name
  FROM converted_act
)

INSERT OR REPLACE INTO trial_goals_fct (timestamp, organization_id, funnel_step, activity_name)
SELECT * from tg_all_actions
ORDER BY timestamp;

---=== Trial goals mart table ===---

CREATE TABLE IF NOT EXISTS trial_goals_mart (
  timestamp DATETIME,
  organization_id TEXT,
  converted INT,
  funnel_step INT,
  activity_name TEXT,
  trial_start DATETIME,
  trial_start_week DATE
);

INSERT OR REPLACE INTO trial_goals_mart (timestamp, organization_id, converted, funnel_step, activity_name, trial_start, trial_start_week)
SELECT
    tg.timestamp,
    tg.organization_id,
    o.converted,
    tg.funnel_step,
    tg.activity_name,
    o.trial_start,
    o.trial_start_week
  FROM trial_goals_fct tg
  INNER JOIN organizations o ON tg.organization_id = o.organization_id
ORDER BY timestamp;

---=== Trial activation fact table ===---

CREATE TABLE IF NOT EXISTS trial_activation_fct (
  organization_id TEXT PRIMARY KEY,
  max_step_ts TIMESTAMP,
  last_funnel_step INT,
  total_steps INT,
  trial_status TEXT
);

WITH ranked_steps AS (
  SELECT
    organization_id,
    timestamp,
    funnel_step,
    activity_name,
    ROW_NUMBER() OVER (PARTITION BY organization_id ORDER BY timestamp DESC) AS rn
  FROM trial_goals_fct
),

distinct_steps AS (
  SELECT
    organization_id,
    COUNT(DISTINCT activity_name) AS total_steps
  FROM trial_goals_fct
  GROUP BY organization_id
),

trial_activation_summary AS (
  SELECT
    r.organization_id,
    r.timestamp AS max_step_ts,
    r.funnel_step AS last_funnel_step,
    d.total_steps,
    CASE 
      WHEN r.funnel_step > 4 THEN 'Completed'
      ELSE 'Not Completed'
    END AS trial_status
  FROM ranked_steps r
  JOIN distinct_steps d ON r.organization_id = d.organization_id
  WHERE r.rn = 1
)

INSERT INTO trial_activation_fct (organization_id, max_step_ts, last_funnel_step, total_steps, trial_status)
SELECT * FROM trial_activation_summary
ON CONFLICT (organization_id) DO UPDATE
SET 
  max_step_ts = EXCLUDED.max_step_ts,
  last_funnel_step = EXCLUDED.last_funnel_step,
  total_steps = EXCLUDED.total_steps,
  trial_status = EXCLUDED.trial_status;
  
---=== Trial activation mart table ===---

CREATE TABLE trial_activation_mart (
  organization_id TEXT PRIMARY KEY,
  updated_at TIMESTAMP,
  last_trial_step INT,
  last_trial_activity TEXT,
  trial_status TEXT,
  total_steps INT,
  trial_start TIMESTAMP,
  trial_start_week DATE,
  trial_end TIMESTAMP
);

WITH data_to_insert AS (
  SELECT
    ta.organization_id,
    ta.max_step_ts AS updated_at,
    ta.last_funnel_step AS last_trial_step,
    fs.activity_name AS last_trial_activity,
    ta.trial_status,
    ta.total_steps,
    o.trial_start,
    o.trial_start_week,
    o.trial_end
  FROM trial_activation_fct ta
  INNER JOIN organizations o ON ta.organization_id = o.organization_id
  INNER JOIN funnel_steps fs ON ta.last_funnel_step = fs.funnel_step
)

INSERT INTO trial_activation_mart (
  organization_id, updated_at, last_trial_step, last_trial_activity, trial_status, total_steps, trial_start, trial_start_week, trial_end
)
SELECT * FROM data_to_insert
ON CONFLICT (organization_id) DO UPDATE
SET
  updated_at = EXCLUDED.updated_at,
  last_trial_step = EXCLUDED.last_trial_step,
  last_trial_activity = EXCLUDED.last_trial_activity,
  trial_status = EXCLUDED.trial_status,
  total_steps = EXCLUDED.total_steps,
  trial_start = EXCLUDED.trial_start,
  trial_start_week = EXCLUDED.trial_start_week,
  trial_end = EXCLUDED.trial_end;




