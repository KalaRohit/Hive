# Sizing and layout pseudocode

This is original pseudocode for [Layout.tla](Layout.tla).
It describes a simplified layout design inspired by Clay, by Nic Barker.
The reference is [Clay's source](https://github.com/nicbarker/clay/blob/main/clay.h), especially `Clay__CalculateFinalLayout` and `Clay__SizeContainersAlongAxis`.
The source header reported version 0.14 on 2026-10-28.
See [NOTICE.md](NOTICE.md) for attribution and [README.md](README.md) for model limits.

## Input rules

The input is an acyclic forest. Each child has one parent and a stable sibling position.
Roots have fixed widths and positions, plus independent z-index values.
Containers use rows or columns with padding and gaps.
Word widths, spaces, and line heights use integer units.
The model has four width modes and content-based heights.
PERCENT is 50 percent. One box has a fixed height of two units.

## Main stages

```text
LAYOUT(roots):
    visit nodes in child-before-parent order:
        MEASURE_WIDTH(node)

    set each root width from its fixed width
    visit containers in parent-before-child order:
        SIZE_CHILD_WIDTHS(container)

    for each text node:
        lines = WRAP_WORDS(words, assigned_width)

    visit nodes in child-before-parent order:
        if node is text:
            height = number of wrapped lines
        else if node is the fixed box:
            height = 2
        else if children form a row:
            height = maximum child height + vertical padding
        else:
            height = sum of child heights + gaps + vertical padding

    sort roots by ascending z-index
    keep declaration order for equal z-index values
    for each sorted root:
        EMIT_TREE(root, root_position)
```

The height stage propagates wrapped text height through its ancestors.
Clay includes further vertical sizing and aspect-ratio operations.
This model has no vertical GROW or PERCENT stage.

## Width measurement

```text
MEASURE_WIDTH(node):
    if width mode is FIXED:
        minimum = preferred = fixed width
    else if node is text:
        minimum = widest word
        preferred = sum of word widths + spaces
    else if children form a row:
        minimum = sum of child minima + gaps + horizontal padding
        preferred = sum of child preferred widths + gaps + horizontal padding
    else:
        minimum = largest child minimum + horizontal padding
        preferred = largest child preferred width + horizontal padding
```

The minimum width prevents word splitting.
Fixed and percent sizes can still be narrower than a word.
An oversized word can extend beyond its assigned rectangle.

## Width allocation

```text
SIZE_CHILD_WIDTHS(parent):
    inner = max(0, parent width - horizontal padding)
    available = inner
    if children form a row:
        available = max(0, inner - total child gaps)

    for each child:
        FIXED:   width = fixed width
        PERCENT: width = floor(available / 2)
        GROW:    width = minimum width
        FIT:     width = max(minimum width, min(preferred width, inner))

    if children form a row:
        while sum of child widths > available:
            candidates = FIT or GROW children above their minimum width
            if candidates are empty:
                stop shrinking; preserve the remaining overflow
            select the widest candidate; break ties by child order
            decrease its width by one unit

        while sum of child widths < available:
            candidates = GROW children
            if candidates are empty:
                stop growing
            select the narrowest candidate; break ties by child order
            increase its width by one unit
    else:
        for each GROW child:
            width = max(minimum width, inner)
```

Unit steps make allocation easy to inspect in TLC.
A production implementation can distribute larger amounts in each step.
Clay uses floating-point sizes and additional minimum and maximum limits.
This simplified algorithm does not promise identical numeric results.

## Word wrapping

```text
WRAP_WORDS(words, width):
    lines = empty list
    for each word in source order:
        if there is no line:
            start a line with the word
        else if last line width + one space + word width <= width:
            append the word to the last line
        else:
            start a new line with the word
    return lines
```

An oversized word stays on its own line.
The algorithm preserves every word and the source order.

## Positions and drawing commands

```text
EMIT_TREE(node, position):
    emit one abstract drawing command for the node's rectangle
    offset = node padding
    for each child in declaration order:
        if children form a row:
            child position = position + (offset.x, node.padding.top)
            offset.x += child width + gap
        else:
            child position = position + (node.padding.left, offset.y)
            offset.y += child height + gap
        EMIT_TREE(child, child position)
```

This is depth-first traversal. A stack can replace recursive calls.
Each root subtree stays together in the output.
The model emits one abstract command per node.
Clay emits specific commands for text, images, rectangles, borders, and clipping.
The renderer must preserve command order.
