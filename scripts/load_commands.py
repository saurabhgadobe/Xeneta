import argparse
from pathlib import Path

from load_raw import DATABASE_PATH, load_csv


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Load the reference data and initial transaction batch."
    )
    parser.add_argument(
        "--database",
        type=Path,
        default=DATABASE_PATH,
        help=f"DuckDB database path (default: {DATABASE_PATH})",
    )
    args = parser.parse_args()

    for table, filename in (
        ("ports", "DE_casestudy_ports.csv"),
        ("regions", "DE_casestudy_regions.csv"),
        ("exchange_rates", "DE_casestudy_exchange_rates.csv"),
    ):
        load_csv(table, filename, args.database)

    for table, filename in (
        ("datapoints", "DE_casestudy_datapoints_1.csv"),
        ("charges", "DE_casestudy_charges_1.csv"),
    ):
        load_csv(table, filename, args.database, batch_id="batch_1")


if __name__ == "__main__":
    main()