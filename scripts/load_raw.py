import argparse
from pathlib import Path

import duckdb


PROJECT_ROOT = Path(__file__).resolve().parents[1]
DATABASE_PATH = PROJECT_ROOT / "dev.duckdb"
INPUT_DIRECTORY = PROJECT_ROOT / "input_files"
RAW_COLUMNS = {
    "ports": ("PID", "CODE", "SLUG", "NAME", "COUNTRY", "COUNTRY_CODE"),
    "regions": ("SLUG", "NAME", "PARENT"),
    "exchange_rates": ("DAY", "CURRENCY", "RATE"),
    "datapoints": (
        "D_ID",
        "CREATED",
        "ORIGIN_PID",
        "DESTINATION_PID",
        "VALID_FROM",
        "VALID_TO",
        "COMPANY_ID",
        "SUPPLIER_ID",
        "EQUIPMENT_ID",
    ),
    "charges": ("D_ID", "CURRENCY", "CHARGE_VALUE"),
}


def load_csv(
    table_name: str,
    filename: str,
    database_path: Path = DATABASE_PATH,
    batch_id: str | None = None,
) -> int:
    if table_name not in RAW_COLUMNS:
        valid_tables = ", ".join(sorted(RAW_COLUMNS))
        raise ValueError(f"Unknown raw table {table_name!r}. Choose from: {valid_tables}")

    csv_path = Path(filename)
    if csv_path.name != filename:
        raise ValueError("Pass only the CSV filename; files are read from input_files/.")
    csv_path = INPUT_DIRECTORY / csv_path
    if not csv_path.is_file():
        raise FileNotFoundError(f"CSV file not found: {csv_path}")
    if table_name in {"datapoints", "charges"} and not batch_id:
        raise ValueError("Transaction files require --batch-id to identify their load.")
    batch_id = batch_id or "reference"

    columns = RAW_COLUMNS[table_name]
    column_list = ", ".join(columns)
    connection = duckdb.connect(str(database_path))
    try:
        connection.begin()
        table_exists = connection.execute(
            """
            SELECT COUNT(*)
            FROM information_schema.tables
            WHERE table_schema = 'raw' AND table_name = ?
            """,
            [table_name],
        ).fetchone()[0]
        if not table_exists:
            raise RuntimeError(
                f"raw.{table_name} does not exist. "
                "Run scripts/create_raw_tables.sql first."
            )

        metadata_columns = connection.execute(
            """
            SELECT column_name
            FROM information_schema.columns
            WHERE table_schema = 'raw'
              AND table_name = ?
              AND column_name IN ('BATCH_ID', 'SOURCE_FILE', 'INGESTED_AT')
            """,
            [table_name],
        ).fetchall()
        if len(metadata_columns) != 3:
            raise RuntimeError(
                f"raw.{table_name} does not have batch and ingestion metadata columns. "
                "Run scripts/migrate_batch_metadata.py first."
            )

        existing_load = connection.execute(
            """
            SELECT SOURCE_FILE
            FROM raw.load_batches
            WHERE TABLE_NAME = ?
              AND (BATCH_ID = ? OR SOURCE_FILE = ?)
            """,
            [table_name, batch_id, filename],
        ).fetchone()
        if existing_load:
            raise RuntimeError(
                f"Batch {batch_id!r} or source file {filename!r} already loaded "
                f"{table_name} from {existing_load[0]!r}; refusing to append it again."
            )

        if table_name in {"datapoints", "charges"}:
            snapshot_table_exists = connection.execute(
                """
                SELECT COUNT(*)
                FROM information_schema.tables
                WHERE table_schema = 'final'
                  AND table_name = 'coverage_snapshots'
                """
            ).fetchone()[0]
            if snapshot_table_exists:
                current_batch_snapshotted = connection.execute(
                    """
                    SELECT COUNT(*)
                    FROM final.coverage_snapshots
                    WHERE BATCH_ID = ?
                    """,
                    [batch_id],
                ).fetchone()[0]
                if current_batch_snapshotted:
                    raise RuntimeError(
                        f"Batch {batch_id!r} already has a coverage snapshot. "
                        "Use a new batch ID for files arriving after its build."
                    )

                pending_batch = connection.execute(
                    """
                    SELECT batches.BATCH_ID
                    FROM raw.load_batches AS batches
                    LEFT JOIN final.coverage_snapshots AS snapshots
                        ON batches.BATCH_ID = snapshots.BATCH_ID
                    WHERE batches.TABLE_NAME IN ('datapoints', 'charges')
                      AND batches.BATCH_ID <> ?
                      AND (
                          snapshots.BATCH_ID IS NULL
                          OR snapshots.AFTER_COVERED_LANES IS NULL
                      )
                    LIMIT 1
                    """,
                    [batch_id],
                ).fetchone()
            else:
                pending_batch = connection.execute(
                    """
                    SELECT BATCH_ID
                    FROM raw.load_batches
                    WHERE TABLE_NAME IN ('datapoints', 'charges')
                      AND BATCH_ID <> ?
                    LIMIT 1
                    """,
                    [batch_id],
                ).fetchone()
            if pending_batch:
                raise RuntimeError(
                    f"Batch {pending_batch[0]!r} has not been built and snapshotted. "
                    "Run dbt build before loading a different batch ID."
                )

        row_count = connection.execute(
            "SELECT COUNT(*) FROM read_csv_auto(?, header = true, all_varchar = true)",
            [str(csv_path)],
        ).fetchone()[0]
        connection.execute(
            f"""
            INSERT INTO raw.{table_name}
                ({column_list}, BATCH_ID, SOURCE_FILE, INGESTED_AT)
            SELECT {column_list}, ?, ?, CURRENT_TIMESTAMP
            FROM read_csv_auto(?, header = true, all_varchar = true)
            """,
            [batch_id, filename, str(csv_path)],
        )
        connection.execute(
            """
            INSERT INTO raw.load_batches
                (BATCH_ID, TABLE_NAME, SOURCE_FILE, ROW_COUNT, LOADED_AT)
            VALUES (?, ?, ?, ?, CURRENT_TIMESTAMP)
            """,
            [batch_id, table_name, filename, row_count],
        )
        connection.commit()
        return row_count
    except Exception:
        connection.rollback()
        raise
    finally:
        connection.close()


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Append one CSV file from input_files/ to a raw DuckDB table."
    )
    parser.add_argument("table", choices=sorted(RAW_COLUMNS))
    parser.add_argument("filename", help="CSV filename located in input_files/")
    parser.add_argument(
        "--database",
        type=Path,
        default=DATABASE_PATH,
        help=f"DuckDB database path (default: {DATABASE_PATH})",
    )
    parser.add_argument(
        "--batch-id",
        help="Shared identifier for a paired datapoints/charges load",
    )
    args = parser.parse_args()

    row_count = load_csv(args.table, args.filename, args.database, args.batch_id)
    print(
        f"Loaded {row_count:,} rows from {args.filename} into raw.{args.table} "
        f"(batch_id={args.batch_id or 'reference'})"
    )


if __name__ == "__main__":
    main()
