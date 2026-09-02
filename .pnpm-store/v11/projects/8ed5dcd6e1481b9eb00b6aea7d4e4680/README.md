# EduVaani Backend

Optional online synchronization backend for EduVaani. The Flutter app does not require this server during classroom use.

## Run

1. Copy `.env.example` to `.env`.
2. Run `npm install`.
3. Run `npm start`.

Available endpoints include `/api/health`, `/api/lessons`, `/api/translations`, `/api/sync`, and `/api/progress`. This Phase 14 version uses in-memory prototype data. MySQL storage is added in Phase 15.
