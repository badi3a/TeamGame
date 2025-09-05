#!/usr/bin/env bash
# Robust one-click runner: setup venv, install dependencies and start services

set -e  # Exit on any error

# Change working directory to script's location
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$script_dir"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to kill processes on specific ports
kill_port() {
    local port=$1
    local pids=$(lsof -ti :$port 2>/dev/null || true)
    if [ ! -z "$pids" ]; then
        print_warning "Killing existing processes on port $port"
        echo $pids | xargs kill -9 2>/dev/null || true
        sleep 1
    fi
}

# Function to wait for service to start
wait_for_service() {
    local url=$1
    local name=$2
    local max_attempts=30
    local attempt=1
    
    print_status "Waiting for $name to start..."
    while [ $attempt -le $max_attempts ]; do
        if curl -s --connect-timeout 2 "$url" >/dev/null 2>&1; then
            print_status "$name is ready! ✅"
            return 0
        fi
        printf "."
        sleep 1
        attempt=$((attempt + 1))
    done
    print_error "$name failed to start after ${max_attempts}s"
    return 1
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to detect environment and generate URLs
get_base_url() {
    if [ -n "$CODESPACE_NAME" ]; then
        # We're in GitHub Codespaces
        echo "https://${CODESPACE_NAME}-8503.${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN}"
    else
        # Local environment
        echo "http://localhost:8503"
    fi
}

# Function to get service URLs
get_service_urls() {
    local base_url
    if [ -n "$CODESPACE_NAME" ]; then
        # Codespaces URLs
        echo "API_URL=https://${CODESPACE_NAME}-8000.${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN}"
        echo "TEACHER_URL=https://${CODESPACE_NAME}-8501.${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN}"
        echo "STUDENT_URL=https://${CODESPACE_NAME}-8502.${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN}"
        echo "MAIN_URL=https://${CODESPACE_NAME}-8503.${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN}"
    else
        # Local URLs
        echo "API_URL=http://localhost:8000"
        echo "TEACHER_URL=http://localhost:8501"
        echo "STUDENT_URL=http://localhost:8502"
        echo "MAIN_URL=http://localhost:8503"
    fi
}

# Cleanup function
cleanup() {
    print_warning "🛑 Shutting down all services..."
    
    # Kill background jobs
    jobs -p | xargs -r kill 2>/dev/null || true
    
    # Kill processes on our ports
    kill_port 8000
    kill_port 8501
    kill_port 8502
    kill_port 8503
    
    # Extra cleanup
    pkill -f "streamlit.*8501" 2>/dev/null || true
    pkill -f "streamlit.*8502" 2>/dev/null || true
    pkill -f "streamlit.*8503" 2>/dev/null || true
    pkill -f "uvicorn.*8000" 2>/dev/null || true
    
    print_status "Cleanup completed"
    exit 0
}

# Set trap to cleanup on script exit
trap cleanup SIGINT SIGTERM EXIT

print_status "🔧 Setting up Quiz System Environment..."

# Check prerequisites
if ! command_exists python3; then
    print_error "Python 3 is required but not installed"
    exit 1
fi

if ! command_exists pip; then
    print_error "pip is required but not installed"
    exit 1
fi

# Kill any existing processes on our ports
print_status "🧹 Cleaning up existing processes..."
kill_port 8000
kill_port 8501
kill_port 8502
kill_port 8503

# Create and activate virtual environment
if [ ! -d ".venv" ]; then
    print_status "Creating virtual environment..."
    python3 -m venv .venv
fi

print_status "Activating virtual environment..."
source .venv/bin/activate

# Verify we're in the virtual environment
if [ "$VIRTUAL_ENV" = "" ]; then
    print_error "Failed to activate virtual environment"
    exit 1
fi

# Install/update requirements
print_status "Installing dependencies..."
pip install --upgrade pip --quiet
pip install -r requirements.txt --quiet

# Check if .env file exists
if [ ! -f ".env" ]; then
    print_warning "No .env file found. Creating from .env.example..."
    if [ -f ".env.example" ]; then
        cp .env.example .env
        print_warning "Please edit .env file and add your GOOGLE_API_KEY"
    else
        print_error "No .env.example file found"
        exit 1
    fi
fi

# Verify .env has API key
if ! grep -q "GOOGLE_API_KEY=" .env || grep -q "GOOGLE_API_KEY=$" .env || grep -q "GOOGLE_API_KEY=your" .env; then
    print_warning "GOOGLE_API_KEY not properly set in .env file"
    print_warning "Please edit .env and add your Google Gemini API key"
fi

print_status "🚀 Starting all services..."

# Get service URLs for current environment
eval $(get_service_urls)

echo "=================================="
echo -e "${BLUE}Environment: ${NC}$([ -n "$CODESPACE_NAME" ] && echo "GitHub Codespaces" || echo "Local")"
if [ -n "$CODESPACE_NAME" ]; then
    echo -e "${BLUE}Codespaces URLs:${NC}"
    echo -e "  Main Hub:    $MAIN_URL"
    echo -e "  API Server:  $API_URL"
    echo -e "  Teacher UI:  $TEACHER_URL"
    echo -e "  Student UI:  $STUDENT_URL"
    echo -e "${YELLOW}Local URLs (use these if Codespaces URLs don't work):${NC}"
    echo -e "  Main Hub:    http://127.0.0.1:8503"
    echo -e "  API Server:  http://127.0.0.1:8000"
    echo -e "  Teacher UI:  http://127.0.0.1:8501"
    echo -e "  Student UI:  http://127.0.0.1:8502"
else
    echo -e "${BLUE}Main Hub:    ${NC}$MAIN_URL"
    echo -e "${BLUE}API Server:  ${NC}$API_URL"
    echo -e "${BLUE}Teacher UI:  ${NC}$TEACHER_URL"
    echo -e "${BLUE}Student UI:  ${NC}$STUDENT_URL"
fi
echo "=================================="
echo -e "${YELLOW}Press Ctrl+C to stop all services${NC}"
echo ""

# Create log directory
mkdir -p logs

# Start API server
print_status "Starting API server on port 8000..."
uvicorn api:app --reload --host 0.0.0.0 --port 8000 > logs/api.log 2>&1 &
API_PID=$!

# Wait for API to start
if ! wait_for_service "http://localhost:8000/health" "API Server"; then
    print_error "API Server failed to start. Check logs/api.log"
    exit 1
fi

# Start Teacher interface
print_status "Starting Teacher interface on port 8501..."
streamlit run streamlit_teacher.py --server.port 8501 --server.headless true --server.address 0.0.0.0 --browser.gatherUsageStats false --global.showWarningOnDirectExecution false > logs/teacher.log 2>&1 &
TEACHER_PID=$!

# Wait for Teacher interface
if ! wait_for_service "http://localhost:8501" "Teacher Interface"; then
    print_error "Teacher Interface failed to start. Check logs/teacher.log"
    exit 1
fi

# Start Student interface
print_status "Starting Student interface on port 8502..."
streamlit run streamlit_student.py --server.port 8502 --server.headless true --server.address 0.0.0.0 --browser.gatherUsageStats false --global.showWarningOnDirectExecution false > logs/student.log 2>&1 &
STUDENT_PID=$!

# Wait for Student interface
if ! wait_for_service "http://localhost:8502" "Student Interface"; then
    print_error "Student Interface failed to start. Check logs/student.log"
    exit 1
fi

# Start Main Hub (foreground)
print_status "Starting Main Hub on port 8503..."
print_status "🎉 All services started successfully!"

if [ -n "$CODESPACE_NAME" ]; then
    print_status "🌐 Try these URLs in your browser:"
    echo -e "${GREEN}Codespaces: ${MAIN_URL}${NC}"
    echo -e "${GREEN}Local:      http://127.0.0.1:8503${NC}"
    print_status "📋 If Codespaces URLs don't work, use the local 127.0.0.1 URLs"
else
    print_status "🌐 Open the Main Hub in your browser at:"
    echo -e "${GREEN}${MAIN_URL}${NC}"
fi

# Give services a moment to fully initialize
sleep 2

# Try to open browser (will work in local environments)
if [ -z "$CODESPACE_NAME" ]; then
    # Only try to open browser in local environment
    main_url=$(get_base_url)
    if command_exists xdg-open; then
        xdg-open "$main_url" 2>/dev/null || true
    elif command_exists open; then
        open "$main_url" 2>/dev/null || true
    fi
fi

# Start Main Hub (this will block)
streamlit run streamlit_main.py --server.port 8503 --server.headless true --server.address 0.0.0.0 --browser.gatherUsageStats false --global.showWarningOnDirectExecution false

# If we get here, the main hub was closed, so cleanup
print_status "Main Hub closed. Shutting down other services..."
