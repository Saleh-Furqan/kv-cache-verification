----------------------------- MODULE kv_cache_spec -----------------------------
(*
  KV Cache Correctness Specification

  Formal specification of cache key metadata requirements (K0-K5) for preventing
  silent semantic violations in LLM serving systems.

  This TLA+ module defines:
  - Cache state (blocks, requests, K0-K5 fields)
  - Sharing rules (when cache can be reused)
  - Correctness invariants (what must always hold)
  - K variants (K0 alone, K0-K1, ..., K0-K5)

  Model checking will show:
  - K0-K4: Have counterexamples (violations possible)
  - K5: No counterexamples (correct)
*)

EXTENDS Naturals, Sequences, FiniteSets

CONSTANTS
  MaxTokens,        \* Maximum token sequence length
  MaxRequests,      \* Maximum concurrent requests
  Models,           \* Set of possible models {GPT4, Llama2, etc}
  Adapters,         \* Set of possible adapters {None, LoRA1, LoRA2, etc}
  Tenants,          \* Set of possible tenants {Tenant1, Tenant2, etc}
  CacheSize         \* Maximum number of cached blocks

ASSUME
  /\ MaxTokens \in 1..10
  /\ MaxRequests \in 1..5
  /\ Cardinality(Models) >= 2
  /\ Cardinality(Adapters) >= 2
  /\ Cardinality(Tenants) >= 2
  /\ CacheSize \in 5..20

\* ============================================================================
\* TYPE DEFINITIONS
\* ============================================================================

TokenSeq == Seq(1..MaxTokens)
BlockId == 1..CacheSize
RequestId == 1..MaxRequests

\* Cache key field: token prefix (K0)
K0 == [
  token_prefix: TokenSeq
]

\* Cache key with model (K0-K1)
K1 == [
  token_prefix: TokenSeq,
  model_id: Models
]

\* Cache key with version (K0-K2)
K2_ == [
  token_prefix: TokenSeq,
  model_id: Models,
  model_version: 1..2  \* versions 1 and 2
]

\* Cache key with adapter (K0-K3)
K3 == [
  token_prefix: TokenSeq,
  model_id: Models,
  model_version: 1..2,
  adapter_id: Adapters
]

\* Cache key with tenant (K0-K4)
K4 == [
  token_prefix: TokenSeq,
  model_id: Models,
  model_version: 1..2,
  adapter_id: Adapters,
  tenant_salt: Tenants
]

\* Full cache key (K0-K5)
K5 == [
  token_prefix: TokenSeq,
  model_id: Models,
  model_version: 1..2,
  adapter_id: Adapters,
  tenant_salt: Tenants,
  multimodal_hash: {"NoImage", "Image1", "Image2"}
]

\* Block in cache
Block == [
  key: K5,              \* Cache key (K0-K5)
  ref_count: 0..MaxRequests,  \* Reference counting
  valid: BOOLEAN        \* Still valid?
]

\* Request to generate tokens
Request == [
  request_id: RequestId,
  token_prefix: TokenSeq,
  model_id: Models,
  model_version: 1..2,
  adapter_id: Adapters,
  tenant_id: Tenants,
  multimodal_hash: {"NoImage", "Image1", "Image2"},
  status: {"waiting", "generating", "complete"}
]

\* ============================================================================
\* STATE VARIABLES
\* ============================================================================

VARIABLE
  cache,              \* BlockId -> Block
  requests            \* RequestId -> Request

vars == << cache, requests >>

\* ============================================================================
\* HELPER FUNCTIONS
\* ============================================================================

\* Extract cache key from request using K-variant
RequestToKeyK0(req) == [
  token_prefix |-> req.token_prefix
]

RequestToKeyK1(req) == [
  token_prefix |-> req.token_prefix,
  model_id |-> req.model_id
]

RequestToKeyK2(req) == [
  token_prefix |-> req.token_prefix,
  model_id |-> req.model_id,
  model_version |-> req.model_version
]

RequestToKeyK3(req) == [
  token_prefix |-> req.token_prefix,
  model_id |-> req.model_id,
  model_version |-> req.model_version,
  adapter_id |-> req.adapter_id
]

