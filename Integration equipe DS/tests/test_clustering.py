import requests
import pandas as pd
import json
import tempfile
import os
from typing import Dict, Any

# Configuration
BASE_URL = "http://localhost:8000"
TEST_CSV_PATH = "test_students.csv"

def create_test_data() -> str:
    """Create a test CSV file with sample student data"""
    
    # Sample student data
    students_data = {
        'first_name': [
            'Alice', 'Bob', 'Charlie', 'Diana', 'Eve', 'Frank', 'Grace', 'Henry',
            'Ivy', 'Jack', 'Kate', 'Liam', 'Mia', 'Noah', 'Olivia', 'Paul',
            'Quinn', 'Ruby', 'Sam', 'Tara', 'Uma', 'Victor', 'Wendy', 'Xander',
            'Yara', 'Zoe', 'Adam', 'Bella', 'Chris', 'Daisy'
        ],
        'last_name': [
            'Anderson', 'Brown', 'Clark', 'Davis', 'Evans', 'Fisher', 'Garcia', 'Harris',
            'Ivanov', 'Johnson', 'King', 'Lee', 'Miller', 'Nelson', 'O\'Connor', 'Parker',
            'Quinn', 'Roberts', 'Smith', 'Taylor', 'Upton', 'Vargas', 'Wilson', 'Xu',
            'Young', 'Zhang', 'Adams', 'Baker', 'Cooper', 'Dixon'
        ],
        'hard_skills': [8, 6, 9, 7, 5, 8, 6, 9, 7, 8, 6, 9, 7, 8, 6, 9, 7, 8, 6, 9, 7, 8, 6, 9, 7, 8, 6, 9, 7, 8],
        'soft_skills': [7, 8, 6, 9, 7, 8, 6, 9, 7, 8, 6, 9, 7, 8, 6, 9, 7, 8, 6, 9, 7, 8, 6, 9, 7, 8, 6, 9, 7, 8],
        'creativity': [6, 9, 7, 8, 6, 9, 7, 8, 6, 9, 7, 8, 6, 9, 7, 8, 6, 9, 7, 8, 6, 9, 7, 8, 6, 9, 7, 8, 6, 9],
        'teamwork': [9, 7, 8, 6, 9, 7, 8, 6, 9, 7, 8, 6, 9, 7, 8, 6, 9, 7, 8, 6, 9, 7, 8, 6, 9, 7, 8, 6, 9, 7],
        'class': ['CS101', 'CS101', 'CS102', 'CS102', 'CS103', 'CS103', 'CS101', 'CS102', 'CS103', 'CS101', 'CS102', 'CS103', 'CS101', 'CS102', 'CS103', 'CS101', 'CS102', 'CS103', 'CS101', 'CS102', 'CS103', 'CS101', 'CS102', 'CS103', 'CS101', 'CS102', 'CS103', 'CS101', 'CS102', 'CS103'],
        'gender': ['F', 'M', 'M', 'F', 'F', 'M', 'F', 'M', 'F', 'M', 'F', 'M', 'F', 'M', 'F', 'M', 'F', 'F', 'M', 'F', 'F', 'M', 'F', 'M', 'F', 'F', 'M', 'F', 'M', 'F'],
        'nationality': ['USA', 'Canada', 'UK', 'France', 'Germany', 'Spain', 'Italy', 'Japan', 'China', 'India', 'Brazil', 'Australia', 'Mexico', 'Netherlands', 'Sweden', 'Norway', 'Denmark', 'Finland', 'Poland', 'Czech', 'Hungary', 'Romania', 'Bulgaria', 'Greece', 'Turkey', 'Israel', 'Egypt', 'Morocco', 'South Africa', 'Nigeria'],
        'age': [20, 21, 22, 20, 21, 22, 20, 21, 22, 20, 21, 22, 20, 21, 22, 20, 21, 22, 20, 21, 22, 20, 21, 22, 20, 21, 22, 20, 21, 22]
    }
    
    # Create DataFrame and save to CSV
    df = pd.DataFrame(students_data)
    df.to_csv(TEST_CSV_PATH, index=False)
    print(f"✅ Created test CSV file: {TEST_CSV_PATH}")
    print(f"📊 Dataset contains {len(df)} students")
    print(f"📋 Columns: {list(df.columns)}")
    return TEST_CSV_PATH

