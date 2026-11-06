# Windows ARM64 verification

Observed on Windows 11 ARM64. Device identifiers, local paths, account details, timestamps and raw logs are intentionally excluded.

## Source and build

- Upstream community fork: <https://github.com/Chetic/opencode-offline>
- Pinned commit: `bcdbd58d57c1c38b13b3f9a3d8b423786f0e1d85`.
- Local build identifier: `1.2.13-spark-offline.1`.
- Build runtime: official Bun **1.4.4**, Windows ARM64.
- The CLI executable and the local ripgrep executable both have PE machine type **0xAA64**.
- WSL and x64 emulation were not needed for the completed Windows build.
- The public PowerShell recipe was rerun successfully from a new empty directory, including a fresh pinned checkout, patch application, frozen dependency installation, native CLI build and web build. That check reused the already SHA256-verified official Bun archive through `-BunArchivePath`.

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
- Direct tests of the JavaScript fetch guard passed **26/26**, including local API requests, embedded WASM data, malicious hostnames, UNC/file URL rejection and redirect handling.

The real-model check used a private test manifest with **8,192 context tokens and 24 GPU layers**, sharing already installed weights through NTFS hard links. It did not alter the production model manifest, stop other applications or download weights. This is a functional agent check, not a performance benchmark or validation of a model's maximum context.

## Limits

- This repository distributes adaptation source and build instructions. Models, personal profiles, chat databases, raw logs and screenshots are excluded.
- The application fetch guard is not a Windows firewall or an OS process sandbox. It does not intercept arbitrary raw sockets or unrelated child programs.
- Offline mode suppresses extra remote terminal syntax-parser registration. Built-in local parsers remain available.
- The tested personal setup disabled LSP downloads and external plugins. A full Windows ARM64 bundle of C++, Rust, Python and TypeScript language servers was not validated.
- The precise repeated-approval patch applies to `spark_files_replace_text` and `spark_files_create_file`. Other tool permissions must be configured deliberately; the upstream default agent is not equivalent to the tested restricted file agent.
- A fully disconnected network adapter and an end-to-end browser asset audit were not tested. The compiled local web endpoint, CSP and observed proxy behavior were checked separately.

See the public patch for the exact changes. Do not interpret a successful build as proof that every upstream feature or arbitrary model/tool combination has been tested.
