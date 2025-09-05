# Test Requirements for Question Generation API Tests

## Required Python Packages
requests>=2.31.0
pytest>=7.4.0

## Test Configuration

### Required Test Data in Firebase

1. **Test Quizzes:**
   - `test_quiz_generate` - For single question generation tests
   - `test_quiz_category` - For category questions generation tests  
   - `test_quiz_full` - For full quiz generation tests (must have exactly 4 categories)

2. **Test Categories:**
   - `test_category_creativity` with `island="Creativity"`
   - `test_category_soft_skills` with `island="Soft Skills"`
   - `test_category_teamwork` with `island="Teamwork"`
   - `test_category_hard_skills` with `island="Hard Skills"`

### Environment Setup

1. **FastAPI Server:**
   - Server must be running on `http://localhost:8000`
   - All endpoints must be accessible
   - Firebase credentials must be configured

2. **Firebase Database:**
   - Must contain the test data mentioned above
   - Categories must use the exact dimension names: "Creativity", "Teamwork", "Soft Skills", "Hard Skills"

### Running Tests

1. **Individual Test Files:**
   ```bash
   python tests/test_generate_endpoint.py
   python tests/test_generate_category_endpoint.py
   python tests/test_generate_full_quiz_endpoint.py
   ```

2. **All Tests:**
   ```bash
   python tests/run_all_tests.py
   ```

3. **With pytest:**
   ```bash
   pytest tests/ -v
   ```

### Test Coverage

- ✅ Single question generation (`/generate`)
- ✅ Category questions generation (`/generate-category`)
- ✅ Full quiz generation (`/generate-full-quiz`)
- ✅ Error handling and validation
- ✅ Response structure validation
- ✅ Metadata verification
- ✅ Distribution testing

### Expected Behavior

1. **Dimension Format:** All tests expect Firebase format dimensions ("Creativity", "Soft Skills", etc.)
2. **Response Scale:** All questions use "1-5" Likert scale
3. **Question Structure:** Standard Question schema with idQuestion, content, idQuiz, idCategory
4. **Error Handling:** Proper HTTP status codes and error messages
