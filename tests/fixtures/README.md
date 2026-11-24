# Test fixtures

Use synthetic data only. Keep real saves, exported player data, production logs, and real identifiers out of this directory. Prefix invented identifiers with `TEST-`.

Group fixtures by domain and name each file `<scenario>.v<schema-version>.json`, for example `ownership/sample-registry.v1.json`. Document the intended case in the test that consumes the fixture.
