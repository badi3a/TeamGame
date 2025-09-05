"""
Test the /generate endpoint for single question generation
"""
import requests
import json
import random
from typing import Dict, Any, Optional

# Test configuration
BASE_URL = "http://localhost:8000"
TEST_QUIZ_ID = "3ikmyg5fvEGorXe10Drn"  # Real quiz ID from Firebase

def get_random_category() -> Optional[Dict[str, str]]:
    """Get a random category from available categories"""
    try:
        # First get available dimensions
        dimensions_response = requests.get(f"{BASE_URL}/questions/dimensions")
        if dimensions_response.status_code != 200:
            print(f"⚠️ Could not fetch dimensions: {dimensions_response.status_code}")
            return None
        
        dimensions = dimensions_response.json()["dimensions"]
        if not dimensions:
            print("⚠️ No dimensions available")
            return None
        
        # Pick a random dimension
        selected_dimension = random.choice(dimensions)
        
        # Get categories from Firebase that match this dimension
        categories_response = requests.get(f"{BASE_URL}/categories")
        if categories_response.status_code != 200:
            print(f"⚠️ Could not fetch categories: {categories_response.status_code}")
            return None
        
        categories = categories_response.json()
        matching_categories = [
            cat for cat in categories 
            if cat.get("island") == selected_dimension
        ]
        
        if not matching_categories:
            print(f"⚠️ No categories found for dimension: {selected_dimension}")
            return None
        
        # Pick a random category from matching ones
        selected_category = random.choice(matching_categories)
        
        return {
            "category_id": selected_category["idCategory"],
            "dimension": selected_dimension,
            "category_name": selected_category.get("island", selected_dimension)
        }
        
    except Exception as e:
        print(f"⚠️ Error getting random category: {e}")
        return None

def get_test_category() -> Dict[str, str]:
    """Get a test category, with fallback options"""
    # Try to get a random category
    random_category = get_random_category()
    if random_category:
        print(f"🎲 Using random category: {random_category['dimension']} (ID: {random_category['category_id']})")
        return random_category
    
    # Fallback to hardcoded options
    fallback_categories = [
        {"category_id": "test_category_creativity", "dimension": "Creativity", "category_name": "Creativity"},
        {"category_id": "test_category_teamwork", "dimension": "Teamwork", "category_name": "Teamwork"},
        {"category_id": "test_category_soft_skills", "dimension": "Soft Skills", "category_name": "Soft Skills"},
        {"category_id": "test_category_hard_skills", "dimension": "Hard Skills", "category_name": "Hard Skills"},
    ]
    
    selected = random.choice(fallback_categories)
    print(f"🔧 Using fallback category: {selected['dimension']} (ID: {selected['category_id']})")
    return selected

