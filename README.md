# TeamGame
 Student Clustering & Grouping part: 
Cette partie est une API FastAPI qui permet de :

*  Analyser un dataset d’étudiants (au format CSV)
* Tester plusieurs algorithmes de clustering (KMeans, Agglomératif, DBSCAN, Spectral, GMM, MeanShift)
* Sélectionner automatiquement le meilleur algorithme en fonction du silhouette score
* Former des groupes hétérogènes de taille fixe à partir des clusters

👉 Objectif : faciliter la constitution de groupes équilibrés et diversifiés d’étudiants pour des projets collaboratifs.

Fonctionnalités principales: 

🔄 Prétraitement des données : encodage (gender, nationality), normalisation des valeurs numériques

🧩 Clustering automatique avec sélection du meilleur algorithme

👨‍👩‍👧‍👦 Génération de groupes hétérogènes selon une taille donnée

🌐 API REST exposée via FastAPI avec endpoint /cluster

Données attendues: 
Le fichier CSV doit contenir au minimum :

* gender (ex: Male/Female/Other)
* nationality
* age
* creativity
* hard_skills
* soft_skills
* teamwork

  
🚀 Installation et lancement

1️⃣ Créer un environnement virtuel & installer les dépendances
python -m venv venv
source venv/bin/activate   # Linux / Mac
venv\Scripts\activate      # Windows

pip install -r requirements.txt

2️⃣ Lancer le serveur FastAPI
uvicorn ClusteringZouhour:app --reload
