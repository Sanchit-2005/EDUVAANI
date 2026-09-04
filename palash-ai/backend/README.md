# EduVaani Backend

Optional online synchronization backend for EduVaani; the neural Text Translator uses this server when the ML services are enabled.

## Run

1. Copy `.env.example` to `.env`.
2. Run `npm install`.
3. Run `npm start`.

Available endpoints include `/health`, `/api/health`, `/api/translate`, `/api/lessons`, `/api/translations`, `/api/sync`, and `/api/progress`. `/health` reports Node liveness plus Python/IndicTrans2 reachability and model readiness without loading the model. This Phase 14 version uses in-memory prototype data. MySQL storage is added in Phase 15.

The server binds to `0.0.0.0:3000` by default so a physical Android device can reach it over the LAN. Check the active host address with `ipconfig`, then configure Flutter with `--dart-define=BACKEND_BASE_URL=http://<host-lan-ip>:3000`. Allow inbound TCP 3000 through Windows Firewall on the active network profile (the diagnosed host is currently Public).
