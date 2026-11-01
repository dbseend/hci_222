import sys
from pathlib import Path

import pytest


BACKEND_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(BACKEND_DIR))

from app.core.auth import AuthenticatedUser, get_current_user
from app.main import app


TEST_USER_ID = "11111111-1111-4111-8111-111111111111"


@pytest.fixture
def anyio_backend():
    return "asyncio"


@pytest.fixture(autouse=True)
def authenticated_user_override():
    app.dependency_overrides[get_current_user] = lambda: AuthenticatedUser(
        id=TEST_USER_ID,
        is_anonymous=True,
    )
    yield
    app.dependency_overrides.pop(get_current_user, None)
