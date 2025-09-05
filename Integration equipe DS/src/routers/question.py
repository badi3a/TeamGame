# routers/question.py
from fastapi import APIRouter, HTTPException
from typing import List
from schemas.question import (
    Question, 
    QuestionGenerateRequest, 
    QuestionGenerateResponse, 
    DimensionsResponse, 
    SubdimensionsResponse,
    CategoryQuestionsRequest,
    CategoryQuestionsResponse,
    FullQuizRequest,
    FullQuizResponse
)
from core.firebase import db
from core.generation_service import QuestionGenerationService

router = APIRouter()
collection_name = "questions"

# Initialize generation service (singleton pattern)
generation_service = None

def get_generation_service():
    global generation_service
    if generation_service is None:
        generation_service = QuestionGenerationService()
    return generation_service

def doc_to_question(doc):
    data = doc.to_dict()
    return Question(
        idQuestion=doc.id,
        content=data.get("content"),
        idQuiz=data.get("idQuiz"),
        idCategory=data.get("idCategory")  # ✅ Ajout
    )


@router.post("/", response_model=Question)
def create_question(question: Question):
    doc_ref = db.collection(collection_name).document()  # ID auto-généré
    data = question.dict(exclude={"idQuestion"})  # on retire idQuestion si présent
    doc_ref.set(data)
    return Question(idQuestion=doc_ref.id, **data)  # on renvoie l'objet avec l'ID généré


@router.get("/", response_model=List[Question])
def get_questions():
    docs = db.collection(collection_name).stream()
    return [doc_to_question(doc) for doc in docs]

# ===============================================
# GENERATION ENDPOINTS (Must be before /{question_id})
# ===============================================

@router.get("/dimensions", response_model=DimensionsResponse)
def get_available_dimensions():
    """Get all available dimensions for question generation (limited to 4 valid categories)"""
    try:
        service = get_generation_service()
        
        # Only return the 4 valid dimensions, not all dataset dimensions
        valid_dimensions = service.get_valid_dimensions()
        
        # Filter categories to only include valid dimensions
        try:
            categories_docs = db.collection("categories").stream()
            existing_category_dimensions = []
            for doc in categories_docs:
                island = doc.to_dict().get("island", "")
                if island:
                    normalized = service.normalize_dimension_name(island)
                    if normalized in valid_dimensions:
                        existing_category_dimensions.append(normalized)
        except Exception as e:
            print(f"⚠️ Could not fetch categories: {e}")
            existing_category_dimensions = []
        
        # Use valid dimensions, but ensure they exist in categories
        if existing_category_dimensions:
            # Return dimensions that actually exist in the database
            available_dimensions = list(set(existing_category_dimensions))
        else:
            # Fallback to all valid dimensions if no categories found
            available_dimensions = valid_dimensions
        
        available_dimensions.sort()
        
        return DimensionsResponse(dimensions=available_dimensions)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to get dimensions: {str(e)}")


@router.get("/subdimensions/{dimension}", response_model=SubdimensionsResponse)
def get_available_subdimensions(dimension: str):
    """Get all available subdimensions for a given dimension (from dataset + categories)"""
    try:
        service = get_generation_service()
        
        # Get subdimensions from dataset
        dataset_subdimensions = service.get_available_subdimensions(dimension)
        
        # Get subdimensions from categories
        try:
            categories_docs = db.collection("categories").where("island", "==", dimension).stream()
            category_subdimensions = []
            for doc in categories_docs:
                subcats = doc.to_dict().get("subcategories", [])
                category_subdimensions.extend(subcats)
        except Exception as e:
            print(f"⚠️ Could not fetch category subdimensions: {e}")
            category_subdimensions = []
        
        # Combine and deduplicate
        all_subdimensions = list(set(dataset_subdimensions + category_subdimensions))
        all_subdimensions.sort()
        
        if not all_subdimensions:
            raise HTTPException(status_code=404, detail=f"No subdimensions found for dimension: {dimension}")
            
        return SubdimensionsResponse(subdimensions=all_subdimensions, dimension=dimension)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to get subdimensions: {str(e)}")


