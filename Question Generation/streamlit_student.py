import streamlit as st
import pandas as pd
import json
from shared_storage import QuizStorage
import plotly.graph_objects as go
import plotly.express as px
import time
from datetime import datetime
import random

st.set_page_config(page_title="🎯 Fun Quiz Portal", page_icon="🎯", layout="wide")

# Initialize storage
@st.cache_resource
def get_storage():
    try:
        return QuizStorage()
    except Exception as e:
        st.error(f"Failed to initialize storage: {str(e)}")
        return None

storage = get_storage()

# Enhanced CSS for a modern, fun interface
st.markdown("""
<style>
/* Import Google Fonts */
@import url('https://fonts.googleapis.com/css2?family=Poppins:wght@300;400;600;700&display=swap');

/* Global styles */
* {
    font-family: 'Poppins', sans-serif;
}

.main-header {
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    padding: 3rem 2rem;
    border-radius: 25px;
    color: white;
    text-align: center;
    margin-bottom: 2rem;
    box-shadow: 0 20px 40px rgba(102, 126, 234, 0.3);
    position: relative;
    overflow: hidden;
}

.main-header::before {
    content: '';
    position: absolute;
    top: -50%;
    left: -50%;
    width: 200%;
    height: 200%;
    background: radial-gradient(circle, rgba(255,255,255,0.1) 0%, transparent 70%);
    animation: sparkle 4s ease-in-out infinite;
}

@keyframes sparkle {
    0%, 100% { transform: rotate(0deg); }
    50% { transform: rotate(180deg); }
}

.quiz-card {
    background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%);
    padding: 2rem;
    border-radius: 20px;
    margin: 1.5rem 0;
    color: white;
    box-shadow: 0 15px 35px rgba(240, 147, 251, 0.3);
    transition: all 0.4s cubic-bezier(0.175, 0.885, 0.32, 1.275);
    cursor: pointer;
    position: relative;
    overflow: hidden;
}

.quiz-card::before {
    content: '';
    position: absolute;
    top: 0;
    left: -100%;
    width: 100%;
    height: 100%;
    background: linear-gradient(90deg, transparent, rgba(255,255,255,0.2), transparent);
    transition: left 0.5s;
}

.quiz-card:hover {
    transform: translateY(-10px) scale(1.02);
    box-shadow: 0 25px 50px rgba(240, 147, 251, 0.4);
}

.quiz-card:hover::before {
    left: 100%;
}

.question-container {
    background: white;
    padding: 3rem 2rem;
    border-radius: 25px;
    margin: 2rem 0;
    box-shadow: 0 10px 40px rgba(0,0,0,0.1);
    border: 1px solid #e0e7ff;
    position: relative;
    transition: all 0.3s ease;
}

.question-container::before {
    content: '';
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    height: 5px;
    background: linear-gradient(90deg, #667eea, #764ba2, #f093fb);
    border-radius: 25px 25px 0 0;
}

.question-container:hover {
    box-shadow: 0 20px 60px rgba(0,0,0,0.15);
    transform: translateY(-5px);
}

.progress-bar-container {
    background: #e5e7eb;
    height: 20px;
    border-radius: 15px;
    overflow: hidden;
    margin: 1rem 0;
    box-shadow: inset 0 2px 4px rgba(0,0,0,0.1);
}

.progress-bar {
    height: 100%;
    background: linear-gradient(90deg, #10b981, #34d399);
    border-radius: 15px;
    transition: width 0.8s cubic-bezier(0.4, 0, 0.2, 1);
    position: relative;
    overflow: hidden;
}

.progress-bar::after {
    content: '';
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: linear-gradient(90deg, transparent, rgba(255,255,255,0.3), transparent);
    animation: shine 2s infinite;
}

@keyframes shine {
    0% { transform: translateX(-100%); }
    100% { transform: translateX(100%); }
}

.emoji-reaction {
    font-size: 3rem;
    display: inline-block;
    animation: bounce 0.6s ease-in-out;
}

@keyframes bounce {
    0%, 20%, 60%, 100% { transform: translateY(0); }
    40% { transform: translateY(-15px); }
    80% { transform: translateY(-8px); }
}

.score-card {
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    padding: 3rem 2rem;
    border-radius: 25px;
    color: white;
    text-align: center;
    margin: 2rem 0;
    box-shadow: 0 20px 40px rgba(102, 126, 234, 0.3);
    position: relative;
    overflow: hidden;
}

.likert-scale {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin: 2rem 0;
    padding: 1rem;
    background: #f8fafc;
    border-radius: 15px;
    border: 2px solid #e2e8f0;
}

.likert-option {
    display: flex;
    flex-direction: column;
    align-items: center;
    padding: 1rem;
    border-radius: 15px;
    transition: all 0.3s ease;
    cursor: pointer;
    min-width: 80px;
}

.likert-option:hover {
    background: #e0e7ff;
    transform: scale(1.05);
}

.likert-option.selected {
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    color: white;
    transform: scale(1.1);
    box-shadow: 0 5px 20px rgba(102, 126, 234, 0.4);
}

.fun-fact {
    background: linear-gradient(135deg, #ffecd2 0%, #fcb69f 100%);
    padding: 1.5rem;
    border-radius: 20px;
    margin: 1rem 0;
    border-left: 5px solid #f59e0b;
    box-shadow: 0 5px 20px rgba(245, 158, 11, 0.2);
}

.celebration {
    position: fixed;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    pointer-events: none;
    z-index: 1000;
}

.confetti {
    position: absolute;
    width: 10px;
    height: 10px;
    background: #f59e0b;
    animation: confetti-fall 3s linear infinite;
}

@keyframes confetti-fall {
    to { 
        transform: translateY(100vh) rotate(360deg);
        opacity: 0;
    }
}

.pulse {
    animation: pulse 2s infinite;
}

@keyframes pulse {
    0% { transform: scale(1); }
    50% { transform: scale(1.05); }
    100% { transform: scale(1); }
}
</style>
""", unsafe_allow_html=True)

