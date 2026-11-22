# Assumptions

## Raw data uniqueness checks

- Port `PID` and `CODE` values are expected to be unique, as specified in the
  case-study brief.
- Region `SLUG` values are expected to be unique.
- Exchange-rate rows are expected to be unique by the combination of `DAY` and
  `CURRENCY`.
- Datapoint `D_ID` values are expected to be unique.
- No unique key is specified for charges. A datapoint can have multiple charge
  rows, and identical charge values do not prove that the rows are duplicates.
  I do not run a uniqueness test on charges or remove any charge rows. I
  recommend adding a stable unique charge identifier (a surrogate key) to the
  source data so individual charges can be identified and validated.

The current ports input contains exact repeated records for PIDs `736` and
`764`. Raw uniqueness tests warn about them. The staging ports view uses
`SELECT DISTINCT` to remove only exact duplicate rows; raw data remains
unchanged. Staging port key tests verify the resulting IDs and codes are
unique.

## Raw data types

- Raw CSV columns are stored as text. Staging data tests check whether the
  non-null values can be converted to the expected types before models use them.
- Port IDs and contract IDs are integers; datapoint validity dates and exchange
  rate days are dates; datapoint creation timestamps are timestamps with a time
  zone; exchange rates and charge values are numeric.
- The initial input files were checked against these types and had no non-null
  values that failed conversion. Null checks are handled separately where a
  field is required.

## Reference-data completeness

- Both origin and destination port IDs in each datapoint must exist in the ports
  reference data.
- Every port region slug must exist in the regions reference data.
- Every charge must reference an existing datapoint.
- Each charge currency must have an exchange rate for every day in its
  datapoint's inclusive validity period. A missing daily rate means the
  contract's USD price cannot be calculated for that day.
- Datapoint validity ranges are inclusive, and the sample's expected date
  window is `2021-01-01` through `2022-06-01`, as stated in the brief.
