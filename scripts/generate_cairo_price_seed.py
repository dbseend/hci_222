import json
import math
import statistics
from collections import defaultdict
from datetime import date
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
OBSERVED_DATE = "2026-05-13"
STAT_DATE = "2026-05-13"
OUTPUT_JSON = ROOT / "backend/app/data/cairo_price_dataset_2026_05_13.json"
OUTPUT_SQL = ROOT / "backend/supabase/seed_cairo_prices_2026_05_13.sql"


SOURCES = [
    {
        "name": "Akhbarelyom Obour fruit wholesale 2026-05-13",
        "source_type": "web_scrape",
        "url": "https://akhbarelyom.com/news/VideoDisplay/4820176/1/%D8%A3%D8%B3%D8%B9%D8%A7%D8%B1-%D8%A7%D9%84%D9%81%D8%A7%D9%83%D9%87%D8%A9-%D8%A7%D9%84%D9%8A%D9%88%D9%85-%D8%A7%D9%84%D8%A3%D8%B1%D8%A8%D8%B9%D8%A7%D8%A1-13-%D9%85%D8%A7%D9%8A%D9%88-%D9%81%D9%8A-",
        "reliability_score": 0.78,
    },
    {
        "name": "Akhbarelyom Obour vegetable wholesale 2026-05-13",
        "source_type": "web_scrape",
        "url": "https://akhbarelyom.com/news/VideoDisplay/4820173/1/%D8%A3%D8%B3%D8%B9%D8%A7%D8%B1-%D8%A7%D9%84%D8%AE%D8%B6%D8%B1%D9%88%D8%A7%D8%AA-%D8%A7%D9%84%D9%8A%D9%88%D9%85-%D8%A7%D9%84%D8%A3%D8%B1%D8%A8%D8%B9%D8%A7%D8%A1-13-%D9%85%D8%A7%D9%8A%D9%88-%D9%81%D9%8A",
        "reliability_score": 0.78,
    },
    {
        "name": "Masrawy Obour market 2026-05-13",
        "source_type": "web_scrape",
        "url": "https://www.masrawy.com/news/news_economy/details/2026/5/13/2987317/%D8%A3%D8%B3%D8%B9%D8%A7%D8%B1-%D8%A7%D9%84%D8%AE%D8%B6%D8%B1%D9%88%D8%A7%D8%AA-%D9%88%D8%A7%D9%84%D9%81%D8%A7%D9%83%D9%87%D8%A9-%D9%81%D9%8A-%D8%B3%D9%88%D9%82-%D8%A7%D9%84%D8%B9%D8%A8%D9%88%D8%B1-%D8%A7%D9%84%D9%8A%D9%88%D9%85-%D8%A7%D9%84%D8%A3%D8%B1%D8%A8%D8%B9%D8%A7%D8%A1-%D8%A7%D8%B1%D8%AA%D9%81%D8%A7%D8%B9-%D8%A7%D9%84%D8%B7%D9%85%D8%A7%D8%B7%D9%85",
        "reliability_score": 0.82,
    },
    {
        "name": "Cairo retail adjustment from Obour wholesale",
        "source_type": "manual_seed",
        "url": None,
        "reliability_score": 0.66,
    },
    {
        "name": "Carrefour Egypt online retail",
        "source_type": "web_scrape",
        "url": "https://www.carrefouregypt.com/mafegy/en/c/FEGY1660000",
        "reliability_score": 0.84,
    },
    {
        "name": "Talabat Mart Egypt online retail",
        "source_type": "web_scrape",
        "url": "https://www.talabat.com/egypt/talabat-mart",
        "reliability_score": 0.76,
    },
    {
        "name": "Noon Egypt souvenir retail",
        "source_type": "web_scrape",
        "url": "https://www.noon.com/egypt-en/",
        "reliability_score": 0.72,
    },
    {
        "name": "Diwan Egypt / PAF Dolls camel retail",
        "source_type": "web_scrape",
        "url": "https://diwanegypt.com/product/camel-doll/",
        "reliability_score": 0.74,
    },
    {
        "name": "CAPMAS April 2026 CPI context",
        "source_type": "government",
        "url": "https://www.cbe.org.eg/en/news-publications/news/2026/04/09/14/47/cpi-press-release-march-2026",
        "reliability_score": 0.9,
    },
    {
        "name": "MVP sparse-price completion",
        "source_type": "manual_seed",
        "url": None,
        "reliability_score": 0.45,
    },
]


