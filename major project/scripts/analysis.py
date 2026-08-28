"""
Virality Prediction Engine + A/B Testing Framework + Engagement Optimization Recommender
Modules 2, 4, 5 of the pipeline.
"""
import pandas as pd
import numpy as np
from scipy import stats

posts = pd.read_csv("dataset_posts.csv")
comments = pd.read_csv("dataset_comments_tagged.csv")

# ---------- Module 2: Viral Coefficient ----------
# Weighs high-value actions (shares, saves) over passive actions (likes)
W_SHARE, W_SAVE, W_LIKE = 3.0, 2.5, 1.0

posts["viral_coefficient"] = (
    (posts["shares"] * W_SHARE + posts["saves"] * W_SAVE + posts["likes"] * W_LIKE)
    / posts["reach"]
) * 100

posts["save_to_share_ratio"] = (posts["saves"] / posts["shares"].replace(0, np.nan)).round(2)

topic_viral = (
    posts.groupby("topic")["viral_coefficient"]
    .mean().sort_values(ascending=False).round(2)
)

# ---------- Module 3 rollup: Problem Awareness per topic ----------
comment_topic = comments.groupby("topic")["predicted_label"].apply(
    lambda s: (s == "Relatable").mean()
).sort_values(ascending=False).round(3)

# ---------- Module 4: A/B Testing Framework ----------
def ab_test(df, col, metric="viral_coefficient"):
    groups = df[col].unique()
    if len(groups) != 2:
        return None
    a = df[df[col] == groups[0]][metric]
    b = df[df[col] == groups[1]][metric]
    t_stat, p_val = stats.ttest_ind(a, b, equal_var=False)
    return {
        "variable": col,
        "group_a": groups[0], "mean_a": round(a.mean(), 3),
        "group_b": groups[1], "mean_b": round(b.mean(), 3),
        "t_stat": round(t_stat, 3), "p_value": round(p_val, 4),
        "significant_at_0.05": p_val < 0.05,
    }

ab_results = [
    ab_test(posts, "format"),
    ab_test(posts, "hook_type"),
]

# posting time has 4 levels -> one-way ANOVA
time_groups = [posts[posts["post_time"] == t]["viral_coefficient"] for t in posts["post_time"].unique()]
f_stat, p_val_time = stats.f_oneway(*time_groups)
ab_results.append({
    "variable": "post_time (ANOVA across 4 levels)",
    "f_stat": round(f_stat, 3), "p_value": round(p_val_time, 4),
    "significant_at_0.05": p_val_time < 0.05,
    "means_by_group": posts.groupby("post_time")["viral_coefficient"].mean().round(2).to_dict(),
})

# ---------- Module 5: Engagement Optimization Recommender ----------
best_topic = topic_viral.index[0]
best_format = posts.groupby("format")["viral_coefficient"].mean().idxmax()
best_hook = posts.groupby("hook_type")["viral_coefficient"].mean().idxmax()
best_time = posts.groupby("post_time")["viral_coefficient"].mean().idxmax()

recommendation = {
    "recommended_topic": best_topic,
    "recommended_format": best_format,
    "recommended_hook": best_hook,
    "recommended_post_time": best_time,
    "expected_viral_coefficient": round(
        posts[(posts.topic == best_topic) & (posts.format == best_format) &
              (posts.hook_type == best_hook) & (posts.post_time == best_time)]["viral_coefficient"].mean()
        if not posts[(posts.topic == best_topic) & (posts.format == best_format) &
                     (posts.hook_type == best_hook) & (posts.post_time == best_time)].empty
        else topic_viral.iloc[0], 2
    ),
}

if __name__ == "__main__":
    posts.to_csv("dataset_posts_scored.csv", index=False)

    print("=== Viral Coefficient by Topic ===")
    print(topic_viral.to_string())

    print("\n=== Problem Awareness (share of Relatable comments) by Topic ===")
    print(comment_topic.to_string())

    print("\n=== A/B Testing Results ===")
    for r in ab_results:
        print(r)

    print("\n=== Engagement Optimization Recommendation (next week) ===")
    for k, v in recommendation.items():
        print(f"  {k}: {v}")
