import argparse
from pathlib import Path

import duckdb


PROJECT_ROOT = Path(__file__).resolve().parents[1]
DATABASE_PATH = PROJECT_ROOT / "dev.duckdb"
INPUT_DIRECTORY = PROJECT_ROOT / "input_files"
SOURCE_FILES = (
    ("ports", "reference", "DE_casestudy_ports.csv", "PID"),
    ("regions", "reference", "DE_casestudy_regions.csv", "SLUG"),
    ("exchange_rates", "reference", "DE_casestudy_exchange_rates.csv", "DAY"),
    ("datapoints", "batch_1", "DE_casestudy_datapoints_1.csv", "D_ID"),
    ("charges", "batch_1", "DE_casestudy_charges_1.csv", "D_ID"),
    ("datapoints", "batch_2", "DE_casestudy_datapoints_2.csv", "D_ID"),
    ("charges", "batch_2", "DE_casestudy_charges_2.csv", "D_ID"),
    ("datapoints", "batch_3", "DE_casestudy_datapoints_3.csv", "D_ID"),
    ("charges", "batch_3", "DE_casestudy_charges_3.csv", "D_ID"),
)


def migrate(database_path: Path = DATABASE_PATH) -> None:
    connection = duckdb.connect(str(database_path))
    try:
        connection.begin()
        connection.execute(
            """
            CREATE TABLE IF NOT EXISTS raw.load_batches (
                BATCH_ID VARCHAR NOT NULL,
                TABLE_NAME VARCHAR NOT NULL,
                SOURCE_FILE VARCHAR NOT NULL,
                ROW_COUNT BIGINT NOT NULL,
                LOADED_AT TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
                PRIMARY KEY (BATCH_ID, TABLE_NAME)
            )
            """
        )
        for table_name, _, _, _ in SOURCE_FILES:
            connection.execute(
                f"ALTER TABLE raw.{table_name} ADD COLUMN IF NOT EXISTS BATCH_ID VARCHAR"
            )
            connection.execute(
                f"ALTER TABLE raw.{table_name} ADD COLUMN IF NOT EXISTS SOURCE_FILE VARCHAR"
            )
            connection.execute(
                f"ALTER TABLE raw.{table_name} ADD COLUMN IF NOT EXISTS INGESTED_AT TIMESTAMPTZ"
            )

        for table_name, batch_id, filename, key_column in SOURCE_FILES:
            csv_path = INPUT_DIRECTORY / filename
            if not csv_path.is_file():
                raise FileNotFoundError(f"CSV file not found: {csv_path}")

            escaped_path = str(csv_path).replace("'", "''")
            source_count = connection.execute(
                f"SELECT COUNT(*) FROM read_csv_auto('{escaped_path}', header=true, all_varchar=true)"
            ).fetchone()[0]
            existing_count = connection.execute(
                f"""
                SELECT COUNT(*)
                FROM raw.{table_name}
                WHERE {key_column} IN (
                    SELECT {key_column}
                    FROM read_csv_auto('{escaped_path}', header=true, all_varchar=true)
                )
                """
            ).fetchone()[0]
            if existing_count == 0:
                continue
            if existing_count != source_count:
                raise RuntimeError(
                    f"Database contains only {existing_count} of {source_count} "
                    f"rows from {filename}; refusing a partial lineage backfill."
                )
            connection.execute(
                """
                INSERT OR IGNORE INTO raw.load_batches
                    (BATCH_ID, TABLE_NAME, SOURCE_FILE, ROW_COUNT, LOADED_AT)
                VALUES (?, ?, ?, ?, CURRENT_TIMESTAMP)
                """,
                [batch_id, table_name, filename, source_count],
            )
            connection.execute(
                f"""
                UPDATE raw.{table_name}
                SET
                    BATCH_ID = ?,
                    SOURCE_FILE = ?,
                    INGESTED_AT = (
                        SELECT LOADED_AT
                        FROM raw.load_batches
                        WHERE BATCH_ID = ? AND TABLE_NAME = ?
                    )
                WHERE {key_column} IN (
                    SELECT {key_column}
                    FROM read_csv_auto('{escaped_path}', header=true, all_varchar=true)
                )
                """,
                [batch_id, filename, batch_id, table_name],
            )
            matched_count = connection.execute(
                f"""
                SELECT COUNT(*)
                FROM raw.{table_name}
                WHERE BATCH_ID = ? AND SOURCE_FILE = ?
                """,
                [batch_id, filename],
            ).fetchone()[0]
            if matched_count != existing_count:
                raise RuntimeError(
                    f"Could not map every row in {filename}: "
                    f"expected {existing_count}, mapped {matched_count}."
                )

        for table_name, _, _, _ in SOURCE_FILES:
            untagged = connection.execute(
                f"""
                SELECT COUNT(*)
                FROM raw.{table_name}
                WHERE BATCH_ID IS NULL
                   OR SOURCE_FILE IS NULL
                   OR INGESTED_AT IS NULL
                """
            ).fetchone()[0]
            if untagged:
                raise RuntimeError(
                    f"raw.{table_name} still has {untagged} untagged rows."
                )
        connection.commit()
    except Exception:
        connection.rollback()
        raise
    finally:
        connection.close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Backfill batch and source-file metadata in an existing DuckDB database."
    )
    parser.add_argument(
        "--database",
        type=Path,
        default=DATABASE_PATH,
        help=f"DuckDB database path (default: {DATABASE_PATH})",
    )
    args = parser.parse_args()
    migrate(args.database)
    print(f"Batch metadata migration completed for {args.database}")
