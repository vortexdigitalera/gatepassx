"""CLI for GatePassX — Dinner & Event Gate Pass tooling."""

import json
import csv
import os
import sys
from datetime import datetime, date
from pathlib import Path
from typing import List, Optional

import click

from .models import GatePass, PassCategory, EventType, get_qr_secret
from .generator import (
    create_pass_pdf,
    generate_batch_pdfs,
    create_passes_sheet,
    save_qr_image,
)
from .utils import verify_qr_payload

__version__ = "1.0.0"


def _load_passes_from_file(path: Path) -> List[GatePass]:
    """Load passes from JSON, YAML, or CSV."""
    suffix = path.suffix.lower()

    if suffix == ".json":
        data = json.loads(path.read_text())
        if isinstance(data, list):
            items = data
        elif isinstance(data, dict):
            items = data.get("passes", [data]) if "pass_id" not in data else [data]
        else:
            items = []
        return [GatePass(**_coerce_item(item)) for item in items]

    elif suffix in {".yaml", ".yml"}:
        import yaml
        data = yaml.safe_load(path.read_text())
        items = data if isinstance(data, list) else data.get("passes", [])
        return [GatePass(**_coerce_item(item)) for item in items]

    elif suffix == ".csv":
        with path.open(newline="") as f:
            reader = csv.DictReader(f)
            passes = []
            for row in reader:
                passes.append(GatePass(**_coerce_csv_row(row)))
            return passes

    else:
        raise click.ClickException(f"Unsupported input format: {suffix}")


def _coerce_item(item: dict) -> dict:
    """Normalize field types for a JSON/YAML pass dict."""
    if "category" in item and isinstance(item["category"], str):
        item["category"] = PassCategory(item["category"].upper())
    if "event_type" in item and isinstance(item["event_type"], str):
        item["event_type"] = EventType(item["event_type"].upper())
    # Legacy field mapping: operator → organizer, trip_type → event_type
    if "operator" in item and "organizer" not in item:
        item["organizer"] = item.pop("operator")
    if "trip_type" in item and "event_type" not in item:
        mapping = {"HAJJ": "OTHER", "UMRAH": "OTHER"}
        item["event_type"] = EventType(mapping.get(item["trip_type"].upper(), item["trip_type"].upper()))
        del item["trip_type"]
    return item


def _coerce_csv_row(row: dict) -> dict:
    """Normalize a CSV row into GatePass-compatible types."""
    if "valid_from" in row and row["valid_from"]:
        row["valid_from"] = date.fromisoformat(row["valid_from"])
    if "valid_to" in row and row["valid_to"]:
        row["valid_to"] = date.fromisoformat(row["valid_to"])
    if "issued_at" in row and row["issued_at"]:
        row["issued_at"] = datetime.fromisoformat(row["issued_at"])
    if "category" in row and row["category"]:
        row["category"] = PassCategory(row["category"].upper())
    if "event_type" in row and row["event_type"]:
        row["event_type"] = EventType(row["event_type"].upper())
    # Legacy columns
    if "operator" in row and "organizer" not in row:
        row["organizer"] = row.pop("operator", "")
    if "trip_type" in row and "event_type" not in row:
        tt = row.pop("trip_type", "")
        if tt:
            row["event_type"] = EventType.OTHER
    return row


# ── CLI Group ────────────────────────────────────────────────────────────────

@click.group()
@click.version_option(__version__, prog_name="gatepassx")
def cli():
    """GatePassX — Dinner & Event Gate Pass Generator and Scanner CLI.

    Generate printable PDFs with QR codes, create/validate passes,
    and manage event gate pass data from the command line.
    """
    pass


# ── generate ─────────────────────────────────────────────────────────────────

@cli.command()
@click.option("-i", "--input", "input_path", required=True,
              type=click.Path(exists=True, path_type=Path),
              help="JSON / YAML / CSV file containing pass data.")
@click.option("-o", "--out", "output_dir", default="generated_passes",
              type=click.Path(path_type=Path),
              help="Output directory for PDFs (default: generated_passes/).")
@click.option("--secret", default=None, help="QR signing secret (default: $GATEPASSX_QR_SECRET).")
@click.option("--sheet", is_flag=True, help="Also produce a batch summary sheet PDF.")
@click.option("--qr-only", is_flag=True, help="Generate QR PNG images instead of PDFs.")
def generate(input_path: Path, output_dir: Path, secret: Optional[str], sheet: bool, qr_only: bool):
    """Generate gate pass PDFs or QR images from a data file."""
    if secret is None:
        secret = get_qr_secret()

    passes = _load_passes_from_file(input_path)
    click.echo(f"✓ Loaded {len(passes)} pass(es) from {input_path}")

    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    if qr_only:
        qr_dir = output_dir / "qr_codes"
        qr_dir.mkdir(exist_ok=True)
        for p in passes:
            p.compute_qr_payload(secret=secret)
            safe_id = p.pass_id.replace("/", "-").replace(" ", "_")
            save_qr_image(p.qr_payload, str(qr_dir / f"{safe_id}.png"))
        click.echo(f"✓ Generated {len(passes)} QR code(s) in {qr_dir}")
    else:
        created = generate_batch_pdfs(passes, str(output_dir), secret=secret)
        click.echo(f"✓ Generated {len(created)} PDF(s) in {output_dir}")

    if sheet:
        sheet_path = output_dir / "batch_sheet.pdf"
        create_passes_sheet(passes, str(sheet_path), secret=secret)
        click.echo(f"✓ Created batch summary sheet: {sheet_path}")

    click.echo("Done.")


