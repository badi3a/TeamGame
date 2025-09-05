from pydantic import BaseModel, Field
from typing import List, Optional, Dict, Any
from fastapi import UploadFile

class Group(BaseModel):
    idGroup: Optional[str] = None  # Optionnel pour l'entrée JSON
    groupName: str
    members: List[str]  # Liste d'IDs d'étudiants

# Clustering schemas
class ClusteringRequest(BaseModel):
    """Request schema for clustering endpoint"""
    file: UploadFile = Field(..., description="CSV file containing student data")
    
    class Config:
        arbitrary_types_allowed = True

class StudentMember(BaseModel):
    """Schema for individual student member in a group"""
    first_name: str
    last_name: str
    hard_skills: float
    soft_skills: float
    creativity: float
    teamwork: float
    class_name: str
    gender: str
    nationality: str
    age: int

class GeneratedGroup(BaseModel):
    """Schema for a generated group"""
    group: int = Field(..., description="Group number")
    size: int = Field(..., description="Number of members in the group")
    members: List[StudentMember] = Field(..., description="List of group members")

class ClusteringResponse(BaseModel):
    """Response schema for clustering endpoint"""
    best_algorithm: str = Field(..., description="Name of the best performing clustering algorithm")
    groups: List[GeneratedGroup] = Field(..., description="List of generated groups")

class ClusteringConfig(BaseModel):
    """Configuration schema for clustering parameters"""
    group_size_min: int = Field(default=5, ge=3, le=10, description="Minimum group size")
    group_size_max: int = Field(default=7, ge=5, le=15, description="Maximum group size")
    population_size: int = Field(default=30, ge=10, le=100, description="Genetic algorithm population size")
    generations: int = Field(default=50, ge=10, le=200, description="Number of genetic algorithm generations")
    distance_metric: str = Field(default="euclidean", description="Distance metric for clustering algorithms")
