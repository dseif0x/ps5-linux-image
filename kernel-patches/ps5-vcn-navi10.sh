#!/bin/bash
# Builds a PS5 VCN firmware from AMD's current Navi10 VCN firmware.
#
# ps5-linux-patches' firmware/amdgpu/ps5_vcn.bin is linux-firmware's
# navi10_vcn.bin 0x08118009 (commit 7b7e771f) with two conditional
# branches turned into nops plus the header CRC. This applies the same
# two patches to navi10_vcn.bin 0x08118012 (commit a97e3b5d), where the
# code is unchanged apart from moving (checked by disassembly):
#   0xfeb5   beqz a14  (16 fe 0e) -> nop   (f0 20 00)
#   0x10aff  beqz.n a8 (8c 28)    -> nop.n (3d f0)
#   0x1c     CRC32 of the ucode   -> recomputed (fixed, input is pinned)
#
# Usage: ps5-vcn-navi10.sh <output ps5_vcn.bin>
set -euo pipefail

out=$1
url=https://gitlab.com/kernel-firmware/linux-firmware/-/raw/a97e3b5db17e373db36f34546e3d61af293ac790/amdgpu/navi10_vcn.bin
src_sha=20cda63482852a8b58e63077fd48a500130642b09a2e0829e1c6edba29ae539b
out_sha=f0181c51089a56b1076dd42fc59f51150e5d8ca82dffca3d31d006acd3256229

sha256() { if command -v sha256sum >/dev/null; then sha256sum "$1"; else shasum -a 256 "$1"; fi | cut -d' ' -f1; }
patch_at() { printf "$2" | dd of="$tmp" bs=1 seek=$(($1)) conv=notrunc 2>/dev/null; }

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
curl -fsSL -o "$tmp" "$url"
[ "$(sha256 "$tmp")" = "$src_sha" ] || { echo "navi10_vcn.bin: unexpected checksum" >&2; exit 1; }

patch_at 0x1c    '\107\045\154\356'   # CRC 0xee6c2547
patch_at 0xfeb5  '\360\040\000'       # nop
patch_at 0x10aff '\075\360'            # nop.n

[ "$(sha256 "$tmp")" = "$out_sha" ] || { echo "patched firmware: unexpected checksum" >&2; exit 1; }
cp "$tmp" "$out"
echo "PS5 VCN firmware: navi10 0x08118012 + PS5 patches -> $out"
