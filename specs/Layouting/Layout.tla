---------------------------- MODULE Layout ----------------------------
EXTENDS Integers, Sequences, FiniteSets

(* Original model inspired by Clay v0.14, by Nic Barker.
   Source: https://github.com/nicbarker/clay/blob/main/clay.h
   This model is a simplified design, not a translation of Clay's source. *)
CONSTANT Scenarios
ASSUME Scenarios \subseteq {"Row", "Column", "Grow", "Percent", "Overflow", "Tie"}
       /\ Scenarios # {}

VARIABLES scene, phase, measured, widthsDone, wrapped, heightsDone,
          minWidth, preferredWidth, width, height, lines,
          rootOrder, pending, draws, x, y
vars == <<scene, phase, measured, widthsDone, wrapped, heightsDone,
          minWidth, preferredWidth, width, height, lines,
          rootOrder, pending, draws, x, y>>

Nodes == {"main", "panel", "text", "box", "popup", "tip"}
TextNodes == {"text", "tip"}
RootSet == {"main", "popup"}
Roots == IF scene = "Tie" THEN <<"popup", "main">> ELSE <<"main", "popup">>
Children(n) == CASE n = "main" -> <<"panel", "box">>
                   [] n = "panel" -> <<"text">>
                   [] n = "popup" -> <<"tip">>
                   [] OTHER -> <<>>
Members(q) == {q[i] : i \in 1..Len(q)}
Parent(n) == CASE n \in {"panel", "box"} -> "main"
                 [] n = "text" -> "panel"
                 [] n = "tip" -> "popup"
                 [] OTHER -> n
Direction(n) == IF n = "main" /\ scene # "Column" THEN "Row" ELSE "Column"
Padding(n) == IF n \in RootSet THEN 1 ELSE 0
Gap(n) == IF n = "main" THEN 1 ELSE 0
Z(n) == IF n = "main" /\ scene # "Tie" THEN 2 ELSE 1
Index(q, n) == CHOOSE i \in 1..Len(q) : q[i] = n
Earlier(a, b) == Z(a) < Z(b) \/ (Z(a) = Z(b) /\ Index(Roots, a) < Index(Roots, b))
ExpectedRoots == IF Earlier("main", "popup") THEN <<"main", "popup">>
                 ELSE <<"popup", "main">>
Mode(n) == CASE n \in RootSet \cup {"box"} -> "Fixed"
               [] n = "tip" -> "Grow"
               [] scene = "Grow" -> "Grow"
               [] scene = "Percent" /\ n = "panel" -> "Percent"
               [] OTHER -> "Fit"
FixedWidth(n) == CASE n = "main" -> IF scene = "Overflow" THEN 6 ELSE 10
                     [] n = "popup" -> 5
                     [] n = "box" -> 2
                     [] OTHER -> 0
Words(n) == IF n = "text" THEN <<3, 2, 4>> ELSE IF n = "tip" THEN <<2, 2>> ELSE <<>>

RECURSIVE Sum(_), Maximum(_), Flatten(_), Pack(_, _), Walk(_), WalkForest(_)
Sum(q) == IF Len(q) = 0 THEN 0 ELSE Head(q) + Sum(Tail(q))
Maximum(q) == IF Len(q) = 0 THEN 0
              ELSE LET rest == Maximum(Tail(q)) IN IF Head(q) > rest THEN Head(q) ELSE rest
Flatten(q) == IF Len(q) = 0 THEN <<>> ELSE Head(q) \o Flatten(Tail(q))
Nonnegative(n) == IF n < 0 THEN 0 ELSE n
LineWidth(q) == Sum(q) + Nonnegative(Len(q) - 1)
(* Greedy word wrapping. An oversized word occupies its own line. *)
Pack(q, limit) ==
    IF Len(q) = 0 THEN <<>>
    ELSE LET previous == Pack(SubSeq(q, 1, Len(q) - 1), limit)
             word == q[Len(q)]
         IN IF Len(previous) = 0 THEN <<<<word>>>>
            ELSE LET last == previous[Len(previous)]
                 IN IF LineWidth(last) + 1 + word <= limit
                    THEN [previous EXCEPT ![Len(previous)] = @ \o <<word>>]
                    ELSE Append(previous, <<word>>)
Walk(n) == <<n>> \o WalkForest(Children(n))
WalkForest(q) == IF Len(q) = 0 THEN <<>> ELSE Walk(Head(q)) \o WalkForest(Tail(q))
ExpectedDraws == WalkForest(ExpectedRoots)

ChildValues(n, f) == [i \in 1..Len(Children(n)) |-> f[Children(n)[i]]]
Content(n, f, axis) ==
    LET q == ChildValues(n, f)
    IN IF (Direction(n) = "Row") = (axis = "Width")
       THEN Sum(q) + Gap(n) * Nonnegative(Len(q) - 1) ELSE Maximum(q)
Intrinsic(n, f) == Content(n, f, "Width") + 2 * Padding(n)
InnerWidth(n) == Nonnegative(width[n] - 2 * Padding(n))
Available(n) == Nonnegative(InnerWidth(n) -
                 IF Direction(n) = "Row" THEN Gap(n) * Nonnegative(Len(Children(n)) - 1) ELSE 0)
Seed(n, c) == CASE Mode(c) = "Fixed" -> FixedWidth(c)
                  [] Mode(c) = "Percent" -> Available(n) \div 2
                  [] Mode(c) = "Grow" -> minWidth[c]
                  [] OTHER -> IF preferredWidth[c] < InnerWidth(n)
                              THEN preferredWidth[c]
                              ELSE IF InnerWidth(n) < minWidth[c] THEN minWidth[c] ELSE InnerWidth(n)

(* Unit steps approximate Clay's continuous space distribution with integers.
   Ties use child order. Minima protect words that cannot be split. *)
RECURSIVE Balance(_, _, _)
Balance(n, f, direction) ==
    LET kids == Children(n)
        total == Sum(ChildValues(n, f))
        candidates == {i \in 1..Len(kids) :
            IF direction = "Shrink"
            THEN Mode(kids[i]) \in {"Fit", "Grow"} /\ f[kids[i]] > minWidth[kids[i]]
            ELSE Mode(kids[i]) = "Grow"}
    IN IF candidates = {} \/
          (IF direction = "Shrink" THEN total <= Available(n) ELSE total >= Available(n))
       THEN f
       ELSE LET best == CHOOSE i \in candidates : \A j \in candidates :
                       IF direction = "Shrink"
                       THEN f[kids[i]] > f[kids[j]] \/ (f[kids[i]] = f[kids[j]] /\ i <= j)
                       ELSE f[kids[i]] < f[kids[j]] \/ (f[kids[i]] = f[kids[j]] /\ i <= j)
                updated == [f EXCEPT ![kids[best]] = @ + IF direction = "Shrink" THEN -1 ELSE 1]
            IN Balance(n, updated, direction)

Init == /\ scene \in Scenarios
        /\ phase = "Measure"
        /\ measured = {} /\ widthsDone = {} /\ wrapped = {} /\ heightsDone = {}
        /\ minWidth = [n \in Nodes |-> 0] /\ preferredWidth = [n \in Nodes |-> 0]
        /\ width = [n \in Nodes |-> IF n \in RootSet THEN FixedWidth(n) ELSE 0]
        /\ height = [n \in Nodes |-> 0]
        /\ lines = [n \in Nodes |-> <<>>]
        /\ rootOrder = <<>> /\ pending = <<>> /\ draws = <<>>
        /\ x = [n \in Nodes |-> 0] /\ y = [n \in Nodes |-> 0]

Measure(n) ==
    /\ phase = "Measure" /\ n \notin measured /\ Members(Children(n)) \subseteq measured
    /\ minWidth' = [minWidth EXCEPT ![n] =
          IF Mode(n) = "Fixed" THEN FixedWidth(n)
          ELSE IF n \in TextNodes THEN Maximum(Words(n)) ELSE Intrinsic(n, minWidth)]
    /\ preferredWidth' = [preferredWidth EXCEPT ![n] =
          IF Mode(n) = "Fixed" THEN FixedWidth(n)
          ELSE IF n \in TextNodes THEN LineWidth(Words(n)) ELSE Intrinsic(n, preferredWidth)]
    /\ measured' = measured \cup {n}
    /\ UNCHANGED <<scene, phase, widthsDone, wrapped, heightsDone, width, height,
                    lines, rootOrder, pending, draws, x, y>>

