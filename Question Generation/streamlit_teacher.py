import streamlit as st
import pandas as pd
import requests
from shared_storage import QuizStorage
import time
import os

def get_url(port, path=""):
    """
    Return a service URL: uses GitHub Codespaces forwarding domain if detected, otherwise localhost.
    """
    cs = os.environ.get("CODESPACE_NAME")
    if cs:
        # Use Codespaces forwarded ports domain (fallback to githubpreview.dev)
        domain = os.environ.get("GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN", "githubpreview.dev")
        return f"https://{cs}-{port}.{domain}{path}"
    return f"http://localhost:{port}{path}"

# Constants
datasets_path = "/workspaces/Stage/Datasets/Quiz Generation/questions.csv"

# Initialize storage with error handling
@st.cache_resource
def get_storage():
    try:
        return QuizStorage()
    except Exception as e:
        st.error(f"Failed to initialize storage: {str(e)}")
        return None

storage = get_storage()

api_base = "http://localhost:8000"  # Internal API calls use localhost

# Load reference questions for fallback
try:
    questions_ref = pd.read_csv(datasets_path, skiprows=1)
    questions_ref.columns = questions_ref.columns.str.strip()
except Exception:
    questions_ref = None

st.set_page_config(page_title="Teacher Quiz Generator", page_icon="👩‍🏫", layout="wide")
st.title("� Quiz Generator")
st.markdown("Create AI-powered self-assessment quizzes")

# Quick navigation 
with st.sidebar:
    st.markdown("### 🧭 Navigation")
    st.markdown(f"- [ Student Interface]({get_url(8502)})")
    st.markdown(f"- [🔧 API Documentation]({get_url(8000, '/docs')})")
    st.divider()

# Sidebar for configuration and saved quizzes
with st.sidebar:
    st.header("⚙️ Configuration")
    
    # Show API status with a simple indicator
    try:
        response = requests.get(f"{api_base}/health", timeout=2)
        if response.status_code == 200:
            st.success("🟢 API Online")
        else:
            st.error("🔴 API Offline")
    except Exception:
        st.error("🔴 API Offline")
    
    st.divider()
    
    # Show saved quizzes
    st.header("📚 Saved Quizzes")
    
    if storage:
        try:
            saved_quizzes = storage.get_all_quizzes()
            
            # Use session state to track quiz count for auto-refresh
            current_count = len(saved_quizzes)
            if "quiz_count" not in st.session_state:
                st.session_state.quiz_count = current_count
            elif st.session_state.quiz_count != current_count:
                st.session_state.quiz_count = current_count
                
        except Exception as e:
            saved_quizzes = []
        
        if saved_quizzes:
            st.write(f"**📊 {len(saved_quizzes)} quiz(es)**")
            
            # Display all quizzes, not just last 5
            for i, quiz in enumerate(reversed(saved_quizzes[-10:])):  # Show last 10, newest first
                with st.expander(f"🎯 {quiz['title']}", expanded=(i < 3)):  # Expand first 3
                    col1, col2, col3 = st.columns(3)
                    with col1:
                        st.write(f"📅 **Created:** {quiz['created_at'][:10]}")
                    with col2:
                        st.write(f"❓ **Questions:** {len(quiz.get('data', []))}")
                    with col3:
                        try:
                            responses = storage.get_responses_for_quiz(quiz['id'])
                            st.write(f"📊 **Responses:** {len(responses)}")
                        except Exception:
                            st.write("📊 **Responses:** 0")
                    
                    # Quick preview of questions
                    if quiz.get('data'):
                        st.write("**Sample Question:**")
                        st.info(quiz['data'][0]['question_text'])
        else:
            st.info("No saved quizzes yet")
    else:
        st.error("Storage not available")

# Load available questions for reference
try:
    questions = pd.read_csv(datasets_path, skiprows=1)
    questions.columns = questions.columns.str.strip()
except Exception as e:
    st.error(f"❌ Could not load questions: {str(e)}")
    st.stop()

# Main interface
col1, col2 = st.columns([2, 1])