@router.post("/generate", response_model=QuestionGenerateResponse)
def generate_questions(request: QuestionGenerateRequest):
    """Generate AI question with auto-detection of dimension and subdimension from category"""
    try:
        # Get category to extract dimension
        category_ref = db.collection("categories").document(request.idCategory)
        category_doc = category_ref.get()
        
        if not category_doc.exists:
            raise HTTPException(status_code=404, detail=f"Category {request.idCategory} not found")
        
        category_data = category_doc.to_dict()
        dimension = category_data.get("island")
        
        if not dimension:
            raise HTTPException(status_code=400, detail="Category has no dimension (island) specified")
        
        # Validate that the dimension is one of the 4 allowed ones
        service = get_generation_service()
        valid_dimensions = service.get_valid_dimensions()
        normalized_dimension = service.normalize_dimension_name(dimension)
        
        if normalized_dimension not in valid_dimensions:
            raise HTTPException(status_code=400, detail=f"Invalid dimension '{dimension}'. Must be one of: {valid_dimensions}")
        
        # Use the normalized dimension for generation
        dimension = normalized_dimension
        
        # Determine subdimension
        subdimension = None
        if request.subdimension:
            # Teacher provided a specific subdimension
            subdimension = request.subdimension
        else:
            # Auto-select subdimension from category or dataset
            category_subdimensions = category_data.get("subcategories", [])
            
            if category_subdimensions:
                # Use first subdimension from category
                subdimension = category_subdimensions[0]
            else:
                # Fallback to first subdimension from dataset for this dimension
                service = get_generation_service()
                dataset_subdimensions = service.get_available_subdimensions(dimension)
                if dataset_subdimensions:
                    subdimension = dataset_subdimensions[0]
                else:
                    raise HTTPException(status_code=400, detail=f"No subdimensions available for dimension '{dimension}'")
        
        # Verify quiz exists
        quiz_ref = db.collection("quizzes").document(request.idQuiz)
        quiz_doc = quiz_ref.get()
        
        if not quiz_doc.exists:
            raise HTTPException(status_code=404, detail=f"Quiz {request.idQuiz} not found")
        
        print(f"🎯 Generating question: {dimension} -> {subdimension} (Year {request.target_year_level})")
        
        # Generate question using the AI service
        service = get_generation_service()
        generation_result = service.generate_questions(
            dimension=dimension,
            subdimension=subdimension,
            target_year_level=request.target_year_level,
            additional_context=None  # Removed additional_context
        )
        
        # Create a Question model instance with the generated content
        new_question = Question(
            content=generation_result["question"],
            idQuiz=request.idQuiz,
            idCategory=request.idCategory
        )
        
        # Use the existing create_question function to save to Firebase
        saved_question = create_question(new_question)
        
        # Update category to include the subdimension if it's not already there
        try:
            _update_category_with_subdimension(request.idCategory, subdimension)
        except Exception as e:
            print(f"⚠️ Warning: Could not update category with subdimension: {e}")
        
        return QuestionGenerateResponse(
            question=saved_question,
            generation_metadata={
                "dimension": generation_result["dimension"],
                "subdimension": generation_result["subdimension"],
                "target_year_level": generation_result["target_year_level"],
                "context_used": generation_result.get("context_used", []),
                "response_scale": "1-5"
            }
        )
        
    except HTTPException:
        raise
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to generate question: {str(e)}")


@router.post("/generate-category", response_model=CategoryQuestionsResponse)
def generate_category_questions(request: CategoryQuestionsRequest):
    """Generate multiple questions for a specific category"""
    try:
        # Get category to extract dimension
        category_ref = db.collection("categories").document(request.idCategory)
        category_doc = category_ref.get()
        
        if not category_doc.exists:
            raise HTTPException(status_code=404, detail=f"Category {request.idCategory} not found")
        
        category_data = category_doc.to_dict()
        dimension = category_data.get("island")
        
        if not dimension:
            raise HTTPException(status_code=400, detail="Category has no dimension (island) specified")
        
        # Validate that the dimension is one of the 4 allowed ones
        service = get_generation_service()
        valid_dimensions = service.get_valid_dimensions()
        normalized_dimension = service.normalize_dimension_name(dimension)
        
        if normalized_dimension not in valid_dimensions:
            raise HTTPException(status_code=400, detail=f"Invalid dimension '{dimension}'. Must be one of: {valid_dimensions}")
        
        # Use the normalized dimension for generation
        dimension = normalized_dimension
        
        # Verify quiz exists
        quiz_ref = db.collection("quizzes").document(request.idQuiz)
        quiz_doc = quiz_ref.get()
        
        if not quiz_doc.exists:
            raise HTTPException(status_code=404, detail=f"Quiz {request.idQuiz} not found")
        
        print(f"🎯 Generating {request.num_questions} questions for {dimension} (Year {request.target_year_level})")
        
        # Generate questions using the AI service
        service = get_generation_service()
        generation_results = service.generate_category_questions(
            dimension=dimension,
            num_questions=request.num_questions,
            target_year_level=request.target_year_level
        )
        
        # Create Question instances and save them to Firebase
        saved_questions = []
        for result in generation_results:
            new_question = Question(
                content=result["question"],
                idQuiz=request.idQuiz,
                idCategory=request.idCategory
            )
            saved_question = create_question(new_question)
            saved_questions.append(saved_question)
            
            # Update category with subdimension
            try:
                _update_category_with_subdimension(request.idCategory, result["subdimension"])
            except Exception as e:
                print(f"⚠️ Warning: Could not update category with subdimension: {e}")
        
        # Prepare metadata
        metadata = {
            "dimension": dimension,
            "total_generated": len(saved_questions),
            "target_year_level": request.target_year_level,
            "subdimension_distribution": generation_results[0]["category_distribution"] if generation_results else {},
            "response_scale": "1-5"
        }
        
        return CategoryQuestionsResponse(
            questions=saved_questions,
            generation_metadata=metadata
        )
        
    except HTTPException:
        raise
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to generate category questions: {str(e)}")


