from fastapi import APIRouter, HTTPException, File, UploadFile
from typing import List
from schemas.group import (
    Group, 
    ClusteringRequest, 
    ClusteringResponse, 
    ClusteringConfig,
    GeneratedGroup,
    StudentMember
)
from core.firebase import db
from core.clustering_service import ClusteringService

router = APIRouter()
collection_name = "groups"

# Initialize clustering service (singleton pattern)
clustering_service = None

def get_clustering_service():
    global clustering_service
    if clustering_service is None:
        clustering_service = ClusteringService()
    return clustering_service

def doc_to_group(doc):
    data = doc.to_dict()
    return Group(
        idGroup=doc.id,
        groupName=data.get("groupName"),
        members=data.get("members", [])
    )

@router.post("/", response_model=Group)
def create_group(group: Group):
    """Create a new group"""
    doc_ref = db.collection(collection_name).document()
    data = group.dict(exclude={"idGroup"})
    doc_ref.set(data)
    return Group(idGroup=doc_ref.id, **data)

@router.get("/", response_model=List[Group])
def get_groups():
    """Get all groups"""
    docs = db.collection(collection_name).stream()
    return [doc_to_group(doc) for doc in docs]

@router.get("/{group_id}", response_model=Group)
def get_group(group_id: str):
    """Get a specific group by ID"""
    doc = db.collection(collection_name).document(group_id).get()
    if not doc.exists:
        raise HTTPException(status_code=404, detail="Group not found")
    return doc_to_group(doc)

@router.put("/{group_id}", response_model=Group)
def update_group(group_id: str, group: Group):
    """Update a group"""
    doc_ref = db.collection(collection_name).document(group_id)
    doc = doc_ref.get()
    if not doc.exists:
        raise HTTPException(status_code=404, detail="Group not found")
    
    data = group.dict(exclude={"idGroup"})
    doc_ref.update(data)
    return Group(idGroup=group_id, **data)

@router.delete("/{group_id}")
def delete_group(group_id: str):
    """Delete a group"""
    doc_ref = db.collection(collection_name).document(group_id)
    doc = doc_ref.get()
    if not doc.exists:
        raise HTTPException(status_code=404, detail="Group not found")
    
    doc_ref.delete()
    return {"message": "Group deleted successfully"}

@router.get("/search/", response_model=List[Group])
def search_groups(keyword: str):
    """Search groups by name"""
    docs = db.collection(collection_name).where("groupName", ">=", keyword).where("groupName", "<=", keyword + "\uf8ff").stream()
    return [doc_to_group(doc) for doc in docs]

# ===============================================
# CLUSTERING ENDPOINTS
# ===============================================

@router.post("/generate-clusters", response_model=ClusteringResponse)
async def generate_clusters(file: UploadFile = File(..., description="CSV file containing student data")):
    """
    Generate optimal student groups using clustering algorithms and genetic optimization.
    
    This endpoint automatically selects the best clustering algorithm from:
    - KMeans, Agglomerative, DBSCAN, Spectral, GMM, MeanShift, MiniSom
    
    **Expected CSV columns:**
    - first_name, last_name
    - hard_skills, soft_skills, creativity, teamwork
    - class, gender, nationality, age
    
    **Returns:**
    - best_algorithm: The algorithm that performed best
    - groups: List of generated groups with student details
    """
    try:
        # Validate file type
        if not file.filename.endswith('.csv'):
            raise HTTPException(status_code=400, detail="File must be a CSV")
        
        # Get clustering service and generate groups
        service = get_clustering_service()
        result = await service.generate_groups(file)
        
        # Convert result to response format
        groups = []
        for group_data in result["groups"]:
            members = []
            for member_data in group_data["members"]:
                # Handle the 'class' field which might be named differently
                class_name = member_data.get("class", member_data.get("class_name", ""))
                
                # Handle gender mapping back to readable format
                gender_display = "Male" if member_data["gender"] == "M" else "Female" if member_data["gender"] == "F" else member_data["gender"]
                
                member = StudentMember(
                    first_name=member_data["first_name"],
                    last_name=member_data["last_name"],
                    hard_skills=float(member_data["hard_skills"]),
                    soft_skills=float(member_data["soft_skills"]),
                    creativity=float(member_data["creativity"]),
                    teamwork=float(member_data["teamwork"]),
                    class_name=class_name,
                    gender=gender_display,
                    nationality=member_data["nationality"],
                    age=int(member_data["age"])
                )
                members.append(member)
            
            group = GeneratedGroup(
                group=group_data["group"],
                size=group_data["size"],
                members=members
            )
            groups.append(group)
        
        return ClusteringResponse(
            best_algorithm=result["best_algorithm"],
            groups=groups
        )
        
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Clustering failed: {str(e)}")

