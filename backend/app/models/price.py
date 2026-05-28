from typing import Literal

from pydantic import BaseModel, Field


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
    data_source: str = "Cairo reference observations"


class PriceCompareRequest(BaseModel):
    product_id: str
    region: str = "cairo"
    user_price: float = Field(gt=0)
    currency: str = "EGP"


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
