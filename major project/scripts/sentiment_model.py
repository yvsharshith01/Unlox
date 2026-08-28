"""
Audience Sentiment Analyzer (NLP Module)
Processes user comments and tags each one "Relatable" or "Neutral" to validate
"Problem Awareness" - i.e. does the audience see themselves in the content.

Approach: lexicon + polarity based classifier.
  1. A hand-built "relatability trigger" lexicon (first-person identification
     phrases: "this is me", "felt this", "so accurate", "called me out", etc.)
  2. TextBlob subjectivity/polarity as a secondary signal - relatable comments
     skew personal/subjective, generic praise comments skew low-subjectivity.
  3. A weighted score decides the final label.

This is intentionally a transparent rule+lexicon model (not a black-box
classifier) so the Strategy Report can explain *why* a comment was tagged
Relatable - useful for a project deliverable that needs to justify its findings.
"""
import re
import pandas as pd
from textblob import TextBlob

RELATABILITY_TRIGGERS = [
    r"\bthis is (me|literally me)\b", r"\bfelt this\b", r"\bso accurate\b",
    r"\bcalled me out\b", r"\bwho told you\b", r"\bstop reading my mind\b",
    r"\bmy soul\b", r"\bi relate\b", r"\brelate to this\b", r"\bmy exact\b",
    r"\bmy life\b", r"\bcrying\b", r"\bhit different\b", r"\bso real\b",
    r"\bonly one who\b", r"\bexplains so much\b", r"\btherapist\b",
    r"\bneeded to hear\b", r"\bhow did you\b.*\bmy\b", r"\bsame energy\b",
    r"\bnever related\b", r"\bexactly what i\b", r"\bit hurts\b",
    r"\bspiritual level\b",
]
TRIGGER_RE = re.compile("|".join(RELATABILITY_TRIGGERS), re.IGNORECASE)


def score_comment(text: str) -> dict:
    text_l = text.lower()
    trigger_hits = len(TRIGGER_RE.findall(text_l))
    blob = TextBlob(text)
    subjectivity = blob.sentiment.subjectivity  # 0 (objective) - 1 (subjective/personal)

    # Weighted relatability score: lexicon triggers dominate, subjectivity nudges it
    score = (trigger_hits * 1.0) + (subjectivity * 0.4)
    label = "Relatable" if score >= 0.4 else "Neutral"

    return {
        "trigger_hits": trigger_hits,
        "subjectivity": round(subjectivity, 3),
        "relatability_score": round(score, 3),
        "predicted_label": label,
    }


def run_pipeline(comments_csv="dataset_comments.csv", out_csv="dataset_comments_tagged.csv"):
    df = pd.read_csv(comments_csv)
    results = df["comment_text"].apply(score_comment).apply(pd.Series)
    tagged = pd.concat([df, results], axis=1)
    tagged.to_csv(out_csv, index=False)
    return tagged


if __name__ == "__main__":
    tagged = run_pipeline()
    accuracy = (tagged["predicted_label"] == tagged["true_label_sim"]).mean()
    print(f"Tagged {len(tagged)} comments -> dataset_comments_tagged.csv")
    print(f"Label distribution:\n{tagged['predicted_label'].value_counts()}")
    print(f"\nAgreement with simulated ground truth: {accuracy:.1%}")
    print(tagged[["comment_text", "trigger_hits", "subjectivity", "predicted_label"]].head(8).to_string())
