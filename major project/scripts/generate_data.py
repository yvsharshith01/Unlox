"""
Content Performance Tracker - Data Extraction Engine (simulated)
Generates a structured dataset of post performance + user comments.
In production this module would call the Instagram Graph API / YouTube Data API
or scrape via Selenium+BeautifulSoup. For this deliverable, a seeded random
generator produces realistic, internally-consistent data so every downstream
module (viral coefficient, sentiment, A/B testing, dashboard) runs on real numbers.
"""
import random
import numpy as np
import pandas as pd
from datetime import datetime, timedelta

random.seed(42)
np.random.seed(42)

TOPICS = [
    "Social Anxiety", "Dating", "Career Burnout", "Family Pressure",
    "Body Image", "Financial Stress", "Loneliness", "Imposter Syndrome",
    "Friendship Fallouts", "Overthinking"
]

FORMATS = ["Short", "Long"]
HOOKS = ["Visual", "Text"]
POST_TIMES = ["Morning", "Afternoon", "Evening", "Night"]

# Baseline "relatability weight" per topic (ground truth we simulate around,
# unknown to the analysis pipeline - this is what the pipeline should discover)
TOPIC_WEIGHT = {
    "Social Anxiety": 1.6, "Dating": 1.3, "Career Burnout": 1.4,
    "Family Pressure": 1.1, "Body Image": 1.5, "Financial Stress": 1.2,
    "Loneliness": 1.7, "Imposter Syndrome": 1.35, "Friendship Fallouts": 1.05,
    "Overthinking": 1.45
}

RELATABLE_COMMENTS = [
    "this is literally me", "wait why is this so accurate", "I felt this in my soul",
    "stop reading my mind", "omg I needed to hear this today", "the way this called me out",
    "I've never related to something more", "this explains so much about me",
    "crying at 2am reading this", "who told you about my life",
    "this is way too real", "I thought I was the only one who felt this way",
    "sending this to my therapist", "how did you describe my exact thoughts",
    "this hit different", "I felt this so deeply", "same energy honestly",
    "this is exactly what I go through", "no because this is so accurate it hurts",
    "I relate to this on a spiritual level"
]

NEUTRAL_COMMENTS = [
    "nice video", "cool content", "good editing", "love the music choice",
    "what app did you use for this", "first", "nice", "following for more",
    "great quality", "what camera do you use", "cute outfit", "love your page",
    "more of this please", "the background is nice", "what's the song name",
    "posted at a good time", "clean transitions", "good lighting",
    "keep it up", "interesting"
]


def generate_posts(n=180):
    rows = []
    start_date = datetime(2026, 3, 1)
    for i in range(n):
        topic = random.choice(TOPICS)
        fmt = random.choice(FORMATS)
        hook = random.choice(HOOKS)
        post_time = random.choice(POST_TIMES)
        post_date = start_date + timedelta(days=random.randint(0, 150))

        base = 1000 * TOPIC_WEIGHT[topic]
        fmt_mult = 1.15 if fmt == "Short" else 0.9
        hook_mult = 1.2 if hook == "Visual" else 1.0
        time_mult = {"Morning": 0.95, "Afternoon": 1.0, "Evening": 1.25, "Night": 1.1}[post_time]

        reach = max(200, int(np.random.normal(base * fmt_mult * hook_mult * time_mult, base * 0.25)))
        likes = max(5, int(reach * np.random.uniform(0.04, 0.09)))
        comments_count = max(0, int(likes * np.random.uniform(0.03, 0.09)))
        shares = max(0, int(reach * np.random.uniform(0.01, 0.045) * TOPIC_WEIGHT[topic] / 1.4))
        saves = max(0, int(reach * np.random.uniform(0.015, 0.05) * TOPIC_WEIGHT[topic] / 1.4))
        avg_watch_pct = np.clip(np.random.normal(0.55 * (1.1 if fmt == "Short" else 0.85), 0.12), 0.1, 0.98)
        followers_gained = max(0, int((shares + saves) * np.random.uniform(0.08, 0.18)))

        rows.append({
            "post_id": f"P{i+1:04d}",
            "post_date": post_date.strftime("%Y-%m-%d"),
            "topic": topic,
            "format": fmt,
            "hook_type": hook,
            "post_time": post_time,
            "reach": reach,
            "likes": likes,
            "comments_count": comments_count,
            "shares": shares,
            "saves": saves,
            "retention_rate": round(avg_watch_pct, 3),
            "followers_gained": followers_gained,
        })
    return pd.DataFrame(rows)


def generate_comments(posts_df, avg_comments_sampled=6):
    """Generate a comments log tied to posts, with a mix of relatable/neutral
    language whose *proportion* is driven by the post's topic weight - this is
    the ground-truth signal the NLP sentiment module has to recover."""
    rows = []
    cid = 1
    for _, post in posts_df.iterrows():
        n_comments = min(post["comments_count"], random.randint(2, avg_comments_sampled))
        relatable_prob = np.clip((TOPIC_WEIGHT[post["topic"]] - 1.0) / 0.8, 0.15, 0.85)
        for _ in range(n_comments):
            is_relatable = random.random() < relatable_prob
            text = random.choice(RELATABLE_COMMENTS if is_relatable else NEUTRAL_COMMENTS)
            rows.append({
                "comment_id": f"C{cid:05d}",
                "post_id": post["post_id"],
                "topic": post["topic"],
                "comment_text": text,
                "true_label_sim": "Relatable" if is_relatable else "Neutral"  # kept only for validation, not used by model
            })
            cid += 1
    return pd.DataFrame(rows)


if __name__ == "__main__":
    posts = generate_posts(180)
    comments = generate_comments(posts)

    posts.to_csv("dataset_posts.csv", index=False)
    comments.to_csv("dataset_comments.csv", index=False)

    print(f"Posts: {len(posts)} rows -> dataset_posts.csv")
    print(f"Comments: {len(comments)} rows -> dataset_comments.csv")
    print(posts.head(3).to_string())