def test_basic_clustering():
    """Test the basic clustering endpoint"""
    print("\n" + "="*50)
    print("🧪 TESTING BASIC CLUSTERING ENDPOINT")
    print("="*50)
    
    try:
        # Prepare the file upload
        with open(TEST_CSV_PATH, 'rb') as f:
            files = {'file': (TEST_CSV_PATH, f, 'text/csv')}
            
            # Make the request
            response = requests.post(
                f"{BASE_URL}/groups/generate-clusters",
                files=files,
                timeout=60  # Increased timeout for clustering
            )
        
        print(f"📡 Response Status: {response.status_code}")
        
        if response.status_code == 200:
            result = response.json()
            print("✅ Basic clustering successful!")
            print(f"🏆 Best Algorithm: {result['best_algorithm']}")
            print(f"👥 Number of Groups: {len(result['groups'])}")
            
            # Print group details
            for group in result['groups']:
                print(f"\n📦 Group {group['group']} ({group['size']} members):")
                for member in group['members']:
                    print(f"   - {member['first_name']} {member['last_name']} "
                          f"({member['gender']}, {member['nationality']}) "
                          f"[Skills: {member['hard_skills']}/{member['soft_skills']}/"
                          f"{member['creativity']}/{member['teamwork']}]")
            
            return True
        else:
            print(f"❌ Basic clustering failed!")
            print(f"Error: {response.text}")
            return False
            
    except Exception as e:
        print(f"❌ Exception during basic clustering test: {str(e)}")
        return False

def test_advanced_clustering():
    """Test the advanced clustering endpoint with custom configuration"""
    print("\n" + "="*50)
    print("🧪 TESTING ADVANCED CLUSTERING ENDPOINT")
    print("="*50)
    
    try:
        # Custom configuration
        config = {
            "group_size_min": 4,
            "group_size_max": 8,
            "population_size": 20,
            "generations": 30,
            "distance_metric": "euclidean"
        }
        
        # Prepare the file upload and config
        with open(TEST_CSV_PATH, 'rb') as f:
            files = {'file': (TEST_CSV_PATH, f, 'text/csv')}
            
            # Make the request with config
            response = requests.post(
                f"{BASE_URL}/groups/generate-clusters-with-config",
                files=files,
                data={'config': json.dumps(config)},
                timeout=60
            )
        
        print(f"📡 Response Status: {response.status_code}")
        print(f"⚙️  Used Config: {config}")
        
        if response.status_code == 200:
            result = response.json()
            print("✅ Advanced clustering successful!")
            print(f"🏆 Best Algorithm: {result['best_algorithm']}")
            print(f"👥 Number of Groups: {len(result['groups'])}")
            
            # Analyze group sizes
            sizes = [group['size'] for group in result['groups']]
            print(f"📊 Group sizes: {sizes}")
            print(f"📊 Average group size: {sum(sizes)/len(sizes):.1f}")
            
            # Print group details
            for group in result['groups']:
                print(f"\n📦 Group {group['group']} ({group['size']} members):")
                for member in group['members']:
                    print(f"   - {member['first_name']} {member['last_name']} "
                          f"({member['gender']}, {member['nationality']}) "
                          f"[Skills: {member['hard_skills']}/{member['soft_skills']}/"
                          f"{member['creativity']}/{member['teamwork']}]")
            
            return True
        else:
            print(f"❌ Advanced clustering failed!")
            print(f"Error: {response.text}")
            return False
            
    except Exception as e:
        print(f"❌ Exception during advanced clustering test: {str(e)}")
        return False

def test_crud_operations():
    """Test basic CRUD operations for groups"""
    print("\n" + "="*50)
    print("🧪 TESTING CRUD OPERATIONS")
    print("="*50)
    
    try:
        # Test data
        test_group = {
            "groupName": "Test Group",
            "members": ["student1", "student2", "student3"]
        }
        
        # Create group
        print("📝 Creating test group...")
        response = requests.post(f"{BASE_URL}/groups/", json=test_group)
        print(f"📡 Create Response: {response.status_code}")
        
        if response.status_code == 200:
            created_group = response.json()
            group_id = created_group['idGroup']
            print(f"✅ Group created with ID: {group_id}")
            
            # Get all groups
            print("\n📋 Getting all groups...")
            response = requests.get(f"{BASE_URL}/groups/")
            print(f"📡 Get All Response: {response.status_code}")
            if response.status_code == 200:
                groups = response.json()
                print(f"✅ Found {len(groups)} groups")
            
            # Get specific group
            print(f"\n🔍 Getting group {group_id}...")
            response = requests.get(f"{BASE_URL}/groups/{group_id}")
            print(f"📡 Get Specific Response: {response.status_code}")
            if response.status_code == 200:
                group = response.json()
                print(f"✅ Retrieved group: {group['groupName']}")
            
            # Update group
            print(f"\n✏️  Updating group {group_id}...")
            updated_group = {
                "groupName": "Updated Test Group",
                "members": ["student1", "student2", "student3", "student4"]
            }
            response = requests.put(f"{BASE_URL}/groups/{group_id}", json=updated_group)
            print(f"📡 Update Response: {response.status_code}")
            if response.status_code == 200:
                print("✅ Group updated successfully")
            
            # Delete group
            print(f"\n🗑️  Deleting group {group_id}...")
            response = requests.delete(f"{BASE_URL}/groups/{group_id}")
            print(f"📡 Delete Response: {response.status_code}")
            if response.status_code == 200:
                print("✅ Group deleted successfully")
            
            return True
        else:
            print(f"❌ Failed to create group: {response.text}")
            return False
            
    except Exception as e:
        print(f"❌ Exception during CRUD test: {str(e)}")
        return False