# Initialize session state
if "current_quiz" not in st.session_state:
    st.session_state.current_quiz = None
if "responses" not in st.session_state:
    st.session_state.responses = {}
if "current_question_index" not in st.session_state:
    st.session_state.current_question_index = 0
if "quiz_completed" not in st.session_state:
    st.session_state.quiz_completed = False
if "student_name" not in st.session_state:
    st.session_state.student_name = ""
if "quiz_started" not in st.session_state:
    st.session_state.quiz_started = False
if "show_celebration" not in st.session_state:
    st.session_state.show_celebration = False

# Quick navigation in sidebar
with st.sidebar:
    st.markdown("### 🧭 Quick Navigation")
    st.markdown("- [🏠 Main Hub](http://localhost:8503)")
    st.markdown("- [👩‍🏫 Teacher Interface](http://localhost:8501)")
    st.markdown("- [🔧 API Docs](http://localhost:8000/docs)")
    st.divider()
    
    # Fun facts in sidebar
    fun_facts = [
        "🧠 Did you know? Taking self-assessments can improve self-awareness by up to 85%!",
        "⚡ Fun fact: The average person makes 35,000 decisions per day!",
        "🎯 Research shows that regular self-reflection boosts performance by 23%!",
        "🌟 Self-assessment is the first step to personal growth!",
        "💡 Studies show that knowing your strengths increases confidence by 40%!"
    ]
    
    st.markdown("### 💡 Fun Fact")
    st.markdown(f'<div class="fun-fact">{random.choice(fun_facts)}</div>', unsafe_allow_html=True)

# Main header with animation
st.markdown("""
<div class="main-header">
    <h1 style="margin: 0; font-size: 3rem; font-weight: 700;">🎯 Fun Quiz Portal</h1>
    <p style="margin: 1rem 0 0 0; font-size: 1.2rem; opacity: 0.9;">Discover yourself through engaging self-assessments!</p>
</div>
""", unsafe_allow_html=True)

# Get available quizzes with robust error handling
if storage:
    try:
        saved_quizzes = storage.get_all_quizzes()
        if saved_quizzes:
            st.sidebar.success(f"✅ Found {len(saved_quizzes)} available quiz(es)")
        else:
            st.sidebar.info("📚 No quizzes available yet")
    except Exception as e:
        st.sidebar.error(f"❌ Error loading quizzes: {str(e)}")
        saved_quizzes = []