ResolveWidth(n) ==
    /\ phase = "Width" /\ n \notin widthsDone
    /\ (n \in RootSet \/ Parent(n) \in widthsDone)
    /\ LET seeded == [c \in Nodes |-> IF c \in Members(Children(n)) THEN Seed(n, c) ELSE width[c]]
           shrunk == IF Direction(n) = "Row" THEN Balance(n, seeded, "Shrink") ELSE seeded
           filled == IF Direction(n) = "Row" THEN Balance(n, shrunk, "Grow")
                     ELSE [c \in Nodes |-> IF c \in Members(Children(n)) /\ Mode(c) = "Grow"
                                          THEN IF InnerWidth(n) < minWidth[c] THEN minWidth[c] ELSE InnerWidth(n)
                                          ELSE shrunk[c]]
       IN width' = filled
    /\ widthsDone' = widthsDone \cup {n}
    /\ UNCHANGED <<scene, phase, measured, wrapped, heightsDone, minWidth, preferredWidth,
                    height, lines, rootOrder, pending, draws, x, y>>

Wrap(n) ==
    /\ phase = "Wrap" /\ n \in TextNodes \ wrapped
    /\ lines' = [lines EXCEPT ![n] = Pack(Words(n), width[n])]
    /\ wrapped' = wrapped \cup {n}
    /\ UNCHANGED <<scene, phase, measured, widthsDone, heightsDone, minWidth, preferredWidth,
                    width, height, rootOrder, pending, draws, x, y>>

