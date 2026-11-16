This repository contains content licensed under two different licenses.

## Documentation and results

All documentation, study write-ups and result tables are licensed under the Creative
Commons Attribution 4.0 International License (CC BY 4.0). This includes, but is not
limited to:
- Markdown files (`.md`)
- Image files (`.png`, `.svg`, etc.)

A full copy of this license is available in the [`LICENSES/CC-BY-4.0.txt`](CC-BY-4.0.txt) file.

Markdown files carry an SPDX header identifying the copyright holder and license:

```
SPDX-FileCopyrightText: <year> CBC/Radio-Canada
SPDX-License-Identifier: CC-BY-4.0
```

## Code and configuration files

All code and configuration files are licensed under the Apache License, Version 2.0. This
includes, but is not limited to:
- Scripts in any language (`.py`, `.sh`, ...)
- YAML files (`.yml`)
- JSON files (`.json`)
- Git configuration files (`.gitignore`)

A full copy of this license is available in the [`LICENSES/Apache-2.0.txt`](Apache-2.0.txt) file.

Code and configuration files carry an SPDX header:

```
SPDX-FileCopyrightText: <year> CBC/Radio-Canada
SPDX-License-Identifier: Apache-2.0
```

Files that cannot carry comments (e.g. `.json` files) do not have a header and are covered
by the statements in this document.

## Presentation slides

Slide decks in a study's `slides/` folder are published as presented, and carry their own licence notice at the
top of the file. They are the exception to the two sections above:

- [`studies/network-transport/2026-10-rdma-grain-transit/slides/wabe-2026-from-memory-to-fabric.html`](../studies/network-transport/2026-10-rdma-grain-transit/slides/wabe-2026-from-memory-to-fabric.html)
  - Presentation content © 2026 CBC/Radio-Canada, licensed under
    [CC BY-ND 4.0](https://creativecommons.org/licenses/by-nd/4.0/): you may redistribute it unmodified, with
    credit.
  - Slide engine (CSS, JavaScript, templates) © 2026 CBC/Radio-Canada, licensed under Apache 2.0
    ([`Apache-2.0.txt`](Apache-2.0.txt)).
  - Embedded third-party components: the Radio Canada typeface, © 2017 The Radio-Canada Project Authors,
    [SIL Open Font License 1.1](https://scripts.sil.org/OFL); [Lucide](https://lucide.dev) icons, MIT License.
  - The CBC/Radio-Canada and Technology & Infrastructure logos in the deck are registered trademarks. Neither
    licence grants any right to use them.