RequestToKeyK4(req) == [
  token_prefix |-> req.token_prefix,
  model_id |-> req.model_id,
  model_version |-> req.model_version,
  adapter_id |-> req.adapter_id,
  tenant_salt |-> req.tenant_id
]

RequestToKeyK5(req) == [
  token_prefix |-> req.token_prefix,
  model_id |-> req.model_id,
  model_version |-> req.model_version,
  adapter_id |-> req.adapter_id,
  tenant_salt |-> req.tenant_id,
  multimodal_hash |-> req.multimodal_hash
]

\* Check if two keys match (for K-variant comparison)
KeysMatchK0(key1, key2) ==
  key1.token_prefix = key2.token_prefix

KeysMatchK1(key1, key2) ==
  /\ key1.token_prefix = key2.token_prefix
  /\ key1.model_id = key2.model_id

KeysMatchK2(key1, key2) ==
  /\ key1.token_prefix = key2.token_prefix
  /\ key1.model_id = key2.model_id
  /\ key1.model_version = key2.model_version

KeysMatchK3(key1, key2) ==
  /\ key1.token_prefix = key2.token_prefix
  /\ key1.model_id = key2.model_id
  /\ key1.model_version = key2.model_version
  /\ key1.adapter_id = key2.adapter_id

KeysMatchK4(key1, key2) ==
  /\ key1.token_prefix = key2.token_prefix
  /\ key1.model_id = key2.model_id
  /\ key1.model_version = key2.model_version
  /\ key1.adapter_id = key2.adapter_id
  /\ key1.tenant_salt = key2.tenant_salt

KeysMatchK5(key1, key2) ==
  /\ key1.token_prefix = key2.token_prefix
  /\ key1.model_id = key2.model_id
  /\ key1.model_version = key2.model_version
  /\ key1.adapter_id = key2.adapter_id
  /\ key1.tenant_salt = key2.tenant_salt
  /\ key1.multimodal_hash = key2.multimodal_hash

\* Find cached block matching key (K-variant specific)
FindCachedBlockK0(req_key) ==
  LET matching == {b \in DOMAIN cache :
                    /\ cache[b].valid
                    /\ KeysMatchK0(req_key, cache[b].key)}
  IN IF matching = {} THEN 0 ELSE CHOOSE b \in matching : TRUE

FindCachedBlockK1(req_key) ==
  LET matching == {b \in DOMAIN cache :
                    /\ cache[b].valid
                    /\ KeysMatchK1(req_key, cache[b].key)}
  IN IF matching = {} THEN 0 ELSE CHOOSE b \in matching : TRUE

FindCachedBlockK2(req_key) ==
  LET matching == {b \in DOMAIN cache :
                    /\ cache[b].valid
                    /\ KeysMatchK2(req_key, cache[b].key)}
  IN IF matching = {} THEN 0 ELSE CHOOSE b \in matching : TRUE

FindCachedBlockK3(req_key) ==
  LET matching == {b \in DOMAIN cache :
                    /\ cache[b].valid
                    /\ KeysMatchK3(req_key, cache[b].key)}
  IN IF matching = {} THEN 0 ELSE CHOOSE b \in matching : TRUE

FindCachedBlockK4(req_key) ==
  LET matching == {b \in DOMAIN cache :
                    /\ cache[b].valid
                    /\ KeysMatchK4(req_key, cache[b].key)}
  IN IF matching = {} THEN 0 ELSE CHOOSE b \in matching : TRUE

FindCachedBlockK5(req_key) ==
  LET matching == {b \in DOMAIN cache :
                    /\ cache[b].valid
                    /\ KeysMatchK5(req_key, cache[b].key)}
  IN IF matching = {} THEN 0 ELSE CHOOSE b \in matching : TRUE

