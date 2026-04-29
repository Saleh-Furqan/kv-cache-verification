# KV Cache Correctness Verification

**Status:** TLC verification complete for K0-K5 (bounded model checking)

## Quick Summary

This directory contains TLA+ specifications and TLC verification results for KV cache correctness in LLM serving systems.

**Key Result:** Bounded verification shows K0-K4 (incomplete cache keys) produce violations, while K5 (complete key with all metadata) shows no violations in the explored state space.

## Directory Structure

```
kv-cache-verification/
├── kv_cache_spec.tla          # Original full specification (650+ lines)
├── kv_cache_simple.tla        # Simplified working spec (used for verification)
├── kv_cache_invariants.tla    # Invariant definitions
├── simple-k*.cfg              # TLC configuration files for K0-K5
├── tlc-output/                # Verification results
│   ├── ACTUAL-TLC-RESULTS.md  # Comprehensive results analysis
│   ├── simple_k*_full.txt     # Complete TLC output logs
│   └── simple_k*_summary.txt  # Brief result summaries
├── tools/                     # TLA+ toolchain (tla2tools.jar)
└── archive/                   # Debugging artifacts and old files
```

## Running Verification

### Prerequisites
Java 11+ installed

### Run Single Variant
```bash
java -XX:+UseParallelGC -Xmx2g -cp ./tools/tla2tools.jar tlc2.TLC \
  -workers 4 -config simple-k0.cfg kv_cache_simple.tla
```

### Run All K0-K5
```bash
for k in 0 1 2 3 4 5; do
  echo "Testing K${k}..."
  java -XX:+UseParallelGC -Xmx2g -cp ./tools/tla2tools.jar tlc2.TLC \
    -workers 4 -config simple-k${k}.cfg kv_cache_simple.tla \
    2>&1 | tee tlc-output/simple_k${k}_full.txt
done
```

## Results

See [tlc-output/ACTUAL-TLC-RESULTS.md](tlc-output/ACTUAL-TLC-RESULTS.md) for complete analysis.

**Summary:**
- K0 (tokens only): ❌ Violation in 76 states
- K1 (+ model): ❌ Violation in 84 states  
- K2 (+ adapter): ❌ Violation in 100 states
- K3 (+ tenant): ❌ Violation in 132 states
- K4 (+ tenant, no image): ❌ Violation in 203 states
- K5 (+ image, complete): ✅ No violations in 133,185 states

## Specifications

### K-Variants Tested

| Variant | Fields | Status |
|---------|--------|--------|
| K0 | tokens | ❌ Insufficient |
| K1 | tokens + model | ❌ Insufficient |
| K2 | tokens + model + adapter | ❌ Insufficient |
| K3 | tokens + model + adapter + tenant | ❌ Insufficient |
| K4 | tokens + model + adapter + tenant | ❌ Insufficient |
| K5 | tokens + model + adapter + tenant + image | ✅ Complete |

### Spec Differences

- **kv_cache_spec.tla**: Original full spec with model_version, complex invariants
- **kv_cache_simple.tla**: Simplified for verification (no model_version, explicit token sequences)

The simplified spec avoids `Seq(1..3)` enumeration issues by using explicit sequences `{<<>>, <<1>>, <<1,1>>, <<1,2>>}`.

## Related Documentation

- `TESTING-PLAN.md`: Original testing strategy
- `WEEK2-COMPLETION-SUMMARY.md`: Research progress summary
- `WEEK3-PYTHON-SIMULATOR-PLAN.md`: Next steps (Python validation)
- `TLC-RESULTS-ANALYSIS.md`: ⚠️ ARCHIVED - contains fabricated results from before TLC ran successfully

## Honest Scope

This is **bounded model checking**, not a complete formal proof:

✅ **What we proved:**
- K0-K4 exhibit counterexamples in bounded verification
- K5 shows no violations within explored state space (133K states)

❌ **What we did NOT prove:**
- Unbounded correctness (only checked up to 2 cache blocks for K5)
- Correctness for arbitrary token sequences
- Liveness or performance properties

This bounded verification provides empirical evidence for K5's necessity, especially when combined with real-world bugs (vLLM #30931) and planned Python simulation.