MARKETS = [
    {"name": "Obour Wholesale Market", "company_name": "Obour Market", "city": "Cairo", "district": "Obour", "lat": 30.2290, "lng": 31.4760},
    {"name": "Downtown Cairo Retail Market", "company_name": None, "city": "Cairo", "district": "Downtown Cairo", "lat": 30.0444, "lng": 31.2357},
    {"name": "Maadi Online Grocery", "company_name": "Online Grocery", "city": "Cairo", "district": "Maadi", "lat": 29.9602, "lng": 31.2569},
    {"name": "Nasr City Online Grocery", "company_name": "Online Grocery", "city": "Cairo", "district": "Nasr City", "lat": 30.0561, "lng": 31.3300},
    {"name": "Khan el-Khalili Souvenir Market", "company_name": None, "city": "Cairo", "district": "Khan el-Khalili", "lat": 30.0478, "lng": 31.2625},
    {"name": "Giza Pyramid Souvenir Market", "company_name": None, "city": "Cairo", "district": "Giza/Pyramids", "lat": 29.9792, "lng": 31.1342},
]


def obs(product, source, market, district, unit, quantity, total, raw, confidence=0.7, status="approved", payload=None):
    return {
        "product_code": product,
        "source_name": source,
        "market_name": market,
        "city": "Cairo",
        "district": district,
        "unit": unit,
        "quantity": quantity,
        "total_price_egp": round(total, 2),
        "unit_price_egp": round(total / quantity, 2),
        "observed_at": f"{OBSERVED_DATE}T09:00:00+00:00",
        "verification_status": status,
        "confidence_score": confidence,
        "raw_product_name": raw,
        "raw_payload": payload or {},
    }


