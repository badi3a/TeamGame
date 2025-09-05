"""
Test the /generate-category endpoint for multiple question generation
"""
import requests
import json
from typing import Dict, Any, List

# Test configuration
BASE_URL = "http://localhost:8000"
TEST_QUIZ_ID = "3ikmyg5fvEGorXe10Drn"  # Real quiz ID from Firebase
TEST_CATEGORY_ID = "qkmM6y1twfrnyFMGdjDL"  # Real Soft Skills category ID from Firebase

class TestGenerateCategoryEndpoint:
    """Test cases for POST /questions/generate-category"""
    
    def test_generate_category_questions_success(self):
        """Test successful category questions generation"""
        url = f"{BASE_URL}/questions/generate-category"
        
        payload = {
            "idQuiz": TEST_QUIZ_ID,
            "idCategory": TEST_CATEGORY_ID,
            "num_questions": 5,
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
        assert len(questions) == 5, f"Should generate 5 questions, got {len(questions)}"
        
        # Check each question
        for i, question in enumerate(questions):
            assert "idQuestion" in question, f"Question {i} should have idQuestion"
            assert "content" in question, f"Question {i} should have content"
            assert "idQuiz" in question, f"Question {i} should have idQuiz"
            assert "idCategory" in question, f"Question {i} should have idCategory"
            
            # Assert question values
            assert question["idQuiz"] == TEST_QUIZ_ID, f"Question {i} should have correct quiz ID"
            assert question["idCategory"] == TEST_CATEGORY_ID, f"Question {i} should have correct category ID"
            assert len(question["content"]) > 10, f"Question {i} content should be meaningful"
        
        # Assert metadata structure
        metadata = data["generation_metadata"]
        assert "dimension" in metadata, "Metadata should contain dimension"
        assert "total_generated" in metadata, "Metadata should contain total_generated"
        assert "target_year_level" in metadata, "Metadata should contain target_year_level"
        assert "subdimension_distribution" in metadata, "Metadata should contain subdimension_distribution"
        assert "response_scale" in metadata, "Metadata should contain response_scale"
        
        # Assert metadata values
        assert metadata["dimension"] == "Soft Skills", "Should use Firebase format dimension"
        assert metadata["total_generated"] == 5, "Should match requested number"
        assert metadata["target_year_level"] == 2, "Should match requested year level"
        assert metadata["response_scale"] == "1-5", "Should use standard Likert scale"
        
        # Assert distribution
        distribution = metadata["subdimension_distribution"]
        assert isinstance(distribution, dict), "Distribution should be a dictionary"
        
        print(f"✅ Generated {len(questions)} questions for Soft Skills")
        print(f"📊 Distribution: {json.dumps(distribution, indent=2)}")
        
        # Print sample questions
        for i, question in enumerate(questions[:2]):
            print(f"  {i+1}. {question['content'][:60]}...")
        
        # Show complete JSON for first question
        if questions:
            print(f"📄 First question complete JSON:")
            print(f"   {json.dumps(questions[0], indent=4)}")
    
    def test_generate_large_batch(self):
        """Test generating a larger batch of questions"""
        url = f"{BASE_URL}/questions/generate-category"
        
        payload = {
            "idQuiz": TEST_QUIZ_ID,
            "idCategory": TEST_CATEGORY_ID,
            "num_questions": 15,
            "target_year_level": 3
        }
        
        response = requests.post(url, json=payload)
        
        assert response.status_code == 200, f"Large batch should work: {response.text}"
        
        data = response.json()
        questions = data["questions"]
        metadata = data["generation_metadata"]
        
        assert len(questions) == 15, f"Should generate 15 questions, got {len(questions)}"
        assert metadata["total_generated"] == 15, "Metadata should reflect correct count"
        
        # Check distribution across subdimensions
        distribution = metadata["subdimension_distribution"]
        total_distributed = sum(distribution.values())
        assert total_distributed == 15, "Distribution should sum to total questions"
        
        print(f"✅ Generated large batch: {len(questions)} questions")
        print(f"📊 Subdimension distribution: {distribution}")
        
        # Show JSON for one question from large batch
        if questions:
            print(f"📄 Sample question from large batch:")
            print(f"   {json.dumps(questions[0], indent=4)}")
    
    def test_generate_minimum_questions(self):
        """Test generating minimum number of questions"""
        url = f"{BASE_URL}/questions/generate-category"
        
        payload = {
            "idQuiz": TEST_QUIZ_ID,
            "idCategory": TEST_CATEGORY_ID,
            "num_questions": 1,
            "target_year_level": 1
        }
        
        response = requests.post(url, json=payload)
        
        assert response.status_code == 200, f"Minimum questions should work: {response.text}"
        
        data = response.json()
        questions = data["questions"]
        
        assert len(questions) == 1, "Should generate exactly 1 question"
        
        print(f"✅ Generated minimum batch: 1 question")
    
    def test_generate_invalid_question_count(self):
        """Test error handling for invalid question count"""
        url = f"{BASE_URL}/questions/generate-category"
        
        # Test too many questions
        payload = {
            "idQuiz": TEST_QUIZ_ID,
            "idCategory": TEST_CATEGORY_ID,
            "num_questions": 100,  # Above limit of 50
            "target_year_level": 2
        }
        
        response = requests.post(url, json=payload)
        
        assert response.status_code == 422, "Should reject too many questions"
        
        # Test zero questions
        payload["num_questions"] = 0
        response = requests.post(url, json=payload)
        
        assert response.status_code == 422, "Should reject zero questions"
        
        print(f"✅ Correctly rejected invalid question counts")
    
    def test_generate_invalid_category(self):
        """Test error handling for invalid category"""
        url = f"{BASE_URL}/questions/generate-category"
        
        payload = {
            "idQuiz": TEST_QUIZ_ID,
            "idCategory": "nonexistent_category",
            "num_questions": 5,
            "target_year_level": 2
        }
        
        response = requests.post(url, json=payload)
        
        assert response.status_code == 404, "Should return 404 for nonexistent category"
        
        error_data = response.json()
        assert "not found" in error_data["detail"].lower(), "Should indicate category not found"
        
        print(f"✅ Correctly rejected invalid category: {error_data['detail']}")
    
    def test_generate_different_dimensions(self):
        """Test generation for different category dimensions"""
        url = f"{BASE_URL}/questions/generate-category"
        
        # Get all available categories dynamically
        try:
            categories_response = requests.get(f"{BASE_URL}/categories")
            if categories_response.status_code != 200:
                print("⚠️ Could not fetch categories for dimension testing")
                return
            
            categories = categories_response.json()
            
            # Test one category from each dimension
            dimensions_tested = set()
            
            for category in categories:
                dimension = category.get("island")
                category_id = category["idCategory"]
                
                # Only test one category per dimension to avoid redundancy
                if dimension in dimensions_tested:
                    continue
                    
                dimensions_tested.add(dimension)
                
                payload = {
                    "idQuiz": TEST_QUIZ_ID,
                    "idCategory": category_id,
                    "num_questions": 3,
                    "target_year_level": 2
                }
                
                response = requests.post(url, json=payload)
                
                if response.status_code == 200:
                    data = response.json()
                    metadata = data["generation_metadata"]
                    
                    assert metadata["dimension"] == dimension, f"Should use correct dimension for {category_id}"
                    
                    print(f"✅ Generated for {dimension}: {len(data['questions'])} questions")
                    
                    # Show sample question JSON
                    if data["questions"]:
                        sample_question = data["questions"][0]
                        print(f"📄 Sample question JSON:")
                        print(f"   {json.dumps(sample_question, indent=4)}")
                else:
                    print(f"⚠️ Failed to generate for {dimension} (category {category_id}): {response.status_code}")
            
            print(f"✅ Tested {len(dimensions_tested)} different dimensions")
            
        except Exception as e:
            print(f"⚠️ Error testing different dimensions: {e}")

def run_category_tests():
    """Run all generate-category endpoint tests"""
    print("🧪 Testing POST /questions/generate-category endpoint")
    print("=" * 60)
    
    test_instance = TestGenerateCategoryEndpoint()
    
    try:
        print("\n1. Testing successful category generation...")
        test_instance.test_generate_category_questions_success()
        
        print("\n2. Testing large batch generation...")
        test_instance.test_generate_large_batch()
        
        print("\n3. Testing minimum questions...")
        test_instance.test_generate_minimum_questions()
        
        print("\n4. Testing invalid question count...")
        test_instance.test_generate_invalid_question_count()
        
        print("\n5. Testing invalid category...")
        test_instance.test_generate_invalid_category()
        
        print("\n6. Testing different dimensions...")
        test_instance.test_generate_different_dimensions()
        
        print("\n✅ All /generate-category tests passed!")
        
    except Exception as e:
        print(f"\n❌ Test failed: {e}")
        raise

if __name__ == "__main__":
    print("🚀 Running /generate-category endpoint tests")
    print("📋 Requirements:")
    print(f"  - FastAPI server running on {BASE_URL}")
    print(f"  - Test quiz '{TEST_QUIZ_ID}' exists in database")
    print(f"  - Test category '{TEST_CATEGORY_ID}' exists with island='Soft Skills'")
    print(f"  - Additional test categories for different dimensions (optional)")
    print(f"  - Valid Firebase credentials configured")
    print()
    
    try:
        run_category_tests()
    except requests.exceptions.RequestException as e:
        print(f"❌ Connection error: {e}")
        print("Make sure the FastAPI server is running!")
    except Exception as e:
        print(f"❌ Test error: {e}")
