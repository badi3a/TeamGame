#!/usr/bin/env python3
"""Test script to verify storage functionality"""

from shared_storage import QuizStorage
import json

def test_storage():
    print("🧪 Testing storage functionality...")
    
    try:
        # Initialize storage
        storage = QuizStorage()
        print("✅ Storage initialized successfully")
        
        # Test saving a quiz (updated for new format without response_scale)
        test_quiz_data = [
            {
                "question_id": "test_001",
                "dimension": "creativity",
                "subdimension": "innovation_problem_solving",
                "question_text": "I often come up with creative solutions to problems",
                "target_year_level": 1  # Changed from 12 to 1 (valid range is 1-3)
                # Removed response_scale - all questions use standard 1-5 Likert scale
            }
        ]
        
        quiz_id = storage.save_quiz(test_quiz_data, "Test Quiz")
        print(f"✅ Quiz saved successfully with ID: {quiz_id}")
        
        # Test loading quizzes
        quizzes = storage.get_all_quizzes()
        print(f"✅ Loaded {len(quizzes)} quizzes")
        
        # Test saving responses
        test_responses = {
            "test_001": 4
        }
        test_scores = {
            "creativity": 4.0
        }
        
        storage.save_responses(quiz_id, "Test Student", test_responses, test_scores)
        print("✅ Responses saved successfully")
        
        # Test loading responses
        responses = storage.get_responses_for_quiz(quiz_id)
        print(f"✅ Loaded {len(responses)} responses")
        
        print("\n🎉 All tests passed! Storage is working correctly.")
        
        # Show what was saved
        print("\n📊 Storage contents:")
        print(f"Quizzes: {len(quizzes)}")
        print(f"Responses: {len(responses)}")
        
        return True
        
    except Exception as e:
        print(f"❌ Test failed: {str(e)}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == "__main__":
    test_storage()