else:
    st.sidebar.error("❌ Storage not available")
    saved_quizzes = []

# Add a refresh button for student interface too
if st.sidebar.button("🔄 Refresh Quizzes"):
    st.rerun()

# Quiz selection screen
if not st.session_state.quiz_started and not st.session_state.current_quiz:
    if saved_quizzes:
        st.markdown("## 🎮 Choose Your Adventure!")
        st.markdown("Select a quiz below to start your self-discovery journey:")
        
        # Display quizzes in an attractive grid
        cols = st.columns(2)
        for i, quiz in enumerate(saved_quizzes):
            # Validate quiz data
            quiz_questions = quiz.get('data', [])
            if not quiz_questions:
                continue  # Skip empty quizzes
                
            with cols[i % 2]:
                quiz_card_html = f"""
                <div class="quiz-card" style="cursor: pointer;">
                    <h3 style="margin: 0 0 1rem 0; font-size: 1.5rem;">📝 {quiz['title']}</h3>
                    <p style="margin: 0 0 1rem 0; opacity: 0.9;">🎯 {len(quiz_questions)} exciting questions</p>
                    <p style="margin: 0 0 1rem 0; opacity: 0.8;">📅 Created: {quiz['created_at'][:10]}</p>
                    <p style="margin: 0; opacity: 0.8;">🏷️ Topics: {', '.join(set([q.get('dimension', 'Unknown') for q in quiz_questions[:3]]))}</p>
                </div>
                """
                st.markdown(quiz_card_html, unsafe_allow_html=True)
                
                # Add button for quiz selection
                if st.button(f"🚀 Start {quiz['title']}", key=f"start_{quiz['id']}", type="primary", use_container_width=True):
                    st.session_state.current_quiz = quiz
                    st.session_state.responses = {}
                    st.session_state.current_question_index = 0
                    st.session_state.quiz_completed = False
                    st.balloons()
                    time.sleep(0.5)
                    st.rerun()
    else:
        st.markdown("""
        <div style="text-align: center; padding: 4rem 2rem;">
            <h2>🎭 No Quizzes Available Yet!</h2>
            <p style="font-size: 1.2rem; color: #6b7280; margin: 2rem 0;">
                Ask your teacher to create some fun quizzes for you!
            </p>
            <p style="font-size: 1rem; color: #9ca3af;">
                📚 Check back soon for exciting self-assessment opportunities!
            </p>
        </div>
        """, unsafe_allow_html=True)

# Student name input
elif st.session_state.current_quiz and not st.session_state.quiz_started:
    st.markdown("## 👋 Welcome to the Quiz!")
    st.markdown(f"**Quiz:** {st.session_state.current_quiz['title']}")
    
    col1, col2, col3 = st.columns([1, 2, 1])
    with col2:
        st.markdown("""
        <div class="question-container" style="text-align: center;">
            <h3>🌟 Tell us about yourself!</h3>
            <p>We'd love to know your name to personalize your experience.</p>
        </div>
        """, unsafe_allow_html=True)
        
        student_name = st.text_input(
            "✨ What's your name?", 
            placeholder="Enter your awesome name here...",
            value=st.session_state.student_name
        )
        
        if student_name:
            st.session_state.student_name = student_name
            
            col1_btn, col2_btn, col3_btn = st.columns([1, 2, 1])
            with col2_btn:
                if st.button("🎉 Start My Quiz Adventure!", type="primary", use_container_width=True):
                    st.session_state.quiz_started = True
                    st.balloons()
                    st.rerun()

