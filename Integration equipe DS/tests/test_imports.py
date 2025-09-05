#!/usr/bin/env python3
"""
Test script to verify all imports work correctly
"""

def test_imports():
    """Test all the imports used in the application"""
    print("🧪 Testing imports...")
    
    try:
        # Test main imports
        print("📦 Testing main imports...")
        from fastapi import FastAPI
        from fastapi.middleware.cors import CORSMiddleware
        print("✅ FastAPI imports successful")
        
        # Test router imports
        print("📦 Testing router imports...")
        from routers import quiz, question, category, answer, score, group
        print("✅ Router imports successful")
        
        # Test schema imports
        print("📦 Testing schema imports...")
        from schemas.group import Group, ClusteringResponse
        from schemas.question import Question
        from schemas.quiz import Quiz
        from schemas.category import Category
        from schemas.answer import Answer
        from schemas.score import Score
        print("✅ Schema imports successful")
        
        # Test core imports
        print("📦 Testing core imports...")
        from core.firebase import db
        from core.clustering_service import ClusteringService
        from core.generation_service import QuestionGenerationService
        print("✅ Core imports successful")
        
        print("\n🎉 All imports successful! The application should start correctly.")
        return True
        
    except ImportError as e:
        print(f"❌ Import error: {e}")
        return False
    except Exception as e:
        print(f"❌ Unexpected error: {e}")
        return False

if __name__ == "__main__":
    success = test_imports()
    if success:
        print("\n✅ Ready to start server with: uvicorn main:app --reload")
    else:
        print("\n❌ Fix import issues before starting server") 