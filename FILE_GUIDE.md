# 📋 Walmart dbt Project - File Reference Guide

## 🎯 Where to Start?

```
START HERE → SETUP_SUMMARY.md
              ↓
         QUICKSTART.md (5-min setup)
              ↓
         Configure profiles.yml
              ↓
         Run: dbt run --full-refresh
              ↓
         SUCCESS! ✅
```

## 📚 Documentation Files

| File | Purpose | When to Read |
|------|---------|--------------|
| `SETUP_SUMMARY.md` | **START HERE** - Project overview | First time |
| `QUICKSTART.md` | 5-minute setup guide | When setting up |
| `README.md` | Complete documentation | Reference |
| `COMPARISON.md` | SQL vs dbt analysis | When deciding approach |

## ⚙️ Configuration Files

| File | Purpose | Action Required |
|------|---------|-----------------|
| `dbt_project.yml` | Project config | ✅ Ready to use |
| `profiles.yml` | Connection settings | ⚠️ Copy to ~/.dbt/ and edit |
| `packages.yml` | Dependencies | ✅ Run `dbt deps` |
| `.gitignore` | Git exclusions | ✅ Ready to use |

## 🗂️ Model Files (The Core Logic)

### Staging Models (`models/staging/`)
Transform raw data into clean, standardized format.

| File | Source | Purpose |
|------|--------|---------|
| `stg_department.sql` | `RAW.DEPARTMENT` | Clean sales data |
| `stg_fact.sql` | `RAW.FACT` | Clean metrics data |
| `stg_stores.sql` | `RAW.STORES` | Clean store master |

### Dimension Models (`models/mart/dimensions/`)
SCD Type 1 - Updates overwrite existing records.

| File | Type | Keys | Update Logic |
|------|------|------|--------------|
| `walmart_date_dim.sql` | SCD1 | `store_date` | Upsert dates |
| `walmart_store_dim.sql` | SCD1 | `store_id, dept_id` | Upsert combos |

### Fact Models (`models/mart/facts/`)
SCD Type 2 - Maintains full history with versioning.

| File | Type | Keys | Versioning |
|------|------|------|------------|
| `walmart_fact_table.sql` | SCD2 | `store_id, dept_id, vrsn_start_date` | Custom logic |

### Snapshots (`snapshots/`)
Alternative SCD Type 2 using dbt built-in functionality.

| File | Strategy | Purpose |
|------|----------|---------|
| `walmart_fact_snapshot.sql` | Check all columns | Auto-versioning |

## 📋 Schema Files

| File | Purpose | Contains |
|------|---------|----------|
| `models/sources.yml` | Define RAW sources | Source tables from RAW schema |
| `models/schema.yml` | Tests & docs | Data quality tests, descriptions |

## 🔧 Macros (`macros/`)

| File | Purpose |
|------|---------|
| `generate_schema_name.sql` | Custom schema naming logic |

## 🎯 Which Files to Edit?

### ✏️ Must Edit Before Running

1. **`profiles.yml`** (copy to `~/.dbt/` first)
   ```yaml
   Line 7: account: <your_account>
   Line 10: user: <your_username>
   Line 11: password: <your_password>
   Line 15: role: <your_role>
   Line 17: warehouse: <your_warehouse>
   ```

### ✏️ Might Edit Later

2. **`dbt_project.yml`** - If changing:
   - Model materialization strategies
   - Schema names
   - Project variables

3. **Model SQL files** - If adding:
   - Custom business logic
   - New calculated fields
   - Additional filters

### ✅ Don't Need to Edit

- `packages.yml` - Standard dbt_utils package
- `.gitignore` - Standard dbt gitignore
- `macros/generate_schema_name.sql` - Standard macro
- `models/sources.yml` - Unless RAW schema changes
- `models/schema.yml` - Unless adding/changing tests

## 🎬 Execution Flow

### First Time Setup
```bash
1. Read QUICKSTART.md
2. Edit ~/.dbt/profiles.yml
3. Run: dbt deps
4. Run: dbt debug
5. Run: dbt run --full-refresh
6. Run: dbt test
7. Run: dbt docs generate
```

### Daily Operations
```bash
1. Run: dbt run          # Incremental load
2. Run: dbt test         # Validate data
3. View: dbt docs serve  # Check docs
```

## 📊 Model Dependencies (Lineage)

```
Sources (RAW)
    ↓
stg_department ──────┐
stg_fact ────────────┼──→ walmart_date_dim
stg_stores ──────────┤
    │                │
    │                └──→ walmart_store_dim
    │                         ↓
    └────────────────────→ walmart_fact_table
```

Run in order:
1. Staging models (parallel)
2. Dimension models (parallel)
3. Fact model (depends on dimensions)

dbt handles this automatically with `dbt run`!

## 🔍 How to Find What You Need

### "I want to understand the project"
→ Read `SETUP_SUMMARY.md`

### "I want to set it up quickly"
→ Follow `QUICKSTART.md`

### "I want complete details"
→ Read `README.md`

### "I want to compare with SQL"
→ Read `COMPARISON.md`

### "I want to modify the date dimension"
→ Edit `models/mart/dimensions/walmart_date_dim.sql`

### "I want to change SCD2 logic"
→ Edit `models/mart/facts/walmart_fact_table.sql`

### "I want to add tests"
→ Edit `models/schema.yml`

### "I want to add a new source"
→ Edit `models/sources.yml`

### "I want to configure Snowflake connection"
→ Edit `~/.dbt/profiles.yml` (copy from `profiles.yml`)

## 🎯 Success Checklist

- [ ] Read `SETUP_SUMMARY.md`
- [ ] Follow `QUICKSTART.md`
- [ ] Configure `profiles.yml` and copy to `~/.dbt/`
- [ ] Run `dbt deps`
- [ ] Run `dbt debug` (should pass)
- [ ] Run `dbt run --full-refresh`
- [ ] Run `dbt test`
- [ ] Run `dbt docs generate`
- [ ] View docs with `dbt docs serve`
- [ ] Check data in Snowflake
- [ ] Celebrate! 🎉

## 📞 Need Help?

1. **Connection issues** → Check `profiles.yml` settings
2. **Model errors** → Run `dbt compile` to see generated SQL
3. **Test failures** → Run `dbt test --select <model>` for specific model
4. **Understanding dbt** → Visit https://docs.getdbt.com/

---

**Happy Transforming!** 🚀
