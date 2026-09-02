# EduVaani architecture

Teacher Hindi speech
-> local recorder
-> ASR service
-> Hindi text
-> translation service
-> Santali text
-> TTS service
-> local audio playback

Flutter uses SQLite for normal offline teaching. Optional synchronization uses Express and MySQL only after an explicit user action while online. The current demo uses mock adapters; the same interfaces accept on-device ONNX adapters once approved model files are present.
