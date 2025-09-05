from pydantic import BaseModel
from typing import Optional

class Score(BaseModel):
    idScore: Optional[str] = None
    totalScore: float
    scoreCategory1: float
    scoreCategory2: float
    scoreCategory3: float
    scoreCategory4: float
    idUser: str
    idQuiz: str
