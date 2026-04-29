----------------------- MODULE kv_cache_invariants ----------------------
(*
  Correctness Invariants for KV Cache Specification

  This module defines the safety properties that MUST hold for cache
  correctness. These are checked by TLC model checker.

  Properties:
  1. MetadataMatch: Shared blocks have matching K0-K5 fields
  2. TenantIsolation: Different tenants never share cache
  3. AdapterIsolation: Different adapters never share cache
  4. ModelIsolation: Different models never share cache
  5. NoStaleReuse: Never reuse blocks with outdated metadata
*)

EXTENDS kv_cache_spec

\* ============================================================================
\* INVARIANTS FOR K0-K4 (Should fail model checking)
\* ============================================================================

\* INVARIANT 1: MetadataMatch with K0 only
\* EXPECTED: FAILS - Two requests with different models but same tokens
\*           will reuse cache incorrectly
Invariant_MetadataMatch_K0 ==
  MetadataMatchK0

\* INVARIANT 2: MetadataMatch with K1 (tokens + model)
\* EXPECTED: May fail depending on test scenario
Invariant_MetadataMatch_K1 ==
  MetadataMatchK1

\* ============================================================================
\* CRITICAL INVARIANTS (Only K4-K5 satisfy these)
\* ============================================================================

\* INVARIANT 3: TenantIsolation
\* Requests from different tenants CANNOT share cache blocks
\* EXPECTED: Fails for K0-K3, Passes for K4-K5
Invariant_TenantIsolation ==
  \A r1, r2 \in DOMAIN requests :
    (requests[r1].tenant_id \neq requests[r2].tenant_id /\
     requests[r1].status = "generating" /\
     requests[r2].status = "generating") =>
    (* Their cache keys must differ *)
    LET key1 == RequestToKeyK5(requests[r1])
        key2 == RequestToKeyK5(requests[r2])
    IN ~KeysMatchK5(key1, key2)

\* INVARIANT 4: AdapterIsolation
\* Requests with different adapters CANNOT share cache
\* EXPECTED: Fails for K0-K2, Passes for K3-K5
Invariant_AdapterIsolation ==
  \A r1, r2 \in DOMAIN requests :
    (requests[r1].adapter_id \neq requests[r2].adapter_id /\
     requests[r1].status = "generating" /\
     requests[r2].status = "generating") =>
    (* Their cache keys must differ in adapter field *)
    LET key1 == RequestToKeyK5(requests[r1])
        key2 == RequestToKeyK5(requests[r2])
    IN ~KeysMatchK5(key1, key2)

\* INVARIANT 5: ModelIsolation
\* Requests with different models CANNOT share cache
\* EXPECTED: Fails for K0, Passes for K1-K5
Invariant_ModelIsolation ==
  \A r1, r2 \in DOMAIN requests :
    (requests[r1].model_id \neq requests[r2].model_id /\
     requests[r1].status = "generating" /\
     requests[r2].status = "generating") =>
    (* Their cache keys must differ in model field *)
    LET key1 == RequestToKeyK5(requests[r1])
        key2 == RequestToKeyK5(requests[r2])
    IN ~KeysMatchK5(key1, key2)

\* INVARIANT 6: VersionIsolation
\* Different model versions CANNOT share cache
\* EXPECTED: Fails for K0-K1, Passes for K2-K5
Invariant_VersionIsolation ==
  \A r1, r2 \in DOMAIN requests :
    (requests[r1].model_version \neq requests[r2].model_version /\
     requests[r1].status = "generating" /\
     requests[r2].status = "generating") =>
    LET key1 == RequestToKeyK5(requests[r1])
        key2 == RequestToKeyK5(requests[r2])
    IN ~KeysMatchK5(key1, key2)

\* INVARIANT 7: MultimodalIsolation
\* Different image hashes CANNOT share cache
\* EXPECTED: Fails for K0-K4, Passes for K5
Invariant_MultimodalIsolation ==
  \A r1, r2 \in DOMAIN requests :
    (requests[r1].multimodal_hash \neq requests[r2].multimodal_hash /\
     requests[r1].status = "generating" /\
     requests[r2].status = "generating") =>
    LET key1 == RequestToKeyK5(requests[r1])
        key2 == RequestToKeyK5(requests[r2])
    IN ~KeysMatchK5(key1, key2)

\* ============================================================================
\* COMBINED INVARIANTS
\* ============================================================================

\* Full specification: All K5 fields must match for sharing
AllK5InvariantsPass ==
  /\ Invariant_MetadataMatch_K5
  /\ Invariant_TenantIsolation
  /\ Invariant_AdapterIsolation
  /\ Invariant_ModelIsolation
  /\ Invariant_VersionIsolation
  /\ Invariant_MultimodalIsolation

\* K0 only (baseline): Only token prefix must match
OnlyK0InvariantsRequired ==
  /\ Invariant_MetadataMatch_K0
  \* Does NOT enforce TenantIsolation, AdapterIsolation, ModelIsolation

\* K4 partial (without multimodal): Requires K0-K4
K4InvariantsPass ==
  /\ Invariant_MetadataMatch_K5
  /\ Invariant_TenantIsolation
  /\ Invariant_AdapterIsolation
  /\ Invariant_ModelIsolation
  /\ Invariant_VersionIsolation
  \* Does NOT enforce MultimodalIsolation

\* ============================================================================
\* LIVENESS PROPERTIES (Fairness)
\* ============================================================================

\* All requests eventually complete
Liveness_AllRequestsComplete ==
  \A r \in 1..MaxRequests :
    []<>(requests[r].status = "complete")

\* Cache doesn't grow indefinitely
Liveness_CacheBounded ==
  <>[](Cardinality({b \in DOMAIN cache : cache[b].valid}) <= CacheSize)

=============================================================================
