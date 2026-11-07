# Graph Report - Acesso remoto  (2026-11-06)

## Corpus Check
- Corpus is ~4,224 words - fits in a single context window. You may not need a graph.

## Summary
- 41 nodes · 49 edges · 6 communities (5 shown, 1 thin omitted)
- Extraction: 86% EXTRACTED · 12% INFERRED · 2% AMBIGUOUS · INFERRED: 6 edges (avg confidence: 0.87)
- Token cost: 105,456 input · 0 output

## Community Hubs (Navigation)
- Conectividade remota e hospedagem
- Host Windows (fork Sunshine)
- App Android e entrada
- Spec, metas e fases
- Presença, WoL e servidor
- Atualização automática

## God Nodes (most connected - your core abstractions)
1. `Gabs Remote Design Spec` - 7 edges
2. `H1 Host Core (Sunshine fork, C++)` - 6 edges
3. `Hosting Verification Report (resposta servidor)` - 5 edges
4. `Verdict: shared hosting cannot run signaling + TURN; VPS (KVM 1) or managed TURN needed` - 4 edges
5. `LizardByte/Sunshine (upstream host)` - 4 edges
6. `Hosting presence page (PC location, WoL queue, HTTPS/PHP only)` - 4 edges
7. `Inbound TCP/UDP Ports Blocked by Hostinger Firewall` - 3 edges
8. `Success Criteria (latency, image, resolution, input, media, availability, update)` - 3 edges
9. `Fork Sunshine + moonlight-android Approach` - 3 edges
10. `moonlight-stream/moonlight-android (upstream app)` - 3 edges

## Surprising Connections (you probably didn't know these)
- `Auto-update via GitHub Releases with Ed25519-signed manifest.json` --conceptually_related_to--> `Vagabs Node process kept alive by vigia.sh`  [AMBIGUOUS]
  docs/superpowers/specs/2026-11-06-gabs-remote-design.md → docs/resposta servidor.md
- `Hosting Verification Report (resposta servidor)` --references--> `Hosting Capability Questionnaire (prompt-servidor)`  [INFERRED]
  docs/resposta servidor.md → docs/prompt-servidor.md
- `Gabs Remote Design Spec` --cites--> `Hosting Verification Report (resposta servidor)`  [EXTRACTED]
  docs/superpowers/specs/2026-11-06-gabs-remote-design.md → docs/resposta servidor.md
- `Inbound TCP/UDP Ports Blocked by Hostinger Firewall` --rationale_for--> `Tailscale as default remote fallback (P2P + DERP)`  [INFERRED]
  docs/resposta servidor.md → docs/superpowers/specs/2026-11-06-gabs-remote-design.md
- `Hosting presence page (PC location, WoL queue, HTTPS/PHP only)` --shares_data_with--> `Hostinger-managed DNS with free subdomains`  [INFERRED]
  docs/superpowers/specs/2026-11-06-gabs-remote-design.md → docs/resposta servidor.md

## Hyperedges (group relationships)
- **Gabs Remote host-side components (H1-H7)** — docs_superpowers_specs_2026_11_06_gabs_remote_design_h1_host_core, docs_superpowers_specs_2026_11_06_gabs_remote_design_h2_virtual_display, docs_superpowers_specs_2026_11_06_gabs_remote_design_h3_virtual_microphone, docs_superpowers_specs_2026_11_06_gabs_remote_design_h4_virtual_webcam, docs_superpowers_specs_2026_11_06_gabs_remote_design_h5_data_channel, docs_superpowers_specs_2026_11_06_gabs_remote_design_h6_tray_panel, docs_superpowers_specs_2026_11_06_gabs_remote_design_h7_host_updater [EXTRACTED 1.00]
- **Gabs Remote Android app components (A1-A5)** — docs_superpowers_specs_2026_11_06_gabs_remote_design_a1_app_core, docs_superpowers_specs_2026_11_06_gabs_remote_design_a2_advanced_input, docs_superpowers_specs_2026_11_06_gabs_remote_design_a3_media_uplink, docs_superpowers_specs_2026_11_06_gabs_remote_design_a4_wol_discovery, docs_superpowers_specs_2026_11_06_gabs_remote_design_a5_app_updater [EXTRACTED 1.00]
- **Hosting investigation driving remote-connectivity design** — docs_prompt_servidor_hosting_capability_questionnaire, docs_resposta_servidor_hosting_verification_report, docs_resposta_servidor_verdict_no_signaling_turn, docs_superpowers_specs_2026_11_06_gabs_remote_design_n1_remote_connectivity, docs_superpowers_specs_2026_11_06_gabs_remote_design_tailscale_fallback [INFERRED 0.85]

