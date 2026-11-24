# Compatibility record

Record these values at the start of each experimental cycle.

## G1 Windows lab cycle, 2026-11-24

The reviewer verified this cycle on a disposable dedicated server.

```text
Palworld client version:       NOT_TESTED
Palworld dedicated version:    v1.0.5.102999
Steam build ID (server):       25247047
UE4SS distribution/version:    UE4SS_v4.0.0.zip, v4.0.0 (30afe5ff)
PalHomeward git commit:        611a16f
Operating system:              Windows 11
Package installation method:   OFFICIAL_LOADER (local numbered Workshop folders)
Test world snapshot hash:      5d56896dcdc571f974fe8230047d707f2d2039682338ac78e2d67238ce5d6fed
```

SteamCMD installed app `2394010`. The dedicated version came from REST `/v1/api/info` and UE4SS.log reported engine version 5.1. The tested PalHomeward package included the `main.lua` newline fix. The pre-cycle snapshot of disposable world `A033711F4F66BEFEFAD607950A5C87FC` is stored outside the repository. [G1 evidence](evidence/G1/README.md)

Claim compatibility only for the exact tested game version and build, with the tested UE4SS version and installation method recorded. Revalidate after game or UE4SS updates. See the [version rule](plan.md#24-version-rule) and [regression matrix](plan.md#124-regression-matrix-by-change).