@router.post("/generate-full-quiz", response_model=FullQuizResponse)
def generate_full_quiz(request: FullQuizRequest):
    """Generate a complete balanced quiz across all 4 major categories"""
    try:
        # Verify quiz exists
        quiz_ref = db.collection("quizzes").document(request.idQuiz)
        quiz_doc = quiz_ref.get()
        
        if not quiz_doc.exists:
            raise HTTPException(status_code=404, detail=f"Quiz {request.idQuiz} not found")
        
        # Get quiz data to find categories
        quiz_data = quiz_doc.to_dict()
        quiz_categories = quiz_data.get("idCategory", [])
        
        if len(quiz_categories) != 4:
            raise HTTPException(status_code=400, detail="Quiz must have exactly 4 categories for full quiz generation")
        
        print(f"🎯 Generating full quiz with {request.total_questions} questions (Year {request.target_year_level})")
        
        # Generate questions using the AI service
        service = get_generation_service()
        generation_result = service.generate_full_quiz(
            total_questions=request.total_questions,
            target_year_level=request.target_year_level
        )
        
        # Map dimensions to category IDs
        dimension_to_category = {}
        for category_id in quiz_categories:
            category_ref = db.collection("categories").document(category_id)
            category_doc = category_ref.get()
            if category_doc.exists:
                category_data = category_doc.to_dict()
                dimension = category_data.get("island")
                if dimension:
                    dimension_to_category[dimension] = category_id
        
        # Create Question instances and save them to Firebase
        saved_questions = []
        for result in generation_result["questions"]:
            dimension = result["dimension"]
            category_id = dimension_to_category.get(dimension)
            
            if not category_id:
                print(f"⚠️ No category found for dimension {dimension}, using first available")
                category_id = quiz_categories[0]
            
            new_question = Question(
                content=result["question"],
                idQuiz=request.idQuiz,
                idCategory=category_id
            )
            saved_question = create_question(new_question)
            saved_questions.append(saved_question)
            
            # Update category with subdimension
            try:
                _update_category_with_subdimension(category_id, result["subdimension"])
            except Exception as e:
                print(f"⚠️ Warning: Could not update category with subdimension: {e}")
        
        # Prepare comprehensive metadata
        metadata = {
            "total_generated": len(saved_questions),
            "target_year_level": request.target_year_level,
            "questions_per_category": generation_result["questions_per_category"],
            "major_categories": generation_result["major_categories"],
            "category_distributions": generation_result["category_distributions"],
            "dimension_to_category_mapping": dimension_to_category,
            "response_scale": "1-5"
        }
        
        return FullQuizResponse(
            questions=saved_questions,
            generation_metadata=metadata
        )
        
    except HTTPException:
        raise
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to generate full quiz: {str(e)}")


def _update_category_with_subdimension(category_id: str, subdimension: str):
    """Update category to include the subdimension if it's not already present"""
    try:
        # Get the category document
        category_ref = db.collection("categories").document(category_id)
        category_doc = category_ref.get()
        
        if category_doc.exists:
            category_data = category_doc.to_dict()
            subcategories = category_data.get("subcategories", [])
            
            # Add the subdimension if it's not already in the list
            if subdimension not in subcategories:
                subcategories.append(subdimension)
                category_ref.update({"subcategories": subcategories})
                print(f"✅ Added '{subdimension}' to category {category_id}")
        else:
            print(f"⚠️ Category {category_id} not found")
            
    except Exception as e:
        print(f"❌ Error updating category: {e}")
        # Don't raise the error as this is not critical for question generation

@router.get("/{question_id}", response_model=Question)
def get_question(question_id: str):
    doc = db.collection(collection_name).document(question_id).get()
    if not doc.exists:
        raise HTTPException(404, "Question non trouvée")
    return doc_to_question(doc)

@router.put("/{question_id}", response_model=Question)
def update_question(question_id: str, question: Question):
    doc_ref = db.collection(collection_name).document(question_id)
    if not doc_ref.get().exists:
        raise HTTPException(404, "Question non trouvée")
    doc_ref.set(question.dict())
    return question

@router.delete("/{question_id}")
def delete_question(question_id: str):
    doc_ref = db.collection(collection_name).document(question_id)
    if not doc_ref.get().exists:
        raise HTTPException(404, "Question non trouvée")
    doc_ref.delete()
    return {"detail": "Question supprimée"}


@router.get("/by_quiz/{quiz_id}", response_model=List[Question])
def get_questions_by_quiz(quiz_id: str):
    query = db.collection(collection_name).where("idQuiz", "==", quiz_id).stream()
    questions = [doc_to_question(doc) for doc in query]
    if not questions:
        raise HTTPException(status_code=404, detail="Aucune question trouvée pour ce quiz")
    return questions


@router.get("/search/", response_model=List[Question])
def search_questions(keyword: str):
    all_questions = db.collection(collection_name).stream()
    filtered = [
        doc_to_question(doc)
        for doc in all_questions
        if keyword.lower() in doc.to_dict().get("content", "").lower()
    ]
    if not filtered:
        raise HTTPException(404, detail="Aucune question ne correspond à ce mot-clé")
    return filtered