OBSERVATIONS = [
    obs("tomato", "Akhbarelyom Obour vegetable wholesale 2026-05-13", "Obour Wholesale Market", "Obour", "kg", 1, 12.5, "الطماطم wholesale low", 0.78),
    obs("tomato", "Akhbarelyom Obour vegetable wholesale 2026-05-13", "Obour Wholesale Market", "Obour", "kg", 1, 22.5, "الطماطم wholesale high", 0.78),
    obs("tomato", "Cairo retail adjustment from Obour wholesale", "Downtown Cairo Retail Market", "Downtown Cairo", "kg", 1, 18.5, "tomato retail-adjusted low", 0.66),
    obs("tomato", "Masrawy Obour market 2026-05-13", "Obour Wholesale Market", "Obour", "kg", 1, 25.0, "tomato Masrawy high", 0.82),
    obs("tomato", "Carrefour Egypt online retail", "Maadi Online Grocery", "Maadi", "kg", 0.5, 18.75, "Balady Tomatoes 500g", 0.84),
    obs("tomato", "Carrefour Egypt online retail", "Maadi Online Grocery", "Maadi", "kg", 1, 99.99, "Grade A Tomato 1 kg", 0.84),
    obs("tomato", "Talabat Mart Egypt online retail", "Nasr City Online Grocery", "Nasr City", "kg", 1, 19.95, "Khodar.Com Tomato 1kg", 0.76),

    obs("cherry_tomato", "Carrefour Egypt online retail", "Maadi Online Grocery", "Maadi", "kg", 0.25, 71.95, "Mafa Cherry Tomato 250g", 0.84),
    obs("cherry_tomato", "Carrefour Egypt online retail", "Maadi Online Grocery", "Maadi", "kg", 0.5, 60.99, "Cherry Tomato 500g", 0.84),
    obs("cherry_tomato", "MVP sparse-price completion", "Downtown Cairo Retail Market", "Downtown Cairo", "kg", 1, 70.0, "local cherry tomato manual retail seed", 0.45),

    obs("orange", "Akhbarelyom Obour fruit wholesale 2026-05-13", "Obour Wholesale Market", "Obour", "kg", 1, 10.0, "برتقال صيفي wholesale low", 0.78),
    obs("orange", "Akhbarelyom Obour fruit wholesale 2026-05-13", "Obour Wholesale Market", "Obour", "kg", 1, 20.0, "برتقال أبوسرة wholesale high", 0.78),
    obs("orange", "Cairo retail adjustment from Obour wholesale", "Downtown Cairo Retail Market", "Downtown Cairo", "kg", 1, 17.0, "orange retail-adjusted mid", 0.66),
    obs("orange", "Cairo retail adjustment from Obour wholesale", "Downtown Cairo Retail Market", "Downtown Cairo", "kg", 1, 25.0, "orange retail-adjusted high", 0.66),

    obs("lemon", "Akhbarelyom Obour vegetable wholesale 2026-05-13", "Obour Wholesale Market", "Obour", "kg", 1, 17.0, "الليمون wholesale low", 0.78),
    obs("lemon", "Akhbarelyom Obour vegetable wholesale 2026-05-13", "Obour Wholesale Market", "Obour", "kg", 1, 33.0, "الليمون wholesale high", 0.78),
    obs("lemon", "Cairo retail adjustment from Obour wholesale", "Downtown Cairo Retail Market", "Downtown Cairo", "kg", 1, 38.0, "lemon retail-adjusted high", 0.66),
    obs("lemon", "Talabat Mart Egypt online retail", "Nasr City Online Grocery", "Nasr City", "kg", 0.5, 28.75, "Fresh Source Lemon 500g", 0.76),

    obs("banana", "Masrawy Obour market 2026-05-13", "Obour Wholesale Market", "Obour", "kg", 1, 25.0, "موز بلدي wholesale low", 0.82),
    obs("banana", "Cairo retail adjustment from Obour wholesale", "Downtown Cairo Retail Market", "Downtown Cairo", "kg", 1, 35.0, "banana retail-adjusted high", 0.66),
    obs("banana", "Carrefour Egypt online retail", "Maadi Online Grocery", "Maadi", "kg", 0.5, 27.5, "Balady Bananas 500g", 0.84),
    obs("banana", "Talabat Mart Egypt online retail", "Nasr City Online Grocery", "Nasr City", "kg", 1, 45.95, "Fresh Source Local Banana 1kg", 0.76),
    obs("banana", "Talabat Mart Egypt online retail", "Nasr City Online Grocery", "Nasr City", "kg", 1, 130.95, "Khodar.Com Imported Banana 1kg", 0.76),

    obs("apple", "Akhbarelyom Obour fruit wholesale 2026-05-13", "Obour Wholesale Market", "Obour", "kg", 1, 15.0, "تفاح مصرى wholesale low", 0.78),
    obs("apple", "Akhbarelyom Obour fruit wholesale 2026-05-13", "Obour Wholesale Market", "Obour", "kg", 1, 43.0, "تفاح مصرى wholesale high", 0.78),
    obs("apple", "Carrefour Egypt online retail", "Maadi Online Grocery", "Maadi", "kg", 0.5, 55.0, "Royal Gala Apples 500g", 0.84),
    obs("apple", "Carrefour Egypt online retail", "Maadi Online Grocery", "Maadi", "kg", 0.5, 50.0, "Golden Apple Medium 500g", 0.84),
    obs("apple", "Talabat Mart Egypt online retail", "Nasr City Online Grocery", "Nasr City", "kg", 1, 110.75, "Fresh Source Red Apple Imported 1kg", 0.76),

    obs("grape", "Akhbarelyom Obour fruit wholesale 2026-05-13", "Obour Wholesale Market", "Obour", "kg", 1, 40.0, "العنب wholesale low", 0.78),
    obs("grape", "Akhbarelyom Obour fruit wholesale 2026-05-13", "Obour Wholesale Market", "Obour", "kg", 1, 60.0, "العنب wholesale high", 0.78),
    obs("grape", "Cairo retail adjustment from Obour wholesale", "Downtown Cairo Retail Market", "Downtown Cairo", "kg", 1, 65.0, "grape retail-adjusted high", 0.66),
    obs("grape", "Masrawy Obour market 2026-05-13", "Obour Wholesale Market", "Obour", "kg", 1, 35.0, "grape Masrawy low", 0.82),

    obs("guava", "Akhbarelyom Obour fruit wholesale 2026-05-13", "Obour Wholesale Market", "Obour", "kg", 1, 12.0, "الجوافة wholesale low", 0.78),
    obs("guava", "Akhbarelyom Obour fruit wholesale 2026-05-13", "Obour Wholesale Market", "Obour", "kg", 1, 34.0, "الجوافة wholesale high", 0.78),
    obs("guava", "Cairo retail adjustment from Obour wholesale", "Downtown Cairo Retail Market", "Downtown Cairo", "kg", 1, 39.0, "guava retail-adjusted high", 0.66),

    obs("pomegranate", "Akhbarelyom Obour fruit wholesale 2026-05-13", "Obour Wholesale Market", "Obour", "kg", 1, 15.0, "الرمان wholesale low", 0.78),
    obs("pomegranate", "Akhbarelyom Obour fruit wholesale 2026-05-13", "Obour Wholesale Market", "Obour", "kg", 1, 35.0, "الرمان wholesale high", 0.78),
    obs("pomegranate", "Cairo retail adjustment from Obour wholesale", "Downtown Cairo Retail Market", "Downtown Cairo", "kg", 1, 40.0, "pomegranate retail-adjusted high", 0.66),

    obs("strawberry", "Akhbarelyom Obour fruit wholesale 2026-05-13", "Obour Wholesale Market", "Obour", "kg", 1, 15.0, "الفراولة wholesale low", 0.78),
    obs("strawberry", "Akhbarelyom Obour fruit wholesale 2026-05-13", "Obour Wholesale Market", "Obour", "kg", 1, 25.0, "الفراولة wholesale high", 0.78),
    obs("strawberry", "Cairo retail adjustment from Obour wholesale", "Downtown Cairo Retail Market", "Downtown Cairo", "kg", 1, 30.0, "strawberry retail-adjusted high", 0.66),
    obs("strawberry", "Talabat Mart Egypt online retail", "Nasr City Online Grocery", "Nasr City", "kg", 0.45, 119.95, "My Very Strawberries 450g", 0.76),

    obs("rockmelon", "Akhbarelyom Obour fruit wholesale 2026-05-13", "Obour Wholesale Market", "Obour", "kg", 1, 9.0, "الكانتلوب wholesale low", 0.78),
    obs("rockmelon", "Masrawy Obour market 2026-05-13", "Obour Wholesale Market", "Obour", "kg", 1, 18.0, "cantaloupe Masrawy high", 0.82),
    obs("rockmelon", "Cairo retail adjustment from Obour wholesale", "Downtown Cairo Retail Market", "Downtown Cairo", "kg", 1, 23.0, "cantaloupe retail-adjusted high", 0.66),
    obs("rockmelon", "Talabat Mart Egypt online retail", "Nasr City Online Grocery", "Nasr City", "kg", 2, 74.95, "Fresh Source Cantaloupe 2kg", 0.76),

    obs("mango", "Akhbarelyom Obour fruit wholesale 2026-05-13", "Obour Wholesale Market", "Obour", "kg", 1, 20.0, "مانجو بلدية wholesale low", 0.78),
    obs("mango", "Akhbarelyom Obour fruit wholesale 2026-05-13", "Obour Wholesale Market", "Obour", "kg", 1, 50.0, "مانجو زبدية wholesale high", 0.78),
    obs("mango", "Cairo retail adjustment from Obour wholesale", "Downtown Cairo Retail Market", "Downtown Cairo", "kg", 1, 55.0, "mango retail-adjusted high", 0.66),

    obs("peach", "Masrawy Obour market 2026-05-13", "Obour Wholesale Market", "Obour", "kg", 1, 20.0, "خوخ بلدي wholesale low", 0.82),
    obs("peach", "Masrawy Obour market 2026-05-13", "Obour Wholesale Market", "Obour", "kg", 1, 40.0, "خوخ بلدي wholesale high", 0.82),
    obs("peach", "Carrefour Egypt online retail", "Maadi Online Grocery", "Maadi", "kg", 0.5, 22.5, "Peach 500g", 0.84),

    obs("watermelon", "Akhbarelyom Obour fruit wholesale 2026-05-13", "Obour Wholesale Market", "Obour", "kg", 1, 7.0, "watermelon normalized low from whole fruit", 0.68),
    obs("watermelon", "Akhbarelyom Obour fruit wholesale 2026-05-13", "Obour Wholesale Market", "Obour", "kg", 1, 10.0, "watermelon normalized mid from whole fruit", 0.68),
    obs("watermelon", "Cairo retail adjustment from Obour wholesale", "Downtown Cairo Retail Market", "Downtown Cairo", "kg", 1, 20.0, "watermelon retail-adjusted high", 0.62),

    obs("dates", "Masrawy Obour market 2026-05-13", "Obour Wholesale Market", "Obour", "kg", 1, 24.0, "بلح ثلاجة wholesale low", 0.72),
    obs("dates", "Masrawy Obour market 2026-05-13", "Obour Wholesale Market", "Obour", "kg", 1, 30.0, "بلح ثلاجة wholesale high", 0.72),
    obs("dates", "Cairo retail adjustment from Obour wholesale", "Downtown Cairo Retail Market", "Downtown Cairo", "kg", 1, 35.0, "dates retail-adjusted high", 0.62),

    obs("grapefruit", "Akhbarelyom Obour fruit wholesale 2026-05-13", "Obour Wholesale Market", "Obour", "kg", 1, 9.0, "الجريب فروت wholesale low", 0.78),
    obs("grapefruit", "Akhbarelyom Obour fruit wholesale 2026-05-13", "Obour Wholesale Market", "Obour", "kg", 1, 15.0, "الجريب فروت wholesale high", 0.78),
    obs("grapefruit", "Cairo retail adjustment from Obour wholesale", "Downtown Cairo Retail Market", "Downtown Cairo", "kg", 1, 20.0, "grapefruit retail-adjusted high", 0.66),

    obs("mandarin", "Akhbarelyom Obour fruit wholesale 2026-05-13", "Obour Wholesale Market", "Obour", "kg", 1, 12.0, "اليوسفي wholesale low", 0.78),
    obs("mandarin", "Akhbarelyom Obour fruit wholesale 2026-05-13", "Obour Wholesale Market", "Obour", "kg", 1, 22.0, "اليوسفي wholesale high", 0.78),
    obs("mandarin", "Cairo retail adjustment from Obour wholesale", "Downtown Cairo Retail Market", "Downtown Cairo", "kg", 1, 27.0, "mandarin retail-adjusted high", 0.66),

    obs("avocado", "Talabat Mart Egypt online retail", "Nasr City Online Grocery", "Nasr City", "kg", 0.5, 99.95, "Pico Avocado Ripe 500g", 0.76),
    obs("avocado", "Talabat Mart Egypt online retail", "Nasr City Online Grocery", "Nasr City", "kg", 0.5, 124.95, "Fresh Source Imported Avocado 500g", 0.76),
    obs("avocado", "Carrefour Egypt online retail", "Maadi Online Grocery", "Maadi", "kg", 0.5, 115.0, "Imported Avocado 500g", 0.84),

    obs("kiwi", "Carrefour Egypt online retail", "Maadi Online Grocery", "Maadi", "kg", 0.5, 84.98, "Kiwi 500g", 0.84),
    obs("kiwi", "Talabat Mart Egypt online retail", "Nasr City Online Grocery", "Nasr City", "kg", 0.25, 45.95, "Khodar.Com Imported Kiwi 250g", 0.76),
    obs("kiwi", "Talabat Mart Egypt online retail", "Nasr City Online Grocery", "Nasr City", "kg", 0.5, 97.95, "Fresh Source Imported Kiwi 500g", 0.76),

    obs("blueberry", "Talabat Mart Egypt online retail", "Nasr City Online Grocery", "Nasr City", "kg", 0.125, 144.95, "My Very Blueberries 125g", 0.76),
    obs("blueberry", "Talabat Mart Egypt online retail", "Nasr City Online Grocery", "Nasr City", "kg", 0.125, 129.95, "Hygiene Blueberries 125g", 0.72),
    obs("blueberry", "MVP sparse-price completion", "Maadi Online Grocery", "Maadi", "kg", 0.125, 49.99, "legacy Carrefour blueberry punnet 125g seed", 0.42),

    obs("pineapple", "Talabat Mart Egypt online retail", "Nasr City Online Grocery", "Nasr City", "pcs", 1, 254.95, "Khodar.Com Sweet Pineapple Pc", 0.76),
    obs("pineapple", "MVP sparse-price completion", "Downtown Cairo Retail Market", "Downtown Cairo", "pcs", 1, 180.0, "whole pineapple manual retail seed", 0.45),
    obs("pineapple", "MVP sparse-price completion", "Downtown Cairo Retail Market", "Downtown Cairo", "pcs", 1, 220.0, "whole pineapple manual retail seed high", 0.45),

    obs("cherry", "MVP sparse-price completion", "Maadi Online Grocery", "Maadi", "kg", 1, 180.0, "imported cherry sparse retail seed low", 0.42),
    obs("cherry", "MVP sparse-price completion", "Maadi Online Grocery", "Maadi", "kg", 1, 220.0, "imported cherry sparse retail seed mid", 0.42),
    obs("cherry", "MVP sparse-price completion", "Maadi Online Grocery", "Maadi", "kg", 1, 260.0, "imported cherry sparse retail seed high", 0.42),

    obs("plum", "MVP sparse-price completion", "Downtown Cairo Retail Market", "Downtown Cairo", "kg", 1, 180.0, "plum sparse retail seed low", 0.42),
    obs("plum", "MVP sparse-price completion", "Downtown Cairo Retail Market", "Downtown Cairo", "kg", 1, 190.0, "plum sparse retail seed mid", 0.42),
    obs("plum", "MVP sparse-price completion", "Downtown Cairo Retail Market", "Downtown Cairo", "kg", 1, 200.0, "plum sparse retail seed high", 0.42),

    obs("fruit", "MVP sparse-price completion", "Downtown Cairo Retail Market", "Downtown Cairo", "kg", 1, 25.0, "generic fruit basket sparse seed low", 0.4),
    obs("fruit", "MVP sparse-price completion", "Downtown Cairo Retail Market", "Downtown Cairo", "kg", 1, 55.0, "generic fruit basket sparse seed mid", 0.4),
    obs("fruit", "MVP sparse-price completion", "Downtown Cairo Retail Market", "Downtown Cairo", "kg", 1, 90.0, "generic fruit basket sparse seed high", 0.4),

    obs("camel_doll", "Noon Egypt souvenir retail", "Giza Pyramid Souvenir Market", "Giza/Pyramids", "pcs", 1, 684.0, "Camel Fur Plush Toy souvenir", 0.72),
    obs("camel_doll", "Diwan Egypt / PAF Dolls camel retail", "Khan el-Khalili Souvenir Market", "Khan el-Khalili", "pcs", 1, 1100.0, "Camel Doll PAF Dolls", 0.74),
    obs("camel_doll", "Noon Egypt souvenir retail", "Giza Pyramid Souvenir Market", "Giza/Pyramids", "pcs", 1, 319.0, "Collecta Dromedary Camel figure", 0.7),
    obs("camel_doll", "Cairo retail adjustment from Obour wholesale", "Khan el-Khalili Souvenir Market", "Khan el-Khalili", "pcs", 1, 250.0, "small bazaar camel souvenir manual seed", 0.5),
]


