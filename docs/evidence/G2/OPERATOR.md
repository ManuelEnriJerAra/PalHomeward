# G2 operator protocol (single account, ~20 minutes)

Lab only: disposable world, never a real save. The probe only reads; it cannot move or protect Pals.

## Before you start
1. Palworld client updated by Steam (it must match the lab server version, v1.0.5.x).
2. PowerShell in the repo root:
   ```powershell
   $env:PALHOMEWARD_LAB = "<your lab root>"
   powershell -ExecutionPolicy Bypass -File tools\lab\g2-session.ps1 begin
   ```
   It must print `hooks registered: 12`.
3. In the client: **Join Multiplayer Game** → address `127.0.0.1:8211`.

## In game
Write down the wall-clock time (HH:MM:SS) when you perform each step; the log is correlated by
time. Keep 5–10 s between steps. Name the Pals in-game (e.g. `Fox1`, `Fox2`) so you can tell
same-species Pals apart in your notes.

| # | Action | Note to record |
|---|---|---|
| 0 | Create a character, build a Palbox (base). Catch 3 Pals, two of the **same species**. | time when the base exists |
| 1 | Assign `Fox1` from the Palbox to the base (drag to worker list). | time |
| 2 | Assign `Fox2` (same species) the same way. | time |
| 3 | Open the Palbox UI, look around, close it **without** changing anything. | time (no-op control) |
| 4 | Move `Fox1` from the base back to the Palbox. | time |
| 5 | Move `Fox2` from the base directly to the party (team). | time |
| 6 | Assign `Fox1` again, then swap it with the third Pal (replace in the same slot). | time |
| 7 | Move a base worker to the Palbox using the right-click / quick action, if available. | time + which UI |
| 8 | Move a Pal from the party to the base. | time |
| 9 | Change Palbox pages back and forth without moving anything. | time (no-op control) |
| 10 | Remove the last worker to the Palbox again (repeat of 4). | time |

Then quit to the main menu and run:
```powershell
powershell -ExecutionPolicy Bypass -File tools\lab\g2-session.ps1 end
```
Send the reviewer your notes (step → time). Do not edit the generated log.

## What this does not cover
Cross-owner removal (player B removing A's worker) needs a second account; G2 stays `BLOCKED` for
those cases until it is available (see `docs/research/PH-007-probe-plan.md`).
