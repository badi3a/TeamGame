# Final Datasets

## Overview
Balanced, production-ready dataset for the Gamified Student Clustering Platform. This dataset has been cleaned, balanced, and optimized for ML training and assessment generation.

## Dataset: All Questions.csv

### Structure
```csv
question_id,dimension,subdimension,question_text,target_year_level
sa_001,creativity,innovation_problem_solving,How confident are you in innovation problem solving?,1
ss_001,soft_skills,critical_thinking,How confident are you in critical thinking?,1
tw_001,teamwork,communication_documentation,How confident are you in facilitating team meetings?,2
hs_001,hard_skills,programming_languages,How confident are you in implementing microservices architecture?,1
```

### Key Features
- **🎯 Balanced Distribution**: 220 questions per dimension (880 total)
- **📊 Perfect Balance**: 25% per dimension (creativity, soft_skills, teamwork, hard_skills)  
- **🏷️ Clean Format**: No response_scale column - all questions use standard 1-5 Likert scale
- **✅ High Quality**: Grammar-corrected, duplicate-free questions
- **🎓 Year-Level Coverage**: Questions distributed across Years 1-3

### Distribution
```
creativity: 220 questions (25.0%)
soft_skills: 220 questions (25.0%)  
teamwork: 220 questions (25.0%)
hard_skills: 220 questions (25.0%)
Total: 880 questions
```

### Question ID Format
- `sa_XXX`: Creativity (Self-Assessment)
- `ss_XXX`: Soft Skills  
- `tw_XXX`: Teamwork
- `hs_XXX`: Hard Skills

### Subdimensions

#### Creativity (220 questions)
- innovation_problem_solving: Creative problem-solving and innovative thinking
- algorithm_design: Creative algorithm development and optimization
- creative_thinking: Abstract thinking and idea generation
- system_architecture: Innovative system and architecture design
- ux_design: User experience and interface creativity
- artistic_creativity: Technical creativity with aesthetic elements

#### Soft Skills (220 questions)
- critical_thinking: Analysis, evaluation, and logical reasoning
- adaptability_learning: Flexibility and continuous learning
- emotional_intelligence: Self-awareness, empathy, and social skills
- leadership: Team leadership and decision-making
- time_management: Organization and prioritization
- communication_skills: Verbal, written, and presentation skills
- problem_solving: Analytical problem-solving approaches
- decision_making: Decision processes and judgment
- stress_management: Coping and resilience strategies
- self_motivation: Drive and personal motivation
- public_speaking: Presentation and speaking confidence
- networking: Professional relationship building
- active_listening: Communication and listening skills
- empathy: Understanding and relating to others
- analytical_thinking: Data analysis and logical thinking
- creativity_thinking: Creative and innovative thinking
- strategic_planning: Planning and strategic thinking

#### Teamwork (220 questions)
- communication_documentation: Team communication and documentation
- code_review_collaboration: Collaborative code development
- project_coordination: Project management and coordination
- mentoring_teaching: Knowledge sharing and mentoring
- cross_functional_work: Multi-disciplinary collaboration
- remote_collaboration: Virtual team collaboration
- conflict_mediation: Conflict resolution and mediation
- team_leadership: Leading and guiding teams
- peer_feedback: Giving and receiving feedback
- knowledge_sharing: Information and skill sharing
- cultural_sensitivity: Cross-cultural collaboration
- meeting_facilitation: Meeting leadership and facilitation
- consensus_building: Building agreement and consensus
- delegation: Task assignment and delegation
- team_building: Team cohesion and relationship building
- collaborative_planning: Joint planning and strategy
- group_problem_solving: Collective problem-solving

#### Hard Skills (220 questions)
- programming_languages: Programming proficiency and coding
- database_management: Database design and administration
- web_development: Web application development
- mobile_development: Mobile app development
- data_structures_algorithms: Core CS concepts and algorithms
- software_testing: Testing methodologies and QA
- version_control: Git and version management
- api_development: API design and development
- cloud_computing: Cloud platforms and services
- cybersecurity: Security principles and implementation
- machine_learning: ML algorithms and implementation
- artificial_intelligence: AI concepts and applications
- blockchain: Blockchain technology and applications
- microservices: Microservices architecture and development
- containerization: Docker and container technologies
- monitoring_logging: System monitoring and logging
- performance_optimization: Performance tuning and optimization

## Usage

### Data Science / ML
```python
import pandas as pd

# Load balanced dataset
df = pd.read_csv('All Questions.csv')

# Quick analysis
print(f"Total questions: {len(df)}")
print(f"Dimensions: {df['dimension'].value_counts()}")
print(f"Year levels: {df['target_year_level'].value_counts().sort_index()}")

# Filter by dimension
creativity_questions = df[df['dimension'] == 'creativity']
teamwork_questions = df[df['dimension'] == 'teamwork']
```

### LLM Integration
The dataset is now compatible with the question generation service:
- No response_scale column required
- Standardized Likert scale format (1-5)
- Clean question text for RAG context
- Balanced distribution for fair training

### Assessment Generation
```python
# All questions use standard 1-5 Likert scale:
# 1 = Strongly Disagree
# 2 = Disagree  
# 3 = Neutral
# 4 = Agree
# 5 = Strongly Agree
```

## Data Quality
- ✅ **Balanced**: Equal representation across all dimensions
- ✅ **Clean**: Grammar-corrected and duplicate-free
- ✅ **Consistent**: Standardized format and structure
- ✅ **Complete**: No missing values or malformed entries
- ✅ **Validated**: All questions follow proper Likert scale format

## Changes from Previous Version
1. **Balanced Distribution**: Fixed severe imbalance (was 950:111:70:33, now 220:220:220:220)
2. **Removed response_scale**: Simplified to 5 columns, standard 1-5 scale assumed
3. **Grammar Fixes**: Corrected malformed questions and grammar issues
4. **Duplicate Removal**: Eliminated redundant and duplicate questions
5. **Format Standardization**: Consistent question formats and structures

## Backup
Original unbalanced dataset backed up as `All Questions - Original.csv`