# ── new ──────────────────────────────────────────────────────────────────────

@cli.command()
@click.option("-o", "--out", default=None, type=click.Path(path_type=Path),
              help="Output JSON file (default: stdout).")
@click.option("--event-name", default="Annual Dinner 2026", help="Event name.")
@click.option("--event-type", default="DINNER",
              type=click.Choice([e.value for e in EventType], case_sensitive=False),
              help="Event type.")
def new(out: Optional[Path], event_name: str, event_type: str):
    """Interactively create a new gate pass (outputs JSON)."""
    click.echo("── GatePassX: New Pass ──")

    et = EventType(event_type.upper())
    ts = datetime.utcnow().strftime("%H%M%S")
    default_id = f"GPX-{et.value}-{datetime.utcnow().year}-{ts}"

    data = {}
    data["pass_id"] = click.prompt("Pass ID", default=default_id)
    data["event_name"] = click.prompt("Event name", default=event_name)
    data["event_type"] = et
    data["full_name"] = click.prompt("Guest full name")
    data["id_number"] = click.prompt("ID / Registration number")
    data["phone"] = click.prompt("Phone", default="") or None
    data["email"] = click.prompt("Email", default="") or None
    data["organizer"] = click.prompt("Organizer", default="Event Organizer")
    data["category"] = click.prompt(
        "Category",
        type=click.Choice([c.value for c in PassCategory], case_sensitive=False),
        default="GUEST",
    )
    data["valid_from"] = click.prompt("Valid from (YYYY-MM-DD)", default=date.today().isoformat())
    data["valid_to"] = click.prompt("Valid to (YYYY-MM-DD)",
                                    default=(date.today().replace(day=min(date.today().day + 3, 28))).isoformat())
    data["gate"] = click.prompt("Gate / Entrance", default="Main Gate")
    data["table_number"] = click.prompt("Table / Seat number", default="") or None
    data["group_ref"] = click.prompt("Group / Invite reference", default="") or None
    data["issued_by"] = click.prompt("Issued by", default="GatePassX CLI")

    gp = GatePass(**data)
    gp.compute_qr_payload(secret=get_qr_secret())
    result = gp.model_dump_json(indent=2)

    if out:
        out.write_text(result)
        click.echo(f"✓ Wrote pass to {out}")
        click.echo(f"  Run: gatepassx generate -i {out} -o ./passes --sheet")
    else:
        click.echo("\n── Pass JSON ──")
        click.echo(result)


# ── validate ─────────────────────────────────────────────────────────────────

@cli.command()
@click.argument("pass_file", type=click.Path(exists=True, path_type=Path))
@click.option("--secret", default=None, help="QR signing secret for verification.")
def validate(pass_file: Path, secret: Optional[str]):
    """Validate and display details of a pass JSON file."""
    if secret is None:
        secret = get_qr_secret()

    data = json.loads(pass_file.read_text())
    gp = GatePass(**data)
    payload = gp.compute_qr_payload(secret=secret)

    click.echo(f"  Pass ID:    {gp.pass_id}")
    click.echo(f"  Event:      {gp.event_name} ({gp.event_type})")
    click.echo(f"  Guest:      {gp.full_name}")
    click.echo(f"  Category:   {gp.category}")
    click.echo(f"  Organizer:  {gp.organizer}")
    click.echo(f"  Valid:      {gp.valid_from} → {gp.valid_to}")
    click.echo(f"  Gate:       {gp.gate or '—'}")
    click.echo(f"  Table:      {gp.table_number or '—'}")
    click.echo(f"\n  QR payload ({len(payload)} bytes):")
    click.echo(f"  {payload}")

    if gp.qr_payload:
        valid, qr_data = verify_qr_payload(gp.qr_payload, secret=secret)
        status = "✓ VALID" if valid else "✗ INVALID"
        click.echo(f"\n  Signature:  {status}")


# ── scan ─────────────────────────────────────────────────────────────────────

@cli.command()
@click.argument("qr_payload")
@click.option("--secret", default=None, help="QR signing secret for verification.")
def scan(qr_payload: str, secret: Optional[str]):
    """Scan/verify a QR payload string from the terminal.

    Paste the raw QR payload to verify its signature and check validity.
    """
    if secret is None:
        secret = get_qr_secret()

    valid, data = verify_qr_payload(qr_payload, secret=secret)

    if not valid:
        click.echo(f"✗ INVALID: {data.get('error', 'unknown error')}")
        sys.exit(1)

    pid = data.get("pid", "?")
    name = data.get("nm", "?")
    cat = data.get("cat", "?")
    vf = data.get("vf", "")
    vt = data.get("vt", "")

    now = date.today()
    try:
        d_from = date.fromisoformat(vf)
        d_to = date.fromisoformat(vt)
        in_window = d_from <= now <= d_to
    except (ValueError, TypeError):
        in_window = False

    click.echo(f"  Pass ID:    {pid}")
    click.echo(f"  Name:       {name}")
    click.echo(f"  Category:   {cat}")
    click.echo(f"  Valid:      {vf} → {vt}")
    click.echo(f"  Signature:  ✓ VALID")
    click.echo(f"  Date check: {'✓ ACTIVE' if in_window else '✗ OUTSIDE VALIDITY WINDOW'}")

    if not in_window:
        sys.exit(2)


