# lib/features/ai/services/ai_source_backend.dart

## AI sources and WebDAV privacy

MyApps-AI v0.6.0 adds `myapps_ai_sources`: `createAiSourceRouter` returns the shared `AiSourceRouter`, which replaces the app's own `AiSourceBackend`. The shared source section offers the source picker, the local models entry and a GPU switch for local models (shown where the GPU is verified); MyDevice has no online sources. Global source selection stays device-local (`aiSourceSelection`), defaults to system AI, and never chooses online as fallback. The router also writes the device-local keys `aiComputePreference`, `aiGpuFailures`, `aiCustomModels` and `aiModelAliases`, which are never synced and never in backups. Local models (Qwen3.5 0.8B/2B Q4_K_M, Gemma 4 E2B Q4_0) show friendly names from the router such as `Qwen: Qwen3.5 0.8B (Q4_K_M)` and can be renamed; a custom GGUF model can be added from a Hugging Face repository after a mandatory warning. They run on the CPU unless the GPU switch is turned on. Downloads require explicit actions, use pinned URLs and SHA-256, and live under `ai_models/` outside data modules, sync, backup and ZIP. Model leases prevent removal during use. Source switches cancel old work and release model resources. Technical details in the AI settings use `MyAppsAiDiagnosticsView` over `router.diagnostics()`: every included backend (app and platform, selection, system AI, llama.cpp library and devices, each local model), copyable. System proofreading remains independent in MyNihongo.

WebDAV notice version 1 must be acknowledged on each device before connection testing, manual/force sync or background sync. The record is in device-local storage_config.json. Existing configurations stay intact while sync is paused; the WebDAV page displays a review banner. Declining saves no configuration and makes no request. JSON/images have no application-level encryption; HTTPS protects transit, HTTP does not. Wire format, locks and conflict policy remain unchanged.

## Declarations

| Declaration | Purpose |
|---|---|
| `AiSourceRouter createAiSourceRouter({StorageAdapter? storage, CapabilityGenAiBackend? system})` | Create the app's AI source router over MyDevice storage; model files live in `<app dir>/ai_models`, choices stay device-local, no online sources. Inputs: optional storage/system for tests. Returns: Router. |
