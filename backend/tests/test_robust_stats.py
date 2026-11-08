import math

import pytest

from app.services import robust_stats as rs


def test_recency_weight_halves_at_tau_ln2() -> None:
    assert rs.recency_weight(0) == 1.0
    assert rs.recency_weight(14 * math.log(2)) == pytest.approx(0.5)
    assert rs.recency_weight(-3) == 1.0


def test_weighted_median_equal_weights_matches_plain_median() -> None:
    assert rs.weighted_median([1, 2, 3, 4, 100], [1] * 5) == 3
    assert rs.weighted_median([1, 2, 3, 4], [1] * 4) == pytest.approx(2.5)


def test_weighted_median_follows_heavy_weight() -> None:
    assert rs.weighted_median([10, 20, 30], [1, 1, 10]) > 25


def test_robust_sigma_resists_outlier() -> None:
    clean = [10, 11, 12, 13, 14]
    dirty = clean + [500]
    w_clean, w_dirty = [1] * 5, [1] * 6
    assert rs.robust_sigma(dirty, w_dirty) < 3 * rs.robust_sigma(clean, w_clean)


def test_robust_sigma_zero_spread_and_singleton() -> None:
    assert rs.robust_sigma([5, 5, 5], [1, 1, 1]) == 0.0
    assert rs.robust_sigma([5], [1]) == 0.0


def test_effective_sample_size_bounds() -> None:
    assert rs.effective_sample_size([1, 1, 1, 1]) == pytest.approx(4)
    assert rs.effective_sample_size([1, 0.01, 0.01]) < 1.1


def test_classify_z_thresholds() -> None:
    assert rs.classify_z(1.6) == "warning"
    assert rs.classify_z(0.2) == "negotiable"
    assert rs.classify_z(0.0) == "safe"
    assert rs.classify_z(-2) == "safe"


def test_confidence_score_monotonic_in_real_samples() -> None:
    low = rs.confidence_score(3, 20, 4)
    high = rs.confidence_score(30, 20, 4)
    assert low < high <= 100
    assert rs.confidence_score(0, 20, 4) == 0.0
