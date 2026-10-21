# Shrike Projects

**Things people have built with [Shrike](https://github.com/vicharak-in/shrike).**

This is the showcase repo for the Shrike FPGA boards (Renesas SLG47910
ForgeFPGA + RP2040 / RP2350 / ESP32-S3): complete applications, demos, and
experiments built by the community. 

Looking to *learn* FPGAs instead? Start with the curated
[teaching examples](https://github.com/vicharak-in/shrike/tree/main/examples)
in the main repo.

This repo is where you go once you want to see what the board can really do ,
and to add what *you* built.

---

**FPGA ✅** = uses the ForgeFPGA fabric. **-** = firmware-only. Both are
welcome here: if it runs on a Shrike board, it belongs.


---

## 100 Days of Shrike

[Drik Paul](https://github.com/drik245) has created a very comprehensive repo for 100 days of shrike project and he is actively workign on it.
Check it out [here](https://github.com/drik245/v4k_shrike).


## Repo layout

```
projects/
└── <project_name>/            lowercase_snake_case
    ├── README.md              what it does, how to run it, wiring, demo
    ├── project.yaml            metadata: author, boards, uses_fpga, tags
    ├── ffpga/src/*.v           RTL             (omit if firmware-only)
    ├── <project_name>.ffpga    Go Configure project
    ├── bitstream/              prebuilt .bin
    ├── firmware/               micropython/ · arduino-ide/ · esp-idf/ …
    ├── host/                   PC-side tools (GUIs, senders, verifiers)
    ├── hardware/               wiring diagrams, external circuits
    └── media/                  images < 200 KB , videos as links, never files
```

Same per-project conventions as the main repo's examples, plus `host/` and
`hardware/` since real projects tend to need them.

## Running a project

Each project's README is self-contained, but the common flow is:

1. Flash the prebuilt bitstream from `bitstream/` using
   [ShrikeFlash](https://vicharak-in.github.io/shrike/getting_started.html)
   (skip for firmware-only projects).
2. Load the firmware from `firmware/` for your board variant
   (MicroPython via `mpremote`, or Arduino IDE , see the
   [getting-started guide](https://vicharak-in.github.io/shrike/getting_started.html)).
3. If there's a `host/` folder, run the PC-side tool per the project README.

Board compatibility is listed per project , bitstreams are identical across
Shrike variants; firmware may be MCU-specific (RP2040 vs RP2350 vs ESP32-S3).

## Contributing your project

Built something on a Shrike? We want it here , polished or not.

1. Check it's a *project*, not a teaching *example* , see the
   [classification criteria](https://github.com/vicharak-in/shrike/blob/main/EXAMPLE_OR_PROJECT.md).
   (Rule of thumb: examples teach one concept; projects show what the board
   can do. When unsure, it goes here.)
2. Copy the layout above (or an existing project), name your folder in
   `lowercase_snake_case`, and fill in a README that lets a stranger
   reproduce your build.
3. Keep the repo light: compress images to < 200 KB; for video, drag the
   file into a GitHub comment/README on the web editor and link the
   generated `user-attachments` URL instead of committing it.
4. Open a PR. Review here checks that it works and is documented , not that
   it's minimal. Creative scope is unlimited.
5. Complete Contribution guide is available here [Contribution Guide](https://github.com/vicharak-in/shrike/blob/main/CONTRIBUTING.md).

Your commits keep your name , that's the whole point of this repo.

## Related

- **[shrike](https://github.com/vicharak-in/shrike)** -- the boards, docs, and teaching examples
- **[Vicharak store](https://store.vicharak.in)**     -- get the hardware.
- **[Discord](https://discord.com/invite/EhQy97CQ9G)** -- questions, help, show-and-tell

## License

Code: [GPL-2.0](./LICENSE.md) · Hardware designs: [CERN-OHL](./LICENSE_HW.md).
Individual projects will be under the same licenses as the repository until mentioned otherwise.
