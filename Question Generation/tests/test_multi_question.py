from shared_storage import QuizStorage

storage = QuizStorage()

# Create a test quiz with multiple questions (updated for new format without response_scale)
test_quiz_data = []
for i in range(5):
    test_quiz_data.append({
        'question_id': f'test_{i+1:03d}',
        'dimension': 'creativity',
        'subdimension': 'innovation_problem_solving', 
        'question_text': f'Test question {i+1}: I demonstrate creative thinking in my work.',
        'target_year_level': 1  # Changed from 12 to 1 (valid range is 1-3)
        # Removed response_scale - all questions use standard 1-5 Likert scale
    })

quiz_id = storage.save_quiz(test_quiz_data, 'Test Quiz with 5 Questions')
print(f'✅ Quiz saved with ID: {quiz_id}')
print(f'✅ Questions saved: {len(test_quiz_data)}')

# Verify
quizzes = storage.get_all_quizzes()
latest_quiz = quizzes[-1]
print(f'✅ Latest quiz has {len(latest_quiz["data"])} questions')
print(f'✅ Quiz title: {latest_quiz["title"]}')
