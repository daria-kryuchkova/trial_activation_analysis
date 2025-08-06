# Trial Conversion & Activation Analysis

This project is a case study in analyzing trial user behavior within a SaaS product to define actionable trial goals and understand what drives conversions. 
The project contains raw.csv - the original source file, Jupyter notebook where the analysis was made and an sql file with model definition for trial goals and trial activation mart tables.

---

## 📌 Task Summary

**Objective:**  
Analyze user behavior during free trials to identify activities that drive conversion, define trial goals, and provide analytical models for product and data teams.

---

## 📝 Notebook Overview


### 1. 🧹 Data Cleaning
- Checked and converted data types: 'converted' from bool to int, all dates to datetime.
- Filled null dates in 'converted_at' for non-converters with 'trial_end' dates.
- Ensured data consistency (e.g., activity dates within trial periods, unique conversion status per organization).

### 2. 🔍 Inconsistencies & Duplicates
- Analyzed duplicates:
  - Found they could be valid (e.g., duplicate shifts created and assignmenet changed often happen after using templates).
  - Retained after confirming they carry meaningful signal.

### 3. 📊 Exploratory Data Analysis (EDA)
- Labeled conversion status:
  - `0` – Not converted  
  - `1` – Converted during trial
  - `2` – Converted after trial
- Key insights:
  - All conversions occur **after day 14** since first action, 50% happen **post-trial**.
  - Most organizations, including converters conly engaged for 1 day.
  - **Weekly retention** is a better metric than daily retention.
  - ~10% of users **never engaged** with the core feature (shift scheduling).
- Analyzed engagement per conversion status and sequence analysis.
- Identified key last activities differentiating converters from non-converters:
  - `Scheduling.Shift.Approved`
  - `Scheduling.Shift.AssignmentChanged`
  - `Absence.Request.Approved`
  - `Timesheets.BulkApprove.Confirmed`

### 4. 🧬 Feature Engineering & Modeling
- Engineered features:
  - Activity span, days active, time to first action, etc.
  - Engagement ratios and average daily records per activity_name.
- Ran 4 models:
  - `Random Forest`, `XGBoost`, `KNN`, `Logistic Regression`
- **Best model: XGBoost**
  - Accuracy: `0.7371`
  - SHAP values used for feature importance interpretation

### 5. 🛠️ Trial Goals & SQL Model Design
- Selected key activities from EDA and modeling as **trial goals**:
  - `Scheduling.Shift.Created'`
  - `Mobile.Schedule.Loaded`
  - `Scheduling.Shift.Approved`
  - `Scheduling.Shift.AssignmentChanged`
  - `Scheduling.Template.ApplyModal.Applied`
- Designed logic for:
  - `trial_goals` mart: tracks goal completion per organization
  - `trial_activation` mart: contains information on the latest trial goal status per organization with total trial_goals completed and trial completion status. 
- SQL logic provided in notebook for both marts

---

## 📈 Key Results

| Metric | Value |
|--------|-------|
| Model Accuracy | **73.7%** |
| Top Features | Activity span, days active, key engagement actions |
| Conversion Timing | Majority convert **after** trial ends |
| Retention | Daily ~15%, Weekly ~20% (weeks 1–4) |

---

## 🧰 Tools & Stack

- **Language**: Python  
- **Notebook**: Jupyter (`.ipynb`)  
- **Libraries**: `pandas`, `matplotlib`, `seaborn`, `sklearn`, `xgboost`, `SHAP`  
- **Output**: SQL logic for data warehouse integration

