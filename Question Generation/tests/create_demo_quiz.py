from shared_storage import QuizStorage

# Create a comprehensive test quiz (updated for new format without response_scale)
storage = QuizStorage()

test_questions = [
    {
        "question_id": "demo_001",
        "dimension": "creativity",
        "subdimension": "innovation_problem_solving",
        "question_text": "I often come up with unique solutions to complex problems.",
        "target_year_level": 1
        # Removed response_scale - all questions use standard 1-5 Likert scale
    },
    {
        "question_id": "demo_002", 
        "dimension": "creativity",
        "subdimension": "innovation_problem_solving",
        "question_text": "I enjoy brainstorming new ideas and approaches.",
        "target_year_level": 1
        # Removed response_scale - all questions use standard 1-5 Likert scale
    },
    {
        "question_id": "demo_003",
        "dimension": "teamwork",
        "subdimension": "communication_documentation",
        "question_text": "I work effectively with team members to achieve common goals.",
        "target_year_level": 1
        # Removed response_scale - all questions use standard 1-5 Likert scale
    },
    {
        "question_id": "demo_004",
        "dimension": "teamwork", 
        "subdimension": "communication_documentation",
        "question_text": "I listen actively to others' perspectives and ideas.",
        "target_year_level": 1
        # Removed response_scale - all questions use standard 1-5 Likert scale
    },
    {
        "question_id": "demo_005",
        "dimension": "soft_skills",
        "subdimension": "leadership",
        "question_text": "I can motivate and inspire others to perform their best.",
        "target_year_level": 1
        # Removed response_scale - all questions use standard 1-5 Likert scale
    },
    {
        "question_id": "demo_006",
        "dimension": "soft_skills",
        "subdimension": "leadership", 
        "question_text": "I take initiative in challenging situations.",
        "target_year_level": 1
        # Removed response_scale - all questions use standard 1-5 Likert scale
    },
    {
        "question_id": "demo_007",
        "dimension": "hard_skills",
        "subdimension": "programming_languages",
        "question_text": "I can analyze data to identify trends and patterns.",
        "target_year_level": 1
        # Removed response_scale - all questions use standard 1-5 Likert scale
    },
    {
        "question_id": "demo_008",
        "dimension": "hard_skills",
        "subdimension": "programming_languages",
        "question_text": "I use data-driven insights to make informed decisions.",
        "target_year_level": 1
        # Removed response_scale - all questions use standard 1-5 Likert scale
    }
]

quiz_id = storage.save_quiz(test_questions, "🎯 Demo Self-Assessment Quiz")
print(f"✅ Created demo quiz with ID: {quiz_id}")
print(f"✅ Quiz contains {len(test_questions)} questions")
print(f"✅ Covers {len(set([q['dimension'] for q in test_questions]))} dimensions")

# Show what was saved
quizzes = storage.get_all_quizzes()
latest = quizzes[-1]
print(f"✅ Latest quiz: '{latest['title']}' with {len(latest['data'])} questions")

print("\n🎉 Demo quiz created successfully!")
print("Now you can:")
print("1. Go to Student Interface (http://localhost:8502)")
print("2. Select the demo quiz")
print("3. Take the assessment and see the fun interface!")
print("4. Check Teacher Interface (http://localhost:8501) for responses")