## Communities (6 total, 1 thin omitted)

### Community 0 - "Conectividade remota e hospedagem"
Cohesion: 0.31
Nodes (8): Hosting Capability Questionnaire (prompt-servidor), Signaling (WebSocket) + TURN/UDP Relay Feasibility Question, Hosting Verification Report (resposta servidor), Hostinger Premium Shared Hosting (hPanel, CloudLinux LVE), Inbound TCP/UDP Ports Blocked by Hostinger Firewall, N1 Remote Connectivity (IPv6 / port forward / Tailscale / own relay), Risks and Open Decisions (CGNAT, driver signing, 4:4:4, upstream divergence), Tailscale as default remote fallback (P2P + DERP)

### Community 1 - "Host Windows (fork Sunshine)"
Cohesion: 0.25
Nodes (9): Apollo fork (virtual display per client, clipboard sync), Foundation/AlkaidLab Sunshine (client microphone protocol), H1 Host Core (Sunshine fork, C++), H2 Virtual Display (IddCx driver), H3 Virtual Microphone driver, H5 Data Channel (clipboard, files, commands, app profiles), H6 Tray + Web Panel, LizardByte/Sunshine (upstream host) (+1 more)

### Community 2 - "App Android e entrada"
Cohesion: 0.25
Nodes (7): A1 App Core (moonlight-android fork), A2 Advanced Input (S Pen, touch modes, keyboard), A3 Media Uplink (mic Opus, camera H.264), Artemis (Android fork of Apollo client), H4 Virtual Webcam (DirectShow), libvirtualhid (keyboard, mouse, touch, pen, gamepad), moonlight-stream/moonlight-android (upstream app)

### Community 3 - "Spec, metas e fases"
Cohesion: 0.29
Nodes (7): Gabs Remote Design Spec, Google Remote Desktop (baseline to beat), Graphify project graph (graphify-out/), Latency Meter (timestamp overlay, click-to-photon), Delivery Phases 1-8, Security: PIN pairing, certificates, optional 2FA, auto-lock, Success Criteria (latency, image, resolution, input, media, availability, update)

### Community 4 - "Presença, WoL e servidor"
Cohesion: 0.40
Nodes (5): Existing services on server (site, /mcp connector, Claude executor queue, email), Hostinger-managed DNS with free subdomains, Vagabs Node process kept alive by vigia.sh, A4 Wake-on-LAN + mDNS Discovery, Hosting presence page (PC location, WoL queue, HTTPS/PHP only)

## Ambiguous Edges - Review These
- `Vagabs Node process kept alive by vigia.sh` → `Auto-update via GitHub Releases with Ed25519-signed manifest.json`  [AMBIGUOUS]
  docs/superpowers/specs/2026-11-06-gabs-remote-design.md · relation: conceptually_related_to

## Knowledge Gaps
- **11 isolated node(s):** `Artemis (Android fork of Apollo client)`, `H4 Virtual Webcam (DirectShow)`, `H5 Data Channel (clipboard, files, commands, app profiles)`, `H6 Tray + Web Panel`, `A4 Wake-on-LAN + mDNS Discovery` (+6 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 11 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **1 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Gabs Remote Design Spec` connect `Spec, metas e fases` to `Conectividade remota e hospedagem`, `App Android e entrada`?**
  _High betweenness centrality (0.653) - this node is a cross-community bridge._
- **What connects `Artemis (Android fork of Apollo client)`, `H4 Virtual Webcam (DirectShow)`, `H5 Data Channel (clipboard, files, commands, app profiles)` to the rest of the system?**
  _11 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Why does `Fork Sunshine + moonlight-android Approach` connect `App Android e entrada` to `Host Windows (fork Sunshine)`, `Spec, metas e fases`?**
  _High betweenness centrality (0.515) - this node is a cross-community bridge._
- **Why does `Hosting Verification Report (resposta servidor)` connect `Conectividade remota e hospedagem` to `Spec, metas e fases`, `Presença, WoL e servidor`?**
  _High betweenness centrality (0.432) - this node is a cross-community bridge._

### Low-confidence Hints
_AMBIGUOUS edges — the extractor was unsure. Verify before acting on these._

- **What is the exact relationship between `Vagabs Node process kept alive by vigia.sh` and `Auto-update via GitHub Releases with Ed25519-signed manifest.json`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._