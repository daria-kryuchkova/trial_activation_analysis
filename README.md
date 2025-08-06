# 🧪 Trial Conversion & Activation Analysis

This project is a case study in analyzing trial user behavior within a SaaS product to define actionable trial goals and understand what drives conversions. The entire workflow—from data cleaning to SQL model design and predictive modeling—is contained in **one Jupyter Notebook**.

---

## 📌 Task Summary

**Objective:**  
Analyze user behavior during free trials to identify activities that drive conversion, define trial goals, and provide analytical models for product and data teams.

---

## 📂 Notebook Overview

The notebook follows this structured approach:

### 1. 🧹 Data Cleaning
- Checked and converted data types (especially datetime fields).
- Handled null values appropriately.
- Ensured data consistency (e.g., activity dates within trial periods).

### 2. 🔍 Inconsistencies & Duplicates
- Verified temporal logic (e.g., no activity before trial start).
- Analyzed duplicates:
  - Found they could be valid (e.g., linked activity types).
  - Retained after confirming they carry meaningful signal.

### 3. 📊 Exploratory Data Analysis (EDA)
- Labeled conversion status:
  - `0` – Not converted  
  - `1` – Converted during trial  
  - `2` – Converted after trial
- Key insights:
  - Most conversions occur **after day 14**, often **post-trial**.
  - **Weekly retention** is a better metric than daily retention.
  - ~10% of users **never engaged** with the core feature (shift scheduling).
- Identified key conversion-driving activities:
  - `Scheduling.Shift.Approved`
  - `Scheduling.Shift.AssignmentChanged`
  - `Absence.Request.Approved`
  - `Timesheets.BulkApprove.Confirmed`

### 4. 🧠 Feature Engineering & Modeling
- Engineered features:
  - Activity span, days active, time to first action, etc.
  - Engagement ratios and transition chains
- Ran 4 models:
  - `Random Forest`, `XGBoost`, `KNN`, `Logistic Regression`
- **Best model: XGBoost**
  - Accuracy: `0.7371`
  - SHAP values used for feature importance interpretation

### 5. 🛠️ Trial Goals & SQL Model Design
- Selected key activities from EDA and modeling as **trial goals**
- Designed logic for:
  - `trial_goals` mart: tracks goal completion per organization
  - `trial_activation` mart: flags orgs that completed all goals
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

