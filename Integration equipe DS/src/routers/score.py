from fastapi import APIRouter, HTTPException
from core.firebase import db
from schemas.score import Score
import uuid
from typing import List

router = APIRouter()

answers_collection = "answers"
scores_collection = "scores"
quizzes_collection = "quizzes"

def doc_to_score(doc) -> Score:
    data = doc.to_dict()
    return Score(
        idScore=doc.id,
        idUser=data["idUser"],
        idQuiz=data["idQuiz"],
        totalScore=data["totalScore"],
        scoreCategory1=data.get("scoreCategory1", 0.0),
        scoreCategory2=data.get("scoreCategory2", 0.0),
        scoreCategory3=data.get("scoreCategory3", 0.0),
        scoreCategory4=data.get("scoreCategory4", 0.0)
    )

@router.post("/calculate_score/{quiz_id}/user/{user_id}", response_model=Score)
def calculate_score(quiz_id: str, user_id: str):
    quiz_doc = db.collection(quizzes_collection).document(quiz_id).get()
    if not quiz_doc.exists:
        raise HTTPException(status_code=404, detail="Quiz non trouvé")
    
    quiz_data = quiz_doc.to_dict()
    categories = quiz_data.get("idCategory", [])
    if len(categories) != 4:
        raise HTTPException(status_code=400, detail="Le quiz doit contenir exactement 4 catégories")

    docs = db.collection(answers_collection) \
             .where("idQuiz", "==", quiz_id) \
             .where("idUser", "==", user_id) \
             .stream()

    answers = [doc.to_dict() for doc in docs]
    if not answers:
        raise HTTPException(status_code=404, detail="Aucune réponse trouvée")

    scores_by_cat = {cat: [] for cat in categories}
    for ans in answers:
        cat = ans.get("idCategory")
        if cat in scores_by_cat:
            scores_by_cat[cat].append(ans.get("value", 0))

    averages = []
    for cat in categories:
        vals = scores_by_cat[cat]
        avg = round(sum(vals) / len(vals), 2) if vals else 0.0
        averages.append(avg)

    total_score = round(sum(averages) / 4, 2)

    # Vérifier si score déjà existant pour update
    existing_score_query = db.collection(scores_collection) \
                             .where("idQuiz", "==", quiz_id) \
                             .where("idUser", "==", user_id) \
                             .limit(1) \
                             .stream()
    existing_score_doc = next(existing_score_query, None)

    if existing_score_doc:
        score_id = existing_score_doc.id
    else:
        score_id = str(uuid.uuid4())

    score_data = {
        "idScore": score_id,
        "idUser": user_id,
        "idQuiz": quiz_id,
        "scoreCategory1": averages[0],
        "scoreCategory2": averages[1],
        "scoreCategory3": averages[2],
        "scoreCategory4": averages[3],
        "totalScore": total_score
    }

    db.collection(scores_collection).document(score_id).set(score_data)
    return Score(**score_data)

@router.get("/get_score/{quiz_id}/user/{user_id}", response_model=Score)
def get_score(quiz_id: str, user_id: str):
    query = db.collection(scores_collection) \
              .where("idQuiz", "==", quiz_id) \
              .where("idUser", "==", user_id) \
              .stream()

    for doc in query:
        return doc_to_score(doc)

    raise HTTPException(status_code=404, detail="Score non trouvé pour ce quiz et cet utilisateur")

# Scores par utilisateur (liste)
@router.get("/scores/user/{user_id}", response_model=List[Score])
def get_scores_by_user(user_id: str):
    docs = db.collection(scores_collection).where("idUser", "==", user_id).stream()
    return [doc_to_score(doc) for doc in docs]

# Scores par quiz (liste)
@router.get("/scores/quiz/{quiz_id}", response_model=List[Score])
def get_scores_by_quiz(quiz_id: str):
    docs = db.collection(scores_collection).where("idQuiz", "==", quiz_id).stream()
    return [doc_to_score(doc) for doc in docs]
