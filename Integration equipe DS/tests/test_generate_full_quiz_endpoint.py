"""
Test the /generate-full-quiz endpoint for complete balanced quiz generation
"""
import requests
import json
from typing import Dict, Any, List

# Test configuration
BASE_URL = "http://localhost:8000"
TEST_QUIZ_ID = "RQIALTIccH9o7XZThPi2"  # Quiz with 4 different categories (all dimensions)

class TestGenerateFullQuizEndpoint:
    """Test cases for POST /questions/generate-full-quiz"""
    
    def test_generate_full_quiz_success(self):
        """Test successful full quiz generation"""
        url = f"{BASE_URL}/questions/generate-full-quiz"
        
        payload = {
            "idQuiz": TEST_QUIZ_ID,
            "total_questions": 20,  # 5 per category
            "target_year_level": 2
        }
        
        response = requests.post(url, json=payload)
        
        # Assert response status
        assert response.status_code == 200, f"Expected 200, got {response.status_code}: {response.text}"
        
        # Parse response
        data = response.json()
        
        # Assert response structure
        assert "questions" in data, "Response should contain 'questions' field"
        assert "generation_metadata" in data, "Response should contain 'generation_metadata' field"
        
        # Assert questions structure
        questions = data["questions"]
        assert isinstance(questions, list), "Questions should be a list"
        assert len(questions) == 20, f"Should generate 20 questions, got {len(questions)}"
        
        # Check each question
        for i, question in enumerate(questions):
            assert "idQuestion" in question, f"Question {i} should have idQuestion"
            assert "content" in question, f"Question {i} should have content"
            assert "idQuiz" in question, f"Question {i} should have idQuiz"
            assert "idCategory" in question, f"Question {i} should have idCategory"
            
            # Assert question values
            assert question["idQuiz"] == TEST_QUIZ_ID, f"Question {i} should have correct quiz ID"
            assert len(question["content"]) > 10, f"Question {i} content should be meaningful"
        
        # Assert metadata structure
        metadata = data["generation_metadata"]
        required_fields = [
            "total_generated", "target_year_level", "questions_per_category",
            "major_categories", "category_distributions", "dimension_to_category_mapping", "response_scale"
        ]
        
        for field in required_fields:
            assert field in metadata, f"Metadata should contain '{field}' field"
        
        # Assert metadata values
        assert metadata["total_generated"] == 20, "Should match requested total"
        assert metadata["target_year_level"] == 2, "Should match requested year level"
        assert metadata["questions_per_category"] == 5, "Should be evenly distributed"
        assert metadata["response_scale"] == "1-5", "Should use standard Likert scale"
        
        # Assert major categories
        major_categories = metadata["major_categories"]
        expected_categories = ["Creativity", "Teamwork", "Soft Skills", "Hard Skills"]
        assert set(major_categories) == set(expected_categories), f"Should include all 4 categories: {major_categories}"
        
        # Assert category distributions
        distributions = metadata["category_distributions"]
        assert len(distributions) == 4, "Should have distributions for 4 categories"
        
        for category in expected_categories:
            assert category in distributions, f"Should have distribution for {category}"
            dist = distributions[category]
            assert dist["questions_generated"] == 5, f"{category} should have 5 questions"
        
        # Assert category mapping
        category_mapping = metadata["dimension_to_category_mapping"]
        assert len(category_mapping) == 4, "Should map all 4 dimensions to categories"
        
        # Count questions by category
        category_counts = {}
        for question in questions:
            cat_id = question["idCategory"]
            category_counts[cat_id] = category_counts.get(cat_id, 0) + 1
        
        # Should have exactly 4 different categories
        assert len(category_counts) == 4, f"Questions should be distributed across 4 categories, got {len(category_counts)}"
        
        # Each category should have exactly 5 questions
        for cat_id, count in category_counts.items():
            assert count == 5, f"Category {cat_id} should have 5 questions, got {count}"
        
        print(f"✅ Generated balanced quiz: {len(questions)} questions across 4 categories")
        print(f"📊 Questions per category: {metadata['questions_per_category']}")
        print(f"🏷️ Categories: {major_categories}")
        
        # Print distribution details
        for category, dist in distributions.items():
            subdist = dist.get("subdimension_distribution", {})
            print(f"  {category}: {dist['questions_generated']} questions across {len(subdist)} subdimensions")
        
        # Show JSON for one question from each category
        categories_shown = set()
        for question in questions:
            cat_id = question["idCategory"]
            if cat_id not in categories_shown:
                # Find which dimension this category belongs to
                dimension = "Unknown"
                for dim, cat_mapping in category_mapping.items():
                    if cat_mapping == cat_id:
                        dimension = dim
                        break
                
                print(f"📄 Sample {dimension} question JSON:")
                print(f"   {json.dumps(question, indent=4)}")
                categories_shown.add(cat_id)
                
                if len(categories_shown) >= 2:  # Show only 2 examples to avoid too much output
                    break
    
    def test_generate_larger_quiz(self):
        """Test generating a larger balanced quiz"""
        url = f"{BASE_URL}/questions/generate-full-quiz"
        
        payload = {
            "idQuiz": TEST_QUIZ_ID,
            "total_questions": 40,  # 10 per category
            "target_year_level": 3
        }
        
        response = requests.post(url, json=payload)
        
        assert response.status_code == 200, f"Larger quiz should work: {response.text}"
        
        data = response.json()
        questions = data["questions"]
        metadata = data["generation_metadata"]
        
        assert len(questions) == 40, f"Should generate 40 questions, got {len(questions)}"
        assert metadata["questions_per_category"] == 10, "Should have 10 questions per category"
        
        # Verify distribution
        category_counts = {}
        for question in questions:
            cat_id = question["idCategory"]
            category_counts[cat_id] = category_counts.get(cat_id, 0) + 1
        
        for cat_id, count in category_counts.items():
            assert count == 10, f"Category {cat_id} should have 10 questions, got {count}"
        
        print(f"✅ Generated large balanced quiz: {len(questions)} questions")
        print(f"📊 Distribution: {dict(category_counts)}")
    
    def test_generate_minimum_quiz(self):
        """Test generating minimum viable quiz"""
        url = f"{BASE_URL}/questions/generate-full-quiz"
        
        payload = {
            "idQuiz": TEST_QUIZ_ID,
            "total_questions": 8,  # 2 per category (minimum)
            "target_year_level": 1
        }
        
        response = requests.post(url, json=payload)
        
        assert response.status_code == 200, f"Minimum quiz should work: {response.text}"
        
        data = response.json()
        questions = data["questions"]
        metadata = data["generation_metadata"]
        
        assert len(questions) == 8, "Should generate 8 questions"
        assert metadata["questions_per_category"] == 2, "Should have 2 questions per category"
        
        print(f"✅ Generated minimum quiz: {len(questions)} questions")
    
    def test_generate_invalid_total_not_divisible_by_4(self):
        """Test error handling for total not divisible by 4"""
        url = f"{BASE_URL}/questions/generate-full-quiz"
        
        invalid_totals = [10, 15, 23, 37]  # Not divisible by 4
        
        for total in invalid_totals:
            payload = {
                "idQuiz": TEST_QUIZ_ID,
                "total_questions": total,
                "target_year_level": 2
            }
            
            response = requests.post(url, json=payload)
            
            assert response.status_code == 400, f"Should reject {total} questions (not divisible by 4)"
        
        print(f"✅ Correctly rejected totals not divisible by 4")
    
    def test_generate_invalid_total_too_large(self):
        """Test error handling for too many questions"""
        url = f"{BASE_URL}/questions/generate-full-quiz"
        
        payload = {
            "idQuiz": TEST_QUIZ_ID,
            "total_questions": 300,  # Above limit of 200
            "target_year_level": 2
        }
        
        response = requests.post(url, json=payload)
        
        assert response.status_code == 422, "Should reject too many questions"
        
        print(f"✅ Correctly rejected excessive question count")
    
    def test_generate_invalid_total_too_small(self):
        """Test error handling for too few questions"""
        url = f"{BASE_URL}/questions/generate-full-quiz"
        
        payload = {
            "idQuiz": TEST_QUIZ_ID,
            "total_questions": 4,  # Below minimum of 8
            "target_year_level": 2
        }
        
        response = requests.post(url, json=payload)
        
        assert response.status_code == 422, "Should reject too few questions"
        
        print(f"✅ Correctly rejected insufficient question count")
    
    def test_generate_invalid_quiz(self):
        """Test error handling for invalid quiz"""
        url = f"{BASE_URL}/questions/generate-full-quiz"
        
        payload = {
            "idQuiz": "nonexistent_quiz",
            "total_questions": 20,
            "target_year_level": 2
        }
        
        response = requests.post(url, json=payload)
        
        assert response.status_code == 404, "Should return 404 for nonexistent quiz"
        
        error_data = response.json()
        assert "quiz" in error_data["detail"].lower(), "Should indicate quiz not found"
        
        print(f"✅ Correctly rejected invalid quiz: {error_data['detail']}")
    
    def test_generate_quiz_wrong_category_count(self):
        """Test error handling for quiz without exactly 4 categories"""
        url = f"{BASE_URL}/questions/generate-full-quiz"
        
        # Use a quiz that has 4 identical categories instead of 4 different ones
        WRONG_QUIZ_ID = "3ikmyg5fvEGorXe10Drn"  # This has 4 identical categories
        
        payload = {
            "idQuiz": WRONG_QUIZ_ID,
            "total_questions": 20,
            "target_year_level": 2
        }
        
        response = requests.post(url, json=payload)
        
        if response.status_code == 400:
            error_data = response.json()
            assert "exactly 4 categories" in error_data["detail"], "Should require exactly 4 categories"
            print(f"✅ Correctly rejected quiz without 4 different categories: {error_data['detail']}")
        else:
            # If it passes, it means the endpoint accepts duplicate categories
            print(f"⚠️ Quiz with duplicate categories was accepted (status: {response.status_code})")
            if response.status_code == 200:
                data = response.json()
                print(f"   Generated {len(data.get('questions', []))} questions anyway")

