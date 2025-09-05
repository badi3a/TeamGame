import streamlit as st
import pandas as pd
import json
from shared_storage import QuizStorage

st.set_page_config(page_title="Student Quiz Portal", page_icon="🎯", layout="wide")

# Initialize storage with error handling
@st.cache_resource
def get_storage():
    try:
        return QuizStorage()
    except Exception as e:
        st.error(f"Failed to initialize storage: {str(e)}")
        return None

storage = get_storage()

st.title("🎯 Student Self-Assessment Portal")
st.markdown("Complete personality-style assessments to evaluate your skills across different dimensions")

# Quick navigation in sidebar
with st.sidebar:
    st.markdown("### 🧭 Quick Navigation")
    st.markdown("- [🏠 Main Hub](http://localhost:8503)")
    st.markdown("- [👩‍🏫 Teacher Interface](http://localhost:8501)")
    st.markdown("- [🔧 API Docs](http://localhost:8000/docs)")
    st.divider()

# Custom CSS for better styling
st.markdown("""
<style>
.quiz-question {
    background-color: #f8f9fa;
    padding: 20px;
    border-radius: 10px;
    margin: 15px 0;
    border-left: 4px solid #007bff;
}
.question-text {
    font-size: 1.1em;
    font-weight: 500;
    margin-bottom: 10px;
}
.question-meta {
    font-size: 0.9em;
    color: #6c757d;
    margin-bottom: 15px;
}
.likert-options {
    display: flex;
    justify-content: space-between;
    gap: 10px;
    margin: 15px 0;
}
.progress-text {
    text-align: center;
    margin: 10px 0;
    font-weight: 500;
}
</style>
""", unsafe_allow_html=True)

# Initialize session state
if 'current_quiz' not in st.session_state:
    st.session_state.current_quiz = None
if 'responses' not in st.session_state:
    st.session_state.responses = {}
if 'student_name' not in st.session_state:
    st.session_state.student_name = ""

# Sidebar for quiz selection
with st.sidebar:
    st.header("📚 Available Quizzes")
    
    # Get saved quizzes
    if storage:
        try:
            saved_quizzes = storage.get_all_quizzes()
            st.success(f"✅ Found {len(saved_quizzes)} saved quizzes")
        except Exception as e:
            st.error(f"❌ Error loading quizzes: {str(e)}")
            saved_quizzes = []
    else:
        st.error("❌ Storage not available")
        saved_quizzes = []
    
    if saved_quizzes:
        st.write("**Teacher-Generated Quizzes:**")
        for quiz in saved_quizzes:
            if st.button(f"📝 {quiz['title']}", key=f"quiz_{quiz['id']}"):
                st.session_state.current_quiz = quiz
                st.session_state.responses = {}
                st.rerun()
        
        st.divider()
    else:
        st.info("📭 No saved quizzes found. Ask your teacher to create some!")

    # File upload option
    st.write("**Or Upload Quiz File:**")
    uploaded_file = st.file_uploader(
        "Upload quiz file", 
        type=["json", "csv"],
        help="Upload a JSON or CSV file containing quiz questions"
    )
    
    if uploaded_file is not None:
        try:
            if uploaded_file.name.endswith('.json'):
                quiz_data = json.load(uploaded_file)
                if isinstance(quiz_data, list):
                    quiz_content = quiz_data
                else:
                    quiz_content = quiz_data.get('data', quiz_data)
            else:  # CSV
                quiz_df = pd.read_csv(uploaded_file)
                quiz_content = quiz_df.to_dict(orient='records')
            
            # Create temporary quiz object
            temp_quiz = {
                'id': 'uploaded_quiz',
                'title': uploaded_file.name.split('.')[0],
                'data': quiz_content,
                'created_at': 'Uploaded file'
            }
            
            st.session_state.current_quiz = temp_quiz
            st.session_state.responses = {}
            st.success(f"✅ Loaded {len(quiz_content)} questions")
            st.rerun()
            
        except Exception as e:
            st.error(f"❌ Error loading file: {str(e)}")

# Main content area
if st.session_state.current_quiz is None:
    # No quiz selected
    st.info("👈 Please select a quiz from the sidebar to begin")
    
    if saved_quizzes:
        st.subheader("📊 Available Quizzes")
        
        for quiz in saved_quizzes:
            with st.expander(f"🎯 {quiz['title']}", expanded=False):
                col1, col2, col3 = st.columns(3)
                
                with col1:
                    st.metric("Questions", len(quiz['data']))
                
                with col2:
                    dimensions = set([q.get('dimension', 'N/A') for q in quiz['data']])
                    st.metric("Dimensions", len(dimensions))
                
                with col3:
                    responses = storage.get_responses_for_quiz(quiz['id'])
                    st.metric("Responses", len(responses))
                
                st.write("**Dimensions covered:**")
                st.write(", ".join(dimensions))
    
    else:
        st.warning("📭 No quizzes available. Ask your teacher to create some!")
        
        # Show sample format
        with st.expander("📋 Expected File Format"):
            st.write("**JSON format:**")
            st.code('''[
  {
    "question_id": "q_001",
    "dimension": "creativity",
    "subdimension": "innovation_problem_solving",
    "question_text": "How confident are you in solving problems creatively?",
    "target_year_level": 2,
    "response_scale": "1-5"
  }
]''', language='json')