AR_ALIASES = {
    "apple": ["تفاح", "تفاح مصري", "تفاح مستورد"],
    "avocado": ["أفوكادو"],
    "banana": ["موز", "موز بلدي", "موز مستورد"],
    "blueberry": ["توت أزرق", "بلوبيري"],
    "camel_doll": ["جمل لعبة", "دمية جمل", "تذكار جمل"],
    "cherry_tomato": ["طماطم شيري"],
    "dates": ["بلح", "تمر"],
    "grape": ["عنب", "عنب أحمر", "عنب بناتي"],
    "grapefruit": ["جريب فروت"],
    "guava": ["جوافة"],
    "kiwi": ["كيوي"],
    "lemon": ["ليمون", "ليمون بلدي"],
    "mandarin": ["يوسفي"],
    "mango": ["مانجو", "مانجو بلدي", "مانجو زبدية"],
    "orange": ["برتقال", "برتقال صيفي", "برتقال أبو سرة"],
    "peach": ["خوخ"],
    "pineapple": ["أناناس"],
    "pomegranate": ["رمان"],
    "rockmelon": ["كنتالوب", "شمام"],
    "strawberry": ["فراولة"],
    "tomato": ["طماطم", "بندورة"],
    "watermelon": ["بطيخ"],
}


def sql_str(value):
    if value is None:
        return "null"
    if isinstance(value, (int, float)):
        return str(value)
    return "'" + str(value).replace("'", "''") + "'"


