#!/usr/bin/env python3
import pathlib
import sys

cfg = pathlib.Path(sys.argv[1])
text = cfg.read_text(encoding="utf-8")

# The fragment is kept in the repository as the auditable contract.
fragment = pathlib.Path("config/pcp-squashfs-boot.fragment").read_text(
    encoding="utf-8"
)

# Kconfig accepts a complete .config with the required values overridden
# before olddefconfig.  Remove existing assignments for symbols we override
# so the final file has one authoritative assignment per symbol.
symbols = []
for line in fragment.splitlines():
    if line.startswith("CONFIG_"):
        symbols.append(line.split("=", 1)[0])

lines = text.splitlines()
filtered = []
symbol_set = set(symbols)

for line in lines:
    if line.startswith("CONFIG_"):
        name = line.split("=", 1)[0]
        if name in symbol_set:
            continue
    elif line.startswith("# CONFIG_") and line.endswith(" is not set"):
        name = line[2:-len(" is not set")]
        if name in symbol_set:
            continue
    filtered.append(line)

filtered.extend(["", "# pCP-N1 SquashFS boot overrides"])
filtered.extend(fragment.splitlines())
cfg.write_text("\n".join(filtered) + "\n", encoding="utf-8")
print(f"Prepared {cfg} with {len(symbols)} explicit overrides.")