ResolveHeight(n) ==
    /\ phase = "Height" /\ n \notin heightsDone
    /\ Members(Children(n)) \subseteq heightsDone
    /\ height' = [height EXCEPT ![n] = IF n \in TextNodes THEN Len(lines[n])
                   ELSE IF n = "box" THEN 2 ELSE Content(n, height, "Height") + 2 * Padding(n)]
    /\ heightsDone' = heightsDone \cup {n}
    /\ UNCHANGED <<scene, phase, measured, widthsDone, wrapped, minWidth, preferredWidth,
                    width, lines, rootOrder, pending, draws, x, y>>

OrderRoot(n) ==
    /\ phase = "Order" /\ n \in RootSet \ Members(rootOrder)
    /\ \A other \in RootSet \ Members(rootOrder) : other = n \/ Earlier(n, other)
    /\ rootOrder' = Append(rootOrder, n)
    /\ UNCHANGED <<scene, phase, measured, widthsDone, wrapped, heightsDone,
                    minWidth, preferredWidth, width, height, lines, pending, draws, x, y>>

ExpectedX(n) ==
    IF n \in RootSet THEN IF n = "popup" THEN 2 ELSE 0
    ELSE LET p == Parent(n)
             before == SubSeq(Children(p), 1, Index(Children(p), n) - 1)
         IN x[p] + Padding(p) + IF Direction(p) = "Row"
                               THEN Sum([i \in 1..Len(before) |-> width[before[i]]]) + Gap(p) * Len(before) ELSE 0
ExpectedY(n) ==
    IF n \in RootSet THEN IF n = "popup" THEN 1 ELSE 0
    ELSE LET p == Parent(n)
             before == SubSeq(Children(p), 1, Index(Children(p), n) - 1)
         IN y[p] + Padding(p) + IF Direction(p) = "Column"
                               THEN Sum([i \in 1..Len(before) |-> height[before[i]]]) + Gap(p) * Len(before) ELSE 0

Emit ==
    /\ phase = "Draw" /\ Len(pending) > 0
    /\ LET n == Head(pending)
       IN /\ x' = [x EXCEPT ![n] = ExpectedX(n)]
          /\ y' = [y EXCEPT ![n] = ExpectedY(n)]
          /\ draws' = Append(draws, n)
          /\ pending' = Children(n) \o Tail(pending)
    /\ UNCHANGED <<scene, phase, measured, widthsDone, wrapped, heightsDone,
                    minWidth, preferredWidth, width, height, lines, rootOrder>>

