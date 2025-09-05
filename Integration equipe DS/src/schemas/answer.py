from pydantic import BaseModel
from typing import Optional

class Answer(BaseModel):
    idAnswer: Optional[str] = None
    idUser: str
    idQuiz: str
    idQuestion: str
    idCategory: str   # ✅ On le stocke ici pour le calcul des scores
    value: int        # de 1 à 5
