# Layout model

This model describes a small layout algorithm inspired by [Clay](https://github.com/nicbarker/clay), by Nic Barker.
It uses Clay's main stages as a design reference.
It is original work and does not reproduce the full Clay implementation.

- [Layout.tla](Layout.tla) contains the model and properties.
- [Pseudocode.md](Pseudocode.md) describes sizing, layout, and command generation.
- [NOTICE.md](NOTICE.md) records attribution and source references.

## Scope

The model has six nodes in two trees.
The main tree contains a panel, a text node, and a fixed box.
The second tree represents a popup with a text child.
The roots have overlapping positions and independent z-index values.

The stages are width measurement, width allocation, word wrapping, height calculation, root ordering, and command generation.
TLC can select different valid node-processing orders within each stage.

The model includes these rules:

- Rows and columns, with padding and gaps.
- FIXED, FIT, GROW, and 50-percent widths.
- Greedy word wrapping, with words kept intact.
- Content heights and one fixed-height box.
- Root sorting by z-index, with declaration order for ties.
- Depth-first command generation and child positions.

Sizes are integers. Spaces and line heights are one unit.
Width distribution changes one unit at a time.
One model action completes width allocation for one container.
The completion property does not inspect each recursive balancing step separately.

## Checks

| Property | Required result |
| --- | --- |
| `TypeOK` | Geometry is nonnegative. Collections contain permitted nodes. |
| `WidthContracts` | Fixed and percent widths follow their rules. Flexible widths respect minima. |
| `FeasibleRowsFit` | A row fits when its required minimum width fits. |
| `GrowUsesSpace` | GROW children consume the available row space when the row can fit. |
| `TextPreserved` | Wrapping preserves every word in source order. |
| `ValidLines` | A line fits, unless one word is too wide. |
| `HeightContracts` | Parent heights include wrapped text and other child heights. |
| `DrawOrder` | Commands follow root z-order and subtree order. |
| `NoDuplicateDraws` | Each node appears at most once. |
| `PositionsCorrect` | Child positions follow their parent's direction, padding, gaps, and sibling sizes. |
| `CompleteFrame` | A completed frame contains every node exactly once. |
| `StageOrder` | Width calculation precedes wrapping. Height calculation precedes drawing. |
| `ExpectedGeometry` | Final geometry matches hand-calculated fixture results. |
| `Completes` | The layout eventually reaches the completed state. |

Completion assumes weak fairness for the next operation.
A continuously enabled operation must eventually occur.
This gives no elapsed-time guarantee.

## Scenes

| Scene | Difference | Text width | Main height |
| --- | --- | ---: | ---: |
| `Row` | Main children form a row. | 5 | 5 |
| `Column` | Main children form a column. | 8 | 7 |
| `Grow` | Flexible children use GROW. | 5 | 5 |
| `Percent` | The panel uses 50 percent of available width. | 4 | 5 |
| `Overflow` | The row is narrower than its required minimum width. | 4 | 5 |
| `Tie` | Equal root z-index values use reversed declaration order. | 5 | 5 |

Overflow is permitted when fixed sizes and minimum widths cannot fit.
The algorithm does not remove content to satisfy a fit check.
In the percent scene, seven available units give a three-unit panel after integer rounding.
The text child needs four units for its widest word, so it extends beyond that panel.

## Run

1. Open PowerShell in `specs/Layouting`.
2. Set `$tlaJar` to the location of `tla2tools.jar`.
3. Run the main configuration.

```powershell
java -Xmx1g -cp $tlaJar tlc2.TLC -config Layout.cfg Layout.tla
```

The main configuration selects all six scenes.
`LayoutRow.cfg` selects only the row scene.
Completed layouts are intentional terminal states, so deadlock checking is disabled.

The diagnostic module deliberately orders roots by declaration order alone.
It must fail `DrawOrder` when that order conflicts with z-index.
This is a test fault, not a reported defect in Clay.

```powershell
java -Xmx1g -cp $tlaJar tlc2.TLC -config LayoutWrongZ.cfg LayoutWrongZ.tla
```

In VS Code, open the module that matches the selected configuration.

## Results from 2026-10-28

TLC version `2026.10.28.014557` produced these results:

| Configuration | Result |
| --- | --- |
| `Layout.cfg` | Pass: 468 different states across all six scenes. All safety checks and completion hold. |
| `LayoutRow.cfg` | Pass: 78 different states for the row scene. |
| `LayoutWrongZ.cfg` | Expected `DrawOrder` failure. The faulty traversal emits the higher-z root first. |

These results apply to the finite fixtures and simplified rules in this model.
They do not establish correctness for all possible UI trees.

## Differences from Clay

This is a prototype of one simplified design.
It is not a proof of Clay or of a Zig UI implementation.
The input forest is fixed, acyclic, and valid.
The model does not include retained-tree updates or dirty-cache invalidation.

Omitted features include maximum-size limits, vertical GROW and PERCENT sizing, alignment options, and text shaping.
The model also omits aspect ratios, clipping, scrolling, animations, hit testing, and GPU behavior.
Floating roots use fixed positions instead of Clay's anchor calculation.
Layout runs over the whole forest for each frame.

See [Clay's source](https://github.com/nicbarker/clay/blob/main/clay.h) for its complete implementation.
