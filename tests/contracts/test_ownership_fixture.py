import json
from pathlib import Path

import pytest
from jsonschema import Draft202012Validator

ROOT = Path(__file__).resolve().parents[2]
SCHEMA = ROOT / "tools/schemas/ownership.v1.schema.json"


@pytest.mark.contract
def test_synthetic_registry_matches_v1_schema():
    schema = json.loads(SCHEMA.read_text(encoding="utf-8"))
    source = ROOT / "tests/fixtures/ownership/sample-registry.v1.json"
    registry = json.loads(source.read_text(encoding="utf-8"))
    Draft202012Validator.check_schema(schema)
    Draft202012Validator(schema).validate(registry)
    assert registry["pals"]["TEST-PAL-0001"]["ownerUid"] == "TEST-PLAYER-A"


@pytest.mark.contract
def test_registry_schema_accepts_sparse_records_and_checks_input_shape():
    validator = Draft202012Validator(json.loads(SCHEMA.read_text(encoding="utf-8")))
    header = {"schemaVersion": 1, "worldId": "world", "revision": 0}
    unresolved = {"status": "UNRESOLVED"}
    verified = {
        "status": "VERIFIED",
        "ownerUid": "A",
        "ownerEvidence": "test_evidence",
        "ownerEvidenceRevision": 0,
    }
    validator.validate({**header, "pals": {}})
    validator.validate({**header, "pals": {"a": unresolved, "b": verified}})
    validator.validate({**header, "pals_list": [{"palId": "a", **unresolved}, {"palId": "b", **verified}]})

    assert not validator.is_valid({**header, "pals": {}, "pals_list": []})
    assert not validator.is_valid({**header, "pals": {"a": {"status": "VERIFIED", "ownerUid": "A"}}})
    assert not validator.is_valid({**header, "pals": {"a": {"palId": "a", **unresolved}}})
    assert not validator.is_valid({**header, "pals_list": [verified]})