with col1:
    st.header("🎯 Generate Quiz")
    
    # Quiz metadata
    quiz_title = st.text_input("Quiz Title", "My Self-Assessment Quiz", key="main_quiz_title")
    
    # Get dimensions from API
    try:
        dims_response = requests.get(f"{api_base}/dimensions", timeout=5)
        if dims_response.status_code == 200:
            dimensions = dims_response.json()
            selected_dim = st.selectbox("Dimension", dimensions, key="main_dimension_select")
            
            # Get subdimensions
            subdims_response = requests.get(f"{api_base}/subdimensions/{selected_dim}", timeout=5)
            if subdims_response.status_code == 200:
                subdimensions = subdims_response.json()
                selected_subdim = st.selectbox("Subdimension", subdimensions, key="main_subdimension_select")
            else:
                st.error("Could not load subdimensions")
                selected_subdim = None
        else:
            # API unavailable; using reference questions for fallback
            dims = questions_ref["dimension"].unique().tolist() if questions_ref is not None else []
            selected_dim = st.selectbox("Dimension", dims, key="fallback_dimension_select")
            subdims = questions_ref[questions_ref["dimension"] == selected_dim]["subdimension"].unique().tolist() if questions_ref is not None else []
            selected_subdim = st.selectbox("Subdimension", subdims, key="fallback_subdimension_select")
    except Exception:
        # API error; using reference questions for fallback
        dims = questions_ref["dimension"].unique().tolist() if questions_ref is not None else []
        selected_dim = st.selectbox("Dimension", dims, key="exception_dimension_select")
        subdims = questions_ref[questions_ref["dimension"] == selected_dim]["subdimension"].unique().tolist() if questions_ref is not None else []
        selected_subdim = st.selectbox("Subdimension", subdims, key="exception_subdimension_select")
    
    year_levels = sorted(questions["target_year_level"].unique())
    selected_year = st.selectbox("Target Year Level", year_levels, key="year_level_select")
    num_questions = st.slider("Number of Questions", min_value=1, max_value=20, value=5, key="num_questions_slider")
    additional_context = st.text_area("Additional Context (optional)", 
                                    placeholder="e.g., Focus on web development, React frameworks...", 
                                    key="additional_context_textarea")

with col2:
    st.header("📋 Preview")
    if selected_dim and selected_subdim:
        filtered_questions = questions[
            (questions["dimension"] == selected_dim) & 
            (questions["subdimension"] == selected_subdim) &
            (questions["target_year_level"] == selected_year)
        ]
        st.write(f"**{len(filtered_questions)} existing questions match your criteria**")
        if len(filtered_questions) > 0:
            st.write("**Sample:**")
            st.info(filtered_questions.iloc[0]["question_text"])

