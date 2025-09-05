import streamlit as st
import requests
import os

st.set_page_config(
    page_title="Quiz System Hub", 
    page_icon="🎓", 
    layout="wide",
    initial_sidebar_state="expanded"
)

# Function to get the correct URLs based on environment
def get_service_urls():
    codespace_name = os.getenv('CODESPACE_NAME')
    github_codespaces_port_forwarding_domain = os.getenv('GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN', 'preview.app.github.dev')
    
    if codespace_name:
        # GitHub Codespace URLs
        base_url = f"https://{codespace_name}-{{port}}.{github_codespaces_port_forwarding_domain}"
        return {
            "API Server": base_url.format(port=8000) + "/health",
            "Teacher UI": base_url.format(port=8501),
            "Student UI": base_url.format(port=8502),
            "Main Hub": base_url.format(port=8503),
            "API Docs": base_url.format(port=8000) + "/docs"
        }
    else:
        # Local development URLs
        return {
            "API Server": "http://localhost:8000/health",
            "Teacher UI": "http://localhost:8501",
            "Student UI": "http://localhost:8502", 
            "Main Hub": "http://localhost:8503",
            "API Docs": "http://localhost:8000/docs"
        }

# Get URLs for current environment
urls = get_service_urls()

# Check if services are running
def check_service_status():
    services = {
        "API Server": urls["API Server"],
        "Teacher UI": urls["Teacher UI"],
        "Student UI": urls["Student UI"]
    }
    
    status = {}
    for name, url in services.items():
        try:
            response = requests.get(url, timeout=3)
            if response.status_code in [200, 405]:  # 405 for Streamlit health checks
                status[name] = {"status": "🟢 Running", "accessible": True}
            else:
                status[name] = {"status": f"🔴 Error ({response.status_code})", "accessible": False}
        except requests.exceptions.ConnectionError:
            status[name] = {"status": "🔴 Offline", "accessible": False}
        except requests.exceptions.Timeout:
            status[name] = {"status": "� Slow", "accessible": True}
        except Exception as e:
            status[name] = {"status": f"🔴 Error", "accessible": False}
    
    return status

st.title("🎓 Quiz System")
st.markdown("### Central hub for quiz creation and management")

# Service status in sidebar
st.sidebar.header("🔧 System Status")

status = check_service_status()
all_running = all(s["accessible"] for s in status.values())

for service, info in status.items():
    st.sidebar.write(f"{service}: {info['status']}")

if all_running:
    st.sidebar.success("✅ All services online")
else:
    st.sidebar.warning("⚠️ Some services offline")

# Add troubleshooting section
st.sidebar.markdown("---")
st.sidebar.markdown("### � Quick Help")
if not all_running:
    st.sidebar.markdown("Run `./run.sh` to start services")
else:
    st.sidebar.markdown("All systems operational! 🎉")

# Navigation
st.markdown("## 🧭 Access Points")

col1, col2, col3 = st.columns(3)

with col1:
    st.markdown("""
    ### 👩‍🏫 Teacher Interface
    **Create and manage quizzes**
    - Generate AI-powered questions
    - Edit and customize quizzes  
    - View student responses
    """)
    
    # Check if teacher interface is accessible
    teacher_accessible = status.get("Teacher UI", {}).get("accessible", False)
    teacher_url = urls["Teacher UI"]
    
    if teacher_accessible:
        st.markdown(f'<a href="{teacher_url}" target="_blank" style="text-decoration: none;"><button style="background-color: #FF6B6B; color: white; padding: 10px 20px; border: none; border-radius: 5px; cursor: pointer; width: 100%;">🚀 Open Teacher Interface</button></a>', unsafe_allow_html=True)
    else:
        st.markdown(f'<button style="background-color: #cccccc; color: #666666; padding: 10px 20px; border: none; border-radius: 5px; width: 100%; cursor: not-allowed;">🚫 Teacher Interface Offline</button>', unsafe_allow_html=True)

with col2:
    st.markdown("""
    ### 🎯 Student Interface  
    **Take assessments**
    - Browse available quizzes
    - Complete self-assessments
    - View your results
    """)
    
    # Check if student interface is accessible
    student_accessible = status.get("Student UI", {}).get("accessible", False)
    student_url = urls["Student UI"]
    
    if student_accessible:
        st.markdown(f'<a href="{student_url}" target="_blank" style="text-decoration: none;"><button style="background-color: #4ECDC4; color: white; padding: 10px 20px; border: none; border-radius: 5px; cursor: pointer; width: 100%;">🚀 Open Student Interface</button></a>', unsafe_allow_html=True)
    else:
        st.markdown(f'<button style="background-color: #cccccc; color: #666666; padding: 10px 20px; border: none; border-radius: 5px; width: 100%; cursor: not-allowed;">🚫 Student Interface Offline</button>', unsafe_allow_html=True)

with col3:
    st.markdown("""
    ### 🔧 API Documentation
    **Developer resources**
    - REST API endpoints
    - Interactive testing
    - Schema documentation
    """)
    
    # Check if API is accessible
    api_accessible = status.get("API Server", {}).get("accessible", False)
    api_url = urls["API Docs"]
    
    if api_accessible:
        st.markdown(f'<a href="{api_url}" target="_blank" style="text-decoration: none;"><button style="background-color: #95E1D3; color: white; padding: 10px 20px; border: none; border-radius: 5px; cursor: pointer; width: 100%;">🚀 Open API Docs</button></a>', unsafe_allow_html=True)
    else:
        st.markdown(f'<button style="background-color: #cccccc; color: #666666; padding: 10px 20px; border: none; border-radius: 5px; width: 100%; cursor: not-allowed;">🚫 API Offline</button>', unsafe_allow_html=True)

st.divider()

# Quick links
st.markdown("### 🔗 Quick Access")
col1, col2, col3 = st.columns(3)

with col1:
    st.link_button("👩‍🏫 Teacher Portal", urls["Teacher UI"], use_container_width=True)

with col2:
    st.link_button("🎯 Student Portal", urls["Student UI"], use_container_width=True)

with col3:
    st.link_button("📚 API Documentation", urls["API Docs"], use_container_width=True)

# Instructions
st.divider()
st.markdown("### � Getting Started")

col1, col2 = st.columns(2)

with col1:
    st.markdown("""
    **For Teachers:**
    1. Open Teacher Interface
    2. Generate questions using AI
    3. Save quizzes for students
    4. Monitor student responses
    """)

with col2:
    st.markdown("""
    **For Students:**
    1. Open Student Interface
    2. Select a quiz from the list
    3. Complete the assessment
    4. View your results
    """)
