from pydantic import BaseModel, Field
from typing import Optional, List

class GenerateRequest(BaseModel):
    dimension: str = Field(..., description="The dimension (e.g., 'creativity', 'teamwork')")
    subdimension: str = Field(..., description="The subdimension (e.g., 'innovation_problem_solving')")
    target_year_level: int = Field(..., ge=1, le=3, description="Target year level (1, 2, or 3)")
    additional_context: Optional[str] = Field(default=None, description="Optional additional context for generation")
    idQuiz: str = Field(..., description="Quiz ID to assign generated question to")
    idCategory: str = Field(..., description="Category ID to assign generated question to")

class GenerateResponse(BaseModel):
    question: str = Field(..., description="Generated Likert scale question")
    dimension: str = Field(..., description="The dimension used for generation")
    subdimension: str = Field(..., description="The subdimension used for generation")
    target_year_level: int = Field(..., description="The target year level used")
    response_scale: str = Field(default="1-5", description="Response scale (1=Strongly Disagree, 5=Strongly Agree)")
    saved_question_id: str = Field(..., description="Firebase ID of saved question")

class DimensionsResponse(BaseModel):
    dimensions: List[str] = Field(..., description="Available dimensions")

class SubdimensionsResponse(BaseModel):
    subdimensions: List[str] = Field(..., description="Available subdimensions for the dimension")
    dimension: str = Field(..., description="The dimension these subdimensions belong to")
