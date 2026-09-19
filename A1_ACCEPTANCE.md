# A1 Acceptance Gate

Status: **FECHADO COM RESSALVA.** A implementação A1 está aceite para avançar para A2. A validação em gamepad físico fica obrigatoriamente aberta em `BL-001` e tem de ser concluída antes de qualquer release pública.

## Estado do gate

- Implementação: ✅
- Export Web real: ✅
- Single-threaded: ✅
- Sem COOP/COEP: ✅
- Desktop live HTTPS: ✅
- Telefone físico: ✅
- Gamepad físico: ⏸️ **DIFERIDO — BL-001**

O código de gamepad está implementado, cobre deteção/hot-swap, prompts e ações via InputMap, e foi validado por testes automatizados/emulação. Falta apenas confirmação com hardware físico real.

## Teste A — telefone físico

**Resultado reportado pelo utilizador: PASS em toda a linha.**

- Phone: **modelo não fornecido**
- OS/version: **Android — versão não fornecida**
- Browser/version: **não fornecido**
- Boot: **PASS**
- Touch controls auto-visible: **PASS**
- Runtime: Web: **PASS**
- Touch capability: true: **PASS**
- First-touch Audio unlocked false -> true: **PASS**
- D-pad movement + Actions [X]: **PASS**
- A/B/PAUSE/BACK counters: **PASS**
- Fullscreen: **PASS**
- Portrait responsive: **PASS**
- Landscape responsive: **PASS**
- Notes: **tudo funcionou à primeira; áudio desbloqueou ao toque em A.**

Este resultado é aceite como evidência do teste físico A. Os campos de modelo/versão ficaram registados como não fornecidos; não foram inferidos.

## Evidência automatizada final

Public build:

https://alexandresalazar89-blip.github.io/GameZone/

A1 final candidate:

`a469454e6aa2ca1e5edaf49e24e31566a05ecc8a`

GitHub Actions:

https://github.com/alexandresalazar89-blip/GameZone/actions/runs/35446087718

Resultados:

- Godot 4.7.2-stable official
- Export Web: **PASS**
- `Emscripten 4.0.20, single-threaded`
- `[A1] A1_BOOT_OK` no site Pages live
- `index.html`: **HTTP 200 / HTTPS**
- `index.pck`: **HTTP 200 / HTTPS**
- `index.wasm`: **HTTP 200 / HTTPS**
- COOP: **ausente**
- COEP: **ausente**
- Desktop Chromium live: **PASS**

## Gamepad físico — diferido

Ver `BACKLOG.md`:

`BL-001 — Gamepad físico: hot-swap connect/disconnect, deteção, prompts e ações mapeadas.`

O guião permanece em `A1_MANUAL_TEST.md` (Teste B). Este item não é FAIL e não deve ser apagado, contornado ou marcado como concluído sem teste em hardware real.

## Gate rule

A1 está **fechado-com-ressalva** exclusivamente para permitir o avanço técnico para A2.

**BL-001 continua a bloquear qualquer release pública final.**