# Quiz taking interface
elif st.session_state.quiz_started and not st.session_state.quiz_completed:
    quiz_data = st.session_state.current_quiz['data']
    current_q_index = st.session_state.current_question_index
    total_questions = len(quiz_data)
    
    # Progress bar
    progress = (current_q_index) / total_questions
    st.markdown(f"""
    <div style="margin: 2rem 0;">
        <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 0.5rem;">
            <span style="font-weight: 600; color: #374151;">Progress</span>
            <span style="font-weight: 600; color: #667eea;">{current_q_index}/{total_questions} Questions</span>
        </div>
        <div class="progress-bar-container">
            <div class="progress-bar" style="width: {progress * 100}%;"></div>
        </div>
    </div>
    """, unsafe_allow_html=True)
    
    if current_q_index < total_questions:
        current_question = quiz_data[current_q_index]
        
        # Question display
        st.markdown(f"""
        <div class="question-container">
            <h3 style="color: #1f2937; margin-bottom: 1rem; font-size: 1.5rem;">
                Question {current_q_index + 1} of {total_questions}
            </h3>
            <p style="font-size: 1.3rem; line-height: 1.6; color: #374151; margin-bottom: 2rem;">
                {current_question['question_text']}
            </p>
            <div style="display: flex; justify-content: space-between; align-items: center; padding: 1rem; background: #f3f4f6; border-radius: 10px;">
                <span style="font-size: 0.9rem; color: #6b7280;">📊 {current_question['dimension'].title()}</span>
                <span style="font-size: 0.9rem; color: #6b7280;">🎯 {current_question['subdimension'].title()}</span>
            </div>
        </div>
        """, unsafe_allow_html=True)
        
        # Likert scale with emojis
        st.markdown("### 🎚️ How much do you agree?")
        
        scale_options = [
            {"value": 1, "emoji": "😟", "label": "Strongly Disagree"},
            {"value": 2, "emoji": "🙁", "label": "Disagree"},
            {"value": 3, "emoji": "😐", "label": "Neutral"},
            {"value": 4, "emoji": "🙂", "label": "Agree"},
            {"value": 5, "emoji": "😍", "label": "Strongly Agree"}
        ]
        
        response = None
        cols = st.columns(5)
        for i, option in enumerate(scale_options):
            with cols[i]:
                if st.button(
                    f"{option['emoji']}\n{option['value']}\n{option['label']}", 
                    key=f"response_{current_q_index}_{option['value']}",
                    use_container_width=True
                ):
                    response = option['value']
                    st.session_state.responses[current_question['question_id']] = response
                    
                    # Show emoji reaction
                    st.markdown(f'<div class="emoji-reaction">{option["emoji"]}</div>', unsafe_allow_html=True)
                    
                    # Auto-advance to next question after a short delay
                    time.sleep(0.5)
                    if current_q_index + 1 < total_questions:
                        st.session_state.current_question_index += 1
                    else:
                        st.session_state.quiz_completed = True
                    st.rerun()
        
        # Navigation buttons
        col1, col2, col3 = st.columns([1, 2, 1])
        with col1:
            if current_q_index > 0:
                if st.button("⬅️ Previous", use_container_width=True):
                    st.session_state.current_question_index -= 1
                    st.rerun()
        
        with col3:
            if current_question['question_id'] in st.session_state.responses:
                if current_q_index + 1 < total_questions:
                    if st.button("Next ➡️", use_container_width=True, type="primary"):
                        st.session_state.current_question_index += 1
                        st.rerun()
                else:
                    if st.button("🏁 Finish Quiz!", use_container_width=True, type="primary"):
                        st.session_state.quiz_completed = True
                        st.rerun()

