# main_combined.py
from fastapi import FastAPI, Request, UploadFile, File, Form
from fastapi.responses import JSONResponse
import pandas as pd
import numpy as np
from sklearn.preprocessing import StandardScaler, LabelEncoder
from sklearn.cluster import (
    KMeans, DBSCAN, SpectralClustering, MeanShift, AgglomerativeClustering
)
from sklearn.mixture import GaussianMixture
from sklearn.metrics import silhouette_score

app = FastAPI()

def preprocess(df):
    df = df.copy()
    for col in ['gender', 'nationality']:
        df[col] = LabelEncoder().fit_transform(df[col].astype(str)) if col in df else 0

    features = ['gender', 'nationality', 'age', 'creativity', 'hard_skills', 'soft_skills', 'teamwork']
    for col in features:
        if col not in df.columns:
            df[col] = 0

    X = df[features]
    X_scaled = StandardScaler().fit_transform(X)
    return X, X_scaled, df, features

def cluster_students(df, k, algo, metric='euclidean'):
    X, X_scaled, df_original, features = preprocess(df)
    if algo == "kmeans":
        labels = KMeans(n_clusters=k, random_state=42).fit_predict(X_scaled)
    elif algo in ["agglo", "hierarchical"]:
        model = AgglomerativeClustering(
            n_clusters=k,
            affinity=metric if metric != 'gower' else 'precomputed',
            linkage='average'
        )
        labels = model.fit_predict(X_scaled)
    elif algo == "dbscan":
        labels = DBSCAN(eps=1.2, min_samples=3).fit_predict(X_scaled)
    elif algo == "spectral":
        labels = SpectralClustering(n_clusters=k, affinity='nearest_neighbors', random_state=42).fit_predict(X_scaled)
    elif algo == "gmm":
        labels = GaussianMixture(n_components=k, random_state=42).fit(X_scaled).predict(X_scaled)
    elif algo == "meanshift":
        labels = MeanShift().fit_predict(X_scaled)
    else:
        raise ValueError("Unsupported algorithm")

    df_original['group'] = labels
    return df_original, labels, X_scaled

def find_best_clustering(df, k=4, metric='euclidean'):
    algorithms = ["kmeans", "agglo", "spectral", "gmm", "meanshift", "dbscan"]
    best_algo = None
    best_score = -1
    best_result = None

    for algo in algorithms:
        try:
            clustered_df, labels, X_scaled = cluster_students(df, k, algo, metric)
            if len(set(labels)) > 1 and (algo != "dbscan" or -1 not in labels):
                score = silhouette_score(X_scaled, labels)
            else:
                score = -1
        except Exception as e:
            print(f"[{algo}] Failed: {e}")
            score = -1

        if score > best_score:
            best_score = score
            best_algo = algo
            best_result = (clustered_df, labels, X_scaled)

    return best_algo, best_score, best_result

def create_fixed_size_heterogeneous_groups(df, cluster_label_col='group', group_size=5):
    clusters = {
        c: df[df[cluster_label_col] == c].sample(frac=1).to_dict('records')
        for c in df[cluster_label_col].unique()
    }

    groups = []
    current_group = []

    while any(clusters[c] for c in clusters):
        for c in clusters:
            if clusters[c]:
                current_group.append(clusters[c].pop())
                if len(current_group) == group_size:
                    groups.append(current_group)
                    current_group = []

    if current_group:
        groups.append(current_group)

    for i, group in enumerate(groups):
        for student in group:
            student['heterogeneous_group'] = i

    grouped_df = pd.DataFrame([s for g in groups for s in g])
    counts = grouped_df['heterogeneous_group'].value_counts().sort_index().to_dict()
    return grouped_df, counts

@app.post("/cluster", response_class=JSONResponse)
async def cluster(
    request: Request,
    file: UploadFile = File(...),
    group_size: int = Form(...)
):
    df = pd.read_csv(file.file)

    best_algo, best_score, best_result = find_best_clustering(df, k=4, metric='euclidean')

    if best_result is None:
        return JSONResponse(
            status_code=400,
            content={"error": "No suitable clustering found."}
        )

    clustered_df, labels, _ = best_result

    grouped_df, group_counts = create_fixed_size_heterogeneous_groups(clustered_df, group_size=group_size)

    groups = {
        str(group_id): group.to_dict(orient='records')
        for group_id, group in grouped_df.groupby('heterogeneous_group')
    }

    return {
        "algorithm": best_algo,
        "silhouette_score": round(best_score, 3),
        "group_size": group_size,
        "total_groups": len(groups),
        "group_counts": group_counts,
        "groups": groups
    }
