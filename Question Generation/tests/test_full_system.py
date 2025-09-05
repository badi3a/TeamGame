#!/usr/bin/env python3
"""
Comprehensive test script to verify the entire quiz system
"""

import requests
import json
from shared_storage import QuizStorage
import time

def test_full_workflow():
    print("🧪 Testing Full Quiz System Workflow...")
    print("=" * 50)
    
    # 1. Test API connection
    print("1️⃣ Testing API connection...")
    try:
        response = requests.get("http://localhost:8000/health", timeout=5)
        if response.status_code == 200:
            print("✅ API server is running")
        else:
            print(f"❌ API health check failed: {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ API connection failed: {str(e)}")
        return False
    
    # 2. Test question generation via API
    print("\n2️⃣ Testing question generation...")
    try:
        # First get available dimensions and subdimensions
        dims_response = requests.get("http://localhost:8000/dimensions", timeout=5)
        if dims_response.status_code == 200:
            dimensions = dims_response.json()
            print(f"Available dimensions: {dimensions}")
            
            if dimensions:
                test_dim = dimensions[0]  # Use first available dimension
                
                # Get subdimensions for this dimension
                subdims_response = requests.get(f"http://localhost:8000/subdimensions/{test_dim}", timeout=5)
                if subdims_response.status_code == 200:
                    subdimensions = subdims_response.json()
                    print(f"Available subdimensions for {test_dim}: {subdimensions}")
                    
                    if subdimensions:
                        test_subdim = subdimensions[0]  # Use first available subdimension
                        
                        payload = {
                            "dimension": test_dim,
                            "subdimension": test_subdim,
                            "target_year_level": 1,  # Use year level 1 which exists in dataset
                            "num_questions": 5,
                            "additional_context": "Focus on workplace scenarios"
                        }
                        
                        response = requests.post("http://localhost:8000/generate", json=payload, timeout=30)
                        if response.status_code == 200:
                            questions = response.json()["questions"]
                            print(f"✅ Generated {len(questions)} questions via API")
                            
                            # Test storage (updated for new format without response_scale)
                            storage = QuizStorage()
                            quiz_data = []
                            for i, question in enumerate(questions):
                                quiz_data.append({
                                    "question_id": f"api_test_{i+1:03d}",
                                    "dimension": test_dim,
                                    "subdimension": test_subdim,
                                    "question_text": question,
                                    "target_year_level": 1
                                    # Removed response_scale - all questions use standard 1-5 Likert scale
                                })
                            
                            quiz_id = storage.save_quiz(quiz_data, f"API Generated Quiz - {len(questions)} Questions")
                            print(f"✅ Saved quiz with ID: {quiz_id}")
                            
                        else:
                            print(f"❌ Question generation failed: {response.status_code}")
                            print(f"Response: {response.text}")
                            return False
                    else:
                        print("❌ No subdimensions available")
                        return False
                else:
                    print(f"❌ Failed to get subdimensions: {subdims_response.status_code}")
                    return False
            else:
                print("❌ No dimensions available")
                return False
        else:
            print(f"❌ Failed to get dimensions: {dims_response.status_code}")
            return False
            
    except Exception as e:
        print(f"❌ Question generation test failed: {str(e)}")
        return False
    
    # 3. Test storage operations
    print("\n3️⃣ Testing storage operations...")
    try:
        storage = QuizStorage()
        
        # Test getting all quizzes
        quizzes = storage.get_all_quizzes()
        print(f"✅ Found {len(quizzes)} saved quizzes")
        
        if quizzes:
            latest_quiz = quizzes[-1]
            print(f"✅ Latest quiz: '{latest_quiz['title']}' with {len(latest_quiz['data'])} questions")
            
            # Test saving responses
            test_responses = {}
            test_scores = {}
            
            for i, question in enumerate(latest_quiz['data'][:3]):  # Test first 3 questions
                test_responses[question['question_id']] = 4  # Mock response
            
            test_scores['creativity'] = 4.0
            
            storage.save_responses(latest_quiz['id'], "Test Student", test_responses, test_scores)
            print("✅ Saved test responses")
            
            # Test getting responses
            responses = storage.get_responses_for_quiz(latest_quiz['id'])
            print(f"✅ Retrieved {len(responses)} responses for the quiz")
            
    except Exception as e:
        print(f"❌ Storage test failed: {str(e)}")
        return False
    
    # 4. Test UI accessibility
    print("\n4️⃣ Testing UI accessibility...")
    services = {
        "Teacher Interface": "http://localhost:8501",
        "Student Interface": "http://localhost:8502", 
        "Main Hub": "http://localhost:8503"
    }
    
    for name, url in services.items():
        try:
            response = requests.get(url, timeout=3)
            if response.status_code == 200:
                print(f"✅ {name} is accessible")
            else:
                print(f"⚠️ {name} returned status {response.status_code}")
        except Exception as e:
            print(f"❌ {name} is not accessible: {str(e)}")
    
    print("\n🎉 Full workflow test completed!")
    print("=" * 50)
    print("Next steps:")
    print("1. Open http://localhost:8503 for the main hub")
    print("2. Use Teacher Interface to generate and save quizzes")
    print("3. Use Student Interface to take the quizzes")
    print("4. Check that saved quizzes appear in both interfaces")
    print("5. Verify that student responses appear in teacher analytics")
    
    return True

if __name__ == "__main__":
    test_full_workflow()
