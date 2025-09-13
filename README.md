# 🎓 TeamGame - Educational Quiz & Student Clustering Platform

A comprehensive educational platform that combines AI-powered quiz generation with intelligent student clustering for optimal team formation. Built with FastAPI, Firebase, and advanced machine learning algorithms.

## 📋 Table of Contents

- [Overview](#overview)
- [Project Structure](#project-structure)
- [Core Features](#core-features)
- [Technology Stack](#technology-stack)
- [Getting Started](#getting-started)
- [API Documentation](#api-documentation)
- [Data Models & Schemas](#data-models--schemas)
- [Machine Learning Components](#machine-learning-components)
- [Testing](#testing)
- [Deployment](#deployment)
- [Contributing](#contributing)

## 🌟 Overview

TeamGame is an educational platform designed to:

1. **Generate AI-powered quiz questions** using Google Gemini with Retrieval-Augmented Generation (RAG)
2. **Intelligently cluster students** into balanced teams using multiple ML algorithms
3. **Manage educational assessments** with comprehensive scoring and analytics
4. **Provide interactive interfaces** for both teachers and students

The platform serves educational institutions looking to create balanced student teams and generate contextually appropriate assessment questions across four key dimensions: **Creativity**, **Teamwork**, **Soft Skills**, and **Hard Skills**.

## 📁 Project Structure

```
TeamGame/
├── Integration equipe DS/           # Main Backend API
│   ├── src/
│   │   ├── main.py                 # FastAPI application entry point
│   │   ├── core/
│   │   │   ├── clustering_service.py    # ML clustering algorithms
│   │   │   ├── generation_service.py    # AI question generation
│   │   │   └── firebase.py             # Database connection
│   │   ├── routers/
│   │   │   ├── quiz.py             # Quiz management endpoints
│   │   │   ├── question.py         # Question & generation endpoints
│   │   │   ├── group.py            # Student clustering endpoints
│   │   │   ├── answer.py           # Student response handling
│   │   │   ├── score.py            # Assessment scoring
│   │   │   └── category.py         # Category management
│   │   └── schemas/                # Pydantic data models
│   ├── tests/                      # Comprehensive test suite
│   ├── requirements.txt            # Python dependencies
│   └── firebase_credentials.json   # Firebase configuration
├── Question Generation/             # Standalone question generation service
│   ├── streamlit_main.py           # Main UI hub
│   ├── streamlit_teacher.py        # Teacher interface
│   ├── streamlit_student.py        # Student interface
│   ├── api.py                      # RAG-based generation API
│   └── shared_storage.py           # Storage management
├── Clustering/                     # Clustering research & development
│   └── ClusteringZouhour.py        # Alternative clustering implementation
├── Datasets Creation/              # Dataset management & generation
│   ├── Merging.py                  # Dataset merging utilities
│   └── Quiz Generation/
│       ├── generate_questions.py   # Question template generation
│       └── Datasets Combined/      # Balanced question datasets
└── Datasets/                       # Production datasets (880 questions)
    └── Final Datasets/
        └── All Questions.csv       # Balanced 4-dimension dataset
```

## 🚀 Core Features

### 1. AI-Powered Question Generation
- **Google Gemini Integration**: Uses advanced LLM for contextual question creation
- **RAG-Based Context**: Retrieves relevant examples using FAISS vector search
- **Balanced Generation**: Ensures equal distribution across 4 key dimensions
- **Custom Subdimensions**: Supports teacher-defined subcategories
- **Smart Prompting**: Dimension-specific templates for optimal results

### 2. Intelligent Student Clustering
- **7 ML Algorithms**: KMeans, Agglomerative, DBSCAN, Spectral, GMM, MeanShift, MiniSom
- **Multi-Criteria Optimization**: Balances skills, demographics, and team dynamics
- **Genetic Algorithm Enhancement**: Optimizes cluster assignments for better balance
- **Performance Scaling**: Adapts algorithm selection based on dataset size
- **Entropy-Based Evaluation**: Ensures diversity in gender and nationality distribution

### 3. Comprehensive Assessment System
- **5-Point Likert Scale**: Standardized assessment methodology
- **Multi-Dimensional Scoring**: Tracks progress across all skill areas
- **Real-Time Analytics**: Immediate feedback and progress tracking
- **Export Capabilities**: Data export for further analysis

### 4. Interactive User Interfaces
- **Teacher Dashboard**: Quiz creation, student management, analytics
- **Student Interface**: Quiz taking, progress tracking, team collaboration
- **System Hub**: Central access point for all services
- **API Documentation**: Auto-generated Swagger/ReDoc interfaces

## 🛠️ Technology Stack

### Backend
- **FastAPI**: Modern Python web framework with automatic API documentation
- **Firebase Firestore**: NoSQL database for scalable data storage
- **Google Gemini**: Advanced LLM for question generation
- **Sentence Transformers**: Semantic embeddings for context retrieval
- **FAISS**: Efficient vector similarity search
- **Scikit-learn**: Machine learning algorithms for clustering
- **Pandas & NumPy**: Data manipulation and numerical computing

### Frontend
- **Streamlit**: Interactive web applications for teacher/student interfaces
- **Angular** (configured): Modern frontend framework support

### ML & AI
- **Multiple Clustering Algorithms**: Comprehensive approach to team formation
- **Retrieval-Augmented Generation**: Context-aware question creation
- **Genetic Algorithm Optimization**: Enhanced cluster quality
- **Semantic Search**: Intelligent content retrieval

### DevOps & Testing
- **Pytest**: Comprehensive testing framework
- **Uvicorn**: ASGI server for FastAPI
- **Environment Management**: Conda/pip hybrid approach
- **VS Code Integration**: Optimized development environment

## 🏁 Getting Started

### Prerequisites
- Python 3.10+
- Conda environment
- Google Gemini API key
- Firebase project with Firestore enabled

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd TeamGame
   ```

2. **Set up the main backend environment**
   ```bash
   cd "Integration equipe DS"
   
   # Create and activate conda environment
   conda create -n teamgame python=3.11
   conda activate teamgame
   
   # Install dependencies
   pip install -r requirements.txt
   ```

3. **Configure environment variables**
   ```bash
   # Create .env file in the root directory
   echo "GEMINI_API_KEY=your_gemini_api_key_here" > .env
   ```

4. **Set up Firebase credentials**
   - Download your Firebase service account JSON
   - Place it as `firebase_credentials.json` in the `Integration equipe DS/` directory

5. **Initialize the dataset**
   ```bash
   # Ensure the questions dataset is available
   # The system expects: ../../Datasets/Final Datasets/All Questions.csv
   # This contains 880 balanced questions across 4 dimensions
   ```

### Running the Application

1. **Start the main API server**
   ```bash
   cd "Integration equipe DS"
   python -m uvicorn src.main:app --reload --host 0.0.0.0 --port 8000
   ```

2. **Start the Question Generation service (optional)**
   ```bash
   cd "Question Generation"
   streamlit run streamlit_main.py --server.port 8503
   ```

3. **Access the applications**
   - **API Server**: http://localhost:8000
   - **API Documentation**: http://localhost:8000/docs
   - **ReDoc**: http://localhost:8000/redoc
   - **System Hub**: http://localhost:8503 (if running Question Generation service)

## 📚 API Documentation

### Core Endpoints

#### Question Management
- `POST /questions/` - Create manual question
- `GET /questions/` - List all questions
- `GET /questions/{question_id}` - Get specific question
- `PUT /questions/{question_id}` - Update question
- `DELETE /questions/{question_id}` - Delete question

#### AI Question Generation
- `POST /questions/generate` - Generate single question
- `POST /questions/generate-category` - Generate multiple questions for category
- `POST /questions/generate-full-quiz` - Generate balanced full quiz
- `GET /questions/dimensions` - Get available dimensions
- `GET /questions/subdimensions/{dimension}` - Get subdimensions

#### Quiz Management
- `POST /quizzes/` - Create quiz
- `GET /quizzes/` - List all quizzes
- `GET /quizzes/{quiz_id}` - Get specific quiz
- `GET /quizzes/by_island/?island={name}` - Filter by dimension
- `GET /quizzes/by_teacher/{teacher_id}` - Filter by teacher

#### Student Clustering
- `POST /groups/generate-clusters` - Generate optimal student groups
- `POST /groups/generate-clusters-advanced` - Advanced clustering with config
- `GET /groups/` - List all groups
- `POST /groups/` - Create manual group

#### Assessment & Analytics
- `POST /answers/` - Submit student responses
- `GET /scores/{quiz_id}` - Get quiz scores
- `POST /scores/calculate` - Calculate assessment scores

### Authentication & Authorization
- CORS enabled for Angular frontend (localhost:4200)
- Firebase authentication integration
- Role-based access control (Teacher/Student)

## 📊 Data Models & Schemas

### Core Entities

```python
# Question Schema
class Question(BaseModel):
    idQuestion: Optional[str] = None
    content: str
    idQuiz: str
    idCategory: str

# Quiz Schema
class Quiz(BaseModel):
    idQuiz: Optional[str] = None
    idTeacher: str
    idCategory: List[str]  # Max 4 categories
    dateCreation: datetime
    isAccessible: bool = True
    accessCode: str
    nameQuiz: str

# Group Schema
class Group(BaseModel):
    idGroup: Optional[str] = None
    groupName: str
    members: List[str]  # Student IDs

# Student Clustering Data
class StudentMember(BaseModel):
    first_name: str
    last_name: str
    hard_skills: float
    soft_skills: float
    creativity: float
    teamwork: float
    class_name: str
    gender: str
    nationality: str
    age: int
```

### Generation Requests

```python
# Single Question Generation
class QuestionGenerateRequest(BaseModel):
    idQuiz: str
    idCategory: str
    subdimension: Optional[str] = None
    target_year_level: int  # 1, 2, or 3

# Full Quiz Generation
class FullQuizRequest(BaseModel):
    idQuiz: str
    total_questions: int  # Must be divisible by 4
    target_year_level: int
```

### Database Collections (Firebase)
- **questions**: Generated and manual questions
- **quizzes**: Quiz metadata and configuration
- **categories**: Question categories (Creativity, Teamwork, Soft Skills, Hard Skills)
- **answers**: Student responses
- **scores**: Assessment results
- **groups**: Student team assignments

## 🤖 Machine Learning Components

### Question Generation Pipeline

1. **Context Retrieval**
   - Uses Sentence Transformers for semantic embeddings
   - FAISS vector search for relevant question examples
   - Dimension-specific context filtering

2. **AI Generation**
   - Google Gemini 2.5-flash for question creation
   - Dimension-specific prompting strategies
   - RAG-enhanced context awareness

3. **Validation & Storage**
   - Automatic question validation
   - Firebase integration
   - Category assignment and metadata

### Student Clustering Pipeline

1. **Data Preprocessing**
   - Skill normalization (1-10 scale)
   - Categorical encoding (gender, nationality, class)
   - Feature scaling with StandardScaler

2. **Algorithm Evaluation**
   ```python
   # Available algorithms with auto-selection
   algorithms = [
       "KMeans",           # Fast, reliable baseline
       "Agglomerative",    # Hierarchical clustering
       "DBSCAN",          # Density-based clustering
       "Spectral",        # Graph-based clustering
       "GMM",             # Probabilistic clustering
       "MeanShift",       # Adaptive clustering
       "MiniSom"          # Self-organizing maps
   ]
   ```

3. **Optimization Metrics**
   - **Silhouette Score**: Cluster cohesion and separation
   - **Davies-Bouldin Index**: Cluster compactness
   - **Gender Entropy**: Gender balance within groups
   - **Nationality Entropy**: Cultural diversity balance

4. **Genetic Algorithm Enhancement**
   - Population-based optimization
   - Multi-objective fitness function
   - Balanced group size constraints

### Dataset Specifications

**Production Dataset: All Questions.csv**
- **Total Questions**: 880 (perfectly balanced)
- **Distribution**: 220 questions per dimension
- **Dimensions**: Creativity, Teamwork, Soft Skills, Hard Skills
- **Subdimensions**: 60+ specialized categories
- **Format**: Standardized 5-point Likert scale
- **Year Levels**: Questions for Years 1-3

## 🧪 Testing

### Test Structure
```
tests/
├── test_clustering.py              # Clustering algorithm tests
├── test_generate_endpoint.py       # Single question generation
├── test_generate_category_endpoint.py # Category generation
├── test_generate_full_quiz_endpoint.py # Full quiz generation
├── test_real_dataset_clustering.py # Real data clustering
├── test_imports.py                 # Dependency verification
└── run_all_tests.py               # Test runner
```

### Running Tests

```bash
# Run all tests
python tests/run_all_tests.py

# Run specific test files
python tests/test_clustering.py
python tests/test_generate_endpoint.py

# Using pytest
pytest tests/ -v
```

### Test Requirements
- FastAPI server running on localhost:8000
- Firebase test data (test quizzes and categories)
- Valid API keys in environment
- Required Python packages (requests, pytest)

## 🚀 Deployment

### Local Development
```bash
# Start main API server
cd "Integration equipe DS"
python -m uvicorn src.main:app --reload --host 0.0.0.0 --port 8000

# Start additional services
cd "Question Generation"
streamlit run streamlit_main.py --server.port 8503
```

### Production Deployment
1. **Environment Variables**
   - `GEMINI_API_KEY`: Google Gemini API key
   - `FIREBASE_CREDENTIALS`: Path to Firebase credentials
   - `DATASET_PATH`: Path to questions dataset

2. **Dependencies**
   - Install production requirements
   - Configure Firebase for production
   - Set up proper CORS for frontend

3. **Database Setup**
   - Initialize Firebase Firestore
   - Upload production dataset
   - Configure security rules

## 🤝 Contributing

### Development Workflow
1. Fork the repository
2. Create a feature branch
3. Follow the existing code structure
4. Add tests for new functionality
5. Update documentation
6. Submit a pull request

### Code Standards
- **Python**: Follow PEP 8 guidelines
- **FastAPI**: Use type hints and Pydantic models
- **Testing**: Maintain test coverage above 80%
- **Documentation**: Update README for significant changes

### Key Development Areas
- **Algorithm Enhancement**: Improve clustering algorithms
- **UI/UX**: Enhance Streamlit interfaces
- **Performance**: Optimize question generation speed
- **Features**: Add new assessment dimensions
- **Integration**: Expand LMS compatibility

## 📈 Roadmap

### Short Term (Next 3 months)
- [ ] Docker containerization
- [ ] Enhanced question templates
- [ ] Improved clustering visualization
- [ ] Performance optimization



**Built with ❤️ for educational excellence**
