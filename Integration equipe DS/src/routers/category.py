from fastapi import APIRouter, HTTPException, Body
from typing import List
from schemas.category import Category
from core.firebase import db

router = APIRouter()
collection_name = "categories"

def doc_to_category(doc):
    data = doc.to_dict()
    return Category(
        idCategory=doc.id,
        island=data.get("island", ""),
        subcategories=data.get("subcategories", [])
    )

# 🔹 Créer une nouvelle catégorie
@router.post("/", response_model=Category)
def create_category(category: Category):
    doc_ref = db.collection(collection_name).document()
    data = category.dict(exclude={"idCategory"})
    doc_ref.set(data)
    return Category(idCategory=doc_ref.id, **data)

# 🔹 Lister toutes les catégories
@router.get("/", response_model=List[Category])
def get_categories():
    docs = db.collection(collection_name).stream()
    return [doc_to_category(doc) for doc in docs]

# 🔹 Obtenir une catégorie par ID
@router.get("/{category_id}", response_model=Category)
def get_category(category_id: str):
    doc = db.collection(collection_name).document(category_id).get()
    if not doc.exists:
        raise HTTPException(status_code=404, detail="Catégorie non trouvée")
    return doc_to_category(doc)

# 🔹 Mettre à jour toute une catégorie
@router.put("/{category_id}", response_model=Category)
def update_category(category_id: str, category: Category):
    doc_ref = db.collection(collection_name).document(category_id)
    if not doc_ref.get().exists:
        raise HTTPException(status_code=404, detail="Catégorie non trouvée")
    data = category.dict(exclude_unset=True, exclude={"idCategory"})
    doc_ref.update(data)
    return Category(idCategory=category_id, **data)

# 🔹 Supprimer une catégorie
@router.delete("/{category_id}")
def delete_category(category_id: str):
    doc_ref = db.collection(collection_name).document(category_id)
    if not doc_ref.get().exists:
        raise HTTPException(status_code=404, detail="Catégorie non trouvée")
    doc_ref.delete()
    return {"detail": "Catégorie supprimée"}

# ✅🔹 AJOUTER une sous-catégorie
@router.post("/{category_id}/subcategories")
def add_subcategory(category_id: str, subcategory: str = Body(...)):
    doc_ref = db.collection(collection_name).document(category_id)
    doc = doc_ref.get()
    if not doc.exists:
        raise HTTPException(status_code=404, detail="Catégorie non trouvée")
    current_data = doc.to_dict()
    subcategories = current_data.get("subcategories", [])
    if subcategory.strip() == "":
        raise HTTPException(status_code=422, detail="La sous-catégorie ne peut pas être vide")
    if subcategory in subcategories:
        raise HTTPException(status_code=400, detail="Sous-catégorie déjà existante")
    subcategories.append(subcategory)
    doc_ref.update({"subcategories": subcategories})
    return {"detail": f"Sous-catégorie '{subcategory}' ajoutée"}

# ✅🔹 SUPPRIMER une sous-catégorie
@router.delete("/{category_id}/subcategories/{subcategory}")
def delete_subcategory(category_id: str, subcategory: str):
    doc_ref = db.collection(collection_name).document(category_id)
    doc = doc_ref.get()
    if not doc.exists:
        raise HTTPException(status_code=404, detail="Catégorie non trouvée")
    current_data = doc.to_dict()
    subcategories = current_data.get("subcategories", [])
    if subcategory not in subcategories:
        raise HTTPException(status_code=404, detail="Sous-catégorie non trouvée")
    subcategories.remove(subcategory)
    doc_ref.update({"subcategories": subcategories})
    return {"detail": f"Sous-catégorie '{subcategory}' supprimée"}

# ✅🔹 METTRE À JOUR le nom d'une sous-catégorie
@router.put("/{category_id}/subcategories/{old_subcategory}")
def update_subcategory(category_id: str, old_subcategory: str, new_subcategory: str = Body(...)):
    doc_ref = db.collection(collection_name).document(category_id)
    doc = doc_ref.get()
    if not doc.exists:
        raise HTTPException(status_code=404, detail="Catégorie non trouvée")
    current_data = doc.to_dict()
    subcategories = current_data.get("subcategories", [])
    if old_subcategory not in subcategories:
        raise HTTPException(status_code=404, detail="Ancienne sous-catégorie non trouvée")
    if new_subcategory in subcategories:
        raise HTTPException(status_code=400, detail="Nouvelle sous-catégorie déjà existante")
    index = subcategories.index(old_subcategory)
    subcategories[index] = new_subcategory
    doc_ref.update({"subcategories": subcategories})
    return {"detail": f"Sous-catégorie renommée en '{new_subcategory}'"}