"""
Dashboard Frontend (Streamlit version) - Module 6 alt implementation.
Run with: streamlit run app_streamlit.py
Included alongside dashboard.html so the submission satisfies the
"Streamlit or Dash" tech-stack line item; dashboard.html is the version
to submit/open directly since it needs no server.
"""
import pandas as pd
import streamlit as st
import plotly.express as px

st.set_page_config(page_title="Growth Dashboard", layout="wide")

posts = pd.read_csv("dataset_posts_scored.csv")
comments = pd.read_csv("dataset_comments_tagged.csv")

st.title("The Data-Driven Social Engagement Initiative")
st.caption("Growth Visualization Dashboard")

c1, c2, c3, c4 = st.columns(4)
c1.metric("Posts Analyzed", posts["post_id"].nunique())
c2.metric("Followers Gained", int(posts["followers_gained"].sum()))
c3.metric("Comments Processed", len(comments))
c4.metric("% Tagged Relatable", f"{(comments['predicted_label']=='Relatable').mean()*100:.1f}%")

topic_summary = posts.groupby("topic")["viral_coefficient"].mean().sort_values(ascending=False).reset_index()
st.subheader("Viral Coefficient by Struggle Topic")
st.plotly_chart(px.bar(topic_summary, x="topic", y="viral_coefficient"), use_container_width=True)

relatable = comments.groupby("topic")["predicted_label"].apply(lambda s: (s == "Relatable").mean() * 100).reset_index(name="relatable_pct")
st.subheader("Problem Awareness by Topic")
st.plotly_chart(px.bar(relatable, x="topic", y="relatable_pct"), use_container_width=True)

st.subheader("Raw Data")
st.dataframe(posts)
