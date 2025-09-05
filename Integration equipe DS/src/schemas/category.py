from pydantic import BaseModel
from typing import Optional, List

class Category(BaseModel):
    idCategory: Optional[str] = None  # Optionnel pour l’entrée JSON
    island: str  
    subcategories: List[str] = []  # liste de noms des sous categories
