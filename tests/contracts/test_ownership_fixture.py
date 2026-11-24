import json
from pathlib import Path

import pytest
from jsonschema import Draft202012Validator

ROOT = Path(__file__).resolve().parents[2]


@pytest.mark.contract
def test_synthetic_registry_matches_v1_schema():
    schema = json.loads((ROOT / "tools/schemas/ownership.v1.schema.json").read_text(encoding="utf-8"))
    source = ROOT / "tests/fixtures/ownership/sample-registry.v1.json"
    registry = json.loads(source.read_text(encoding="utf-8"))
    Draft202012Validator.check_schema(schema)
    Draft202012Validator(schema).validate(registry)
    assert registry["pals"]["TEST-PAL-0001"]["ownerUid"] == "TEST-PLAYER-A"
