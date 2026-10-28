# Clay reference and attribution

The design reference is **Clay**, the C UI layout library by **Nic Barker**.
The source header reported version **0.14** when reviewed on **2026-10-28**.
These links refer to the main branch and can change.

- [Official repository and documentation](https://github.com/nicbarker/clay)
- [Implementation in clay.h](https://github.com/nicbarker/clay/blob/main/clay.h)
- [Original license](https://github.com/nicbarker/clay/blob/main/LICENSE.md)

Relevant functions are `Clay__SizeContainersAlongAxis` and `Clay__CalculateFinalLayout`.
The latter includes word wrapping, height propagation, root z-order, and render-command generation.
Clay uses the zlib/libpng license and credits Copyright (c) 2024 Nic Barker.

The TLA+ files and pseudocode here are original, simplified models inspired by these ideas.
They are not Clay source, a direct translation, or an official Clay specification.
They do not establish correctness or compatibility of the original library.
Keep the original license notice if Clay source is later copied into this project.
