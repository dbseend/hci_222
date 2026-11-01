from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

from app.core.config import DEFAULT_CURRENCY, DEFAULT_REGION


Verdict = Literal["safe", "negotiable", "warning"]


class Product(BaseModel):
    product_id: str
    display_name: str
    unit: str
    aliases: list[str] = Field(default_factory=list)


class PriceStats(BaseModel):
    product_id: str
    region: str
    currency: str
    avg_price: float
    median_price: float
    min_price: float
    max_price: float
    stddev_price: float
    sample_count: int
    window_days: int | None = None
    stat_date: str | None = None
    data_source: str = "Regional reference observations"


class PriceCompareRequest(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True, allow_inf_nan=False)

    product_id: str = Field(min_length=1, max_length=64, pattern=r"^[a-z0-9_]+$")
    region: str = Field(default=DEFAULT_REGION, min_length=1, max_length=64)
    user_price: float = Field(gt=0, le=1_000_000)
    currency: str = Field(default=DEFAULT_CURRENCY, min_length=3, max_length=3)


class PriceCompareResponse(BaseModel):
    product_id: str
    display_name: str
    unit: str
    region: str
    currency: str
    user_price: float
    avg_price: float
    median_price: float
    min_price: float
    max_price: float
    stddev_price: float
    sample_count: int
    percent_diff: float
    verdict: Verdict
    message: str
