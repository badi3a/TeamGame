from fastapi import APIRouter, HTTPException, Query
from typing import List
from schemas.quiz import Quiz
from core.firebase import db

router = APIRouter()
collection_name = "quizzes"
category_collection = "categories"

# 🔄 Convertir un document Firestore en objet Quiz
def doc_to_quiz(doc):
    data = doc.to_dict()
    return Quiz(
        idQuiz=doc.id,
        idTeacher=data.get("idTeacher"),
        idCategory=data.get("idCategory"),
        dateCreation=data.get("dateCreation"),
        isAccessible=data.get("isAccessible", True),
        accessCode=data.get("accessCode"),
        nameQuiz=data.get("nameQuiz")
    )

# ✅ Créer un quiz (au plus 4 catégories)
@router.post("/", response_model=Quiz)
def create_quiz(quiz: Quiz):
    if not isinstance(quiz.idCategory, list) or len(quiz.idCategory) > 4:
        raise HTTPException(
            status_code=400,
            detail="A quiz can have at most 4 categories."
        )
    doc_ref = db.collection(collection_name).document()
    data = quiz.dict(exclude={"idQuiz"})
    doc_ref.set(data)
    return Quiz(idQuiz=doc_ref.id, **data)

# ✅ Lister tous les quizzes
@router.get("/", response_model=List[Quiz])
def get_quizzes():
    docs = db.collection(collection_name).stream()
    return [doc_to_quiz(doc) for doc in docs]

# ✅ Récupérer un quiz par ID
@router.get("/{quiz_id}", response_model=Quiz)
def get_quiz(quiz_id: str):
    doc = db.collection(collection_name).document(quiz_id).get()
    if not doc.exists:
        raise HTTPException(404, "Quiz non trouvé")
    return doc_to_quiz(doc)

# ✅ Modifier un quiz
@router.put("/{quiz_id}", response_model=Quiz)
def update_quiz(quiz_id: str, quiz: Quiz):
    if len(quiz.idCategory) > 4:
        raise HTTPException(400, "A quiz can have at most 4 categories.")
    doc_ref = db.collection(collection_name).document(quiz_id)
    if not doc_ref.get().exists:
        raise HTTPException(404, "Quiz non trouvé")
    doc_ref.update(quiz.dict(exclude={"idQuiz"}))
    return Quiz(idQuiz=quiz_id, **quiz.dict(exclude={"idQuiz"}))

# ✅ Supprimer un quiz
@router.delete("/{quiz_id}")
def delete_quiz(quiz_id: str):
    doc_ref = db.collection(collection_name).document(quiz_id)
    if not doc_ref.get().exists:
        raise HTTPException(404, "Quiz non trouvé")
    doc_ref.delete()
    return {"detail": "Quiz supprimé"}

# ✅ Filtrer les quizzes par island (nom de catégorie)
@router.get("/by_island/", response_model=List[Quiz])
def get_quizzes_by_island(island: str = Query(..., description="Nom de l'island")):
    categories_query = db.collection(category_collection).where("island", "==", island).stream()
    id_categories = [doc.id for doc in categories_query]

    if not id_categories:
        raise HTTPException(404, "Aucune catégorie trouvée pour cet island")

    quizzes = []
    all_quizzes = db.collection(collection_name).stream()
    for doc in all_quizzes:
        quiz = doc_to_quiz(doc)
        if any(cat in id_categories for cat in quiz.idCategory):
            quizzes.append(quiz)

    if not quizzes:
        raise HTTPException(404, "Aucun quiz trouvé pour cet island")

    return quizzes

# ✅ Filtrer par enseignant (idTeacher)
@router.get("/by_teacher/{teacher_id}", response_model=List[Quiz])
def get_quizzes_by_teacher(teacher_id: str):
    docs = db.collection(collection_name).where("idTeacher", "==", teacher_id).stream()
    quizzes = [doc_to_quiz(doc) for doc in docs]
    if not quizzes:
        raise HTTPException(404, "Aucun quiz trouvé pour cet enseignant")
    return quizzes

# ✅ Lister les quizzes accessibles (publics)
@router.get("/accessible/", response_model=List[Quiz])
def get_accessible_quizzes():
    docs = db.collection(collection_name).where("isAccessible", "==", True).stream()
    return [doc_to_quiz(doc) for doc in docs]

# ✅ Obtenir un quiz par code d’accès
@router.get("/access_code/{code}", response_model=Quiz)
def get_quiz_by_access_code(code: str):
    docs = db.collection(collection_name).where("accessCode", "==", code).stream()
    for doc in docs:
        return doc_to_quiz(doc)
    raise HTTPException(404, "Aucun quiz avec ce code d'accès")

# ✅ Lister uniquement les noms des quizzes
@router.get("/names/", response_model=List[str])
def get_quiz_names():
    docs = db.collection(collection_name).stream()
    names = [doc.to_dict().get("nameQuiz") for doc in docs if doc.to_dict().get("nameQuiz")]
    if not names:
        raise HTTPException(404, "Aucun nom de quiz trouvé")
    return names
