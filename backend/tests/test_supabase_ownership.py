import pytest

from app.models.detection import DetectionResponse
from app.models.community import CommunityPostCreate
from app.models.scan_history import ScanHistoryPriceUpdate
from app.services import supabase_backend
from app.services.supabase_backend import (
    SupabaseBackendUnavailable,
    SupabaseResourceNotFound,
    SupabaseUnknownProduct,
)


TEST_USER_ID = "11111111-1111-4111-8111-111111111111"


class FakeResponse:
    def __init__(self, rows: list[dict]):
        self.data = rows


class QuerySpy:
    def __init__(self, rows: list[dict]):
        self.rows = rows
        self.filters: list[tuple[str, object]] = []

    def update(self, _: dict):
        return self

    def insert(self, _: dict):
        return self

    def select(self, *_args, **_kwargs):
        return self

    def limit(self, _limit: int):
        return self

    def order(self, *_args, **_kwargs):
        return self

    def eq(self, column: str, value: object):
        self.filters.append((column, value))
        return self

    def execute(self):
        return FakeResponse(self.rows)


class ClientSpy:
    def __init__(self, query: QuerySpy):
        self.query = query

    def table(self, table_name: str):
        assert table_name == "scan_histories"
        return self.query


@pytest.mark.parametrize("operation", ["detection", "price"])
def test_scan_history_updates_are_scoped_to_verified_owner(
    monkeypatch,
    operation: str,
) -> None:
    query = QuerySpy(
        [{"id": "history-1", "image_path": "owner/image.jpg", "created_at": "now"}]
    )
    monkeypatch.setattr(
        supabase_backend,
        "get_supabase_client",
        lambda: ClientSpy(query),
    )
    monkeypatch.setattr(
        supabase_backend,
        "_scan_history_response",
        lambda client, row: row,
    )

    if operation == "detection":
        supabase_backend.update_scan_history_detection(
            history_id="history-1",
            client_user_id=TEST_USER_ID,
            payload=DetectionResponse(
                product_id="tomato",
                name_kr="Tomato",
                name_ar="طماطم",
                confidence=0.9,
            ),
        )
    else:
        supabase_backend.update_scan_history_price(
            history_id="history-1",
            client_user_id=TEST_USER_ID,
            payload=ScanHistoryPriceUpdate(
                quoted_total_price_egp=20,
                quoted_quantity=1,
                quoted_unit="kg",
                quoted_unit_price_egp=20,
            ),
        )

    assert ("id", "history-1") in query.filters
    assert ("client_user_id", TEST_USER_ID) in query.filters


def test_scan_history_update_hides_another_users_record(monkeypatch) -> None:
    query = QuerySpy([])
    monkeypatch.setattr(
        supabase_backend,
        "get_supabase_client",
        lambda: ClientSpy(query),
    )

    with pytest.raises(SupabaseResourceNotFound):
        supabase_backend.update_scan_history_detection(
            history_id="someone-elses-history",
            client_user_id=TEST_USER_ID,
            payload=DetectionResponse(
                product_id="tomato",
                name_kr="Tomato",
                name_ar="طماطم",
                confidence=0.9,
            ),
        )


def test_unknown_community_product_does_not_create_master_data() -> None:
    query = QuerySpy([])

    with pytest.raises(SupabaseUnknownProduct):
        supabase_backend._require_product(
            client=_ProductClientSpy(query),
            product_code="attacker_product",
        )

    assert query.filters == [("code", "attacker_product")]


def test_community_post_uses_canonical_product_name(monkeypatch) -> None:
    client = _CommunityWriteClientSpy()
    monkeypatch.setattr(supabase_backend, "get_supabase_client", lambda: client)

    supabase_backend.create_community_post(
        payload=CommunityPostCreate(
            product_name="Spoofed product name",
            product_code="tomato",
            price=20,
        ),
        client_user_id=TEST_USER_ID,
    )

    assert client.purchase_query.inserted["product_name_override"] == "Tomato"


