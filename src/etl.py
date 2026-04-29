from __future__ import annotations

import argparse
import csv
import re
import sys
from collections import Counter
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Set

DEFAULT_OUTPUT = Path("data/processed/knowledge_base.pl")
DEFAULT_LOCAL_CANDIDATES = [
    Path("data/raw/BMW sales data (2010-2024) (1).csv"),
    Path("data/raw/BMW sales data (2010-2024).csv"),
    Path("BMW sales data (2010-2024) (1).csv"),
    Path("BMW sales data (2010-2024).csv"),
]
KAGGLE_DEFAULT_PATH = Path(
    "/kaggle/input/bmw-sales-dataset/BMW sales data (2010-2024) (1).csv"
)

FIELDS = [
    "Model",
    "Year",
    "Region",
    "Fuel_Type",
    "Transmission",
    "Engine_Size_L",
    "Price_USD",
    "Sales_Volume",
]

KNOWN_FUEL_TYPES = {"petrol", "diesel", "hybrid", "electric"}
KNOWN_TRANSMISSIONS = {"manual", "automatic"}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Gera knowledge_base.pl a partir do CSV BMW."
    )
    parser.add_argument(
        "--input",
        type=Path,
        help="Caminho para o CSV local (prioridade maxima).",
    )
    parser.add_argument(
        "--kaggle",
        action="store_true",
        help="Tenta o path padrao do Kaggle se --input nao for informado.",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=DEFAULT_OUTPUT,
        help=f"Arquivo de saida Prolog (padrao: {DEFAULT_OUTPUT}).",
    )
    return parser.parse_args()


def sanitize_text(raw: str) -> str:
    cleaned = (raw or "").strip().lower()
    cleaned = re.sub(r"[^a-z0-9]+", "_", cleaned)
    cleaned = cleaned.strip("_")
    if not cleaned:
        return "unknown"
    return cleaned


def to_prolog_atom(raw: str) -> str:
    sanitized = sanitize_text(raw)
    if sanitized[0].isdigit():
        return f"'{sanitized}'"
    return sanitized


def parse_int(raw: str) -> int:
    value = (raw or "").strip()
    if value == "":
        raise ValueError("valor inteiro vazio")
    return int(float(value))


def parse_float(raw: str) -> float:
    value = (raw or "").strip()
    if value == "":
        raise ValueError("valor float vazio")
    return float(value)


def resolve_input_path(args: argparse.Namespace) -> Path:
    if args.input:
        if not args.input.exists():
            raise FileNotFoundError(f"--input inexistente: {args.input}")
        return args.input

    candidates: List[Path] = []
    if args.kaggle:
        candidates.append(KAGGLE_DEFAULT_PATH)
    candidates.extend(DEFAULT_LOCAL_CANDIDATES)

    for candidate in candidates:
        if candidate.exists():
            return candidate

    raise FileNotFoundError(
        "CSV nao encontrado. Informe --input <arquivo.csv> ou use --kaggle no ambiente Kaggle."
    )


def validate_headers(fieldnames: Optional[Iterable[str]]) -> None:
    if not fieldnames:
        raise ValueError("CSV sem cabecalho.")
    missing = [field for field in FIELDS if field not in fieldnames]
    if missing:
        raise ValueError(f"Cabecalho invalido; campos ausentes: {missing}")


