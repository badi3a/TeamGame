from pydantic import BaseModel, Field
from typing import Optional, List

class Question(BaseModel):
    idQuestion: Optional[str] = None
    content: str
    idQuiz: str
    idCategory: str  # ✅ La catégorie liée à cette question

class QuestionGenerateRequest(BaseModel):
    """Request for AI-generated questions"""
    idQuiz: str = Field(..., description="Quiz ID to assign generated question to")
    idCategory: str = Field(..., description="Category ID to assign generated question to")
    subdimension: Optional[str] = Field(default=None, description="Specific subdimension (optional - will auto-detect from category)")
    target_year_level: int = Field(..., ge=1, le=3, description="Target year level (1, 2, or 3)")

class QuestionGenerateResponse(BaseModel):
    """Response for AI-generated questions"""
    question: Question = Field(..., description="The generated and saved question")
    generation_metadata: dict = Field(..., description="Metadata about the generation process")

class DimensionsResponse(BaseModel):
    """Available dimensions for question generation"""
    dimensions: List[str] = Field(..., description="Available dimensions")

class SubdimensionsResponse(BaseModel):
    """Available subdimensions for a specific dimension"""
    subdimensions: List[str] = Field(..., description="Available subdimensions")
    dimension: str = Field(..., description="The dimension these subdimensions belong to")

class CategoryQuestionsRequest(BaseModel):
    """Request for generating multiple questions for a specific category"""
    idQuiz: str = Field(..., description="Quiz ID to assign generated questions to")
    idCategory: str = Field(..., description="Category ID to generate questions for")
    num_questions: int = Field(..., ge=1, le=50, description="Number of questions to generate (1-50)")
    target_year_level: int = Field(..., ge=1, le=3, description="Target year level (1, 2, or 3)")

class CategoryQuestionsResponse(BaseModel):
    """Response for generating multiple questions for a specific category"""
    questions: List[Question] = Field(..., description="The generated and saved questions")
    generation_metadata: dict = Field(..., description="Metadata about the generation process")

class FullQuizRequest(BaseModel):
    """Request for generating a complete balanced quiz across all 4 major categories"""
    idQuiz: str = Field(..., description="Quiz ID to assign generated questions to")
    total_questions: int = Field(..., ge=8, le=200, description="Total number of questions to generate (8-200, must be divisible by 4)")
    target_year_level: int = Field(..., ge=1, le=3, description="Target year level (1, 2, or 3)")

class FullQuizResponse(BaseModel):
    """Response for generating a complete balanced quiz"""
    questions: List[Question] = Field(..., description="All generated and saved questions")
    generation_metadata: dict = Field(..., description="Metadata about the generation process including distribution")


