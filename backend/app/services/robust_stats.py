"""Robust, recency-weighted reference statistics for price comparison.

Replaces the plain mean/stddev z-score with statistics that tolerate the
right-skewed, small-sample price distributions seen in souq markets:

* recency weight      w_i = source_weight_i * confidence_i * exp(-age_i / tau)
* location            weighted median
* scale               sigma_r = 1.4826 * weighted MAD (falls back to IQR/1.349)
* verdict             z_r = (price - median) / sigma_r
* confidence          0.65 * size_score(real samples) + 0.35 * spread_score
"""

from __future__ import annotations

import math
from collections.abc import Sequence

MAD_TO_SIGMA = 1.4826
IQR_TO_SIGMA = 1.349
DEFAULT_DECAY_TAU_DAYS = 14.0
Z_WARNING = 1.5
Z_NEGOTIABLE = 0.0
CONFIDENCE_TARGET_REAL_SAMPLES = 30
CONFIDENCE_SIZE_WEIGHT = 0.65
CONFIDENCE_SPREAD_WEIGHT = 0.35


def recency_weight(age_days: float, tau_days: float = DEFAULT_DECAY_TAU_DAYS) -> float:
    """Exponential decay; observations from the future count as age 0."""
    if tau_days <= 0:
        raise ValueError("tau_days must be positive")
    return math.exp(-max(age_days, 0.0) / tau_days)


def weighted_quantile(values: Sequence[float], weights: Sequence[float], q: float) -> float:
    """Weighted quantile with linear interpolation between cumulative midpoints."""
    if len(values) != len(weights):
        raise ValueError("values and weights must have the same length")
    pairs = sorted((v, w) for v, w in zip(values, weights) if w > 0)
    if not pairs:
        return 0.0
    if len(pairs) == 1:
        return pairs[0][0]
    total = sum(w for _, w in pairs)
    positions: list[float] = []
    cumulative = 0.0
    for _, weight in pairs:
        positions.append((cumulative + weight / 2) / total)
        cumulative += weight
    if q <= positions[0]:
        return pairs[0][0]
    if q >= positions[-1]:
        return pairs[-1][0]
    for index in range(1, len(pairs)):
        if q <= positions[index]:
            left, right = positions[index - 1], positions[index]
            ratio = (q - left) / (right - left)
            return pairs[index - 1][0] + (pairs[index][0] - pairs[index - 1][0]) * ratio
    return pairs[-1][0]


def weighted_median(values: Sequence[float], weights: Sequence[float]) -> float:
    return weighted_quantile(values, weights, 0.5)


def weighted_mad(values: Sequence[float], weights: Sequence[float], center: float) -> float:
    return weighted_median([abs(v - center) for v in values], weights)


def robust_sigma(values: Sequence[float], weights: Sequence[float]) -> float:
    """Robust scale estimate; 0.0 when the sample has no spread at all."""
    if len(values) < 2:
        return 0.0
    median = weighted_median(values, weights)
    sigma = MAD_TO_SIGMA * weighted_mad(values, weights, median)
    if sigma > 0:
        return sigma
    iqr = weighted_quantile(values, weights, 0.75) - weighted_quantile(values, weights, 0.25)
    return iqr / IQR_TO_SIGMA if iqr > 0 else 0.0


def effective_sample_size(weights: Sequence[float]) -> float:
    """Kish effective sample size: (sum w)^2 / sum w^2."""
    total = sum(weights)
    squares = sum(w * w for w in weights)
    return (total * total) / squares if squares > 0 else 0.0


def robust_z(price: float, median: float, sigma: float) -> float:
    """Signed distance from the median in robust-sigma units."""
    if sigma <= 0:
        if price > median:
            return math.inf
        return 0.0 if price == median else -math.inf
    return (price - median) / sigma


def classify_z(z: float) -> str:
    """Map a z-like score to the app's three-tier verdict."""
    if z > Z_WARNING:
        return "warning"
    if z > Z_NEGOTIABLE:
        return "negotiable"
    return "safe"


def confidence_score(
    real_sample_size: float,
    median: float,
    sigma: float,
    *,
    target_samples: int = CONFIDENCE_TARGET_REAL_SAMPLES,
) -> float:
    """0..100 trust score. Synthetic observations must NOT be counted in
    ``real_sample_size``; the score therefore stays low until real or
    crowdsourced observations accumulate."""
    if real_sample_size <= 0 or median <= 0:
        return 0.0
    size_score = min(real_sample_size / target_samples, 1.0) * 100
    robust_cv = sigma / median
    spread_penalty = min(max((robust_cv - 0.10) / 0.60, 0.0), 1.0) * 100
    spread_score = 100 - spread_penalty
    score = CONFIDENCE_SIZE_WEIGHT * size_score + CONFIDENCE_SPREAD_WEIGHT * spread_score
    return round(min(max(score, 0.0), 100.0), 1)