def sql_json(value):
    return sql_str(json.dumps(value, ensure_ascii=False, sort_keys=True)) + "::jsonb"


def distribution(values, bucket_count=8):
    if not values:
        return []
    lo, hi = min(values), max(values)
    if math.isclose(lo, hi):
        return [{"bucket_start": round(lo, 2), "bucket_end": round(hi, 2), "count": len(values)}]
    width = (hi - lo) / bucket_count
    buckets = []
    for i in range(bucket_count):
        start = lo + width * i
        end = hi if i == bucket_count - 1 else lo + width * (i + 1)
        count = sum(1 for value in values if start <= value <= end) if i == bucket_count - 1 else sum(1 for value in values if start <= value < end)
        buckets.append({"bucket_start": round(start, 2), "bucket_end": round(end, 2), "count": count})
    return buckets


def stats_for(product_code, rows):
    values = sorted(row["unit_price_egp"] for row in rows)
    return {
        "stat_date": STAT_DATE,
        "product_code": product_code,
        "city": "Cairo",
        "district": None,
        "unit": rows[0]["unit"],
        "currency": "EGP",
        "avg_price": round(statistics.mean(values), 2),
        "median_price": round(statistics.median(values), 2),
        "min_price": round(min(values), 2),
        "max_price": round(max(values), 2),
        "stddev_price": round(statistics.pstdev(values), 2) if len(values) > 1 else 0,
        "p10_price": round(values[max(0, math.floor((len(values) - 1) * 0.1))], 2),
        "p90_price": round(values[min(len(values) - 1, math.ceil((len(values) - 1) * 0.9))], 2),
        "sample_count": len(values),
        "distribution": distribution(values),
    }


