# The Data-Driven Social Engagement Initiative

An end-to-end analytics pipeline that scores social content performance, tags audience sentiment with an NLP classifier, computes a custom **Viral Coefficient**, runs A/B/ANOVA significance tests on content variables, and recommends the next post to publish — all backed by a reproducible dataset and an interactive dashboard.

---

## Table of contents

- [Deliverables](#deliverables-per-project-brief)
- [Project structure](#project-structure)
- [Setup](#setup)
- [Running the pipeline](#running-the-pipeline)
- [Methodology](#methodology)
  - [1. Data Extraction Engine](#1-data-extraction-engine-generate_datapy)
  - [2. Viral Coefficient](#2-viral-coefficient-analysispy)
  - [3. NLP Sentiment / Problem-Awareness Tagger](#3-nlp-sentiment--problem-awareness-tagger-sentiment_modelpy)
  - [4. A/B Testing Framework](#4-ab-testing-framework-analysispy)
  - [5. Engagement Optimization Recommender](#5-engagement-optimization-recommender-analysispy)
  - [6. Dashboard](#6-dashboard-build_dashboardpy--app_streamlitpy)
- [Key results](#key-results)
- [A note on the data source](#a-note-on-the-data-source)
- [Reproducibility](#reproducibility)
- [Tech stack](#tech-stack)
- [License](#license)

---

## Deliverables (per project brief)

| # | Deliverable | Location |
|---|---|---|
| 1 | Analytics Dashboard | `dashboard/dashboard.html` (Plotly, static — open in any browser) and `scripts/app_streamlit.py` (interactive, run with Streamlit) |
| 2 | Structured Dataset | `dataset/dataset_posts_scored.csv` (180 posts) and `dataset/dataset_comments_tagged.csv` (594 comments) |
| 3 | NLP Sentiment Model | `scripts/sentiment_model.py` |
| 4 | Strategy Report | `reports/Strategy_Report.docx` |
| 5 | Content Series | `reports/Content_Series.docx` — 6 post concepts used as the test subject |

---

## Project structure

```
submission/
├── README.md
├── dashboard/
│   └── dashboard.html              # static Plotly dashboard, no server needed
├── dataset/
│   ├── dataset_posts.csv           # raw generated posts (pre-analysis)
│   ├── dataset_posts_scored.csv    # posts + viral_coefficient, save_to_share_ratio
│   ├── dataset_comments.csv        # raw generated comments (pre-tagging)
│   └── dataset_comments_tagged.csv # comments + NLP labels
├── reports/
│   ├── Strategy_Report.docx
│   └── Content_Series.docx
└── scripts/
    ├── generate_data.py            # Module 1 — Data Extraction Engine
    ├── sentiment_model.py          # Module 3 — NLP Sentiment Analyzer
    ├── analysis.py                 # Modules 2, 4, 5 — Viral Coefficient, A/B tests, Recommender
    ├── build_dashboard.py          # Module 6 — Dashboard builder
    └── app_streamlit.py            # Interactive Streamlit version of the dashboard
```

---

## Setup

Requires Python 3.9+.

```bash
git clone <your-repo-url>
cd submission/scripts

pip install pandas numpy scipy textblob plotly streamlit
python3 -m textblob.download_corpora
```

The `textblob` corpora download is a one-time step (pulls NLTK data for tokenization/subjectivity scoring).

---

## Running the pipeline

Scripts must run **in this order** — each stage writes a CSV the next stage reads.

```bash
cd scripts

python3 generate_data.py       # writes dataset_posts.csv, dataset_comments.csv
python3 sentiment_model.py     # writes dataset_comments_tagged.csv
python3 analysis.py            # writes dataset_posts_scored.csv, prints all stats
python3 build_dashboard.py     # writes dashboard.html
```

To view results:

```bash
open dashboard.html                        # static dashboard, macOS
# or just double-click dashboard.html in a file browser

streamlit run app_streamlit.py             # interactive dashboard, http://localhost:8501
```

---

## Methodology

### 1. Data Extraction Engine (`generate_data.py`)

Stands in for the Content Performance Tracker (the module that would normally call the Instagram Graph API / YouTube Data API or scrape via Selenium + BeautifulSoup). Produces:

- **180 posts** across 10 emotional/topic categories (Social Anxiety, Dating, Career Burnout, Body Image, Loneliness, etc.), each with `format` (Short/Long), `hook_type` (Visual/Text), `post_time` (Morning/Afternoon/Evening/Night), `reach`, `likes`, `comments_count`, `shares`, `saves`, `retention_rate`, `followers_gained`.
- **594 comments** distributed across those posts, generated from two pools (relatable-identification phrases vs. generic praise) so the dataset has an internal, simulated ground-truth label (`true_label_sim`) to validate the NLP tagger against.

Generation is **seeded** (`random.seed(42)`, `np.random.seed(42)`) with a hidden per-topic "relatability weight" baked into the generator — this is the pattern the downstream pipeline is meant to discover independently (see [Key results](#key-results): it does).

### 2. Viral Coefficient (`analysis.py`)

A weighted engagement score per post, favoring high-intent actions (shares, saves) over passive ones (likes):

```
viral_coefficient = (shares × 3.0 + saves × 2.5 + likes × 1.0) / reach × 100
```

Aggregated by topic to rank which emotional themes travel furthest relative to their reach.

### 3. NLP Sentiment / Problem-Awareness Tagger (`sentiment_model.py`)

Classifies each comment as **Relatable** or **Neutral** — i.e., does the audience see themselves in the content, versus giving generic/low-signal praise ("cute outfit", "good editing").

Deliberately a **transparent lexicon + polarity model**, not a black-box classifier, so every tag is explainable in the Strategy Report:

1. **Trigger lexicon** — ~24 regex patterns for first-person identification phrases (`"this is me"`, `"felt this"`, `"called me out"`, `"stop reading my mind"`, `"crying"`, `"hit different"`, etc.).
2. **TextBlob subjectivity** as a secondary signal — relatable comments skew personal/subjective; generic praise skews low-subjectivity.
3. Weighted score: `score = trigger_hits × 1.0 + subjectivity × 0.4`, labeled `Relatable` if `score ≥ 0.4`.

Validated against the generator's simulated ground truth (`true_label_sim`) — see accuracy in [Key results](#key-results).

### 4. A/B Testing Framework (`analysis.py`)

Tests whether each content variable produces a statistically significant difference in `viral_coefficient`:

- **`format`** (Short vs. Long) and **`hook_type`** (Visual vs. Text) — independent two-sample **Welch's t-test** (`scipy.stats.ttest_ind`, `equal_var=False`).
- **`post_time`** (4 levels) — **one-way ANOVA** (`scipy.stats.f_oneway`).

Reports t/F statistic, p-value, and significance at α = 0.05 for each.

### 5. Engagement Optimization Recommender (`analysis.py`)

Picks the single best-performing level of each variable (topic, format, hook, post time) by mean viral coefficient, and — where a post with that exact combination exists in the dataset — reports its actual observed viral coefficient as the expected value for next week's recommended post.

### 6. Dashboard (`build_dashboard.py` / `app_streamlit.py`)

Two versions of the same visualization suite (viral coefficient by topic, reach vs. engagement, save-to-share ratio, sentiment distribution, A/B test results):

- `dashboard.html` — static Plotly export, opens with no dependencies, no server.
- `app_streamlit.py` — same charts, interactive filters, requires `streamlit run`.

---

## Key results

*(from the last full pipeline run — regenerate to reproduce exactly, see [Reproducibility](#reproducibility))*

- **NLP tagger accuracy**: 87.2% agreement with simulated ground truth (324 Relatable / 270 Neutral out of 594 comments).
- **Highest viral coefficient by topic**: Loneliness (26.42), Social Anxiety (25.28), Body Image (23.53) — recovers the generator's hidden topic-weight ranking without being told it.
- **A/B tests**: none of `format`, `hook_type`, or `post_time` reached significance at α = 0.05 in this dataset (p = 0.496, 0.084, 0.661 respectively) — reported honestly in the Strategy Report rather than overstated.
- **Recommendation**: Loneliness / Short / Text / Morning → expected viral coefficient 29.82.

## A note on the data source

No live Instagram/YouTube API access was available in the project timeframe, so `generate_data.py` produces a **seeded, internally-consistent synthetic dataset** standing in for that live API/scrape output — it is not scraped from real social platforms.

Every number in the dashboard and reports downstream of that dataset is a **real, computed output** of the pipeline (nothing is hardcoded) — the statistical methodology, NLP tagging, and A/B/ANOVA testing are all genuine and reproducible. The synthetic input is the one substitution made under deadline constraints, and it's isolated to a single module: swapping `generate_data.py`'s output for a real Instagram Graph API / YouTube Data API pull requires no changes anywhere else, since every downstream script only depends on the CSV schema (`dataset_posts.csv`, `dataset_comments.csv`).

## Reproducibility

`generate_data.py` seeds both `random` and `numpy.random` with `42`. Deleting all CSVs and rerunning the four scripts in order reproduces byte-identical output every time — this is what makes the "not hardcoded" claim checkable rather than just asserted.

## Tech stack

| Layer | Tool |
|---|---|
| Data generation | Python, NumPy |
| Data wrangling | Pandas |
| NLP | TextBlob (regex lexicon + polarity/subjectivity) |
| Statistics | SciPy (`stats.ttest_ind`, `stats.f_oneway`) |
| Visualization | Plotly (static export + Streamlit interactive) |
| Reports | Word (.docx) |

## License

Add your license of choice here (e.g. MIT) before pushing publicly, or omit this section if the repo is private/for coursework submission only.
