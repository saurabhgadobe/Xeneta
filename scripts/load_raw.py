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

    columns = RAW_COLUMNS[table_name]
    column_list = ", ".join(columns)
    connection = duckdb.connect(str(database_path))
    try:
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

        row_count = connection.execute(
            "SELECT COUNT(*) FROM read_csv_auto(?, header = true, all_varchar = true)",
            [str(csv_path)],
        ).fetchone()[0]
        connection.execute(
            f"""
            INSERT INTO raw.{table_name} ({column_list})
            SELECT {column_list}
            FROM read_csv_auto(?, header = true, all_varchar = true)
            """,
            [str(csv_path)],
        )
        return row_count
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
    args = parser.parse_args()

    row_count = load_csv(args.table, args.filename, args.database)
    print(f"Loaded {row_count:,} rows from {args.filename} into raw.{args.table}")


if __name__ == "__main__":
    main()