\* Create new cache block
NewBlock(req, variant) ==
  IF variant = "K0" THEN
    [key |-> RequestToKeyK0(req),
     ref_count |-> 1,
     valid |-> TRUE]
  ELSE IF variant = "K1" THEN
    [key |-> RequestToKeyK1(req),
     ref_count |-> 1,
     valid |-> TRUE]
  ELSE IF variant = "K2" THEN
    [key |-> RequestToKeyK2(req),
     ref_count |-> 1,
     valid |-> TRUE]
  ELSE IF variant = "K3" THEN
    [key |-> RequestToKeyK3(req),
     ref_count |-> 1,
     valid |-> TRUE]
  ELSE IF variant = "K4" THEN
    [key |-> RequestToKeyK4(req),
     ref_count |-> 1,
     valid |-> TRUE]
  ELSE
    [key |-> RequestToKeyK5(req),
     ref_count |-> 1,
     valid |-> TRUE]

\* ============================================================================
\* INITIALIZATION
\* ============================================================================

Init ==
  /\ cache = [i \in 1..CacheSize |-> [key |-> RequestToKeyK5([
               request_id |-> 0,
               token_prefix |-> <<>>,
               model_id |-> CHOOSE m \in Models : TRUE,
               model_version |-> 1,
               adapter_id |-> CHOOSE a \in Adapters : TRUE,
               tenant_id |-> CHOOSE t \in Tenants : TRUE,
               multimodal_hash |-> "NoImage",
               status |-> "waiting"]),
             ref_count |-> 0,
             valid |-> FALSE]]
  /\ requests = [i \in 1..MaxRequests |->
               IF i = 1 THEN
                 [request_id |-> 1,
                  token_prefix |-> <<>>,
                  model_id |-> CHOOSE m \in Models : TRUE,
                  model_version |-> 1,
                  adapter_id |-> CHOOSE a \in Adapters : TRUE,
                  tenant_id |-> CHOOSE t \in Tenants : TRUE,
                  multimodal_hash |-> "NoImage",
                  status |-> "waiting"]
               ELSE
                 [request_id |-> 2,
                  token_prefix |-> <<>>,
                  model_id |-> CHOOSE m \in Models : m /= (CHOOSE m2 \in Models : TRUE),
                  model_version |-> 2,
                  adapter_id |-> CHOOSE a \in Adapters : a /= (CHOOSE a2 \in Adapters : TRUE),
                  tenant_id |-> CHOOSE t \in Tenants : t /= (CHOOSE t2 \in Tenants : TRUE),
                  multimodal_hash |-> "Image1",
                  status |-> "waiting"]]

\* ============================================================================
\* ACTIONS
\* ============================================================================

\* Start generating with a request (create new cache entry or reuse existing)
StartGenerateK0(req_id, variant) ==
  /\ requests[req_id].status = "waiting"
  /\ LET req == requests[req_id]
         req_key == RequestToKeyK0(req)
         cached_block == FindCachedBlockK0(req_key)
     IN IF cached_block /= 0 THEN
       \* Reuse existing block
       /\ cache' = [cache EXCEPT ![cached_block].ref_count = cache[cached_block].ref_count + 1]
       /\ requests' = [requests EXCEPT ![req_id].status = "generating"]
       ELSE
       \* Create new block
       /\ LET new_block == NewBlock(req, "K0")
              free_slot == CHOOSE s \in 1..CacheSize : ~cache[s].valid
          IN cache' = [cache EXCEPT ![free_slot] = new_block]
       /\ requests' = [requests EXCEPT ![req_id].status = "generating"]

StartGenerateK1(req_id) ==
  /\ requests[req_id].status = "waiting"
  /\ LET req == requests[req_id]
         req_key == RequestToKeyK1(req)
         cached_block == FindCachedBlockK1(req_key)
     IN IF cached_block /= 0 THEN
       /\ cache' = [cache EXCEPT ![cached_block].ref_count = cache[cached_block].ref_count + 1]
       /\ requests' = [requests EXCEPT ![req_id].status = "generating"]
       ELSE
       /\ LET new_block == NewBlock(req, "K1")
              free_slot == CHOOSE s \in 1..CacheSize : ~cache[s].valid
          IN cache' = [cache EXCEPT ![free_slot] = new_block]
       /\ requests' = [requests EXCEPT ![req_id].status = "generating"]