def test_error_handling():
    """Test error handling with invalid data"""
    print("\n" + "="*50)
    print("🧪 TESTING ERROR HANDLING")
    print("="*50)
    
    try:
        # Test with invalid file format
        print("📁 Testing with invalid file format...")
        with tempfile.NamedTemporaryFile(suffix='.txt', delete=False) as f:
            f.write(b"This is not a CSV file")
            temp_file = f.name
        
        with open(temp_file, 'rb') as f:
            files = {'file': ('test.txt', f, 'text/plain')}
            response = requests.post(f"{BASE_URL}/groups/generate-clusters", files=files)
        
        print(f"📡 Invalid file response: {response.status_code}")
        if response.status_code == 400:
            print("✅ Correctly rejected invalid file format")
        else:
            print("❌ Should have rejected invalid file format")
        
        # Clean up
        os.unlink(temp_file)
        
        # Test with missing columns
        print("\n📊 Testing with missing columns...")
        invalid_data = {
            'first_name': ['Alice', 'Bob'],
            'last_name': ['Smith', 'Jones'],
            'age': [20, 21]
            # Missing required columns
        }
        
        df_invalid = pd.DataFrame(invalid_data)
        invalid_csv_path = "invalid_test.csv"
        df_invalid.to_csv(invalid_csv_path, index=False)
        
        with open(invalid_csv_path, 'rb') as f:
            files = {'file': (invalid_csv_path, f, 'text/csv')}
            response = requests.post(f"{BASE_URL}/groups/generate-clusters", files=files)
        
        print(f"📡 Missing columns response: {response.status_code}")
        if response.status_code == 400:
            print("✅ Correctly rejected file with missing columns")
        else:
            print("❌ Should have rejected file with missing columns")
        
        # Clean up
        os.unlink(invalid_csv_path)
        
        return True
        
    except Exception as e:
        print(f"❌ Exception during error handling test: {str(e)}")
        return False

def main():
    """Run all tests"""
    print("🚀 STARTING CLUSTERING ENDPOINT TESTS")
    print("="*60)
    
    # Check if server is running
    try:
        response = requests.get(f"{BASE_URL}/")
        if response.status_code != 200:
            print("❌ Server is not running. Please start the FastAPI server first.")
            print("💡 Run: uvicorn main:app --reload")
            return
        print("✅ Server is running!")
    except requests.exceptions.ConnectionError:
        print("❌ Cannot connect to server. Please start the FastAPI server first.")
        print("💡 Run: uvicorn main:app --reload")
        return
    
    # Create test data
    test_csv_path = create_test_data()
    
    # Run tests
    tests = [
        ("Basic Clustering", test_basic_clustering),
        ("Advanced Clustering", test_advanced_clustering),
        ("CRUD Operations", test_crud_operations),
        ("Error Handling", test_error_handling)
    ]
    
    results = []
    for test_name, test_func in tests:
        try:
            result = test_func()
            results.append((test_name, result))
        except Exception as e:
            print(f"❌ {test_name} failed with exception: {str(e)}")
            results.append((test_name, False))
    
    # Print summary
    print("\n" + "="*60)
    print("📊 TEST RESULTS SUMMARY")
    print("="*60)
    
    passed = 0
    total = len(results)
    
    for test_name, result in results:
        status = "✅ PASSED" if result else "❌ FAILED"
        print(f"{test_name}: {status}")
        if result:
            passed += 1
    
    print(f"\n🎯 Overall: {passed}/{total} tests passed")
    
    if passed == total:
        print("🎉 All tests passed! The clustering endpoints are working correctly.")
    else:
        print("⚠️  Some tests failed. Please check the implementation.")
    
    # Clean up
    if os.path.exists(TEST_CSV_PATH):
        os.unlink(TEST_CSV_PATH)
        print(f"\n🧹 Cleaned up test file: {TEST_CSV_PATH}")

if __name__ == "__main__":
    main() 