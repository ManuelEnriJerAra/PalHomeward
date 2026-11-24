# Release candidate checklist

- [ ] G0–G8 PASS with actual evidence.
- [ ] All P0 tests recorded as PASS. No mandatory test remains `NOT_RUN`.
- [ ] `OBSERVE` and actual `AUTO_RETURN` modes tested.
- [ ] All covered removal paths documented and verified.
- [ ] `OwnerUid`, `WorldId` and `InstanceId` remain distinct.
- [ ] 0 confirmed losses or duplicates in the suite and soak test.
- [ ] Offline owner return works or the scope has been formally changed **before** release.
- [ ] Backup and restoration practiced.
- [ ] Uninstall practiced on a test snapshot.
- [ ] Official `Info.json` with `IsServer: true` verified.
- [ ] Versions, compatibility, licenses and limitations published.
- [ ] Security and code reviews completed.
- [ ] Human approval recorded in `docs/evidence/G8/signoff.md`.
