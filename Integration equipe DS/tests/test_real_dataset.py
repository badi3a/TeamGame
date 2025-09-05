import requests
import pandas as pd
import os

def test_real_dataset():
    """Test clustering with the real students_dataset.csv"""
    print("🚀 Testing Clustering with Real Dataset")
    print("="*50)
    
    # Check if dataset exists
    dataset_path = "students_dataset.csv"
    if not os.path.exists(dataset_path):
        print(f"❌ Dataset not found: {dataset_path}")
        return
    
    # Check if server is running
    try:
        response = requests.get("http://localhost:8000/")
        if response.status_code != 200:
            print("❌ Server not running. Start with: uvicorn main:app --reload")
            return
        print("✅ Server is running!")
    except:
        print("❌ Cannot connect to server. Start with: uvicorn main:app --reload")
        return
    
    # Load and display dataset info
    df = pd.read_csv(dataset_path)
    print(f"📊 Dataset loaded: {len(df)} students")
    print(f"📋 Columns: {list(df.columns)}")
    print(f"👥 Sample data:")
    print(df.head(3).to_string())
    
    try:
        # Test basic clustering endpoint
        print("\n🧪 Testing Basic Clustering...")
        with open(dataset_path, 'rb') as f:
            files = {'file': (dataset_path, f, 'text/csv')}
            response = requests.post(
                "http://localhost:8000/groups/generate-clusters",
                files=files,
                timeout=120  # Increased timeout for large dataset
            )
        
        print(f"📡 Response Status: {response.status_code}")
        
        if response.status_code == 200:
            result = response.json()
            print("✅ Basic clustering successful!")
            print(f"🏆 Best Algorithm: {result['best_algorithm']}")
            print(f"👥 Number of Groups: {len(result['groups'])}")
            
            # Analyze results
            total_students = sum(group['size'] for group in result['groups'])
            print(f"📊 Total students processed: {total_students}")
            
            # Show group distribution
            sizes = [group['size'] for group in result['groups']]
            print(f"📊 Group sizes: {sizes}")
            print(f"📊 Average group size: {sum(sizes)/len(sizes):.1f}")
            
            # Show first group as example
            if result['groups']:
                first_group = result['groups'][0]
                print(f"\n📦 Example Group {first_group['group']} ({first_group['size']} members):")
                for member in first_group['members'][:3]:  # Show first 3 members
                    print(f"   - {member['first_name']} {member['last_name']} "
                          f"({member['gender']}, {member['nationality']}) "
                          f"[Skills: {member['hard_skills']:.1f}/{member['soft_skills']:.1f}/"
                          f"{member['creativity']:.1f}/{member['teamwork']:.1f}]")
                if len(first_group['members']) > 3:
                    print(f"   ... and {len(first_group['members']) - 3} more members")
            
            print("\n🎉 Real dataset clustering test passed!")
            
        else:
            print(f"❌ Basic clustering failed!")
            print(f"Error: {response.text}")
            
    except Exception as e:
        print(f"❌ Error during clustering test: {str(e)}")
    
    try:
        # Test advanced clustering with custom parameters
        print("\n🧪 Testing Advanced Clustering...")
        with open(dataset_path, 'rb') as f:
            files = {'file': (dataset_path, f, 'text/csv')}
            data = {
                'group_size_min': 6,
                'group_size_max': 8,
                'population_size': 20,
                'generations': 30,
                'distance_metric': 'euclidean'
            }
            response = requests.post(
                "http://localhost:8000/groups/generate-clusters-with-config",
                files=files,
                data=data,
                timeout=120
            )
        
        print(f"📡 Advanced Response Status: {response.status_code}")
        
        if response.status_code == 200:
            result = response.json()
            print("✅ Advanced clustering successful!")
            print(f"🏆 Best Algorithm: {result['best_algorithm']}")
            print(f"👥 Number of Groups: {len(result['groups'])}")
            
            # Analyze results
            sizes = [group['size'] for group in result['groups']]
            print(f"📊 Group sizes: {sizes}")
            print(f"📊 Average group size: {sum(sizes)/len(sizes):.1f}")
            
            print("\n🎉 Advanced clustering test passed!")
            
        else:
            print(f"❌ Advanced clustering failed!")
            print(f"Error: {response.text}")
            
    except Exception as e:
        print(f"❌ Error during advanced clustering test: {str(e)}")

if __name__ == "__main__":
    test_real_dataset() 