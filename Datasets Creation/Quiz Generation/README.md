# Quiz Generation Dataset

## Overview
This directory provides a streamlined CSV of 150 self-assessment questions spanning creativity, teamwork, soft skills, and hard skills. Each item includes a 5-point Likert scale response and targets academic levels 1–3, ready for retrieval-augmented generation with LLMs.

## Folder Structure
```
Quiz Generation/
├── README.md                # Project documentation and instructions
├── questions.csv            # 150 self-assessment items (1–5 Likert scale)
```

## Quick Start (Data Scientists)
```python
import pandas as pd

# Load the self-assessment questions
questions = pd.read_csv('questions.csv')

# Basic validation
assert len(questions) == 150, "Expected 150 self-assessment items"
print("✅ Questions loaded successfully")
print(questions.head())
```

## Data Schema
Each record in `questions.csv` contains:
- **question_id**: Unique identifier (e.g., `sa_001`)
- **dimension**: One of `creativity`, `teamwork`, `soft_skills`, `hard_skills`
- **subdimension**: Specific category within the dimension
- **question_text**: Self-assessment prompt text
- **target_year_level**: Integer (1–3) indicating academic year level
- **response_scale**: Always `1-5` (Likert scale: 1=Strongly Disagree ... 5=Strongly Agree)
