from pydantic import BaseModel, Field
from datetime import datetime
from typing import List, Optional

class Quiz(BaseModel):
    idQuiz: Optional[str] = None  # Optionnel pour l’entrée JSON
    idTeacher: str
    idCategory: List[str] = Field(..., min_items=4, max_items=4)
    dateCreation: datetime
    isAccessible: bool = True
    accessCode: str
    nameQuiz: str
    
