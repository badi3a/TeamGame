#!/usr/bin/env bash
# One-click runner: setup venv, install dependencies and start services

echo "🔧 Setting up environment..."

# Create and activate virtual environment
if [ ! -d ".venv" ]; then
  echo "Creating virtual environment..."
  python3 -m venv .venv
fi
source .venv/bin/activate

# Install requirements
echo "Installing dependencies..."
pip install --upgrade pip > /dev/null 2>&1
pip install -r requirements.txt > /dev/null 2>&1

# Function to kill all background processes
cleanup() {
    echo "� Stopping all services..."
    kill $(jobs -p) 2>/dev/null
    pkill -f "streamlit\|uvicorn" 2>/dev/null || true
    exit
}

# Set trap to cleanup on script exit
trap cleanup SIGINT SIGTERM

echo "�🚀 Starting all services..."
echo "=================================="
echo "Main Hub:   http://localhost:8503"
echo "API Server: http://localhost:8000"
echo "Teacher UI: http://localhost:8501" 
echo "Student UI: http://localhost:8502"
echo "=================================="
echo "Press Ctrl+C to stop all services"
echo ""

# Start all services in background with proper logging
echo "Starting API server..."
uvicorn api:app --reload --host 0.0.0.0 --port 8000 > api.log 2>&1 &
API_PID=$!

echo "Starting Teacher interface..."
streamlit run streamlit_teacher.py --server.port 8501 --server.headless true > teacher.log 2>&1 &
TEACHER_PID=$!

echo "Starting Student interface..."
streamlit run streamlit_student.py --server.port 8502 --server.headless true > student.log 2>&1 &
STUDENT_PID=$!

echo "Starting Main Hub..."
streamlit run streamlit_main.py --server.port 8503 --server.headless false

# If we get here, the main hub exited, so cleanup
cleanup
