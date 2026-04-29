----------------------------- MODULE kv_cache_simple -----------------------------
(*
  Simplified KV Cache Correctness Specification

  Tests whether different K-variants (K0-K5) correctly prevent cache reuse
  when metadata differs.
*)

EXTENDS Naturals, Sequences, FiniteSets

CONSTANTS
  Models,           \* {GPT4, Llama2}
  Adapters,         \* {None, LoRA1}
  Tenants          \* {Tenant1, Tenant2}

VARIABLES
  cache_blocks,     \* Set of cache blocks created
  violations        \* Set of detected violations

vars == << cache_blocks, violations >>

\* Cache block with full metadata
\* (not used for type checking, just documentation)
\* CacheBlock == [
\*   tokens: {<<>>, <<1>>, <<1,1>>, <<1,2>>},
\*   model: Models,
\*   adapter: Adapters,
\*   tenant: Tenants,
\*   image: {"NoImage", "Image1"}
\* ]

\* ============================================================================
\* K-VARIANT KEY FUNCTIONS
\* ============================================================================

\* K0: Only tokens
KeyK0(block) == block.tokens

\* K1: Tokens + Model
KeyK1(block) == <<block.tokens, block.model>>

\* K2: K1 + Adapter
KeyK2(block) == <<block.tokens, block.model, block.adapter>>

\* K3: K2 + Tenant
KeyK3(block) == <<block.tokens, block.model, block.adapter, block.tenant>>

\* K4: K3 (simplified spec omits model_version, so K4 same as K3)
KeyK4(block) == <<block.tokens, block.model, block.adapter, block.tenant>>

\* K5: K4 + Image (COMPLETE - all metadata fields)
KeyK5(block) == <<block.tokens, block.model, block.adapter, block.tenant, block.image>>

\* ============================================================================
\* INITIALIZATION
\* ============================================================================

Init ==
  /\ cache_blocks = {}
  /\ violations = {}

\* ============================================================================
\* ACTIONS - Add cache blocks with different metadata
\* ============================================================================

AddBlock ==
  \E tokens \in {<<>>, <<1>>, <<1,1>>, <<1,2>>},
     model \in Models, adapter \in Adapters,
     tenant \in Tenants, image \in {"NoImage", "Image1"} :
    /\ cache_blocks' = cache_blocks \cup {[
         tokens |-> tokens,
         model |-> model,
         adapter |-> adapter,
         tenant |-> tenant,
         image |-> image]}
    /\ UNCHANGED violations

\* ============================================================================
\* INVARIANTS - Detect violations for each K-variant
\* ============================================================================

\* K0 Correctness: Different metadata but same tokens = VIOLATION
ViolationK0 ==
  ~(\E b1, b2 \in cache_blocks :
      /\ b1 /= b2
      /\ KeyK0(b1) = KeyK0(b2)  \* Same tokens
      /\ \/ b1.model /= b2.model
         \/ b1.adapter /= b2.adapter
         \/ b1.tenant /= b2.tenant
         \/ b1.image /= b2.image)

\* K1 Correctness: Same tokens+model but different adapter/tenant/image = VIOLATION
ViolationK1 ==
  ~(\E b1, b2 \in cache_blocks :
      /\ b1 /= b2
      /\ KeyK1(b1) = KeyK1(b2)  \* Same tokens + model
      /\ \/ b1.adapter /= b2.adapter
         \/ b1.tenant /= b2.tenant
         \/ b1.image /= b2.image)

\* K2 Correctness: Same tokens+model+adapter but different tenant/image = VIOLATION
ViolationK2 ==
  ~(\E b1, b2 \in cache_blocks :
      /\ b1 /= b2
      /\ KeyK2(b1) = KeyK2(b2)  \* Same tokens + model + adapter
      /\ \/ b1.tenant /= b2.tenant
         \/ b1.image /= b2.image)

\* K3 Correctness: Same tokens+model+adapter+tenant but different image = VIOLATION
ViolationK3 ==
  ~(\E b1, b2 \in cache_blocks :
      /\ b1 /= b2
      /\ KeyK3(b1) = KeyK3(b2)  \* Same tokens + model + adapter + tenant
      /\ b1.image /= b2.image)

\* K4 Correctness: K4 same as K3 in simplified spec (no model_version field)
ViolationK4 ==
  ~(\E b1, b2 \in cache_blocks :
      /\ b1 /= b2
      /\ KeyK4(b1) = KeyK4(b2)  \* Same as K3
      /\ b1.image /= b2.image)

\* K5 Correctness: COMPLETE key - NO violations possible
ViolationK5 ==
  ~(\E b1, b2 \in cache_blocks :
      /\ b1 /= b2
      /\ KeyK5(b1) = KeyK5(b2))  \* If keys match, blocks must be identical

\* ============================================================================
\* STATE CONSTRAINTS (for limiting state space exploration)
\* ============================================================================

StateConstraintK4 == Cardinality(cache_blocks) <= 2
StateConstraintK5 == Cardinality(cache_blocks) <= 2

\* ============================================================================
\* SPECIFICATIONS
\* ============================================================================

Next == AddBlock

SpecK0 == Init /\ [][Next]_vars
SpecK1 == Init /\ [][Next]_vars
SpecK2 == Init /\ [][Next]_vars
SpecK3 == Init /\ [][Next]_vars
SpecK4 == Init /\ [][Next]_vars
SpecK5 == Init /\ [][Next]_vars

================================================================================