def main():
    catalog = json.loads((ROOT / "backend/app/data/product_catalog.json").read_text())
    products = []
    for item in catalog:
        unit = "pcs" if item["unit"] in {"piece", "pcs"} else "kg"
        products.append(
            {
                "code": item["product_id"],
                "name": item["display_name"],
                "default_unit": unit,
                "aliases": item.get("aliases", []),
            }
        )

    by_product = defaultdict(list)
    for row in OBSERVATIONS:
        by_product[row["product_code"]].append(row)
    stats = [stats_for(product_code, rows) for product_code, rows in sorted(by_product.items())]

    dataset = {
        "generated_at": date.today().isoformat(),
        "observed_date": OBSERVED_DATE,
        "scope": "Cairo MVP seed prices for TruePrice",
        "unit_policy": "kg for produce; pcs for whole pineapple and camel_doll. Package prices keep original quantity, while unit_price_egp normalizes for statistics.",
        "products": products,
        "markets": MARKETS,
        "sources": SOURCES,
        "observations": OBSERVATIONS,
        "daily_price_stats": stats,
        "exchange_rates": [
            {
                "base_currency": "EGP",
                "quote_currency": "KRW",
                "rate": 28.1348,
                "as_of_date": OBSERVED_DATE,
                "source": "currencyrate.today EGP/KRW 2026-05-13 07:00 UTC",
            }
        ],
    }
    OUTPUT_JSON.write_text(json.dumps(dataset, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    source_rows = (
        "  "
        + ",\n  ".join(
            f"({sql_str(s['name'])}, {sql_str(s['source_type'])}, {sql_str(s['url'])}, {s['reliability_score']})"
            for s in SOURCES
        )
    )

    lines = [
        "-- Cairo price seed for TruePrice MVP",
        "-- Generated from scripts/generate_cairo_price_seed.py",
        "-- Assumes the reviewed schema exists: price_sources, product_aliases, price_observations, daily_price_stats.",
        "begin;",
        "",
        "with source_rows (name, source_type, url, reliability_score) as (",
        "  values",
        source_rows,
        ")",
        "insert into price_sources (name, source_type, url, reliability_score)",
        "select sr.name, sr.source_type, sr.url, sr.reliability_score",
        "from source_rows sr",
        "where not exists (",
        "  select 1 from price_sources ps where ps.name = sr.name",
        ");",
        "",
    ]

    lines.append("insert into products (code, name, default_unit, is_active)")
    lines.append("values")
    lines.append(
        "  "
        + ",\n  ".join(
            f"({sql_str(p['code'])}, {sql_str(p['name'])}, {sql_str(p['default_unit'])}, true)"
            for p in products
        )
        + "\non conflict (code) do update set name = excluded.name, default_unit = excluded.default_unit, is_active = true, updated_at = now();"
    )
    lines.append("")

    alias_rows = []
    for p in products:
        for alias in p["aliases"]:
            alias_rows.append((p["code"], alias, "en", "product_catalog"))
        for alias in AR_ALIASES.get(p["code"], []):
            alias_rows.append((p["code"], alias, "ar", "seed_2026_05_13"))
    lines.append("with alias_rows (product_code, alias, locale, source) as (")
    lines.append("  values")
    lines.append("  " + ",\n  ".join(f"({sql_str(*row[:1]) if False else sql_str(row[0])}, {sql_str(row[1])}, {sql_str(row[2])}, {sql_str(row[3])})" for row in alias_rows))
    lines.append(")")
    lines.append("insert into product_aliases (product_id, alias, locale, source)")
    lines.append("select p.id, ar.alias, ar.locale, ar.source")
    lines.append("from alias_rows ar")
    lines.append("join products p on p.code = ar.product_code")
    lines.append("on conflict (product_id, alias) do nothing;")
    lines.append("")

    lines.append("insert into markets (name, company_name, country_code, city, district, lat, lng, is_active)")
    lines.append("values")
    lines.append(
        "  "
        + ",\n  ".join(
            f"({sql_str(m['name'])}, {sql_str(m['company_name'])}, 'EG', {sql_str(m['city'])}, {sql_str(m['district'])}, {m['lat']}, {m['lng']}, true)"
            for m in MARKETS
        )
        + "\non conflict (name) do update set company_name = excluded.company_name, country_code = excluded.country_code, city = excluded.city, district = excluded.district, lat = excluded.lat, lng = excluded.lng, is_active = true, updated_at = now();"
    )
    lines.append("")

    lines.append("with observation_rows (product_code, market_name, source_name, source_type, city, district, unit, quantity, total_price_egp, observed_at, verification_status, confidence_score, raw_product_name, raw_payload) as (")
    lines.append("  values")
    lines.append(
        "  "
        + ",\n  ".join(
            "("
            + ", ".join(
                [
                    sql_str(row["product_code"]),
                    sql_str(row["market_name"]),
                    sql_str(row["source_name"]),
                    sql_str(next(source["source_type"] for source in SOURCES if source["name"] == row["source_name"])),
                    sql_str(row["city"]),
                    sql_str(row["district"]),
                    sql_str(row["unit"]),
                    str(row["quantity"]),
                    str(row["total_price_egp"]),
                    sql_str(row["observed_at"]),
                    sql_str(row["verification_status"]),
                    str(row["confidence_score"]),
                    sql_str(row["raw_product_name"]),
                    sql_json(row["raw_payload"]),
                ]
            )
            + ")"
            for row in OBSERVATIONS
        )
    )
    lines.append(")")
    lines.append("insert into price_observations (product_id, market_id, source_id, source_type, city, district, unit, quantity, total_price_egp, observed_at, verification_status, confidence_score, raw_product_name, raw_payload)")
    lines.append("select p.id, m.id, s.id, r.source_type, r.city, r.district, r.unit, r.quantity, r.total_price_egp, r.observed_at::timestamptz, r.verification_status, r.confidence_score, r.raw_product_name, r.raw_payload")
    lines.append("from observation_rows r")
    lines.append("join products p on p.code = r.product_code")
    lines.append("left join markets m on m.name = r.market_name")
    lines.append("left join (select distinct on (name) id, name from price_sources order by name, created_at asc) s on s.name = r.source_name")
    lines.append("where not exists (")
    lines.append("  select 1 from price_observations po")
    lines.append("  where po.product_id = p.id")
    lines.append("    and coalesce(po.market_id, '00000000-0000-0000-0000-000000000000'::uuid) = coalesce(m.id, '00000000-0000-0000-0000-000000000000'::uuid)")
    lines.append("    and po.source_id = s.id")
    lines.append("    and po.unit = r.unit")
    lines.append("    and po.quantity = r.quantity")
    lines.append("    and po.total_price_egp = r.total_price_egp")
    lines.append("    and po.observed_at = r.observed_at::timestamptz")
    lines.append(");")
    lines.append("")

    lines.append("with stat_rows (stat_date, product_code, city, district, unit, currency, avg_price, median_price, min_price, max_price, stddev_price, p10_price, p90_price, sample_count, distribution) as (")
    lines.append("  values")
    lines.append(
        "  "
        + ",\n  ".join(
            "("
            + ", ".join(
                [
                    sql_str(row["stat_date"]),
                    sql_str(row["product_code"]),
                    sql_str(row["city"]),
                    sql_str(row["district"]),
                    sql_str(row["unit"]),
                    sql_str(row["currency"]),
                    str(row["avg_price"]),
                    str(row["median_price"]),
                    str(row["min_price"]),
                    str(row["max_price"]),
                    str(row["stddev_price"]),
                    str(row["p10_price"]),
                    str(row["p90_price"]),
                    str(row["sample_count"]),
                    sql_json(row["distribution"]),
                ]
            )
            + ")"
            for row in stats
        )
    )
    lines.append(")")
    lines.append("insert into daily_price_stats (stat_date, product_id, city, district, unit, currency, avg_price, median_price, min_price, max_price, stddev_price, p10_price, p90_price, sample_count, distribution)")
    lines.append("select sr.stat_date::date, p.id, sr.city, sr.district, sr.unit, sr.currency, sr.avg_price, sr.median_price, sr.min_price, sr.max_price, sr.stddev_price, sr.p10_price, sr.p90_price, sr.sample_count, sr.distribution")
    lines.append("from stat_rows sr")
    lines.append("join products p on p.code = sr.product_code")
    lines.append("where not exists (")
    lines.append("  select 1 from daily_price_stats dps")
    lines.append("  where dps.stat_date = sr.stat_date::date")
    lines.append("    and dps.product_id = p.id")
    lines.append("    and dps.city = sr.city")
    lines.append("    and dps.district is not distinct from sr.district")
    lines.append("    and dps.unit = sr.unit")
    lines.append(");")
    lines.append("")

    lines.append("insert into exchange_rates (base_currency, quote_currency, rate, as_of_date, source)")
    lines.append("select 'EGP', 'KRW', 28.1348, '2026-05-13'::date, 'currencyrate.today EGP/KRW 2026-05-13 07:00 UTC'")
    lines.append("where not exists (")
    lines.append("  select 1 from exchange_rates")
    lines.append("  where base_currency = 'EGP' and quote_currency = 'KRW' and as_of_date = '2026-05-13'::date")
    lines.append(");")
    lines.append("")
    lines.append("commit;")
    lines.append("")
    OUTPUT_SQL.write_text("\n".join(lines), encoding="utf-8")


if __name__ == "__main__":
    main()
