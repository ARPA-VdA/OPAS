# OPAS DL Service — documentation

This documentation is bilingual: the same five documents exist once per
language, kept in sync with each other.

- [en/](en/README.md) — English
- [it/](it/README.md) — Italiano

It is consulted from the Electron client (opas-dl-neo) under
*Impostazioni → Documentazione*, which reads the folder matching the app's
current UI language (`it` and `it_pa` both use `it/`; anything else falls
back to `en/`).

## Keeping this up to date

These documents describe *behavior*, not just structure — they need to stay
accurate as `service_master.py`, `control_server.py`, `driver_manager.py`,
and the driver SDK evolve, **and both language copies need to stay in sync
with each other**. When a change touches documented behavior, update the
relevant doc(s), in both languages, as part of that same change.
