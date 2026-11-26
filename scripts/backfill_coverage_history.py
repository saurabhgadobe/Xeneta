import argparse
import json
import subprocess
import tempfile
from pathlib import Path

import duckdb

from load_raw import DATABASE_PATH, PROJECT_ROOT, load_csv


DBT_EXECUTABLE = PROJECT_ROOT.parent / ".venv" / "bin" / "dbt"
SNAPSHOT_TABLE_SQL = """
CREATE TABLE IF NOT EXISTS final.coverage_snapshots (
    BATCH_ID VARCHAR PRIMARY KEY,
    DATAPOINTS_SOURCE_FILE VARCHAR,
    CHARGES_SOURCE_FILE VARCHAR,
    BEFORE_COVERED_LANES BIGINT NOT NULL,
    AFTER_COVERED_LANES BIGINT,
    DBT_INVOCATION_ID VARCHAR NOT NULL,
    CAPTURED_AT TIMESTAMPTZ NOT NULL,
    COMPLETED_AT TIMESTAMPTZ
)
"""
REFERENCE_FILES = (
    ("ports", "DE_casestudy_ports.csv"),
    ("regions", "DE_casestudy_regions.csv"),
    ("exchange_rates", "DE_casestudy_exchange_rates.csv"),
)
TRANSACTION_BATCHES = (
    (
        "batch_1",
        "DE_casestudy_datapoints_1.csv",
        "DE_casestudy_charges_1.csv",
    ),
    (
        "batch_2",
        "DE_casestudy_datapoints_2.csv",
        "DE_casestudy_charges_2.csv",
    ),
    (
        "batch_3",
        "DE_casestudy_datapoints_3.csv",
        "DE_casestudy_charges_3.csv",
    ),
)


def build_batch(profiles_directory: Path, batch_id: str) -> None:
    result = subprocess.run(
        [
            str(DBT_EXECUTABLE),
            "build",
            "--profiles-dir",
            str(profiles_directory),
            "--no-use-colors",
        ],
        cwd=PROJECT_ROOT,
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode:
        raise RuntimeError(
            f"dbt build failed after loading {batch_id}.\n"
            f"{result.stdout[-8000:]}\n{result.stderr[-3000:]}"
        )

    completion = next(
        (
            line.strip()
            for line in reversed(result.stdout.splitlines())
            if "Done. PASS=" in line
        ),
        "dbt build completed",
    )
    print(f"{batch_id}: {completion}")


def replay_history() -> list[tuple[object, ...]]:
    with tempfile.TemporaryDirectory(prefix="xeneta-coverage-") as directory:
        temporary_root = Path(directory)
        replay_database = temporary_root / "replay.duckdb"
        profiles_directory = temporary_root / "profiles"
        profiles_directory.mkdir()
        (profiles_directory / "profiles.yml").write_text(
            "xeneta:\n"
            "  outputs:\n"
            "    dev:\n"
            "      type: duckdb\n"
            f"      path: {json.dumps(str(replay_database))}\n"
            "      threads: 1\n"
            "  target: dev\n"
        )

        connection = duckdb.connect(str(replay_database))
        try:
            connection.execute(
                (PROJECT_ROOT / "scripts" / "create_raw_tables.sql").read_text()
            )
        finally:
            connection.close()

        for table_name, filename in REFERENCE_FILES:
            load_csv(table_name, filename, replay_database)

        snapshots: list[tuple[object, ...]] = []
        for batch_id, datapoints_file, charges_file in TRANSACTION_BATCHES:
            load_csv("datapoints", datapoints_file, replay_database, batch_id)
            load_csv("charges", charges_file, replay_database, batch_id)

            build_batch(profiles_directory, batch_id)
            connection = duckdb.connect(str(replay_database), read_only=True)
            try:
                row = connection.execute(
                    """
                    SELECT
                        BATCH_ID,
                        DATAPOINTS_SOURCE_FILE,
                        CHARGES_SOURCE_FILE,
                        BEFORE_COVERED_LANES,
                        AFTER_COVERED_LANES,
                        DBT_INVOCATION_ID,
                        CAPTURED_AT,
                        COMPLETED_AT
                    FROM final.coverage_snapshots
                    WHERE BATCH_ID = ?
                    """,
                    [batch_id],
                ).fetchone()
            finally:
                connection.close()
            if row is None or row[4] is None:
                raise RuntimeError(
                    f"Coverage snapshot for {batch_id} was not completed."
                )
            snapshots.append(row)

        return snapshots


def save_snapshots(
    snapshots: list[tuple[object, ...]], database_path: Path
) -> None:
    connection = duckdb.connect(str(database_path))
    try:
        connection.begin()
        connection.execute("CREATE SCHEMA IF NOT EXISTS final")
        connection.execute(SNAPSHOT_TABLE_SQL)
        for snapshot in snapshots:
            existing = connection.execute(
                """
                SELECT BEFORE_COVERED_LANES, AFTER_COVERED_LANES
                FROM final.coverage_snapshots
                WHERE BATCH_ID = ?
                """,
                [snapshot[0]],
            ).fetchone()
            if existing is not None:
                if existing != (snapshot[3], snapshot[4]):
                    raise RuntimeError(
                        f"Existing coverage snapshot for {snapshot[0]} does not "
                        "match the replayed history."
                    )
                continue
            connection.execute(
                """
                INSERT INTO final.coverage_snapshots (
                    BATCH_ID,
                    DATAPOINTS_SOURCE_FILE,
                    CHARGES_SOURCE_FILE,
                    BEFORE_COVERED_LANES,
                    AFTER_COVERED_LANES,
                    DBT_INVOCATION_ID,
                    CAPTURED_AT,
                    COMPLETED_AT
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """,
                list(snapshot),
            )
        connection.commit()
    except Exception:
        connection.rollback()
        raise
    finally:
        connection.close()


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Replay batches 1-3 in a temporary database and backfill their "
            "before/after covered-lane snapshots."
        )
    )
    parser.add_argument(
        "--database",
        type=Path,
        default=DATABASE_PATH,
        help=f"Database to receive the snapshots (default: {DATABASE_PATH})",
    )
    args = parser.parse_args()

    snapshots = replay_history()
    save_snapshots(snapshots, args.database)
    print(f"Saved {len(snapshots)} historical coverage snapshots to {args.database}")


if __name__ == "__main__":
    main()
