"""R-compatible MT initialization and uniform replacement sampling.

NumPy supplies MT19937 itself. This adapter specifies R's seed expansion and
sample.kind='Rejection' bit consumption, using zero-based indices. Algorithms:
https://github.com/wch/r-source/blob/R-4-5-branch/src/main/RNG.c
Validated against independent R 4.5.3 fixtures; no R runtime is used here.
"""

import numpy as np
import numpy.typing as npt


def r_mt19937(seed: int) -> np.random.MT19937:
    if isinstance(seed, bool) or not isinstance(seed, int) or not -(2**31) < seed < 2**31:
        raise ValueError("Seed must be a non-missing R signed integer")
    word = seed & 0xFFFFFFFF
    state = []
    # 50 warmup values, then one historical position word, then 624 MT words.
    for position in range(675):
        word = (69069 * word + 1) & 0xFFFFFFFF
        if position >= 51:
            state.append(word)
    generator = np.random.MT19937(0)
    mt_state = generator.state
    mt_state["state"]["key"] = np.array(state, dtype=np.uint32)
    mt_state["state"]["pos"] = 624
    generator.state = mt_state
    return generator


def sample_index(generator: np.random.MT19937, n: int) -> int:
    """One draw equivalent to sample.int(n, 1, replace=TRUE) - 1."""
    if not 1 <= n < 2**31:
        raise ValueError("Sample population must be between 1 and 2^31-1")
    bits = (n - 1).bit_length()
    while True:
        candidate = 0
        for _ in range(bits // 16 + 1):
            candidate = (candidate << 16) | (int(generator.random_raw()) >> 16)
        candidate &= (1 << bits) - 1
        if candidate < n:
            return candidate


def block_indices(n: int, length: int, repetitions: int, seed: int) -> npt.NDArray[np.int64]:
    if isinstance(length, bool) or not isinstance(length, int) or not 1 <= length < n:
        raise ValueError("Invalid block length")
    generator = r_mt19937(seed)
    starts_per_draw = (n + length - 1) // length
    starts = np.array([sample_index(generator, n) for _ in range(repetitions * starts_per_draw)], dtype=np.int64)
    indices = (starts.reshape(repetitions, starts_per_draw, 1) + np.arange(length)) % n
    return indices.reshape(repetitions, -1)[:, :n]
