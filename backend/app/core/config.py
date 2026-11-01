from app.core.env import env_value


DEFAULT_REGION = (
    env_value("TRUEPRICE_DEFAULT_REGION", "cairo") or "cairo"
).strip().lower()
DEFAULT_CURRENCY = "EGP"
