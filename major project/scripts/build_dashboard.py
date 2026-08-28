"""
Growth Visualization Dashboard (Module 6)
Self-contained interactive HTML dashboard (Plotly) - maps struggle-topic
correlation to growth, and visualizes the save-to-share ratio.
Chosen as a static/interactive HTML file (instead of a live Streamlit server)
so it can be downloaded, opened in any browser, and submitted directly.
"""
import pandas as pd
import plotly.graph_objects as go
import plotly.express as px
from plotly.subplots import make_subplots

posts = pd.read_csv("dataset_posts_scored.csv")
comments = pd.read_csv("dataset_comments_tagged.csv")

topic_summary = posts.groupby("topic").agg(
    viral_coefficient=("viral_coefficient", "mean"),
    followers_gained=("followers_gained", "sum"),
    reach=("reach", "mean"),
    saves=("saves", "sum"),
    shares=("shares", "sum"),
).round(2).reset_index()
topic_summary["save_to_share_ratio"] = (topic_summary["saves"] / topic_summary["shares"]).round(2)
topic_summary = topic_summary.sort_values("viral_coefficient", ascending=False)

relatable_share = comments.groupby("topic")["predicted_label"].apply(
    lambda s: (s == "Relatable").mean() * 100
).round(1).reset_index(name="relatable_pct")
topic_summary = topic_summary.merge(relatable_share, on="topic")

fmt_summary = posts.groupby(["format", "hook_type"])["viral_coefficient"].mean().reset_index()
time_summary = posts.groupby("post_time")["viral_coefficient"].mean().reindex(
    ["Morning", "Afternoon", "Evening", "Night"]).reset_index()
daily = posts.groupby("post_date")["followers_gained"].sum().reset_index()
daily["post_date"] = pd.to_datetime(daily["post_date"])
daily = daily.sort_values("post_date")
daily["cumulative_followers"] = daily["followers_gained"].cumsum()

COLORWAY = ["#6C5CE7", "#00B894", "#FD79A8", "#FDCB6E", "#0984E3", "#E17055", "#00CEC9", "#636E72", "#A29BFE", "#FF7675"]

fig = make_subplots(
    rows=3, cols=2,
    specs=[
        [{"colspan": 2}, None],
        [{"type": "xy"}, {"type": "xy"}],
        [{"type": "xy"}, {"type": "xy"}],
    ],
    subplot_titles=(
        "Follower Growth Over Time (cumulative)",
        "Viral Coefficient by Struggle Topic",
        "Problem Awareness: % Comments Tagged 'Relatable' by Topic",
        "Save-to-Share Ratio by Topic (users saving > sharing = felt understood)",
        "Viral Coefficient: Format x Hook Type",
    ),
    vertical_spacing=0.11,
    horizontal_spacing=0.1,
)

fig.add_trace(go.Scatter(x=daily["post_date"], y=daily["cumulative_followers"],
                          mode="lines", fill="tozeroy", line=dict(color="#6C5CE7", width=3),
                          name="Cumulative Followers"), row=1, col=1)

fig.add_trace(go.Bar(x=topic_summary["topic"], y=topic_summary["viral_coefficient"],
                      marker_color=COLORWAY, name="Viral Coefficient"), row=2, col=1)

fig.add_trace(go.Bar(x=topic_summary["topic"], y=topic_summary["relatable_pct"],
                      marker_color="#00B894", name="% Relatable"), row=2, col=2)

fig.add_trace(go.Bar(x=topic_summary["topic"], y=topic_summary["save_to_share_ratio"],
                      marker_color="#FD79A8", name="Save:Share Ratio"), row=3, col=1)

for hook in fmt_summary["hook_type"].unique():
    sub = fmt_summary[fmt_summary["hook_type"] == hook]
    fig.add_trace(go.Bar(x=sub["format"], y=sub["viral_coefficient"], name=f"Hook: {hook}"), row=3, col=2)

fig.update_layout(
    height=1150, width=1150,
    title=dict(text="Data-Driven Social Engagement Initiative — Growth Dashboard",
               font=dict(size=22, color="#2D3436")),
    showlegend=True,
    template="plotly_white",
    font=dict(family="Arial", size=12),
    margin=dict(t=90),
)
fig.update_xaxes(tickangle=-35)

html_str = fig.to_html(include_plotlyjs="cdn", full_html=False)

kpi_html = f"""
<div class="kpi-row">
  <div class="kpi"><div class="kpi-value">{posts['post_id'].nunique()}</div><div class="kpi-label">Posts Analyzed</div></div>
  <div class="kpi"><div class="kpi-value">{int(posts['followers_gained'].sum()):,}</div><div class="kpi-label">Followers Gained</div></div>
  <div class="kpi"><div class="kpi-value">{len(comments):,}</div><div class="kpi-label">Comments Processed</div></div>
  <div class="kpi"><div class="kpi-value">{(comments['predicted_label']=='Relatable').mean()*100:.1f}%</div><div class="kpi-label">Tagged Relatable</div></div>
  <div class="kpi"><div class="kpi-value">{topic_summary.iloc[0]['topic']}</div><div class="kpi-label">Top Performing Topic</div></div>
</div>
"""

page = f"""<!DOCTYPE html>
<html><head><meta charset="utf-8">
<title>Growth Visualization Dashboard</title>
<style>
body {{ font-family: Arial, sans-serif; background:#F5F6FA; margin:0; padding:24px; }}
.header {{ text-align:center; margin-bottom: 16px; }}
.header h1 {{ color:#2D3436; margin-bottom:4px; }}
.header p {{ color:#636E72; }}
.kpi-row {{ display:flex; justify-content:center; gap:16px; flex-wrap:wrap; margin: 20px 0 30px; }}
.kpi {{ background:white; border-radius:12px; padding:18px 26px; box-shadow: 0 2px 8px rgba(0,0,0,0.06); text-align:center; min-width:140px;}}
.kpi-value {{ font-size:26px; font-weight:bold; color:#6C5CE7; }}
.kpi-label {{ font-size:12px; color:#636E72; margin-top:4px; }}
.chart-container {{ background:white; border-radius:12px; padding:10px; box-shadow: 0 2px 8px rgba(0,0,0,0.06); max-width:1180px; margin:0 auto;}}
</style></head>
<body>
<div class="header">
<h1>The Data-Driven Social Engagement Initiative</h1>
<p>Growth Visualization Dashboard — Module 6</p>
</div>
{kpi_html}
<div class="chart-container">{html_str}</div>
</body></html>
"""

with open("dashboard.html", "w") as f:
    f.write(page)

print("dashboard.html written.")
print(topic_summary.to_string())
