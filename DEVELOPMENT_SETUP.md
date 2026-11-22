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

Run the raw key validations with:

```sh
../.venv/bin/dbt test --profiles-dir . --select source:raw
```

Port uniqueness tests are expected to report the repeated records currently
present in the input. See `ASSUMPTIONS.md` for the uniqueness rules and the
reason charges are not given a uniqueness test.

Run type-conversion checks on the raw values with:

```sh
../.venv/bin/dbt test --profiles-dir . --select path:tests/staging/types
```

The source tests also validate that datapoint ports, port regions, and charge
datapoints exist. A custom completeness test checks that each charge currency
has an exchange rate for every day of its contract's validity period.

Validate that each contract's start date is on or before its end date and that
the sample validity dates stay within the brief's expected date window with:

```sh
../.venv/bin/dbt test --profiles-dir . --select path:tests/staging/dates
```

Build and validate the typed staging views with:

```sh
../.venv/bin/dbt run --profiles-dir . --select staging
../.venv/bin/dbt test --profiles-dir . --select staging
```
