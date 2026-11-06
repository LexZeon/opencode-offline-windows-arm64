# Windows ARM64 verification

Observed on Windows 11 ARM64. Device identifiers, local paths, account details, timestamps and raw logs are intentionally excluded.

## Source and build

- Upstream community fork: <https://github.com/Chetic/opencode-offline>
- Pinned commit: `bcdbd58d57c1c38b13b3f9a3d8b423786f0e1d85`.
- Build runtime: official Bun **1.4.4**, Windows ARM64.
- The CLI executable and the local ripgrep executable both have PE machine type **0xAA64**.
- WSL and x64 emulation were not needed for the completed Windows build.
- The public PowerShell recipe was rerun successfully from a new empty directory after the image-input update, including a fresh pinned checkout, source patch application, a new dependency cache, frozen dependency installation with the nested dependency patch, native CLI build and web build. That check reused the already SHA256-verified official Bun archive through `-BunArchivePath`.
- The updated community source was also fully compiled and tested separately. The build procedure is unchanged; the script pins the current source patch by SHA256. Building does not start the application or load a model.
- The subsequent Windows clipboard/path update passed typechecking and focused tests, and both native CLI and web assets were rebuilt using the existing verified dependency installation. A second fresh dependency bootstrap is not claimed for that update. The final source patch is reapplied against the pinned base and compared with the latest successfully built runtime source.

Bun 1.3.10 could compile the CLI but failed to initialize the terminal renderer: Windows ARM64 FFI was unavailable. Bun 1.4.4 passed actual DLL, pointer and numeric FFI checks, and the compiled terminal interface rendered successfully. Use the version pinned by the build script.

## Observed application checks

- Native terminal interface rendered the selected local model and a connected local file MCP server, and exited cleanly.
- Compiled application started on a random loopback port and parsed its configuration successfully.
- Local bundled web HTML was served successfully with the offline Content Security Policy.
- A local file MCP server connected. A local model actually read a synthetic file and returned its random marker.
- An exact text replacement remained pending until approval, then changed only the intended content.
- File creation remained pending until approval, then created only the requested file.
- For the two guarded file MCP tools, an `Always` response was treated as a single approval. A subsequent creation requested approval again; rejection left its target absent.
- Both the actual application test and its model backend used rejecting outbound proxies. No external proxy attempts were observed.
- Direct tests of the JavaScript fetch guard passed **35/35**, including local API requests, supported local data resources, process-registered Blob resources, malicious hostnames, unregistered Blob URLs, UNC/file URL rejection and redirect handling.

The real-model check used a private test manifest with **8,192 context tokens and 24 GPU layers**, sharing already installed weights through NTFS hard links. It did not alter the production model manifest, stop other applications or download weights. This is a functional agent check, not a performance benchmark or validation of a model's maximum context.

## Image-input update

- **47 targeted community tests passed**, covering the image/offline changes and their error paths.
- **Eight concurrent requests against the compiled local API passed**: four valid and four invalid inputs, with accepted normalization and rejected-input responses checked.
- AVIF input is decoded and normalized locally to supported PNG/JPEG before it reaches the model. PNG input remains supported.
- Invalid image data, MIME mismatches and dimensions outside the allowed bounds are rejected with readable, safe HTTP 400 responses.
- The TUI includes failed-draft restoration. Backend rejection and subsequent-request recovery were exercised; the TUI restoration branch was reviewed in source, not separately tested through the UI.
- Supported local `data:` resources and Blob URLs registered by the current process are treated as local resources. This does not permit external hosts, UNC paths, arbitrary file URLs, unregistered Blob URLs or external redirects.
- The compiled image-to-model path passed actual AVIF and PNG checks using an existing local backend at **131,072 context tokens**. These image checks are separate from the earlier 8,192-token file-permission checks.
- The two AVIF fixtures came from the public [libavif project at the pinned commit](https://github.com/AOMediaCodec/libavif/tree/e760e8f05375cbd0c6d72065b18cac4542b13092/tests/data); their bytes were independently checked against that source. Other PNG/JPEG test cases use inline or generated synthetic data. No user images, encoded user-image data or raw reports are distributed here.

## Windows clipboard and local-path update

- The opencode typecheck and **41 image tests / 106 assertions passed**, including 33 focused clipboard, path and keybinding tests. The source offline guard again passed **35/35**, with zero redirect-destination requests.
- Clipboard serialization accepts Explorer file lists (`CF_HDROP`, at most 16 files) and PNG bitmap data. Matching quoted local paths support spaces and Unicode names. Ordinary clipboard text remains text; invalid attachments produce readable errors.
- Windows defaults include Ctrl+V and Alt+V. The normal prompt has a clickable **Alt+V paste image** action because terminal hosts may consume Ctrl+V before the application receives it. No global terminal configuration change is required.
- Native PowerShell UTF-8 round-trip of a synthetic Unicode path passed. A resident public AVIF fixture passed the real Windows metadata gate and was normalized to PNG. These checks did not access or change the system clipboard.
- Separate controlled native clipboard checks passed the three input forms: Explorer-style AVIF file list with Unicode/spaces, PNG bitmap, and quoted text path. The prior clipboard data was restored; only public/synthetic fixture results are described here. This does not test a physical drag gesture or terminal delivery of Alt+V.
- Windows helpers run hidden in STA mode with timeouts and bounded output. Files are read with a 64 MiB limit after local fixed-drive, canonical-path and resident-file checks. UNC/device paths, mapped network drives, remote URLs, true links and online-only Cloud Files are refused before content reads.
- Native ARM64 CLI and web builds passed with Bun 1.4.4. Physical dragging and dropping into a user terminal was not automated in this test set; transport and keyboard interception depend on the terminal host.

## Limits

- This repository distributes adaptation source and build instructions. Models, personal profiles, chat databases, raw logs and screenshots are excluded.
- The application fetch guard is not a Windows firewall or an OS process sandbox. It does not intercept arbitrary raw sockets or unrelated child programs.
- Offline mode suppresses extra remote terminal syntax-parser registration. Built-in local parsers remain available.
- The tested personal setup disabled LSP downloads and external plugins. A full Windows ARM64 bundle of C++, Rust, Python and TypeScript language servers was not validated.
- The precise repeated-approval patch applies to `spark_files_replace_text` and `spark_files_create_file`. Other tool permissions must be configured deliberately; the upstream default agent is not equivalent to the tested restricted file agent.
- Image normalization and the tested model responses do not establish support for every codec, animation, metadata field, image size or model. Readable rejection and recovery are part of the supported behavior.
- A fully disconnected network adapter and an end-to-end browser asset audit were not tested. The compiled local web endpoint, CSP and observed proxy behavior were checked separately.

See the public patch for the exact changes. Do not interpret a successful build as proof that every upstream feature or arbitrary model/tool combination has been tested.
