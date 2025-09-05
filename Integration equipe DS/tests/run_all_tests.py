"""
Run all API endpoint tests for question generation
"""
import sys
import traceback
from pathlib import Path

# Add parent directory to path for imports
sys.path.append(str(Path(__file__).parent.parent))

# Import test modules
from test_generate_endpoint import run_generate_tests
from test_generate_category_endpoint import run_category_tests  
from test_generate_full_quiz_endpoint import run_full_quiz_tests

def run_all_tests():
    """Run all API endpoint tests"""
    print("🚀 Running All Question Generation API Tests")
    print("=" * 80)
    
    tests = [
        ("Single Question Generation", run_generate_tests),
        ("Category Questions Generation", run_category_tests),
        ("Full Quiz Generation", run_full_quiz_tests)
    ]
    
    results = {}
    
    for test_name, test_function in tests:
        print(f"\n🧪 Running {test_name} Tests...")
        print("-" * 60)
        
        try:
            test_function()
            results[test_name] = "✅ PASSED"
            print(f"\n✅ {test_name} tests completed successfully!")
            
        except Exception as e:
            results[test_name] = f"❌ FAILED: {str(e)}"
            print(f"\n❌ {test_name} tests failed: {e}")
            traceback.print_exc()
        
        print("\n" + "=" * 80)
    
    # Print summary
    print("\n📊 TEST RESULTS SUMMARY")
    print("=" * 80)
    
    for test_name, result in results.items():
        print(f"{result} {test_name}")
    
    # Check if all passed
    failed_tests = [name for name, result in results.items() if "FAILED" in result]
    
    if failed_tests:
        print(f"\n❌ {len(failed_tests)} test suite(s) failed:")
        for test_name in failed_tests:
            print(f"  - {test_name}")
        return False
    else:
        print(f"\n🎉 All {len(tests)} test suites passed!")
        return True

if __name__ == "__main__":
    print("📋 Pre-Test Checklist:")
    print("  ✓ FastAPI server running on http://localhost:8000")
    print("  ✓ Firebase credentials configured")
    print("  ✓ Test data exists in database:")
    print("    - Quiz ID: 3ikmyg5fvEGorXe10Drn (nameQuiz: test_quiz_generate)")
    print("    - Categories with correct island values (Creativity, Teamwork, Soft Skills, Hard Skills)")
    print("    - All tests will use dynamic category selection from available Firebase categories")
    print()
    
    input("Press Enter to start tests (or Ctrl+C to cancel)...")
    
    success = run_all_tests()
    
    if success:
        print("\n🎊 All tests completed successfully!")
        sys.exit(0)
    else:
        print("\n💥 Some tests failed. Check output above for details.")
        sys.exit(1)
