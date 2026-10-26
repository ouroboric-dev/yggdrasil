---
title: Brand tools spike findings
status: draft
date: 2026-10-27
related: [delta.md, tasks.md, ../../specs/2026-10-26-brand-tools.md, ../../plans/2026-10-27-brand-tools/tasks.md]
style: spec
---

# Change proposal: brand tools spike findings

## Why

Task BT-T01 of the brand tools plan checked the facts the spec marked as not verified (§13). Two differ from the
spec.

1. **The detail limit cannot see small losses.** §5.3 removes the differing pixels within 2 pixels of an edge with a
   5 by 5 minimum filter, then requires that none remain. A lost detail smaller than 5 by 5 pixels leaves nothing
   after the filter, so the limit passes. VTracer 0.6.15 with the fixed settings keeps dots and holes down to 2 by 2
   pixels, so the spec's fixture ("a 3-pixel dot that `filter_speckle` drops") is not a gap: the dot survives.
   What VTracer does lose is thin strokes: a ring 2 pixels wide, on a 1200-pixel fixture, traced into 5 separate
   shapes instead of 1. Counting shapes and holes catches that, and every other case the spike drew.
2. **resvg loads TTF and OTF, not WOFF2.** With `--skip-system-fonts --use-font-file`, resvg 0.48.1 renders text from
   a TTF and fails to load the same font as WOFF2 ("Failed to load a font face"). fontTools, already a dependency,
   converts WOFF and WOFF2 to TTF.

## What the spike confirmed

- The SHA-256 values of the resvg 0.48.1 binaries for `linux-x86_64`, `macos-aarch64` and `macos-x86_64` match the
  digests GitHub publishes for the release assets. They are in Asgard's `scripts/brand/resvg.lock`.
- VTracer 0.6.15, Pillow 12.3.0, fontTools 4.66.1 and Brotli 1.2.0 install from wheels on Python 3.11 and 3.14.
- A two-colour mark traces faithfully: 0.25% shape mismatch, colours exact, and only `svg` and `path` elements.

## What changes

- §5.3 **detail:** the number of separate shapes and the number of holes, each counted on the alpha mask with
  4-connected regions of at least 4 pixels, MUST be the same in her PNG and in the render.
- §8: the lost-detail fixture is a ring 2 pixels wide that breaks apart; small dots and holes are fixtures that stay
  faithful.
- §5.4 **type:** the board converts a WOFF or WOFF2 font to TTF with fontTools before resvg renders the specimen.
- §13: the resvg and wheel items are verified; GitHub's file view of the board's images stays to check.

## Not changed

The shape and colour limits, the VTracer settings and every other criterion.
