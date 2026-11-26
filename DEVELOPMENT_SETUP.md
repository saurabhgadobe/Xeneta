# Development setup

## Raw data

Create the raw schema and empty tables by running `scripts/create_raw_tables.sql`
in the DuckDB SQL editor. Then load the reference data and batch 1 from
`input_files/` with:

```sh
../.venv/bin/python scripts/load_commands.py --database dev.duckdb
```

The loader preserves the CSV columns and adds `BATCH_ID` and `SOURCE_FILE`
metadata to raw rows. `BATCH_ID` identifies a logical ingestion batch, while
`SOURCE_FILE` identifies the exact file. The manifest in `raw.load_batches`
records each file, row count, and load time. Files in a paired load share an
ID, but either file can be loaded first. The initial runner labels the first
pair `batch_1`:

Every raw source row also receives an `INGESTED_AT` timestamp when it is loaded.
Staging preserves that timestamp; daily prices expose datapoint, charge, and
effective ingestion times; aggregations expose the latest ingestion time among
the prices contributing to that lane/day row.

```sh
../.venv/bin/python scripts/load_raw.py datapoints DE_casestudy_datapoints_2.csv --batch-id batch_2
../.venv/bin/python scripts/load_raw.py charges DE_casestudy_charges_2.csv --batch-id batch_2
```

The loader does not create tables or deduplicate source rows. It refuses to
load the same table twice under one batch ID or load the same source filename
again, so run the SQL setup first and load each source file only once. If
upgrading an existing database loaded
before batch metadata was added, run:

```sh
../.venv/bin/python scripts/migrate_batch_metadata.py
```

The migration tags the already-loaded reference data and batches 1–3 using
their source CSVs. It fails if it cannot map every database row back to its
source file. Pass `--database path/to/database.duckdb` for a non-default
database. Existing rows get the corresponding manifest `LOADED_AT` as their
backfilled `INGESTED_AT`. Example row-level lineage and batch-manifest queries
are in `examples/batch_lineage_queries.sql`.

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

Raw source tests report data-quality issues as warnings. Staging models filter
invalid or ambiguous records while preserving the original raw data. This
includes invalid types and dates, duplicate keys, missing references, invalid
exchange rates, and incomplete charge-to-daily-rate coverage. Staging model
tests then verify the filtered rows.

Validate contract date order and review any out-of-window raw datapoints with:

```sh
../.venv/bin/dbt test --profiles-dir . --select path:tests/staging/dates
```

Out-of-window datapoints are warned about in raw and excluded, with their
charges, from the staging layer.

The reference staging models remain views. `stg_datapoints` is incremental and
stages each `D_ID` only once; later raw rows with an already-staged ID are not
updates. Datapoint files are expected to contain new IDs only.
`stg_charges` and `final.prices` are rebuilt from the complete raw/staged
history on each build. This lets a charge file wait in raw until its datapoint
arrives, and lets late charges recalculate existing datapoint prices. Build and
validate the initial batch and its dependencies with:

```sh
../.venv/bin/dbt build --profiles-dir . --select +aggregations
```

For each later paired batch, append the datapoints and charges files with the
same `BATCH_ID` (in either order), then run the same build command:

```sh
../.venv/bin/python scripts/load_raw.py datapoints DE_casestudy_datapoints_2.csv --batch-id batch_2_datapoints
../.venv/bin/python scripts/load_raw.py charges DE_casestudy_charges_2.csv --batch-id batch_2_charges
../.venv/bin/dbt build --profiles-dir . --select +aggregations
```

Run the build after each batch before loading a different batch ID. The loader
blocks a new ID while an earlier batch is unsnapshotted, so the recorded
before/after counts correspond to one batch update at a time.

For batch 3, use the `_3` filenames and `--batch-id batch_3`. A charge with no
datapoint yet remains in `raw.charges` and is not staged; it becomes eligible
on a later build after its datapoint is loaded, even if the datapoint has a
different batch ID. While it is pending, the raw charge-to-datapoint
relationship test reports a warning; the build continues and leaves the row in
raw. Put late charges for an already-priced datapoint in a new charge-file
batch. They are included on the next build, which recalculates prices and
aggregates from all available charges.

The full build also refreshes `final.aggregations` from all available daily
prices, so lane averages, medians, coverage counts, and `dq_ok` reflect each
new batch. Coverage thresholds are configured in `dbt_project.yml` as
`coverage_min_companies` and `coverage_min_suppliers`. Example consumer queries
are in `examples/consumer_queries.sql`.

The aggregation model's dbt pre-hook and post-hook record covered lane counts
before and after each unrecorded transaction batch in
`final.coverage_snapshots`. To reconstruct historical before/after counts for
batches 1–3, replay the CSVs in a temporary database and copy the snapshots to
the current database with:

```sh
../.venv/bin/python scripts/backfill_coverage_history.py --database dev.duckdb
```

The replay leaves the current raw, staging, price, and aggregation tables
untouched. Query snapshots with `examples/batch_lineage_queries.sql`.