def row_to_fact(
    row: Dict[str, str],
    rejected_reasons: Counter[str],
    normalization_sources: Dict[str, Dict[str, Set[str]]],
    warnings: Counter[str],
) -> Optional[str]:
    for field in ("Model", "Region", "Fuel_Type", "Transmission"):
        original = (row.get(field) or "").strip()
        normalized = sanitize_text(original)
        normalization_sources.setdefault(field, {}).setdefault(normalized, set()).add(
            original
        )
        if original == "":
            rejected_reasons[f"campo_textual_vazio:{field}"] += 1
            return None

    try:
        model = to_prolog_atom(row["Model"])
        year = parse_int(row["Year"])
        region = to_prolog_atom(row["Region"])
        fuel_type = to_prolog_atom(row["Fuel_Type"])
        transmission = to_prolog_atom(row["Transmission"])
        engine_size = parse_float(row["Engine_Size_L"])
        price_usd = parse_int(row["Price_USD"])
        sales_volume = parse_int(row["Sales_Volume"])
    except KeyError as exc:
        rejected_reasons[f"campo_ausente:{exc.args[0]}"] += 1
        return None
    except ValueError as exc:
        rejected_reasons[f"erro_parse:{exc}"] += 1
        return None

    if not (1900 <= year <= 2100):
        rejected_reasons["year_fora_faixa"] += 1
        return None
    if engine_size <= 0:
        rejected_reasons["engine_size_invalido"] += 1
        return None
    if price_usd <= 0:
        rejected_reasons["price_invalido"] += 1
        return None
    if sales_volume < 0:
        rejected_reasons["sales_volume_negativo"] += 1
        return None

    fuel_text = sanitize_text(row["Fuel_Type"])
    if fuel_text not in KNOWN_FUEL_TYPES:
        warnings[f"fuel_type_nao_esperado:{fuel_text}"] += 1
    transmission_text = sanitize_text(row["Transmission"])
    if transmission_text not in KNOWN_TRANSMISSIONS:
        warnings[f"transmission_nao_esperado:{transmission_text}"] += 1

    return (
        f"bmw({model}, {year}, {region}, {fuel_type}, "
        f"{transmission}, {engine_size:.1f}, {price_usd}, {sales_volume})."
    )


def write_output(output_path: Path, facts: List[str], input_path: Path) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w", encoding="utf-8", newline="\n") as output_file:
        output_file.write("% knowledge_base.pl — BMW Global Sales (2010-2024)\n")
        output_file.write(f"% Source CSV: {input_path}\n")
        output_file.write(f"% Facts generated: {len(facts)}\n\n")
        for fact in facts:
            output_file.write(fact + "\n")


def print_report(
    input_path: Path,
    output_path: Path,
    rows_read: int,
    facts_written: int,
    rejected_reasons: Counter[str],
    warnings: Counter[str],
    normalization_sources: Dict[str, Dict[str, Set[str]]],
) -> None:
    rejected_total = rows_read - facts_written
    print("=== RELATORIO DE QUALIDADE ETL ===")
    print(f"Entrada: {input_path}")
    print(f"Saida: {output_path}")
    print(f"Linhas lidas: {rows_read}")
    print(f"Linhas aceitas: {facts_written}")
    print(f"Linhas rejeitadas: {rejected_total}")

    print("\nMotivos de rejeicao:")
    if rejected_reasons:
        for reason, count in rejected_reasons.most_common():
            print(f"- {reason}: {count}")
    else:
        print("- nenhum")

    print("\nAlertas de dominio:")
    if warnings:
        for warning, count in warnings.most_common():
            print(f"- {warning}: {count}")
    else:
        print("- nenhum")

    print("\nPossiveis colisoes de normalizacao (mesmo token para originais distintos):")
    collision_lines = []
    for field, normalized_map in normalization_sources.items():
        for normalized, originals in normalized_map.items():
            if len(originals) > 1:
                variants = sorted(v for v in originals if v)
                collision_lines.append(
                    f"- {field}:{normalized} <= {variants[:4]}"
                    + (" ..." if len(variants) > 4 else "")
                )
    if collision_lines:
        for line in collision_lines[:20]:
            print(line)
        if len(collision_lines) > 20:
            print(f"- ... e mais {len(collision_lines) - 20} casos")
    else:
        print("- nenhuma colisao detectada")


def run_etl(input_path: Path, output_path: Path) -> int:
    rejected_reasons: Counter[str] = Counter()
    warnings: Counter[str] = Counter()
    normalization_sources: Dict[str, Dict[str, Set[str]]] = {}
    facts: List[str] = []
    rows_read = 0

    with input_path.open("r", encoding="utf-8-sig", newline="") as csv_file:
        reader = csv.DictReader(csv_file)
        validate_headers(reader.fieldnames)
        for row in reader:
            rows_read += 1
            fact = row_to_fact(row, rejected_reasons, normalization_sources, warnings)
            if fact is None:
                continue
            facts.append(fact)

    write_output(output_path, facts, input_path)
    print_report(
        input_path,
        output_path,
        rows_read,
        len(facts),
        rejected_reasons,
        warnings,
        normalization_sources,
    )

    return 0


def main() -> int:
    args = parse_args()
    try:
        input_path = resolve_input_path(args)
        return run_etl(input_path, args.output)
    except (FileNotFoundError, ValueError) as exc:
        print(f"ERRO: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