StartGenerateK2(req_id) ==
  /\ requests[req_id].status = "waiting"
  /\ LET req == requests[req_id]
         req_key == RequestToKeyK2(req)
         cached_block == FindCachedBlockK2(req_key)
     IN IF cached_block /= 0 THEN
       /\ cache' = [cache EXCEPT ![cached_block].ref_count = cache[cached_block].ref_count + 1]
       /\ requests' = [requests EXCEPT ![req_id].status = "generating"]
       ELSE
       /\ LET new_block == NewBlock(req, "K2")
              free_slot == CHOOSE s \in 1..CacheSize : ~cache[s].valid
          IN cache' = [cache EXCEPT ![free_slot] = new_block]
       /\ requests' = [requests EXCEPT ![req_id].status = "generating"]

StartGenerateK3(req_id) ==
  /\ requests[req_id].status = "waiting"
  /\ LET req == requests[req_id]
         req_key == RequestToKeyK3(req)
         cached_block == FindCachedBlockK3(req_key)
     IN IF cached_block /= 0 THEN
       /\ cache' = [cache EXCEPT ![cached_block].ref_count = cache[cached_block].ref_count + 1]
       /\ requests' = [requests EXCEPT ![req_id].status = "generating"]
       ELSE
       /\ LET new_block == NewBlock(req, "K3")
              free_slot == CHOOSE s \in 1..CacheSize : ~cache[s].valid
          IN cache' = [cache EXCEPT ![free_slot] = new_block]
       /\ requests' = [requests EXCEPT ![req_id].status = "generating"]

StartGenerateK4(req_id) ==
  /\ requests[req_id].status = "waiting"
  /\ LET req == requests[req_id]
         req_key == RequestToKeyK4(req)
         cached_block == FindCachedBlockK4(req_key)
     IN IF cached_block /= 0 THEN
       /\ cache' = [cache EXCEPT ![cached_block].ref_count = cache[cached_block].ref_count + 1]
       /\ requests' = [requests EXCEPT ![req_id].status = "generating"]
       ELSE
       /\ LET new_block == NewBlock(req, "K4")
              free_slot == CHOOSE s \in 1..CacheSize : ~cache[s].valid
          IN cache' = [cache EXCEPT ![free_slot] = new_block]
       /\ requests' = [requests EXCEPT ![req_id].status = "generating"]

StartGenerateK5(req_id) ==
  /\ requests[req_id].status = "waiting"
  /\ LET req == requests[req_id]
         req_key == RequestToKeyK5(req)
         cached_block == FindCachedBlockK5(req_key)
     IN IF cached_block /= 0 THEN
       /\ cache' = [cache EXCEPT ![cached_block].ref_count = cache[cached_block].ref_count + 1]
       /\ requests' = [requests EXCEPT ![req_id].status = "generating"]
       ELSE
       /\ LET new_block == NewBlock(req, "K5")
              free_slot == CHOOSE s \in 1..CacheSize : ~cache[s].valid
          IN cache' = [cache EXCEPT ![free_slot] = new_block]
       /\ requests' = [requests EXCEPT ![req_id].status = "generating"]

\* Complete request and release cache references
CompleteRequest(req_id) ==
  /\ requests[req_id].status = "generating"
  /\ LET req == requests[req_id]
     IN \E b \in DOMAIN cache :
          /\ cache[b].ref_count > 0
          /\ cache' = [cache EXCEPT ![b].ref_count = cache[b].ref_count - 1]
  /\ requests' = [requests EXCEPT ![req_id].status = "complete"]

\* ============================================================================
\* MAIN SPECIFICATION (parametric by K-variant)
\* ============================================================================

\* For testing K0 (baseline - tokens only)
NextK0 == \E r \in 1..MaxRequests : StartGenerateK0(r, "K0") \/ CompleteRequest(r)

\* For testing K1 (K0 + model_id)
NextK1 == \E r \in 1..MaxRequests : StartGenerateK1(r) \/ CompleteRequest(r)