# Results screen
elif st.session_state.quiz_completed:
    # Show celebration animation
    if not st.session_state.show_celebration:
        st.balloons()
        st.session_state.show_celebration = True
    
    st.markdown("""
    <div style="text-align: center; margin: 2rem 0;">
        <h1 style="font-size: 3rem; margin-bottom: 1rem;">🎉 Congratulations!</h1>
        <p style="font-size: 1.3rem; color: #6b7280;">You've completed the quiz! Here are your amazing results:</p>
    </div>
    """, unsafe_allow_html=True)
    
    # Calculate scores
    quiz_data = st.session_state.current_quiz['data']
    dimension_scores = {}
    dimension_counts = {}
    
    for question in quiz_data:
        dimension = question['dimension']
        if question['question_id'] in st.session_state.responses:
            if dimension not in dimension_scores:
                dimension_scores[dimension] = 0
                dimension_counts[dimension] = 0
            dimension_scores[dimension] += st.session_state.responses[question['question_id']]
            dimension_counts[dimension] += 1
    
    # Calculate averages
    avg_scores = {}
    for dim, total in dimension_scores.items():
        avg_scores[dim] = total / dimension_counts[dim] if dimension_counts[dim] > 0 else 0
    
    # Display results with charts
    if avg_scores:
        col1, col2 = st.columns(2)
        
        with col1:
            # Radar chart
            categories = list(avg_scores.keys())
            values = list(avg_scores.values())
            
            fig = go.Figure()
            fig.add_trace(go.Scatterpolar(
                r=values,
                theta=categories,
                fill='toself',
                name=st.session_state.student_name,
                line_color='rgb(102, 126, 234)',
                fillcolor='rgba(102, 126, 234, 0.3)'
            ))
            
            fig.update_layout(
                polar=dict(
                    radialaxis=dict(
                        visible=True,
                        range=[0, 5]
                    )),
                showlegend=True,
                title="🎯 Your Skill Profile",
                height=400
            )
            
            st.plotly_chart(fig, use_container_width=True)
        
        with col2:
            # Bar chart
            fig_bar = px.bar(
                x=categories,
                y=values,
                title="📊 Your Scores by Dimension",
                color=values,
                color_continuous_scale="viridis",
                height=400
            )
            fig_bar.update_layout(
                xaxis_title="Dimensions",
                yaxis_title="Average Score",
                showlegend=False
            )
            st.plotly_chart(fig_bar, use_container_width=True)
        
        # Score cards
        st.markdown("### 🏆 Detailed Results")
        cols = st.columns(len(avg_scores))
        for i, (dimension, score) in enumerate(avg_scores.items()):
            with cols[i]:
                # Determine emoji based on score
                if score >= 4.5:
                    emoji = "🌟"
                    level = "Expert"
                elif score >= 4:
                    emoji = "🚀"
                    level = "Advanced"
                elif score >= 3:
                    emoji = "💪"
                    level = "Proficient"
                elif score >= 2:
                    emoji = "📈"
                    level = "Developing"
                else:
                    emoji = "🌱"
                    level = "Beginner"
                
                st.markdown(f"""
                <div class="score-card">
                    <div style="font-size: 2rem; margin-bottom: 1rem;">{emoji}</div>
                    <h3 style="margin: 0 0 0.5rem 0; font-size: 1.2rem;">{dimension.title()}</h3>
                    <div style="font-size: 2rem; font-weight: bold; margin: 1rem 0;">{score:.1f}/5</div>
                    <div style="font-size: 1rem; opacity: 0.9;">{level}</div>
                </div>
                """, unsafe_allow_html=True)
    
    # Save responses
    if storage and st.session_state.responses:
        try:
            storage.save_responses(
                st.session_state.current_quiz['id'],
                st.session_state.student_name,
                st.session_state.responses,
                avg_scores
            )
            st.success("✅ Your responses have been saved!")
        except Exception as e:
            st.error(f"❌ Error saving responses: {str(e)}")
    
    # Action buttons
    col1, col2, col3 = st.columns(3)
    
    with col1:
        if st.button("🔄 Take Another Quiz", use_container_width=True, type="primary"):
            st.session_state.current_quiz = None
            st.session_state.responses = {}
            st.session_state.current_question_index = 0
            st.session_state.quiz_completed = False
            st.session_state.quiz_started = False
            st.session_state.show_celebration = False
            st.rerun()
    
    with col2:
        if st.button("🏠 Back to Home", use_container_width=True):
            st.session_state.current_quiz = None
            st.session_state.responses = {}
            st.session_state.current_question_index = 0
            st.session_state.quiz_completed = False
            st.session_state.quiz_started = False
            st.session_state.show_celebration = False
            st.rerun()
    
    with col3:
        # Download results
        results_data = {
            "Student": st.session_state.student_name,
            "Quiz": st.session_state.current_quiz['title'],
            "Completed": datetime.now().isoformat(),
            "Scores": avg_scores,
            "Responses": st.session_state.responses
        }
        
        st.download_button(
            label="📥 Download Results",
            data=json.dumps(results_data, indent=2),
            file_name=f"quiz_results_{st.session_state.student_name}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json",
            mime="application/json",
            use_container_width=True
        )
