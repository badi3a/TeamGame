import pandas as pd
import numpy as np
from io import BytesIO
from sklearn.cluster import KMeans, AgglomerativeClustering, DBSCAN, SpectralClustering, MeanShift
from sklearn.mixture import GaussianMixture
from sklearn.preprocessing import StandardScaler, LabelEncoder
from sklearn.metrics import silhouette_score, davies_bouldin_score
from minisom import MiniSom
import gower
import random
from typing import List, Dict, Any, Tuple
from fastapi import UploadFile

class ClusteringService:
    def __init__(self):
        self.REQUIRED_COLS = {
            "first_name", "last_name", "hard_skills", "soft_skills", 
            "creativity", "teamwork", "class", "gender", "nationality", "age"
        }
        
        # Column mapping for different dataset formats
        self.COLUMN_MAPPING = {
            # Your dataset format -> Expected format
            "student_id": None,  # Will be dropped
            "class_name": "class",
            "Male": "M",
            "Female": "F"
        }
    
    def entropy(self, series):
        """Calculate entropy of a series"""
        counts = series.value_counts()
        probs = counts / counts.sum()
        return -(probs * np.log2(probs + 1e-9)).sum()

    def gender_nationality_entropy(self, df: pd.DataFrame, labels: List[int]) -> Tuple[float, float]:
        """Calculate gender and nationality entropy for clusters"""
        df_temp = df.copy()
        df_temp['cluster'] = labels
        gender_e = df_temp.groupby('cluster')['gender'].agg(lambda x: self.entropy(x)).mean()
        nat_e = df_temp.groupby('cluster')['nationality'].agg(lambda x: self.entropy(x)).mean()
        return gender_e, nat_e

    def run_algorithms(self, X_scaled: np.ndarray, df: pd.DataFrame, distance_metric: str = "euclidean") -> List[Tuple[str, np.ndarray]]:
        """Run optimized clustering algorithms and return results"""
        results = []
        n_samples = len(X_scaled)
        
        # Determine optimal number of clusters based on dataset size
        # For large datasets, use more clusters to reduce group size
        n_clusters = max(4, min(20, n_samples // 150))  # Aim for ~150 students per cluster
        
        print(f"Processing {n_samples} students with {n_clusters} clusters...")
        
        # KMeans (fastest and most reliable)
        kmeans = KMeans(n_clusters=n_clusters, random_state=42, n_init=10)
        results.append(("KMeans", kmeans.fit_predict(X_scaled)))

        # For large datasets, skip computationally expensive algorithms
        if n_samples < 1000:
            # Agglomerative Clustering (expensive for large datasets)
            agg = AgglomerativeClustering(n_clusters=n_clusters, metric='euclidean', linkage='ward')
            results.append(("Agglomerative", agg.fit_predict(X_scaled)))

            # DBSCAN (skip Gower distance for performance)
            dbscan = DBSCAN(eps=0.6, min_samples=5)
            db_labels = dbscan.fit_predict(X_scaled)
            results.append(("DBSCAN", db_labels))

            # Spectral Clustering (reduce neighbors for large datasets)
            n_neighbors = min(15, n_samples // 10)
            spectral = SpectralClustering(n_clusters=n_clusters, affinity='nearest_neighbors', 
                                        n_neighbors=n_neighbors, random_state=42)
            results.append(("Spectral", spectral.fit_predict(X_scaled)))

        # Gaussian Mixture Model (efficient for large datasets)
        gmm = GaussianMixture(n_components=n_clusters, random_state=42, max_iter=50)
        results.append(("GMM", gmm.fit_predict(X_scaled)))

        # Skip MeanShift and MiniSom for large datasets (too slow)
        if n_samples < 500:
            # Mean Shift (with error handling)
            try:
                meanshift = MeanShift()
                ms_labels = meanshift.fit_predict(X_scaled)
                results.append(("MeanShift", ms_labels))
            except Exception:
                pass

            # MiniSom (reduce training iterations for performance)
            som = MiniSom(6, 6, X_scaled.shape[1], sigma=1.0, learning_rate=0.5)
            som.random_weights_init(X_scaled)
            som.train_random(X_scaled, 50)  # Reduced from 100 to 50
            som_labels = np.array([som.winner(x)[0]*6 + som.winner(x)[1] for x in X_scaled])
            results.append(("MiniSom", som_labels))

        print(f"Completed {len(results)} clustering algorithms")
        return results

    def evaluate_algorithms(self, X_scaled: np.ndarray, df: pd.DataFrame, results: List[Tuple[str, np.ndarray]], features: List[str]) -> List[Tuple[str, float, float, float, float]]:
        """Evaluate clustering algorithms using multiple metrics"""
        eval_data = []
        for algo_name, labels in results:
            if len(set(labels)) <= 1:
                continue
            try:
                sil = silhouette_score(X_scaled, labels)
            except Exception:
                sil = np.nan
            try:
                dbs = davies_bouldin_score(X_scaled, labels)
            except Exception:
                dbs = np.nan
            ge, ne = self.gender_nationality_entropy(df, labels)
            eval_data.append((algo_name, sil, dbs, ge, ne))
        return eval_data

    def create_initial_groups(self, df: pd.DataFrame, group_size_min: int = 5, group_size_max: int = 7) -> List[List[int]]:
        """Create initial groups for genetic algorithm"""
        n_students = len(df)
        n_groups = max(1, n_students // group_size_min)
        groups = [[] for _ in range(n_groups)]
        for i, idx in enumerate(df.index):
            groups[i % n_groups].append(idx)
        return groups

    def fitness(self, groups: List[List[int]], df: pd.DataFrame) -> float:
        """Calculate fitness score for a group configuration"""
        alpha, beta, gamma = 2.0, 1.0, 3.0
        scores = []
        features = ['hard_skills', 'soft_skills', 'creativity', 'teamwork']
        
        for group in groups:
            if len(group) < 5 or len(group) > 7:
                return -np.inf
            sub_df = df.loc[group]
            diversity_score = sub_df['gender'].nunique() + sub_df['nationality'].nunique()
            skill_coverage = sum(any(sub_df[f] > 4) for f in features)
            skill_balance = -sub_df[features].mean().std()
            score = alpha * diversity_score + beta * skill_coverage + gamma * skill_balance
            scores.append(score)
        return np.mean(scores)

    def mutate(self, groups: List[List[int]]) -> List[List[int]]:
        """Mutate groups by swapping members between groups"""
        g1, g2 = random.sample(range(len(groups)), 2)
        if groups[g1] and groups[g2]:
            i1 = random.choice(groups[g1])
            i2 = random.choice(groups[g2])
            groups[g1].remove(i1)
            groups[g1].append(i2)
            groups[g2].remove(i2)
            groups[g2].append(i1)
        return groups

    def crossover(self, p1: List[List[int]], p2: List[List[int]]) -> List[List[int]]:
        """Crossover operation for genetic algorithm"""
        half = len(p1) // 2
        child = p1[:half] + p2[half:]
        seen = set()
        for g in child:
            unique = []
            for s in g:
                if s not in seen:
                    unique.append(s)
                    seen.add(s)
            g[:] = unique
        return child

    def repair(self, groups: List[List[int]]) -> List[List[int]]:
        """Repair groups to ensure size constraints"""
        changed = True
        while changed:
            changed = False
            for g in groups:
                while len(g) > 7:
                    s = g.pop()
                    min_grp = min(groups, key=len)
                    min_grp.append(s)
                    changed = True
        return groups

    def preprocess_data(self, df: pd.DataFrame) -> pd.DataFrame:
        """Preprocess the dataset to match expected format"""
        df_processed = df.copy()
        
        # Handle column name mapping
        if "class_name" in df_processed.columns and "class" not in df_processed.columns:
            df_processed["class"] = df_processed["class_name"]
        
        # Handle gender mapping
        if "gender" in df_processed.columns:
            df_processed["gender"] = df_processed["gender"].map({
                "Male": "M", 
                "Female": "F"
            }).fillna(df_processed["gender"])
        
        # Drop student_id if present
        if "student_id" in df_processed.columns:
            df_processed = df_processed.drop("student_id", axis=1)
        
        # Check if we have the required columns (with some flexibility)
        required_cols_flexible = {
            "first_name", "last_name", "hard_skills", "soft_skills", 
            "creativity", "teamwork", "gender", "nationality", "age"
        }
        
        # Check for class column (either "class" or "class_name")
        has_class = "class" in df_processed.columns or "class_name" in df_processed.columns
        
        if not has_class:
            # Add a default class if missing
            df_processed["class"] = "Default"
        
        # Validate that we have the essential columns
        missing_cols = required_cols_flexible - set(df_processed.columns)
        if missing_cols:
            raise ValueError(f"Dataset missing required columns: {missing_cols}")
        
        return df_processed

    async def generate_groups(self, file: UploadFile) -> Dict[str, Any]:
        """Main method to generate optimal groups from uploaded CSV file"""
        print("Starting group generation process...")
        
        # Read CSV file
        print("Reading CSV file...")
        df = pd.read_csv(BytesIO(await file.read()))
        print(f"Loaded dataset with {len(df)} students")
        
        # For very large datasets, consider sampling for algorithm selection
        if len(df) > 2000:
            print("Large dataset detected. Using sampling for algorithm selection...")
            sample_size = min(1000, len(df))
            df_sample = df.sample(n=sample_size, random_state=42)
            use_sampling = True
        else:
            df_sample = df
            use_sampling = False
        
        # Preprocess the data
        print("Preprocessing data...")
        df = self.preprocess_data(df)
        if use_sampling:
            df_sample = self.preprocess_data(df_sample)
        
        # Validate required columns
        if not self.REQUIRED_COLS.issubset(df.columns):
            raise ValueError(f"Dataset missing required columns. Available: {list(df.columns)}. Required: {list(self.REQUIRED_COLS)}")
        
        # Encode categorical variables
        print("Encoding categorical variables...")
        le_gender = LabelEncoder()
        le_nationality = LabelEncoder()
        df['gender'] = le_gender.fit_transform(df['gender'])
        df['nationality'] = le_nationality.fit_transform(df['nationality'])
        
        if use_sampling:
            df_sample['gender'] = le_gender.transform(df_sample['gender'])
            df_sample['nationality'] = le_nationality.transform(df_sample['nationality'])

        # Prepare features for clustering
        print("Preparing features for clustering...")
        features = ["gender", "nationality", "age", "hard_skills", "soft_skills", "creativity", "teamwork"]
        scaler = StandardScaler()
        X_scaled = scaler.fit_transform(df[features])
        
        if use_sampling:
            X_scaled_sample = scaler.transform(df_sample[features])
        else:
            X_scaled_sample = X_scaled

        # Run clustering algorithms on sample for algorithm selection
        print("Running clustering algorithms...")
        results = self.run_algorithms(X_scaled_sample, df_sample, distance_metric="euclidean")
        
        print("Evaluating algorithms...")
        evals = self.evaluate_algorithms(X_scaled_sample, df_sample, results, features)
        
        # Find best algorithm
        best_algo = max(evals, key=lambda x: x[1] if not np.isnan(x[1]) else -1)
        print(f"Best algorithm: {best_algo[0]}")
        
        # Apply best algorithm to full dataset
        if use_sampling:
            print(f"Applying {best_algo[0]} to full dataset...")
            if best_algo[0] == "KMeans":
                n_samples = len(X_scaled)
                n_clusters = max(4, min(20, n_samples // 150))
                kmeans = KMeans(n_clusters=n_clusters, random_state=42, n_init=10)
                best_labels = kmeans.fit_predict(X_scaled)
            elif best_algo[0] == "GMM":
                n_samples = len(X_scaled)
                n_clusters = max(4, min(20, n_samples // 150))
                gmm = GaussianMixture(n_components=n_clusters, random_state=42, max_iter=50)
                best_labels = gmm.fit_predict(X_scaled)
            else:
                # Fallback to KMeans for large datasets
                n_samples = len(X_scaled)
                n_clusters = max(4, min(20, n_samples // 150))
                kmeans = KMeans(n_clusters=n_clusters, random_state=42, n_init=10)
                best_labels = kmeans.fit_predict(X_scaled)
        else:
            best_labels = [lbl for name, lbl in results if name == best_algo[0]][0]
            
        df['cluster'] = best_labels

        # Optimized genetic algorithm for group optimization
        print("Starting genetic algorithm optimization...")
        initial_groups = self.create_initial_groups(df)
        
        # Reduce genetic algorithm parameters for large datasets
        n_students = len(df)
        if n_students > 1000:
            pop_size, generations = 20, 30  # Reduced from 30, 50
            print(f"Using reduced GA parameters for large dataset: pop_size={pop_size}, generations={generations}")
        else:
            pop_size, generations = 30, 50
            print(f"Using standard GA parameters: pop_size={pop_size}, generations={generations}")
        
        population = [initial_groups.copy() for _ in range(pop_size)]
        best_ind, best_fit = None, -np.inf
        
        # Progress tracking
        progress_interval = max(1, generations // 10)
        
        for gen in range(generations):
            if gen % progress_interval == 0:
                print(f"Generation {gen}/{generations}")
                
            fitness_scores = [self.fitness(ind, df) for ind in population]
            for fit, ind in zip(fitness_scores, population):
                if fit > best_fit:
                    best_fit = fit
                    best_ind = [g.copy() for g in ind]
            
            # Selection (keep top 30%)
            sorted_pop = sorted(zip(fitness_scores, population), key=lambda x: x[0], reverse=True)
            population = [ind for _, ind in sorted_pop[:int(pop_size * 0.3)]]
            
            # Reproduction
            while len(population) < pop_size:
                p1, p2 = random.sample(population, 2)
                child = self.crossover(p1, p2)
                child = self.mutate(child)
                child = self.repair(child)
                population.append(child)

        print("Preparing final output...")
        # Decode categorical variables back to original strings
        df['gender'] = le_gender.inverse_transform(df['gender'])
        df['nationality'] = le_nationality.inverse_transform(df['nationality'])
        
        # Check if we have a valid solution
        if best_ind is None:
            raise ValueError("Failed to generate valid groups")
        
        # Prepare output
        groups_output = []
        for i, group in enumerate(best_ind):
            members = df.loc[group].to_dict(orient="records")
            groups_output.append({
                "group": i+1, 
                "size": len(group), 
                "members": members
            })

        print(f"Successfully generated {len(groups_output)} groups with best fitness: {best_fit:.3f}")
        return {
            "best_algorithm": best_algo[0],
            "groups": groups_output
        }
    
    async def generate_groups_quick(self, file: UploadFile) -> Dict[str, Any]:
        """Quick group generation using only KMeans clustering"""
        print("Starting quick group generation process...")
        
        # Read CSV file
        print("Reading CSV file...")
        df = pd.read_csv(BytesIO(await file.read()))
        print(f"Loaded dataset with {len(df)} students")
        
        # Preprocess the data
        print("Preprocessing data...")
        df = self.preprocess_data(df)
        
        # Validate required columns
        if not self.REQUIRED_COLS.issubset(df.columns):
            raise ValueError(f"Dataset missing required columns. Available: {list(df.columns)}. Required: {list(self.REQUIRED_COLS)}")
        
        # Encode categorical variables
        print("Encoding categorical variables...")
        le_gender = LabelEncoder()
        le_nationality = LabelEncoder()
        df['gender'] = le_gender.fit_transform(df['gender'])
        df['nationality'] = le_nationality.fit_transform(df['nationality'])

        # Prepare features for clustering
        print("Preparing features for clustering...")
        features = ["gender", "nationality", "age", "hard_skills", "soft_skills", "creativity", "teamwork"]
        scaler = StandardScaler()
        X_scaled = scaler.fit_transform(df[features])

        # Use only KMeans clustering
        print("Running KMeans clustering...")
        n_samples = len(X_scaled)
        n_clusters = max(4, min(20, n_samples // 150))  # Aim for ~150 students per cluster
        print(f"Using {n_clusters} clusters for {n_samples} students")
        
        kmeans = KMeans(n_clusters=n_clusters, random_state=42, n_init=10)
        labels = kmeans.fit_predict(X_scaled)
        df['cluster'] = labels

        # Simplified genetic algorithm for group optimization
        print("Starting simplified genetic algorithm optimization...")
        initial_groups = self.create_initial_groups(df)
        
        # Reduced parameters for quick processing
        pop_size, generations = 15, 20
        print(f"Using quick GA parameters: pop_size={pop_size}, generations={generations}")
        
        population = [initial_groups.copy() for _ in range(pop_size)]
        best_ind, best_fit = None, -np.inf
        
        for gen in range(generations):
            if gen % 5 == 0:
                print(f"Generation {gen}/{generations}")
                
            fitness_scores = [self.fitness(ind, df) for ind in population]
            for fit, ind in zip(fitness_scores, population):
                if fit > best_fit:
                    best_fit = fit
                    best_ind = [g.copy() for g in ind]
            
            # Selection (keep top 30%)
            sorted_pop = sorted(zip(fitness_scores, population), key=lambda x: x[0], reverse=True)
            population = [ind for _, ind in sorted_pop[:int(pop_size * 0.3)]]
            
            # Reproduction
            while len(population) < pop_size:
                p1, p2 = random.sample(population, 2)
                child = self.crossover(p1, p2)
                child = self.mutate(child)
                child = self.repair(child)
                population.append(child)

        print("Preparing final output...")
        # Decode categorical variables back to original strings
        df['gender'] = le_gender.inverse_transform(df['gender'])
        df['nationality'] = le_nationality.inverse_transform(df['nationality'])
        
        # Check if we have a valid solution
        if best_ind is None:
            raise ValueError("Failed to generate valid groups")
        
        # Prepare output
        groups_output = []
        for i, group in enumerate(best_ind):
            members = df.loc[group].to_dict(orient="records")
            groups_output.append({
                "group": i+1, 
                "size": len(group), 
                "members": members
            })

        print(f"Successfully generated {len(groups_output)} groups with best fitness: {best_fit:.3f}")
        return {
            "best_algorithm": "KMeans",
            "groups": groups_output
        }
    
    async def generate_groups_with_config(
        self, 
        file: UploadFile, 
        group_size_min: int = 5,
        group_size_max: int = 7,
        population_size: int = 30,
        generations: int = 50,
        distance_metric: str = "euclidean"
    ) -> Dict[str, Any]:
        """Generate groups with custom configuration parameters"""
        print(f"Starting group generation with custom config: min={group_size_min}, max={group_size_max}, pop={population_size}, gen={generations}")
        
        # Read CSV file
        print("Reading CSV file...")
        df = pd.read_csv(BytesIO(await file.read()))
        print(f"Loaded dataset with {len(df)} students")
        
        # For very large datasets, consider sampling for algorithm selection
        if len(df) > 2000:
            print("Large dataset detected. Using sampling for algorithm selection...")
            sample_size = min(1000, len(df))
            df_sample = df.sample(n=sample_size, random_state=42)
            use_sampling = True
        else:
            df_sample = df
            use_sampling = False
        
        # Preprocess the data
        print("Preprocessing data...")
        df = self.preprocess_data(df)
        if use_sampling:
            df_sample = self.preprocess_data(df_sample)
        
        # Validate required columns
        if not self.REQUIRED_COLS.issubset(df.columns):
            raise ValueError(f"Dataset missing required columns. Available: {list(df.columns)}. Required: {list(self.REQUIRED_COLS)}")
        
        # Encode categorical variables
        print("Encoding categorical variables...")
        le_gender = LabelEncoder()
        le_nationality = LabelEncoder()
        df['gender'] = le_gender.fit_transform(df['gender'])
        df['nationality'] = le_nationality.fit_transform(df['nationality'])
        
        if use_sampling:
            df_sample['gender'] = le_gender.transform(df_sample['gender'])
            df_sample['nationality'] = le_nationality.transform(df_sample['nationality'])

        # Prepare features for clustering
        print("Preparing features for clustering...")
        features = ["gender", "nationality", "age", "hard_skills", "soft_skills", "creativity", "teamwork"]
        scaler = StandardScaler()
        X_scaled = scaler.fit_transform(df[features])
        
        if use_sampling:
            X_scaled_sample = scaler.transform(df_sample[features])
        else:
            X_scaled_sample = X_scaled

        # Run clustering algorithms on sample for algorithm selection
        print("Running clustering algorithms...")
        results = self.run_algorithms(X_scaled_sample, df_sample, distance_metric=distance_metric)
        
        print("Evaluating algorithms...")
        evals = self.evaluate_algorithms(X_scaled_sample, df_sample, results, features)
        
        # Find best algorithm
        best_algo = max(evals, key=lambda x: x[1] if not np.isnan(x[1]) else -1)
        print(f"Best algorithm: {best_algo[0]}")
        
        # Apply best algorithm to full dataset
        if use_sampling:
            print(f"Applying {best_algo[0]} to full dataset...")
            if best_algo[0] == "KMeans":
                n_samples = len(X_scaled)
                n_clusters = max(4, min(20, n_samples // 150))
                kmeans = KMeans(n_clusters=n_clusters, random_state=42, n_init=10)
                best_labels = kmeans.fit_predict(X_scaled)
            elif best_algo[0] == "GMM":
                n_samples = len(X_scaled)
                n_clusters = max(4, min(20, n_samples // 150))
                gmm = GaussianMixture(n_components=n_clusters, random_state=42, max_iter=50)
                best_labels = gmm.fit_predict(X_scaled)
            else:
                # Fallback to KMeans for large datasets
                n_samples = len(X_scaled)
                n_clusters = max(4, min(20, n_samples // 150))
                kmeans = KMeans(n_clusters=n_clusters, random_state=42, n_init=10)
                best_labels = kmeans.fit_predict(X_scaled)
        else:
            best_labels = [lbl for name, lbl in results if name == best_algo[0]][0]
            
        df['cluster'] = best_labels

        # Custom genetic algorithm with provided parameters
        print(f"Starting genetic algorithm optimization with custom parameters...")
        initial_groups = self.create_initial_groups(df, group_size_min, group_size_max)
        
        print(f"Using custom GA parameters: pop_size={population_size}, generations={generations}")
        
        population = [initial_groups.copy() for _ in range(population_size)]
        best_ind, best_fit = None, -np.inf
        
        # Progress tracking
        progress_interval = max(1, generations // 10)
        
        for gen in range(generations):
            if gen % progress_interval == 0:
                print(f"Generation {gen}/{generations}")
                
            fitness_scores = [self.fitness(ind, df) for ind in population]
            for fit, ind in zip(fitness_scores, population):
                if fit > best_fit:
                    best_fit = fit
                    best_ind = [g.copy() for g in ind]
            
            # Selection (keep top 30%)
            sorted_pop = sorted(zip(fitness_scores, population), key=lambda x: x[0], reverse=True)
            population = [ind for _, ind in sorted_pop[:int(population_size * 0.3)]]
            
            # Reproduction
            while len(population) < population_size:
                p1, p2 = random.sample(population, 2)
                child = self.crossover(p1, p2)
                child = self.mutate(child)
                child = self.repair(child)
                population.append(child)

        print("Preparing final output...")
        # Decode categorical variables back to original strings
        df['gender'] = le_gender.inverse_transform(df['gender'])
        df['nationality'] = le_nationality.inverse_transform(df['nationality'])
        
        # Check if we have a valid solution
        if best_ind is None:
            raise ValueError("Failed to generate valid groups")
        
        # Prepare output
        groups_output = []
        for i, group in enumerate(best_ind):
            members = df.loc[group].to_dict(orient="records")
            groups_output.append({
                "group": i+1, 
                "size": len(group), 
                "members": members
            })

        print(f"Successfully generated {len(groups_output)} groups with best fitness: {best_fit:.3f}")
        return {
            "best_algorithm": best_algo[0],
            "groups": groups_output
        } 