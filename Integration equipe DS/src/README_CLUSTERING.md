# Clustering Integration

This document describes the clustering functionality that has been integrated into the FastAPI application.

## Overview

The clustering system uses multiple machine learning algorithms to create optimal student groups based on various criteria including skills, demographics, and performance metrics.

## Files Created/Modified

### 1. `core/clustering_service.py`
Contains the main clustering logic extracted from the original `main.py`:
- Multiple clustering algorithms (KMeans, DBSCAN, Spectral, GMM, etc.)
- Genetic algorithm for group optimization
- Fitness function considering diversity, skill coverage, and balance

### 2. `schemas/group.py` (Updated)
Added new schemas for clustering:
- `ClusteringRequest`: Input schema for clustering endpoint
- `ClusteringResponse`: Output schema for clustering results
- `ClusteringConfig`: Configuration schema for clustering parameters
- `StudentMember`: Schema for individual student data
- `GeneratedGroup`: Schema for generated groups

### 3. `routers/group.py` (New)
CRUD operations for groups plus clustering endpoints:
- Standard CRUD operations (Create, Read, Update, Delete)
- `/generate-clusters`: Basic clustering endpoint
- `/generate-clusters-with-config`: Advanced clustering with custom parameters

### 4. `main.py` (Updated)
Added group router to the FastAPI application.

## API Endpoints

### Basic Clustering
```
POST /groups/generate-clusters
```
Upload a CSV file to generate optimal student groups.

**Expected CSV columns:**
- `first_name`, `last_name`
- `hard_skills`, `soft_skills`, `creativity`, `teamwork`
- `class`, `gender`, `nationality`, `age`

### Advanced Clustering with Configuration
```
POST /groups/generate-clusters-with-config
```
Upload a CSV file with custom clustering parameters.

**Configuration options:**
- `group_size_min`: Minimum group size (default: 5)
- `group_size_max`: Maximum group size (default: 7)
- `population_size`: Genetic algorithm population size (default: 30)
- `generations`: Number of genetic algorithm generations (default: 50)
- `distance_metric`: Distance metric for clustering (default: "euclidean")

## Clustering Algorithms

The system evaluates multiple algorithms and selects the best performing one:

1. **KMeans**: Standard k-means clustering
2. **Agglomerative**: Hierarchical clustering with Ward linkage
3. **DBSCAN**: Density-based clustering
4. **Spectral**: Spectral clustering with nearest neighbors
5. **GMM**: Gaussian Mixture Model
6. **MeanShift**: Mean shift clustering (when applicable)
7. **MiniSom**: Self-organizing maps

## Evaluation Metrics

The system evaluates algorithms using:
- **Silhouette Score**: Measures cluster cohesion and separation
- **Davies-Bouldin Score**: Measures cluster quality
- **Gender Entropy**: Measures gender diversity within clusters
- **Nationality Entropy**: Measures nationality diversity within clusters

## Genetic Algorithm Optimization

After clustering, a genetic algorithm optimizes group assignments considering:
- **Diversity**: Gender and nationality diversity
- **Skill Coverage**: Ensuring groups have students with high skills in different areas
- **Skill Balance**: Balancing skill levels within groups
- **Size Constraints**: Maintaining group size between 5-7 students

## Usage Example

```python
import requests

# Upload CSV file for clustering
with open('students.csv', 'rb') as f:
    files = {'file': f}
    response = requests.post('http://localhost:8000/groups/generate-clusters', files=files)
    
    if response.status_code == 200:
        result = response.json()
        print(f"Best algorithm: {result['best_algorithm']}")
        for group in result['groups']:
            print(f"Group {group['group']}: {group['size']} members")
```

## Dependencies

The clustering functionality requires these additional packages:
- `scikit-learn`: For clustering algorithms
- `minisom`: For self-organizing maps
- `gower`: For Gower distance calculations
- `pandas`: For data manipulation
- `numpy`: For numerical operations

Install with:
```bash
pip install -r requirements.txt
```

## Error Handling

The system includes comprehensive error handling for:
- Missing required CSV columns
- Invalid file formats
- Clustering algorithm failures
- Data validation errors

All errors return appropriate HTTP status codes and descriptive error messages. 