else:
    # Quiz selected - show assessment interface
    current_quiz = st.session_state.current_quiz
    quiz_data = current_quiz['data']
    
    # Student name input
    if not st.session_state.student_name:
        st.subheader("👤 Student Information")
        student_name = st.text_input("Please enter your name:", placeholder="Your full name")
        if st.button("Continue to Quiz") and student_name:
            st.session_state.student_name = student_name
            st.rerun()
        st.stop()
    
    # Quiz header
    st.subheader(f"📝 {current_quiz['title']}")
    st.write(f"Welcome, **{st.session_state.student_name}**! 👋")
    
    # Progress tracking
    total_questions = len(quiz_data)
    answered_questions = len(st.session_state.responses)
    progress = answered_questions / total_questions if total_questions > 0 else 0
    
    st.progress(progress)
    st.markdown(f'<div class="progress-text">Progress: {answered_questions}/{total_questions} questions completed</div>', 
                unsafe_allow_html=True)
    
    if answered_questions == total_questions and total_questions > 0:
        st.balloons()
        st.success("🎉 Quiz completed! Scroll down to see your results.")
    
    # Quiz questions
    st.subheader("🎯 Assessment Questions")
    
    responses = {}
    
    for idx, question in enumerate(quiz_data):
        question_id = question.get('question_id', f'q_{idx}')
        question_text = question.get('question_text', 'Question text missing')
        dimension = question.get('dimension', 'Unknown')
        subdimension = question.get('subdimension', 'Unknown')
        
        # Question container
        st.markdown(f"""
        <div class="quiz-question">
            <div class="question-text">Question {idx + 1}: {question_text}</div>
            <div class="question-meta">Dimension: {dimension} → {subdimension}</div>
        </div>
        """, unsafe_allow_html=True)
        
        # Likert scale response
        response = st.radio(
            label=f"Your response to question {idx + 1}:",
            options=[1, 2, 3, 4, 5],
            format_func=lambda x: {
                1: "1 - Strongly Disagree", 
                2: "2 - Disagree", 
                3: "3 - Neutral", 
                4: "4 - Agree", 
                5: "5 - Strongly Agree"
            }[x],
            key=f"question_{question_id}",
            horizontal=True,
            label_visibility="collapsed"
        )
        
        responses[question_id] = response
        st.divider()
    
    # Update session state
    st.session_state.responses = responses
    
    # Submit button and results
    if len(responses) == total_questions:
        if st.button("📤 Submit Assessment", type="primary", use_container_width=True):
            
            # Calculate dimension scores
            dimension_scores = {}
            question_count = {}
            
            for question in quiz_data:
                dim = question.get('dimension', 'Unknown')
                q_id = question.get('question_id', f'q_{quiz_data.index(question)}')
                score = responses.get(q_id, 3)  # Default to neutral if missing
                
                if dim not in dimension_scores:
                    dimension_scores[dim] = 0
                    question_count[dim] = 0
                
                dimension_scores[dim] += score
                question_count[dim] += 1
            
            # Calculate averages
            avg_scores = {
                dim: dimension_scores[dim] / question_count[dim] 
                for dim in dimension_scores.keys()
            }
            
            # Save responses if this is a saved quiz
            if current_quiz['id'] != 'uploaded_quiz':
                storage.save_responses(
                    current_quiz['id'],
                    st.session_state.student_name,
                    responses,
                    avg_scores
                )
                st.success("✅ Your responses have been saved!")
            
            # Results visualization
            st.subheader("📈 Your Assessment Results")
            
            col1, col2 = st.columns([1, 1])
            
            with col1:
                st.write("**Your Dimension Scores (1-5 scale):**")
                for dim, score in avg_scores.items():
                    # Color coding based on score
                    if score >= 4:
                        color = "🟢"
                    elif score >= 3:
                        color = "🟡"
                    else:
                        color = "🔴"
                    
                    st.metric(
                        f"{color} {dim.replace('_', ' ').title()}", 
                        f"{score:.2f}",
                        delta=f"{score-3:.2f}" if abs(score-3) > 0.1 else None
                    )
            
            with col2:
                # Create chart data
                chart_data = pd.DataFrame({
                    'Dimension': [d.replace('_', ' ').title() for d in avg_scores.keys()],
                    'Score': list(avg_scores.values())
                })
                
                st.bar_chart(chart_data.set_index('Dimension'), height=300)
            
            # Interpretation
            st.subheader("💡 Score Interpretation")
            
            interpretation = {
                (4.0, 5.0): ("🌟 Excellent", "You demonstrate strong confidence and competence in this area."),
                (3.5, 4.0): ("✅ Good", "You show solid skills with room for minor improvements."),
                (2.5, 3.5): ("⚡ Developing", "You're building skills in this area - keep practicing!"),
                (1.0, 2.5): ("📚 Needs Development", "Focus on building skills in this area through practice and learning.")
            }
            
            for dim, score in avg_scores.items():
                for (min_score, max_score), (level, description) in interpretation.items():
                    if min_score <= score < max_score:
                        st.info(f"**{dim.replace('_', ' ').title()}** - {level}: {description}")
                        break
            
            # Download results
            results = {
                'student_name': st.session_state.student_name,
                'quiz_title': current_quiz['title'],
                'responses': responses,
                'dimension_scores': avg_scores,
                'completion_time': pd.Timestamp.now().isoformat(),
                'total_questions': total_questions
            }
            
            st.download_button(
                label="📄 Download Your Results",
                data=json.dumps(results, indent=2),
                file_name=f"assessment_results_{st.session_state.student_name}_{pd.Timestamp.now().strftime('%Y%m%d_%H%M%S')}.json",
                mime="application/json"
            )
            
            # Reset option
            if st.button("🔄 Take Another Quiz"):
                st.session_state.current_quiz = None
                st.session_state.responses = {}
                st.session_state.student_name = ""
                st.rerun()
