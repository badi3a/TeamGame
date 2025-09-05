# Datasets

## Overview
Clean, production-ready datasets for the Gamified Student Clustering Platform. Designed by data scientists for data scientists - optimized for pandas, scikit-learn, and ML pipelines.

## Structure
```
Datasets/
├── Quiz Generation/          # Legacy assessment dataset (160 questions)
│   ├── taxonomy.csv          # 4 dimensions × 21 subcategories (21 rows)
│   ├── questions.csv         # 160 realistic university scenarios (160 rows)  
│   ├── rubrics.csv           # Year-appropriate scoring standards (6 rows)
│   ├── features_template.csv # ML feature columns (32 features)
│   ├── scoring_guide.md      # Mathematical methodology
│   ├── validate_data.py      # Data integrity validation script
│   └── README.md            # Detailed data science documentation
└── Final Datasets/          # ✨ PRODUCTION DATASET (880 questions)
    ├── All Questions.csv     # Balanced, cleaned, production-ready dataset
    ├── balance_and_fix_dataset.py  # Dataset balancing script
    ├── dataset_stats.py      # Analysis and statistics script
    └── README.md            # Production dataset documentation
```

## 🎯 RECOMMENDED: Final Datasets
**Use `Final Datasets/All Questions.csv` for production and ML training.**

### Key Features
- **🎯 Perfect Balance**: 220 questions per dimension (880 total)
- **📊 25% Distribution**: creativity, soft_skills, teamwork, hard_skills
- **✅ High Quality**: Grammar-corrected, duplicate-free
- **🏷️ Clean Format**: 5 columns, no response_scale needed
- **🎓 Year Coverage**: Questions for Years 1-3

### Quick Start (Production)
```python
import pandas as pd

# Load production dataset
df = pd.read_csv('Final Datasets/All Questions.csv')

# Verify perfect balance
print(f"Total questions: {len(df)}")  # 880
distribution = df['dimension'].value_counts()
print(f"Distribution: {distribution}")  # All 220 each

# Standard columns
print(f"Columns: {list(df.columns)}")
# ['question_id', 'dimension', 'subdimension', 'question_text', 'target_year_level']

# All questions use 1-5 Likert scale (no response_scale column needed)
```

## Use Cases
- **LLM Quiz Generation**: Train language models to create assessment questions
- **Student Clustering**: Form optimal teams based on complementary skills  
- **Academic Research**: Analyze collaboration patterns in software engineering education
- **Learning Analytics**: Track student development across multiple dimensions