class TestGenerateEndpoint:
    """Test cases for POST /questions/generate"""
    
    def __init__(self):
        """Initialize with a random category for this test run"""
        self.test_category = get_test_category()
        self.category_id = self.test_category["category_id"]
        self.expected_dimension = self.test_category["dimension"]
        print(f"🎯 Test suite will use: {self.expected_dimension} (Category ID: {self.category_id})")
    
    def test_generate_question_success(self):
        """Test successful question generation"""
        url = f"{BASE_URL}/questions/generate"
        
        payload = {
            "idQuiz": TEST_QUIZ_ID,
            "idCategory": self.category_id,
            "target_year_level": 2
        }
        
        response = requests.post(url, json=payload)
        
        # Assert response status
        assert response.status_code == 200, f"Expected 200, got {response.status_code}: {response.text}"
        
        # Parse response
        data = response.json()
        
        # Assert response structure
        assert "question" in data, "Response should contain 'question' field"
        assert "generation_metadata" in data, "Response should contain 'generation_metadata' field"
        
        # Assert question structure
        question = data["question"]
        assert "idQuestion" in question, "Question should have idQuestion"
        assert "content" in question, "Question should have content"
        assert "idQuiz" in question, "Question should have idQuiz"
        assert "idCategory" in question, "Question should have idCategory"
        
        # Assert question content
        assert question["idQuiz"] == TEST_QUIZ_ID, "Question should have correct quiz ID"
        assert question["idCategory"] == self.category_id, "Question should have correct category ID"
        assert len(question["content"]) > 10, "Question content should be meaningful"
        
        # Assert metadata structure
        metadata = data["generation_metadata"]
        assert "dimension" in metadata, "Metadata should contain dimension"
        assert "subdimension" in metadata, "Metadata should contain subdimension"
        assert "target_year_level" in metadata, "Metadata should contain target_year_level"
        assert "response_scale" in metadata, "Metadata should contain response_scale"
        
        # Assert metadata values
        assert metadata["dimension"] == self.expected_dimension, f"Should use expected dimension: {self.expected_dimension}"
        assert metadata["target_year_level"] == 2, "Should match requested year level"
        assert metadata["response_scale"] == "1-5", "Should use standard Likert scale"
        
        print(f"✅ Generated question for {self.expected_dimension}: {question['content']}")
        print(f"📊 Metadata: {json.dumps(metadata, indent=2)}")
        print(f"📄 Complete question JSON:")
        print(f"   {json.dumps(question, indent=4)}")
    
    def test_generate_with_custom_subdimension(self):
        """Test question generation with custom subdimension"""
        url = f"{BASE_URL}/questions/generate"
        
        payload = {
            "idQuiz": TEST_QUIZ_ID,
            "idCategory": self.category_id,
            "subdimension": "custom_innovation",
            "target_year_level": 1
        }
        
        response = requests.post(url, json=payload)
        
        assert response.status_code == 200, f"Custom subdimension should work: {response.text}"
        
        data = response.json()
        metadata = data["generation_metadata"]
        
        assert metadata["subdimension"] == "custom_innovation", "Should use custom subdimension"
        
        print(f"✅ Generated for {self.expected_dimension} with custom subdimension: {metadata['subdimension']}")
    
    def test_generate_invalid_category(self):
        """Test error handling for invalid category"""
        url = f"{BASE_URL}/questions/generate"
        
        payload = {
            "idQuiz": TEST_QUIZ_ID,
            "idCategory": "nonexistent_category",
            "target_year_level": 2
        }
        
        response = requests.post(url, json=payload)
        
        assert response.status_code == 404, "Should return 404 for nonexistent category"
        
        error_data = response.json()
        assert "not found" in error_data["detail"].lower(), "Should indicate category not found"
        
        print(f"✅ Correctly rejected invalid category: {error_data['detail']}")
    
    def test_generate_invalid_year_level(self):
        """Test error handling for invalid year level"""
        url = f"{BASE_URL}/questions/generate"
        
        payload = {
            "idQuiz": TEST_QUIZ_ID,
            "idCategory": self.category_id,
            "target_year_level": 5  # Invalid - should be 1, 2, or 3
        }
        
        response = requests.post(url, json=payload)
        
        assert response.status_code == 422, "Should return validation error for invalid year level"
        
        print(f"✅ Correctly rejected invalid year level for {self.expected_dimension}")
    
    def test_generate_missing_quiz(self):
        """Test error handling for nonexistent quiz"""
        url = f"{BASE_URL}/questions/generate"
        
        payload = {
            "idQuiz": "nonexistent_quiz",
            "idCategory": self.category_id,
            "target_year_level": 2
        }
        
        response = requests.post(url, json=payload)
        
        assert response.status_code == 404, "Should return 404 for nonexistent quiz"
        
        error_data = response.json()
        assert "quiz" in error_data["detail"].lower(), "Should indicate quiz not found"
        
        print(f"✅ Correctly rejected invalid quiz for {self.expected_dimension}: {error_data['detail']}")

def run_generate_tests():
    """Run all generate endpoint tests"""
    print("🧪 Testing POST /questions/generate endpoint")
    print("=" * 50)
    
    test_instance = TestGenerateEndpoint()
    
    try:
        print("\n1. Testing successful generation...")
        test_instance.test_generate_question_success()
        
        print("\n2. Testing custom subdimension...")
        test_instance.test_generate_with_custom_subdimension()
        
        print("\n3. Testing invalid category...")
        test_instance.test_generate_invalid_category()
        
        print("\n4. Testing invalid year level...")
        test_instance.test_generate_invalid_year_level()
        
        print("\n5. Testing missing quiz...")
        test_instance.test_generate_missing_quiz()
        
        print("\n✅ All /generate tests passed!")
        
    except Exception as e:
        print(f"\n❌ Test failed: {e}")
        raise

if __name__ == "__main__":
    print("🚀 Running /generate endpoint tests")
    print("📋 Requirements:")
    print(f"  - FastAPI server running on {BASE_URL}")
    print(f"  - Test quiz '{TEST_QUIZ_ID}' exists in database")
    
    # Get random test category
    test_category = get_test_category()
    print(f"  - Selected category: '{test_category['category_id']}' ({test_category['dimension']})")
    print(f"  - Valid Firebase credentials configured")
    print()
    
    try:
        run_generate_tests()
    except requests.exceptions.RequestException as e:
        print(f"❌ Connection error: {e}")
        print("Make sure the FastAPI server is running!")
    except Exception as e:
        print(f"❌ Test error: {e}")
