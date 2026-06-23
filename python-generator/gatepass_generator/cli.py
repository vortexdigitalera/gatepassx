"""CLI for the AHUON GatePassX Python generator."""

import json
import csv
import os
import warnings
from datetime import datetime, date
from pathlib import Path
from typing import List

import click
import yaml

from .models import GatePass, PassCategory, TripType
from .generator import create_pass_pdf, generate_batch_pdfs, create_passes_sheet

_QR_SECRET_ENV_VAR = "AHUON_QR_SECRET"
_QR_SECRET_DEV_DEFAULT = "ahuon-dev-secret-do-not-use-in-production"


def _get_qr_secret() -> str:
    secret = os.environ.get(_QR_SECRET_ENV_VAR)
    if not secret:
        warnings.warn(
            f"{_QR_SECRET_ENV_VAR} not set — using insecure dev default. "
            f"Set {_QR_SECRET_ENV_VAR} in production."
        )
        secret = _QR_SECRET_DEV_DEFAULT
    return secret


def _load_passes_from_file(path: Path) -> List[GatePass]:
    """Load passes from JSON, YAML or CSV."""
    suffix = path.suffix.lower()
    if suffix in {".json"}:
        data = json.loads(path.read_text())
        if isinstance(data, list):
            items = data
        elif isinstance(data, dict):
            items = data.get("passes", [data]) if "pass_id" not in data else [data]
        else:
            items = []
        return [GatePass(**item) for item in items]
    elif suffix in {".yaml", ".yml"}:
        data = yaml.safe_load(path.read_text())
        items = data if isinstance(data, list) else data.get("passes", [])
        return [GatePass(**item) for item in items]
    elif suffix in {".csv"}:
        with path.open(newline="") as f:
            reader = csv.DictReader(f)
            passes = []
            for row in reader:
                # Coerce types
                if "valid_from" in row:
                    row["valid_from"] = date.fromisoformat(row["valid_from"])
                if "valid_to" in row:
                    row["valid_to"] = date.fromisoformat(row["valid_to"])
                if "issued_at" in row and row["issued_at"]:
                    row["issued_at"] = datetime.fromisoformat(row["issued_at"])
                # Enums
                if "category" in row:
                    row["category"] = PassCategory(row["category"].upper())
                if "trip_type" in row and row["trip_type"]:
                    row["trip_type"] = TripType(row["trip_type"].upper())
                passes.append(GatePass(**row))
            return passes
    else:
        raise click.ClickException(f"Unsupported input format: {suffix}")


@click.group()
@click.version_option("0.1.0")
def cli():
    """GatePassX Python Generator — AHUON Gate Pass tooling."""
    pass


@cli.command("generate")
@click.option("--input", "-i", "input_path", required=True, type=click.Path(exists=True, path_type=Path),
              help="Path to JSON / YAML / CSV containing pass data.")
@click.option("--out", "-o", "output_dir", default="generated_passes", type=click.Path(path_type=Path),
              help="Output directory for PDFs.")
@click.option("--secret", default=None, help="Secret for QR signing (default: $AHUON_QR_SECRET).")
@click.option("--sheet", is_flag=True, help="Also produce a summary batch sheet PDF.")
def generate(input_path: Path, output_dir: Path, secret: str | None, sheet: bool):
    if secret is None:
        secret = _get_qr_secret()
    """Generate gate pass PDF(s) from input data file."""
    passes = _load_passes_from_file(input_path)
    click.echo(f"Loaded {len(passes)} pass(es) from {input_path}")

    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    created = generate_batch_pdfs(passes, str(output_dir), secret=secret)
    click.echo(f"Generated {len(created)} individual PDF(s) in {output_dir}")

    if sheet:
        sheet_path = output_dir / "batch_sheet.pdf"
        create_passes_sheet(passes, str(sheet_path), secret=secret)
        click.echo(f"Created batch summary sheet: {sheet_path}")

    click.echo("Done.")


@cli.command("new-pass")
@click.option("--out", "-o", default="pass.json", type=click.Path(path_type=Path))
def new_pass(out: Path):
    """Interactively create a sample pass JSON (for testing / import into Flutter)."""
    click.echo("Creating new GatePass interactively (press enter for defaults).")
    data = {}
    data["pass_id"] = click.prompt("Pass ID", default=f"AHUON-HAJJ-2026-{datetime.utcnow().strftime('%H%M%S')}")
    data["full_name"] = click.prompt("Full name")
    data["id_number"] = click.prompt("ID / Passport / Plate")
    data["phone"] = click.prompt("Phone", default="")
    data["operator"] = click.prompt("Operator (AHUON member)", default="Al-Mufid Travels")
    data["category"] = click.prompt("Category", type=click.Choice([c.value for c in PassCategory]), default="PILGRIM")
    data["trip_type"] = click.prompt("Trip Type", type=click.Choice([t.value for t in TripType]), default="HAJJ")
    data["valid_from"] = click.prompt("Valid from (YYYY-MM-DD)", default=date.today().isoformat())
    data["valid_to"] = click.prompt("Valid to (YYYY-MM-DD)", default=(date.today().replace(year=date.today().year+1)).isoformat())
    data["gate"] = click.prompt("Gate", default="Lagos Hajj Camp Gate A")
    data["group_ref"] = click.prompt("Group / Flight ref", default="")
    data["issued_by"] = click.prompt("Issued by", default="AHUON Ops")

    gp = GatePass(**data)
    gp.compute_qr_payload(secret=_get_qr_secret())
    out.write_text(gp.model_dump_json(indent=2))
    click.echo(f"Wrote {out}")
    click.echo("You can now run: gatepassx generate -i pass.json -o ./out --sheet")


@cli.command("validate")
@click.argument("pass_file", type=click.Path(exists=True, path_type=Path))
@click.option("--secret", default=None)
def validate_cmd(pass_file: Path, secret: str | None):
    if secret is None:
        secret = _get_qr_secret()
    """Validate / show QR payload for a pass JSON file."""
    data = json.loads(pass_file.read_text())
    gp = GatePass(**data)
    payload = gp.compute_qr_payload(secret=secret)
    click.echo("Pass ID: " + gp.pass_id)
    click.echo("QR payload:")
    click.echo(payload)
    click.echo("\nVerification dict (without secret):")
    click.echo(json.dumps(gp.to_verification_dict(), indent=2))


if __name__ == "__main__":
    cli()