class _ProductClientSpy:
    def __init__(self, query: QuerySpy):
        self.query = query

    def table(self, table_name: str):
        assert table_name == "products"
        return self.query


class _RecordingInsertQuery(QuerySpy):
    def __init__(self):
        super().__init__([])
        self.inserted = None

    def insert(self, payload: dict):
        self.inserted = payload
        return self


class _CommunityWriteClientSpy:
    def __init__(self):
        self.product_query = QuerySpy([{"id": "product-1", "name": "Tomato"}])
        self.purchase_query = _RecordingInsertQuery()

    def table(self, table_name: str):
        if table_name == "products":
            return self.product_query
        assert table_name == "purchases"
        return self.purchase_query


def test_raw_supabase_sdk_error_is_wrapped() -> None:
    class FailingQuery:
        def execute(self):
            raise RuntimeError("sdk internals")

    with pytest.raises(SupabaseBackendUnavailable) as error:
        supabase_backend._execute(FailingQuery(), "Failed operation.")

    assert str(error.value) == "Failed operation."


def test_scan_upload_removes_storage_object_when_database_insert_fails(
    monkeypatch,
) -> None:
    query = QuerySpy([])
    removed = []
    monkeypatch.setattr(
        supabase_backend,
        "get_supabase_client",
        lambda: _ScanInsertClientSpy(query),
    )
    monkeypatch.setattr(supabase_backend, "_upload_bytes", lambda **_kwargs: None)
    monkeypatch.setattr(
        supabase_backend,
        "_execute",
        lambda *_args, **_kwargs: (_ for _ in ()).throw(
            SupabaseBackendUnavailable("insert failed")
        ),
    )
    monkeypatch.setattr(
        supabase_backend,
        "_delete_object",
        lambda **kwargs: removed.append(kwargs),
    )

    with pytest.raises(SupabaseBackendUnavailable):
        supabase_backend.save_scan_history_image(
            image_bytes=b"image",
            filename="scan.jpg",
            content_type="image/jpeg",
            client_user_id=TEST_USER_ID,
        )

    assert len(removed) == 1
    assert removed[0]["bucket"] == supabase_backend.SCAN_HISTORY_BUCKET
    assert removed[0]["path"].startswith(f"{TEST_USER_ID}/")


class _ScanInsertClientSpy:
    def __init__(self, query: QuerySpy):
        self.query = query

    def table(self, table_name: str):
        assert table_name == "scan_histories"
        return self.query


def test_scan_history_uses_one_batch_request_for_signed_urls(monkeypatch) -> None:
    rows = [
        {"id": "1", "image_path": "owner/one.jpg", "created_at": "now"},
        {"id": "2", "image_path": "owner/two.jpg", "created_at": "now"},
    ]
    client = _HistoryListClientSpy(QuerySpy(rows))
    monkeypatch.setattr(supabase_backend, "get_supabase_client", lambda: client)

    items = supabase_backend.list_scan_history_images(
        client_user_id=TEST_USER_ID,
        limit=50,
    )

    assert client.file_api.batch_calls == [
        ["owner/one.jpg", "owner/two.jpg"],
    ]
    assert [item.image_url for item in items] == [
        "https://signed.test/owner/one.jpg",
        "https://signed.test/owner/two.jpg",
    ]


class _HistoryListClientSpy:
    def __init__(self, query: QuerySpy):
        self.query = query
        self.file_api = _StorageFileApiSpy()
        self.storage = self

    def table(self, table_name: str):
        assert table_name == "scan_histories"
        return self.query

    def from_(self, bucket: str):
        assert bucket == supabase_backend.SCAN_HISTORY_BUCKET
        return self.file_api


class _StorageFileApiSpy:
    def __init__(self):
        self.batch_calls = []

    def create_signed_urls(self, paths, _expires_in):
        self.batch_calls.append(paths)
        return [
            {
                "path": path,
                "signedURL": f"https://signed.test/{path}",
            }
            for path in paths
        ]