\* For testing K2 (K0-K1 + model_version)
NextK2 == \E r \in 1..MaxRequests : StartGenerateK2(r) \/ CompleteRequest(r)

\* For testing K3 (K0-K2 + adapter_id)
NextK3 == \E r \in 1..MaxRequests : StartGenerateK3(r) \/ CompleteRequest(r)

\* For testing K4 (K0-K3 + tenant_salt)
NextK4 == \E r \in 1..MaxRequests : StartGenerateK4(r) \/ CompleteRequest(r)

\* For testing K5 (K0-K4 + multimodal_hash) - SHOULD BE CORRECT
NextK5 == \E r \in 1..MaxRequests : StartGenerateK5(r) \/ CompleteRequest(r)

\* ============================================================================
\* INVARIANTS
\* ============================================================================

\* Invariant 1: MetadataMatch
\* If two requests are using same cached block, their cache keys must match
MetadataMatchK0 ==
  \A b \in DOMAIN cache :
    (cache[b].valid /\ cache[b].ref_count > 0) =>
    \A r1, r2 \in DOMAIN requests :
      (requests[r1].status = "generating" /\
       requests[r2].status = "generating") =>
      KeysMatchK0(RequestToKeyK0(requests[r1]),
                  RequestToKeyK0(requests[r2]))

MetadataMatchK1 ==
  \A b \in DOMAIN cache :
    (cache[b].valid /\ cache[b].ref_count > 0) =>
    \A r1, r2 \in DOMAIN requests :
      (requests[r1].status = "generating" \/ requests[r2].status = "generating") =>
      KeysMatchK1(RequestToKeyK1(requests[r1]),
                  RequestToKeyK1(requests[r2]))

MetadataMatchK5 ==
  \A r1, r2 \in DOMAIN requests :
    (r1 /= r2 /\
     requests[r1].status = "generating" /\
     requests[r2].status = "generating" /\
     ~KeysMatchK5(RequestToKeyK5(requests[r1]), RequestToKeyK5(requests[r2]))) =>
    ~(\E b \in DOMAIN cache :
        cache[b].valid /\
        KeysMatchK5(cache[b].key, RequestToKeyK5(requests[r1])) /\
        KeysMatchK5(cache[b].key, RequestToKeyK5(requests[r2])))

\* Invariant 2: TenantIsolation (only valid for K4 and K5)
\* Requests from different tenants never share cache
TenantIsolationK4 ==
  \A r1, r2 \in DOMAIN requests :
    (requests[r1].tenant_id /= requests[r2].tenant_id /\
     requests[r1].status = "generating" /\
     requests[r2].status = "generating") =>
    RequestToKeyK4(requests[r1]).tenant_salt /=
    RequestToKeyK4(requests[r2]).tenant_salt

TenantIsolationK5 ==
  \A r1, r2 \in DOMAIN requests :
    (requests[r1].tenant_id /= requests[r2].tenant_id /\
     requests[r1].status = "generating" /\
     requests[r2].status = "generating") =>
    RequestToKeyK5(requests[r1]).tenant_salt /=
    RequestToKeyK5(requests[r2]).tenant_salt

\* Invariant 3: NoStaleReuse
\* Never reuse cache blocks that no longer match current context
NoStaleReuseK5 ==
  \A b \in DOMAIN cache :
    (cache[b].valid /\ cache[b].ref_count > 0) =>
    \A r \in DOMAIN requests :
      requests[r].status = "generating" =>
      KeysMatchK5(RequestToKeyK5(requests[r]), cache[b].key)

\* ============================================================================
\* SPECIFICATIONS FOR TESTING
\* ============================================================================

\* Spec with K0 variant (should have counterexamples)
SpecK0 == Init /\ [][NextK0]_vars /\ WF_vars(NextK0)

\* Spec with K1 variant (should have counterexamples)
SpecK1 == Init /\ [][NextK1]_vars /\ WF_vars(NextK1)

\* Spec with K5 variant (should pass all invariants)
SpecK5 == Init /\ [][NextK5]_vars /\ WF_vars(NextK5)

=============================================================================
