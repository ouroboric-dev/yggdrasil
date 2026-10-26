---
title: Delta for the brand tools spike findings
status: draft
date: 2026-10-27
related: [proposal.md, tasks.md, ../../specs/2026-10-26-brand-tools.md]
style: spec
---

# Delta: brand tools spec §5.3, §5.4, §8, §13

## Modified

- §5.3, **detail** (was: after the differing pixels within 2 pixels of an edge are removed with a 5 by 5 minimum
  filter, differing pixels MUST NOT remain): the number of separate shapes and the number of holes MUST be the same
  in her PNG and in the render. Each is counted on the alpha mask (alpha 128 or more is opaque) as 4-connected
  regions of at least 4 pixels. A hole is a transparent region that does not touch the image's border.
- §5.3, the gap image `trace-<mode>.png` also marks each shape or hole that is in one image and not in the other.
- §5.4, **type:** a role whose files are WOFF or WOFF2 is converted to TTF with fontTools, in a temporary folder,
  before resvg renders its specimen. The tools still MUST NOT change a font file (5.2.9).
- §8, `brand.test.sh` fixtures: "a mark with a 3-pixel dot that `filter_speckle` drops" becomes "a ring 2 pixels wide
  that the trace breaks apart (a gap)", and "a 2 by 2 dot and a 2 by 2 hole (faithful)" is added.

## Removed

- §13: "resvg's text rendering for the type specimens (`--use-font-file`), and which font formats it loads" and "The
  resvg binaries' SHA-256 values": verified by BT-T01.
