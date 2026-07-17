# SwitchboardDemo

Minimal macOS chat app showing cloud and on-device inference behind one seam:

- [Switchboard](https://valni.ai) is unified inference with per-end-user metering, spend controls, and billing built in; one endpoint serves the whole model catalog with your account key.
- `SwitchboardLocal` runs open-weight MLX models on the Mac itself, with no key and no network after download.

One window: enter a key or load a local model, pick from the model picker, type, get a streamed reply. The same transcript can flip between a 1B model running on Apple Silicon and a frontier model mid-conversation.

## Anatomy

The source is split so you can tell the Switchboard setup from the demo around it:

| Folder | What it is |
|---|---|
| `Sources/SwitchboardDemo/SwitchboardIntegration/` | The Switchboard setup. `SwitchboardModelCatalog` (picker list from the API), `NativeChatBody` (builds the native `RouterBody` for the model's wire format: Anthropic Messages, OpenAI Responses, or OpenAI Chat Completions), `SwitchboardInference` (one `InferenceProvider` over the unified inference endpoint), `LocalModelStore` (on-device model lifecycle: add, download, persist, stream), `HybridServices` (composes cloud and local behind the app's two protocols), `DemoConfiguration` (base URL). Copy this folder as your starting point. |
| everything else | This demo's chat UI and state: views, view model, transcript types, and the two small protocols (`ModelCatalogProviding`, `ChatStreaming`) the UI consumes. |

The app talks to the integration layer only through those two protocols, wired once in `SwitchboardDemoApp`. One deliberate exception: the local-models section binds views directly to `LocalModel`, whose `@Published state` exists exactly for that purpose. Observing it for download progress is the intended SDK pattern, not a shortcut.

## Get a key

1. Sign in to the platform portal and open the **Switchboard** tab of your account.
2. Under API keys, name the key (for example `switchboard-demo`), leave the scope on **Company**, and mint.
3. Copy the plaintext `swb_...` from the modal. It is shown once and never again; only a hash is stored server-side.

If the mint is rejected, complete your account entity setup (company name and entity type) on the same tab first.

## Run

The package depends on sibling checkouts of the Switchboard SDK and its generated types package: clone [Switchboard](https://github.com/Valni-Labs/Switchboard) and [SwitchboardNative](https://github.com/Valni-Labs/SwitchboardNative) next to this repository so `../Switchboard` and `../SwitchboardNative` resolve.

```sh
swift run
```

Or open `Package.swift` in Xcode and run the `SwitchboardDemo` target. Keys are entered in the app window; local models work with no key at all.

First Xcode build only: the build stops with `Validate plug-in "CudaBuild" in package "mlx-swift"`. `mlx-swift` (pulled in by `SwitchboardLocal`) ships a build plugin that Xcode requires you to trust. Click the error in the Issue navigator, choose **Trust & Enable**, and build again. `swift run` and `swift build` are unaffected. Non-interactive `xcodebuild` invocations (CI, scripts) can pass `-skipPackagePluginValidation` instead; that flag bypasses Xcode's plugin trust check entirely, so reserve it for builds whose dependencies you control.

## Environment

| Variable | Required | Purpose |
|---|---|---|
| `SWITCHBOARD_BASE_URL` | No | Defaults to the production Switchboard endpoint. |

The `swb_` key is a server credential. This demo accepts it in the UI because it is a local development tool; do not ship a key inside a distributed client.

## Requirements

macOS 14+, Swift 6 toolchain. On-device models additionally require Apple Silicon.
