from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def test_server_only_tables_are_revoked_from_client_roles() -> None:
    migration = (
        ROOT / "backend" / "supabase" / "auth_ownership_hardening.sql"
    ).read_text(encoding="utf-8").lower()

    for relation in (
        "products",
        "purchases",
        "scan_histories",
        "price_sources",
        "price_observations",
        "price_reference_stats",
        "community_feed_v1",
    ):
        assert f"public.{relation}" in migration

    assert "from anon, authenticated" in migration
    assert "storage.objects" in migration
