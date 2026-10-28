------------------------- MODULE LayoutWrongZ -------------------------
EXTENDS Layout

(* Deliberate test fault. Use declaration order instead of z-order.
   This is not a reported defect in Clay. *)
WrongOrderRoot(n) ==
    /\ phase = "Order" /\ n \in RootSet \ Members(rootOrder)
    /\ \A other \in RootSet \ Members(rootOrder) : Index(Roots, n) <= Index(Roots, other)
    /\ rootOrder' = Append(rootOrder, n)
    /\ UNCHANGED <<scene, phase, measured, widthsDone, wrapped, heightsDone,
                    minWidth, preferredWidth, width, height, lines, pending, draws, x, y>>
WrongNext == \/ \E n \in Nodes : Measure(n) \/ ResolveWidth(n) \/ ResolveHeight(n)
             \/ \E n \in TextNodes : Wrap(n)
             \/ \E n \in RootSet : WrongOrderRoot(n)
             \/ Emit \/ Advance
WrongSpec == Init /\ [][WrongNext]_vars /\ WF_vars(WrongNext)
=============================================================================