# Generate quiz
if st.button("🎯 Generate Quiz", type="primary", key="generate_quiz_btn"):
    if not selected_subdim:
        st.error("Please select/enter a subdimension")
    else:
        with st.spinner("Generating questions..."):
            payload = {
                "dimension": selected_dim,
                "subdimension": selected_subdim,
                "target_year_level": int(selected_year),
                "num_questions": num_questions,
                "additional_context": additional_context if additional_context else None
            }
            
            try:
                response = requests.post(f"{api_base}/generate", json=payload, timeout=30)
                if response.status_code == 200:
                    generated_questions = response.json()["questions"]
                 
                    # Create structured quiz data
                    quiz_data = []
                    for i, question in enumerate(generated_questions):
                        quiz_data.append({
                            "question_id": f"gen_{i+1:03d}",
                            "dimension": selected_dim,
                            "subdimension": selected_subdim,
                            "question_text": question,
                            "target_year_level": selected_year,
                            "response_scale": "1-5"
                        })
                    
                    quiz_df = pd.DataFrame(quiz_data)
                    
                    st.success(f"✅ Generated {len(quiz_data)} questions!")
                    st.subheader("Generated Quiz")
                    
                    # Editable dataframe
                    edited_df = st.data_editor(
                        quiz_df,
                        num_rows="dynamic",
                        use_container_width=True,
                        column_config={
                            "question_text": st.column_config.TextColumn("Question Text", width="large"),
                            "question_id": st.column_config.TextColumn("ID", width="small"),
                        }
                    )
                    
                    # Save and download options
                    col1, col2, col3 = st.columns(3)
                    
                    with col1:
                        # Input for custom quiz title before saving
                        save_title = st.text_input("Save as:", value=quiz_title, key="save_title")
                        
                        # Show what will be saved
                        st.info(f"📝 Ready to save: {len(edited_df)} questions")
                        
                        if st.button("💾 Save Quiz", type="secondary", key="save_quiz_btn"):
                            if not storage:
                                st.error("❌ Storage not available")
                            elif not save_title.strip():
                                st.error("❌ Please enter a quiz title")
                            else:
                                try:
                                    # Ensure we're saving the edited dataframe
                                    quiz_data_to_save = edited_df.to_dict(orient="records")
                                    
                                    quiz_id = storage.save_quiz(quiz_data_to_save, save_title.strip())
                                    st.success(f"✅ Quiz '{save_title}' saved with {len(quiz_data_to_save)} questions!")
                                    st.balloons()
                                    
                                    # Force refresh of sidebar
                                    st.session_state.last_refresh += 1
                                    time.sleep(1)  # Give time for file to be written
                                    st.rerun()
                                
                                except Exception as e:
                                    st.error(f"❌ Save failed: {str(e)}")
                    
                    with col2:
                        st.download_button(
                            label="📄 Download JSON",
                            data=edited_df.to_json(orient="records", force_ascii=False, indent=2),
                            file_name=f"quiz_{selected_dim}_{selected_subdim}_year{selected_year}.json",
                            mime="application/json"
                        )
                    
                    with col3:
                        st.download_button(
                            label="📊 Download CSV",
                            data=edited_df.to_csv(index=False),
                            file_name=f"quiz_{selected_dim}_{selected_subdim}_year{selected_year}.csv",
                            mime="text/csv"
                        )
                        
                elif response.status_code == 401:
                    # Fallback: sample existing questions
                    fallback = questions_ref[
                        (questions_ref["dimension"]==selected_dim)&
                        (questions_ref["subdimension"]==selected_subdim)&
                        (questions_ref["target_year_level"]==selected_year)
                    ]
                    sampled = fallback.question_text.sample(min(num_questions, len(fallback))).tolist() if not fallback.empty else []
                    generated_questions = sampled
                    # Build quiz_data
                    quiz_data = []
                    for i, question in enumerate(generated_questions):
                        quiz_data.append({
                            "question_id": f"ref_{i+1:03d}",
                            "dimension": selected_dim,
                            "subdimension": selected_subdim,
                            "question_text": question,
                            "target_year_level": selected_year,
                            "response_scale": "1-5"
                        })
                    st.info(f"📝 Using {len(quiz_data)} reference questions as fallback.")
                else:
                    st.error(f"❌ Generation failed: {response.status_code} - {response.text}")
                    quiz_data = []
                
            except Exception as e:
                st.error(f"❌ Request failed: {str(e)}")

# View responses section
if storage and saved_quizzes:
    st.divider()
    st.header("📊 Quiz Responses")
    
    selected_quiz_for_responses = st.selectbox(
        "Select quiz to view responses:",
        saved_quizzes,
        format_func=lambda x: f"{x['title']} ({x['created_at'][:10]})",
        key="quiz_responses_select"
    )
    
    if selected_quiz_for_responses:
        try:
            responses = storage.get_responses_for_quiz(selected_quiz_for_responses['id'])
            if responses:
                st.write(f"📈 {len(responses)} student responses:")
                
                # Create summary dataframe
                summary_data = []
                for response in responses:
                    summary_data.append({
                        "Student": response['student_name'],
                        "Submitted": response['submitted_at'][:16],
                        **{f"{dim}_score": f"{score:.2f}" for dim, score in response['scores'].items()}
                    })
                
                summary_df = pd.DataFrame(summary_data)
                st.dataframe(summary_df, use_container_width=True)
                
                # Download responses
                st.download_button(
                    label="📥 Download All Responses",
                    data=pd.DataFrame(responses).to_csv(index=False),
                    file_name=f"responses_{selected_quiz_for_responses['title']}.csv",
                    mime="text/csv"
                )
            else:
                st.info("No responses yet for this quiz")
        except Exception as e:
            st.error(f"Error loading responses: {str(e)}")
