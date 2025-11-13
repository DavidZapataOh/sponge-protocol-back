#!/usr/bin/env python3
"""Export proofs/public inputs (binary) to JSON hex blobs for Solidity tests."""
from __future__ import annotations

import argparse
import json
from pathlib import Path

FIELD_ELEMENT_SIZE = 32


def to_hex(data: bytes) -> str:
    return "0x" + data.hex()


def read_public_inputs(path: Path) -> list[str]:
    data = path.read_bytes()
    if len(data) % FIELD_ELEMENT_SIZE != 0:
        raise ValueError(f"Public inputs file {path} length {len(data)} is not a multiple of 32")
    return [to_hex(data[i : i + FIELD_ELEMENT_SIZE]) for i in range(0, len(data), FIELD_ELEMENT_SIZE)]


def export_directory(dir_path: Path) -> dict[str, object]:
    proof_path = dir_path / "target" / "proof"
    public_inputs_path = dir_path / "target" / "public_inputs"
    if not proof_path.exists() or not public_inputs_path.exists():
        raise FileNotFoundError(f"Expected proof/public_inputs in {dir_path}/target")
    proof_hex = to_hex(proof_path.read_bytes())
    public_inputs_hex = read_public_inputs(public_inputs_path)
    payload = {
        "proof": proof_hex,
        "public_inputs": public_inputs_hex,
    }
    output_path = dir_path / "target" / "proof.json"
    output_path.write_text(json.dumps(payload, indent=2))
    return payload


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "circuits",
        nargs="*",
        default=["deposit", "transfer", "withdraw"],
        help="Circuit directories to export (relative to circuits-privacy)",
    )
    parser.add_argument(
        "--base-dir",
        type=Path,
        default=Path(__file__).resolve().parents[1] / "circuits-privacy",
        help="Root directory containing circuit folders",
    )
    args = parser.parse_args()

    results = {}
    for circuit in args.circuits:
        folder = args.base_dir / circuit
        payload = export_directory(folder)
        results[circuit] = payload

    print(json.dumps(results, indent=2))


if __name__ == "__main__":
    main()
