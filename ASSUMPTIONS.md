# Assumptions

## Source data

- Ports, regions, and exchange rates come from one authoritative, static
  reference load.
- Port `PID`/`CODE`, region `SLUG`, exchange-rate `(DAY, CURRENCY)`, and
  datapoint `D_ID` are expected to identify unique records. Ambiguous records
  are excluded from staging; exact repeated port rows are collapsed.
- Charges have no unique row identifier. Multiple rows per `D_ID` are valid;
  charge rows are not deduplicated. A stable source charge ID is needed to
  identify individual corrections safely.
- Raw CSV values are stored as text and converted in staging. Rates must be
  positive because USD prices are calculated as `CHARGE_VALUE / RATE`.

## Validation and pricing

- Datapoint origin/destination ports and port-region references must exist.
  Charge `D_ID`s must match staged datapoints.
- Datapoint validity dates are inclusive and must fall within
  `2021-01-01`–`2022-06-01`. Equipment IDs must be 1–6. Required IDs, dates,
  company, and supplier values must be valid.
- Every charge needs a matching exchange rate for every day in its datapoint's
  validity period. If a charge is invalid or any required rate is missing, all
  charges for that datapoint are excluded from pricing; raw rows remain intact.
- Invalid regions, ambiguous region slugs, missing region parents, and ports
  without a valid region are excluded from staging.

## Loads and refreshes

- Raw datapoint and charge loads are append-only and tracked by batch ID,
  source file, and ingestion timestamp. Datapoint IDs are expected once across
  loads; staging adds new IDs and does not update an already-staged ID.
- Charges may arrive before or after their datapoints. Unmatched charges remain
  in raw; later builds stage them when the datapoint becomes available. Late
  charges are included in recalculated prices.
- `stg_charges`, `final.prices`, and `final.aggregations` rebuild from available
  history on each dbt build. This favors correctness at the assignment's
  current scale. Production incremental processing should target affected
  records and be validated against full rebuilds; safe charge-level updates
  require a stable charge-row identity.
- The loader prevents reloading the same source file. Since charges have no
  unique row ID, a correction file adds charge rows; it cannot safely replace
  individual prior rows.
- Reference data and exchange rates are assumed static. Changes to them or to
  staging logic require a full refresh to recalculate historical outputs.
- `INGESTED_AT` records source-row load time and is propagated through the
  models. Existing rows were backfilled from the batch manifest's `LOADED_AT`.

## Lane aggregates

- Ports roll up to themselves and all ancestor regions. Origin and destination
  are independent and directional; A→B and B→A are separate lanes.
- `final.aggregations` stores each lane/day/equipment row, including rows that
  do not meet coverage thresholds. `dq_ok` is true when distinct company and
  supplier counts meet the configurable minimums.
- Coverage snapshots record covered lane/day/equipment row counts before and
  after each batch build.