@router.post("/generate-clusters-with-config", response_model=ClusteringResponse)
async def generate_clusters_with_config(
    file: UploadFile = File(..., description="CSV file containing student data"),
    group_size_min: int = 5,
    group_size_max: int = 7,
    population_size: int = 30,
    generations: int = 50,
    distance_metric: str = "euclidean"
):
    """
    Generate optimal student groups with custom configuration parameters.
    
    This endpoint allows you to customize the clustering parameters:
    - **group_size_min**: Minimum group size (default: 5)
    - **group_size_max**: Maximum group size (default: 7)
    - **population_size**: Genetic algorithm population size (default: 30)
    - **generations**: Number of genetic algorithm generations (default: 50)
    - **distance_metric**: Distance metric for clustering (default: "euclidean")
    
    Expected CSV columns:
    - first_name, last_name, hard_skills, soft_skills, creativity, teamwork
    - class, gender, nationality, age
    """
    try:
        # Validate file type
        if not file.filename.endswith('.csv'):
            raise HTTPException(status_code=400, detail="File must be a CSV")
        
        # Create config from parameters
        config = ClusteringConfig(
            group_size_min=group_size_min,
            group_size_max=group_size_max,
            population_size=population_size,
            generations=generations,
            distance_metric=distance_metric
        )
        
        # Get clustering service
        service = get_clustering_service()
        
        # Generate groups with custom configuration
        result = await service.generate_groups_with_config(
            file, 
            group_size_min=config.group_size_min,
            group_size_max=config.group_size_max,
            population_size=config.population_size,
            generations=config.generations,
            distance_metric=config.distance_metric
        )
        
        # Convert result to response format (same as above)
        groups = []
        for group_data in result["groups"]:
            members = []
            for member_data in group_data["members"]:
                class_name = member_data.get("class", member_data.get("class_name", ""))
                
                # Handle gender mapping back to readable format
                gender_display = "Male" if member_data["gender"] == "M" else "Female" if member_data["gender"] == "F" else member_data["gender"]
                
                member = StudentMember(
                    first_name=member_data["first_name"],
                    last_name=member_data["last_name"],
                    hard_skills=float(member_data["hard_skills"]),
                    soft_skills=float(member_data["soft_skills"]),
                    creativity=float(member_data["creativity"]),
                    teamwork=float(member_data["teamwork"]),
                    class_name=class_name,
                    gender=gender_display,
                    nationality=member_data["nationality"],
                    age=int(member_data["age"])
                )
                members.append(member)
            
            group = GeneratedGroup(
                group=group_data["group"],
                size=group_data["size"],
                members=members
            )
            groups.append(group)
        
        return ClusteringResponse(
            best_algorithm=result["best_algorithm"],
            groups=groups
        )
        
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Clustering failed: {str(e)}")

@router.post("/generate-clusters-quick", response_model=ClusteringResponse)
async def generate_clusters_quick(file: UploadFile = File(..., description="CSV file containing student data")):
    """
    Generate student groups using KMeans clustering only (fastest option).
    
    This is a quick version that skips algorithm comparison and uses only KMeans
    for optimal performance on large datasets.
    
    **Expected CSV columns:**
    - first_name, last_name
    - hard_skills, soft_skills, creativity, teamwork
    - class, gender, nationality, age
    
    **Returns:**
    - best_algorithm: "KMeans"
    - groups: List of generated groups with student details
    """
    try:
        # Validate file type
        if not file.filename.endswith('.csv'):
            raise HTTPException(status_code=400, detail="File must be a CSV")
        
        # Get clustering service and use quick generation
        service = get_clustering_service()
        result = await service.generate_groups_quick(file)
        
        # Convert result to response format (same as above)
        groups = []
        for group_data in result["groups"]:
            members = []
            for member_data in group_data["members"]:
                # Handle the 'class' field which might be named differently
                class_name = member_data.get("class", member_data.get("class_name", ""))
                
                # Handle gender mapping back to readable format
                gender_display = "Male" if member_data["gender"] == "M" else "Female" if member_data["gender"] == "F" else member_data["gender"]
                
                member = StudentMember(
                    first_name=member_data["first_name"],
                    last_name=member_data["last_name"],
                    hard_skills=float(member_data["hard_skills"]),
                    soft_skills=float(member_data["soft_skills"]),
                    creativity=float(member_data["creativity"]),
                    teamwork=float(member_data["teamwork"]),
                    class_name=class_name,
                    gender=gender_display,
                    nationality=member_data["nationality"],
                    age=int(member_data["age"])
                )
                members.append(member)
            
            group = GeneratedGroup(
                group=group_data["group"],
                size=group_data["size"],
                members=members
            )
            groups.append(group)
        
        return ClusteringResponse(
            best_algorithm=result["best_algorithm"],
            groups=groups
        )
        
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Clustering failed: {str(e)}")