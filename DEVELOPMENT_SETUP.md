# Development setup

## Raw data

Create the raw schema and empty tables by running `scripts/create_raw_tables.sql`
in the DuckDB SQL editor. Then load the reference data and batch 1 from
`input_files/` with:

```sh
python scripts/load_commands.py
```

The runner calls `scripts/load_raw.py` once for each initial file. Later
datapoint and charge batches append to the same tables by specifying the table
and filename directly. For example:

```sh
python scripts/load_raw.py datapoints DE_casestudy_datapoints_2.csv
python scripts/load_raw.py charges DE_casestudy_charges_2.csv
```

The loader does not create tables or deduplicate rows, so run the SQL setup
first and load each source file only once.

## dbt

The dbt project is configured in `dbt_project.yml` and uses the DuckDB profile
in `profiles.yml`. From the project folder, validate the project configuration
with:

```sh
../.venv/bin/dbt parse --profiles-dir .
```