# ── qr ───────────────────────────────────────────────────────────────────────

@cli.command()
@click.option("-i", "--input", "input_path", required=True,
              type=click.Path(exists=True, path_type=Path),
              help="Pass JSON file to generate QR from.")
@click.option("-o", "--out", default=None, type=click.Path(path_type=Path),
              help="Output PNG path (default: <pass_id>.png in current dir).")
@click.option("--size", default=10, help="QR box size in pixels (default: 10).")
@click.option("--secret", default=None)
def qr(input_path: Path, out: Optional[Path], size: int, secret: Optional[str]):
    """Generate a standalone QR code PNG from a pass JSON file."""
    if secret is None:
        secret = get_qr_secret()

    data = json.loads(input_path.read_text())
    gp = GatePass(**data)
    payload = gp.compute_qr_payload(secret=secret)

    out_path = out or Path(f"{gp.pass_id.replace('/', '-').replace(' ', '_')}.png")
    save_qr_image(payload, str(out_path), box_size=size)
    click.echo(f"✓ QR code saved to {out_path}")


# ── template ─────────────────────────────────────────────────────────────────

@cli.command()
@click.option("-o", "--out", default="template.json", type=click.Path(path_type=Path),
              help="Output template file.")
@click.option("--format", "fmt", type=click.Choice(["json", "csv"]), default="json",
              help="Template format.")
def template(out: Path, fmt: str):
    """Generate a sample data template for bulk import."""
    if fmt == "json":
        sample = {
            "passes": [
                {
                    "pass_id": "GPX-DINNER-2026-000001",
                    "event_name": "Annual Gala Dinner",
                    "event_type": "DINNER",
                    "category": "GUEST",
                    "full_name": "Jane Doe",
                    "id_number": "REG-001",
                    "phone": "+2348012345678",
                    "email": "jane@example.com",
                    "organizer": "Event Co.",
                    "valid_from": "2026-07-01",
                    "valid_to": "2026-07-01",
                    "gate": "Main Entrance",
                    "table_number": "T-12",
                    "group_ref": "INV-2026-001",
                    "issued_by": "GatePassX CLI",
                }
            ]
        }
        out.write_text(json.dumps(sample, indent=2))
    else:
        headers = [
            "pass_id", "event_name", "event_type", "category", "full_name",
            "id_number", "phone", "email", "organizer", "valid_from", "valid_to",
            "gate", "table_number", "group_ref", "issued_by",
        ]
        row = [
            "GPX-DINNER-2026-000001", "Annual Gala Dinner", "DINNER", "GUEST",
            "Jane Doe", "REG-001", "+2348012345678", "jane@example.com",
            "Event Co.", "2026-07-01", "2026-07-01", "Main Entrance",
            "T-12", "INV-2026-001", "GatePassX CLI",
        ]
        with out.open("w", newline="") as f:
            w = csv.writer(f)
            w.writerow(headers)
            w.writerow(row)

    click.echo(f"✓ Template written to {out} ({fmt} format)")
    click.echo(f"  Edit the file, then run: gatepassx generate -i {out} -o ./passes")


# ── info ─────────────────────────────────────────────────────────────────────

@cli.command()
@click.option("-i", "--input", "input_path", required=True,
              type=click.Path(exists=True, path_type=Path),
              help="Data file to summarize.")
def info(input_path: Path):
    """Show statistics and summary of a pass data file."""
    passes = _load_passes_from_file(input_path)

    categories: dict = {}
    event_types: dict = {}
    for p in passes:
        cat = p.category.value if hasattr(p.category, "value") else str(p.category)
        et = p.event_type.value if hasattr(p.event_type, "value") else str(p.event_type)
        categories[cat] = categories.get(cat, 0) + 1
        event_types[et] = event_types.get(et, 0) + 1

    click.echo(f"  File:       {input_path}")
    click.echo(f"  Total:      {len(passes)} pass(es)")

    if passes:
        click.echo(f"\n  Event:      {passes[0].event_name}")
        click.echo(f"  Organizer:  {passes[0].organizer}")

    click.echo("\n  By category:")
    for cat, count in sorted(categories.items()):
        click.echo(f"    {cat:<14} {count}")

    click.echo("\n  By event type:")
    for et, count in sorted(event_types.items()):
        click.echo(f"    {et:<14} {count}")

    now = date.today()
    active = sum(1 for p in passes if p.valid_from <= now <= p.valid_to)
    click.echo(f"\n  Active now:  {active} / {len(passes)}")


if __name__ == "__main__":
    cli()