Advance ==
    /\ CASE phase = "Measure" /\ measured = Nodes -> phase' = "Width"
            [] phase = "Width" /\ widthsDone = Nodes -> phase' = "Wrap"
            [] phase = "Wrap" /\ wrapped = TextNodes -> phase' = "Height"
            [] phase = "Height" /\ heightsDone = Nodes -> phase' = "Order"
            [] phase = "Order" /\ Members(rootOrder) = RootSet -> phase' = "Draw"
            [] phase = "Draw" /\ pending = <<>> -> phase' = "Done"
            [] OTHER -> FALSE
    /\ pending' = IF phase = "Order" THEN rootOrder ELSE pending
    /\ UNCHANGED <<scene, measured, widthsDone, wrapped, heightsDone, minWidth,
                    preferredWidth, width, height, lines, rootOrder, draws, x, y>>

Next == \/ \E n \in Nodes : Measure(n) \/ ResolveWidth(n) \/ ResolveHeight(n)
        \/ \E n \in TextNodes : Wrap(n)
        \/ \E n \in RootSet : OrderRoot(n)
        \/ Emit \/ Advance
Spec == Init /\ [][Next]_vars /\ WF_vars(Next)

TypeOK == /\ scene \in Scenarios
          /\ phase \in {"Measure", "Width", "Wrap", "Height", "Order", "Draw", "Done"}
          /\ measured \subseteq Nodes /\ widthsDone \subseteq Nodes
          /\ wrapped \subseteq TextNodes /\ heightsDone \subseteq Nodes
          /\ \A f \in {minWidth, preferredWidth, width, height, x, y} : f \in [Nodes -> Nat]
          /\ lines \in [Nodes -> Seq(Seq(Nat))]
          /\ rootOrder \in Seq(RootSet) /\ pending \in Seq(Nodes) /\ draws \in Seq(Nodes)
WidthContracts == \A n \in widthsDone :
    \A c \in Members(Children(n)) :
        /\ (Mode(c) = "Fixed" => width[c] = FixedWidth(c))
        /\ (Mode(c) = "Percent" => width[c] = Available(n) \div 2)
        /\ (Mode(c) \in {"Fit", "Grow"} => width[c] >= minWidth[c])
TextPreserved == \A n \in wrapped : Flatten(lines[n]) = Words(n)
RequiredWidth(n) ==
    LET required == [c \in Nodes |-> IF Mode(c) \in {"Fit", "Grow"} THEN minWidth[c] ELSE width[c]]
    IN Content(n, required, "Width")
FeasibleRowsFit == \A n \in widthsDone :
    (Direction(n) = "Row" /\ RequiredWidth(n) <= InnerWidth(n)) =>
        Content(n, width, "Width") <= InnerWidth(n)
GrowUsesSpace == \A n \in widthsDone :
    (Direction(n) = "Row" /\ RequiredWidth(n) <= InnerWidth(n) /\
     (\E c \in Members(Children(n)) : Mode(c) = "Grow")) =>
        Content(n, width, "Width") = InnerWidth(n)
ValidLines == \A n \in wrapped : \A i \in 1..Len(lines[n]) :
    LineWidth(lines[n][i]) <= width[n] \/ Len(lines[n][i]) = 1
HeightContracts == \A n \in heightsDone : height[n] =
    IF n \in TextNodes THEN Len(lines[n])
    ELSE IF n = "box" THEN 2 ELSE Content(n, height, "Height") + 2 * Padding(n)
DrawOrder == draws = SubSeq(ExpectedDraws, 1, Len(draws))
NoDuplicateDraws == Cardinality(Members(draws)) = Len(draws)
PositionsCorrect == \A n \in Members(draws) : x[n] = ExpectedX(n) /\ y[n] = ExpectedY(n)
CompleteFrame == phase = "Done" => Members(draws) = Nodes /\ Len(draws) = Cardinality(Nodes)
StageOrder == /\ (phase \in {"Wrap", "Height", "Order", "Draw", "Done"} => widthsDone = Nodes)
              /\ (phase \in {"Height", "Order", "Draw", "Done"} => wrapped = TextNodes)
              /\ (phase \in {"Order", "Draw", "Done"} => heightsDone = Nodes)
Completes == <>(phase = "Done")
(* Hand-calculated results provide checks outside the layout equations. *)
ExpectedGeometry == phase = "Done" =>
    /\ width["panel"] = CASE scene = "Column" -> 8
                             [] scene = "Percent" -> 3
                             [] scene = "Overflow" -> 4
                             [] OTHER -> 5
    /\ height["main"] = IF scene = "Column" THEN 7 ELSE 5
    /\ height["tip"] = 2 /\ height["popup"] = 4
=============================================================================