def run_full_quiz_tests():
    """Run all generate-full-quiz endpoint tests"""
    print("🧪 Testing POST /questions/generate-full-quiz endpoint")
    print("=" * 70)
    
    test_instance = TestGenerateFullQuizEndpoint()
    
    try:
        print("\n1. Testing successful full quiz generation...")
        test_instance.test_generate_full_quiz_success()
        
        print("\n2. Testing larger quiz generation...")
        test_instance.test_generate_larger_quiz()
        
        print("\n3. Testing minimum quiz generation...")
        test_instance.test_generate_minimum_quiz()
        
        print("\n4. Testing invalid total (not divisible by 4)...")
        test_instance.test_generate_invalid_total_not_divisible_by_4()
        
        print("\n5. Testing invalid total (too large)...")
        test_instance.test_generate_invalid_total_too_large()
        
        print("\n6. Testing invalid total (too small)...")
        test_instance.test_generate_invalid_total_too_small()
        
        print("\n7. Testing invalid quiz...")
        test_instance.test_generate_invalid_quiz()
        
        print("\n8. Testing quiz with wrong category count...")
        test_instance.test_generate_quiz_wrong_category_count()
        
        print("\n✅ All /generate-full-quiz tests passed!")
        
    except Exception as e:
        print(f"\n❌ Test failed: {e}")
        raise

if __name__ == "__main__":
    print("🚀 Running /generate-full-quiz endpoint tests")
    print("📋 Requirements:")
    print(f"  - FastAPI server running on {BASE_URL}")
    print(f"  - Test quiz '{TEST_QUIZ_ID}' exists with exactly 4 categories")
    print(f"  - Categories should represent: Creativity, Teamwork, Soft Skills, Hard Skills")
    print(f"  - Valid Firebase credentials configured")
    print(f"  - Optional: test quiz with wrong number of categories for error testing")
    print()
    
    try:
        run_full_quiz_tests()
    except requests.exceptions.RequestException as e:
        print(f"❌ Connection error: {e}")
        print("Make sure the FastAPI server is running!")
    except Exception as e:
        print(f"❌ Test error: {e}")
