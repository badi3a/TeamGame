#!/usr/bin/env python3
"""
Dataset Merging Script for All Questions.csv

This script merges new questions from "Our Datasets" folder into the main "All Questions.csv" file
while maintaining balanced dimensions and adding new subcategories.

Features:
- Maintains existing question ID format (sa_XXX)
- Balances dimensions across creativity, teamwork, soft_skills, hard_skills
- Adds new subcategories from merged datasets
- Preserves existing structure and features
- Handles both CSV and Excel input formats
- Generates comprehensive merge report
"""

import pandas as pd
import numpy as np
from pathlib import Path
import json
from collections import Counter, defaultdict
from datetime import datetime
import re
import openpyxl  # For Excel file handling

class DatasetMerger:
    def __init__(self, base_dir=None):
        # Auto-detect the correct path based on current working directory
        if base_dir is None:
            current_dir = Path.cwd()
            if "Datasets" in str(current_dir):
                # If we're already in Datasets folder or subfolder
                if current_dir.name == "Datasets":
                    self.base_dir = current_dir / "Final Datasets"
                elif current_dir.name == "Final Datasets":
                    self.base_dir = current_dir
                else:
                    # Look for Final Datasets in current or parent directories
                    self.base_dir = current_dir / "Final Datasets"
                    if not self.base_dir.exists():
                        self.base_dir = current_dir.parent / "Final Datasets"
            else:
                # Default fallback - look for Datasets folder
                datasets_path = current_dir / "Datasets" / "Final Datasets"
                if datasets_path.exists():
                    self.base_dir = datasets_path
                else:
                    self.base_dir = Path("Final Datasets")
        else:
            self.base_dir = Path(base_dir)
        
        self.all_questions_path = self.base_dir / "All Questions.csv"
        self.our_datasets_dir = self.base_dir / "Our Datasets"
        
        print(f"🔍 Working directory: {Path.cwd()}")
        print(f"📁 Base directory: {self.base_dir.absolute()}")
        print(f"📄 All Questions path: {self.all_questions_path.absolute()}")
        print(f"📂 Our Datasets path: {self.our_datasets_dir.absolute()}")
        
        # Load existing data
        self.existing_df = None
        self.new_datasets = {}
        self.merged_df = None
        
        # Tracking for balanced merging
        self.dimension_counts = {}
        self.next_question_id = 1
        
        # Category mapping for soft skills (since they don't have explicit dimensions)
        self.soft_skills_category_mapping = {
            'communication': 'soft_skills',
            'time_management': 'soft_skills', 
            'critical_thinking': 'soft_skills',
            'adaptability': 'soft_skills',
            'adaptability_learning': 'soft_skills',
            'presentation_communication': 'soft_skills',
            'leadership': 'teamwork',
            'teamwork': 'teamwork',
            'collaboration': 'teamwork',
            'conflict_resolution': 'teamwork',
            'problem_solving': 'creativity',
            'innovation': 'creativity',
            'creative_thinking': 'creativity',
            'design_thinking': 'creativity',
            'programming': 'hard_skills',
            'technical_skills': 'hard_skills',
            'database': 'hard_skills',
            'testing': 'hard_skills',
            'devops': 'hard_skills'
        }
        
    def load_existing_data(self):
        """Load the existing All Questions.csv file"""
        print(f"\n📂 Loading existing All Questions.csv from: {self.all_questions_path}")
        
        # Check if file exists
        if not self.all_questions_path.exists():
            print(f"❌ File not found: {self.all_questions_path}")
            print(f"🔍 Looking for alternative paths...")
            
            # Try alternative paths
            alternative_paths = [
                Path("Datasets/Final Datasets/All Questions.csv"),
                Path("Final Datasets/All Questions.csv"),
                Path("All Questions.csv"),
                Path.cwd() / "Datasets" / "Final Datasets" / "All Questions.csv"
            ]
            
            for alt_path in alternative_paths:
                print(f"   Checking: {alt_path.absolute()}")
                if alt_path.exists():
                    self.all_questions_path = alt_path
                    self.base_dir = alt_path.parent
                    self.our_datasets_dir = self.base_dir / "Our Datasets"
                    print(f"   ✅ Found at: {alt_path.absolute()}")
                    break
            else:
                print(f"❌ Could not find All Questions.csv in any expected location")
                return False
        
        try:
            # Read the CSV, skipping the comment line
            self.existing_df = pd.read_csv(self.all_questions_path, skiprows=1)
            
            # Clean column names
            self.existing_df.columns = self.existing_df.columns.str.strip()
            
            # Get current dimension distribution
            self.dimension_counts = self.existing_df['dimension'].value_counts().to_dict()
            
            # Get next question ID
            existing_ids = self.existing_df['question_id'].str.extract(r'sa_(\d+)')[0].astype(int)
            self.next_question_id = existing_ids.max() + 1
            
            print(f"✅ Loaded {len(self.existing_df)} existing questions")
            print(f"📊 Current dimension distribution: {self.dimension_counts}")
            print(f"🔢 Next question ID: sa_{self.next_question_id:03d}")
            
            return True
            
        except Exception as e:
            print(f"❌ Error loading existing data: {e}")
            return False
    
    def load_new_datasets(self):
        """Load all datasets from Our Datasets folder"""
        print(f"\n📁 Loading new datasets from: {self.our_datasets_dir.absolute()}")
        
        # Check if Our Datasets directory exists
        if not self.our_datasets_dir.exists():
            print(f"❌ Our Datasets directory not found: {self.our_datasets_dir}")
            print(f"🔍 Looking for alternative paths...")
            
            # Try alternative paths for Our Datasets
            alternative_dirs = [
                Path("Datasets/Final Datasets/Our Datasets"),
                Path("Final Datasets/Our Datasets"),
                Path("Our Datasets"),
                self.base_dir.parent / "Our Datasets" if self.base_dir.parent.exists() else None
            ]
            
            for alt_dir in alternative_dirs:
                if alt_dir and alt_dir.exists():
                    self.our_datasets_dir = alt_dir
                    print(f"   ✅ Found Our Datasets at: {alt_dir.absolute()}")
                    break
            else:
                print(f"❌ Could not find Our Datasets directory")
                return False
        
        dataset_files = list(self.our_datasets_dir.glob("*"))
        
        if not dataset_files:
            print(f"⚠️  No files found in Our Datasets directory")
            return False
        
        for file_path in dataset_files:
            if file_path.is_file():
                print(f"🔍 Processing: {file_path.name}")
                
                try:
                    if file_path.suffix.lower() == '.csv':
                        df = pd.read_csv(file_path)
                    elif file_path.suffix.lower() in ['.xlsx', '.xls']:
                        df = pd.read_excel(file_path)
                    else:
                        print(f"⚠️  Skipping unsupported file type: {file_path.name}")
                        continue
                    
                    # Clean column names
                    df.columns = df.columns.str.strip()
                    
                    self.new_datasets[file_path.name] = df
                    print(f"✅ Loaded {len(df)} questions from {file_path.name}")
                    print(f"   Columns: {list(df.columns)}")
                    
                except Exception as e:
                    print(f"❌ Error loading {file_path.name}: {e}")
        
        print(f"📈 Total new datasets loaded: {len(self.new_datasets)}")
        return len(self.new_datasets) > 0
    
    def standardize_question_format(self, question_text):
        """Convert questions to proper Likert scale format (I am/I can statements)"""
        question = question_text.strip()
        
        # If already in correct format, return as is
        if any(question.startswith(starter) for starter in ["I am", "I can", "I feel", "I have", "I consistently", "I effectively"]):
            return question
        
        # Convert "How confident are you..." format to "I am confident..."
        if question.startswith("How confident are you"):
            question = question.replace("How confident are you in", "I am confident in my ability to")
            question = question.replace("How confident are you with", "I am confident with")
            question = question.replace("?", ".")
        
        # Convert "How well do you..." format to "I can..."
        elif question.startswith("How well do you"):
            question = question.replace("How well do you perform", "I can effectively")
            question = question.replace("How well do you", "I can")
            question = question.replace("?", ".")
        
        # Convert "How often do you..." format to "I consistently..."
        elif question.startswith("How often do you"):
            question = question.replace("How often do you engage in", "I consistently engage in")
            question = question.replace("How often do you", "I consistently")
            question = question.replace("?", ".")
        
        # Convert "How comfortable are you..." format to "I feel comfortable..."
        elif question.startswith("How comfortable are you"):
            question = question.replace("How comfortable are you with", "I feel comfortable with")
            question = question.replace("How comfortable are you", "I feel comfortable")
            question = question.replace("?", ".")
        
        # Convert "How effectively can you..." format to "I can effectively..."
        elif question.startswith("How effectively can you"):
            question = question.replace("How effectively can you", "I can effectively")
            question = question.replace("?", ".")
        
        # For statements that don't start with "I", add appropriate prefix
        elif not question.startswith("I "):
            # Try to determine best prefix based on content
            if any(word in question.lower() for word in ["confident", "comfortable", "sure"]):
                question = f"I am {question.lower()}"
            elif any(word in question.lower() for word in ["able", "capability", "skill"]):
                question = f"I can {question.lower()}"
            else:
                question = f"I am confident in my ability to {question.lower()}"
        
        # Ensure proper punctuation
        if not question.endswith('.'):
            question = question.rstrip('?!') + '.'
        
        return question
    
    def map_category_to_dimension(self, category, file_name=""):
        """Map category/subcategory to appropriate dimension"""
        category_lower = category.lower()
        
        # Direct mapping first
        if category_lower in self.soft_skills_category_mapping:
            return self.soft_skills_category_mapping[category_lower]
        
        # Pattern-based mapping
        if any(keyword in category_lower for keyword in ['communication', 'time', 'critical', 'presentation', 'adapt']):
            return 'soft_skills'
        
        if any(keyword in category_lower for keyword in ['team', 'leadership', 'collaboration', 'conflict', 'agile']):
            return 'teamwork'
        
        if any(keyword in category_lower for keyword in ['creative', 'innovation', 'design', 'ux', 'algorithm']):
            return 'creativity'
        
        if any(keyword in category_lower for keyword in ['programming', 'database', 'devops', 'testing', 'technical']):
            return 'hard_skills'
        
        # File name-based fallback
        if 'creativity' in file_name.lower():
            return 'creativity'
        elif 'soft' in file_name.lower():
            return 'soft_skills'
        elif 'team' in file_name.lower():
            return 'teamwork'
        elif 'hard' in file_name.lower() or 'technical' in file_name.lower():
            return 'hard_skills'
        
        # Default fallback
        return 'soft_skills'
    
    def generate_question_id(self):
        """Generate next question ID in sa_XXX format"""
        question_id = f"sa_{self.next_question_id:03d}"
        self.next_question_id += 1
        return question_id
    
    def assign_year_level(self, dimension_counts_by_year, target_balance=True):
        """Assign year level to maintain balance"""
        if not target_balance:
            return np.random.choice([1, 2, 3])
        
        # Find year level with lowest count for this dimension
        min_count = min(dimension_counts_by_year.values())
        candidates = [year for year, count in dimension_counts_by_year.items() if count == min_count]
        
        return np.random.choice(candidates)
    
    def merge_datasets(self, balance_dimensions=True, balance_year_levels=True):
        """Merge all new datasets into existing data with balancing"""
        print(f"\n🔄 Starting dataset merge process...")
        print(f"   Balance dimensions: {balance_dimensions}")
        print(f"   Balance year levels: {balance_year_levels}")
        
        # Start with existing data
        self.merged_df = self.existing_df.copy()
        
        # Track counts for balancing
        dimension_year_counts = defaultdict(lambda: defaultdict(int))
        
        # Initialize counts from existing data
        for _, row in self.existing_df.iterrows():
            dimension_year_counts[row['dimension']][row['target_year_level']] += 1
        
        merge_report = {
            'datasets_processed': [],
            'questions_added': 0,
            'new_subcategories': set(),
            'dimension_distribution': {},
            'errors': []
        }
        
        # Process each new dataset
        for file_name, df in self.new_datasets.items():
            print(f"\n📝 Processing dataset: {file_name}")
            
            dataset_questions = []
            dataset_info = {
                'file_name': file_name,
                'original_count': len(df),
                'processed_count': 0,
                'skipped_count': 0,
                'new_subcategories': set()
            }
            
            for idx, row in df.iterrows():
                try:
                    # Determine question text column
                    question_col = None
                    if 'question' in df.columns:
                        question_col = 'question'
                    elif 'question_text' in df.columns:
                        question_col = 'question_text'
                    elif 'text' in df.columns:
                        question_col = 'text'
                    else:
                        # Use first column that looks like text
                        for col in df.columns:
                            if df[col].dtype == 'object' and len(str(row[col])) > 20:
                                question_col = col
                                break
                    
                    if not question_col:
                        dataset_info['skipped_count'] += 1
                        continue
                    
                    question_text = str(row[question_col]).strip()
                    if not question_text or question_text == 'nan':
                        dataset_info['skipped_count'] += 1
                        continue
                    
                    # Determine category/subdimension
                    subdimension = None
                    if 'category' in df.columns:
                        subdimension = str(row['category']).strip()
                    elif 'subcategory' in df.columns:
                        subdimension = str(row['subcategory']).strip()
                    elif 'subdimension' in df.columns:
                        subdimension = str(row['subdimension']).strip()
                    else:
                        # Extract from filename or use default
                        subdimension = file_name.replace('.csv', '').replace('.xlsx', '').replace('all_', '').replace('_questions', '')
                    
                    # Map to dimension
                    dimension = self.map_category_to_dimension(subdimension, file_name)
                    
                    # Standardize question format
                    standardized_question = self.standardize_question_format(question_text)
                    
                    # Assign year level
                    year_level = self.assign_year_level(dimension_year_counts[dimension], balance_year_levels)
                    
                    # Create new question entry
                    new_question = {
                        'question_id': self.generate_question_id(),
                        'dimension': dimension,
                        'subdimension': subdimension,
                        'question_text': standardized_question,
                        'target_year_level': year_level,
                        'response_scale': '1-5'
                    }
                    
                    dataset_questions.append(new_question)
                    
                    # Update counts
                    dimension_year_counts[dimension][year_level] += 1
                    self.dimension_counts[dimension] = self.dimension_counts.get(dimension, 0) + 1
                    
                    # Track new subcategories
                    existing_subdimensions = set(self.existing_df['subdimension'].unique())
                    if subdimension not in existing_subdimensions:
                        dataset_info['new_subcategories'].add(subdimension)
                        merge_report['new_subcategories'].add(subdimension)
                    
                    dataset_info['processed_count'] += 1
                    
                except Exception as e:
                    dataset_info['skipped_count'] += 1
                    merge_report['errors'].append(f"{file_name} row {idx}: {str(e)}")
            
            # Add questions from this dataset to merged dataframe
            if dataset_questions:
                new_df = pd.DataFrame(dataset_questions)
                self.merged_df = pd.concat([self.merged_df, new_df], ignore_index=True)
                merge_report['questions_added'] += len(dataset_questions)
            
            dataset_info['new_subcategories'] = list(dataset_info['new_subcategories'])
            merge_report['datasets_processed'].append(dataset_info)
            
            print(f"   ✅ Processed: {dataset_info['processed_count']}")
            print(f"   ⚠️  Skipped: {dataset_info['skipped_count']}")
            print(f"   🆕 New subcategories: {len(dataset_info['new_subcategories'])}")
        
        # Final dimension distribution
        merge_report['dimension_distribution'] = self.merged_df['dimension'].value_counts().to_dict()
        merge_report['new_subcategories'] = list(merge_report['new_subcategories'])
        
        print(f"\n📊 MERGE COMPLETE!")
        print(f"   Total questions added: {merge_report['questions_added']}")
        print(f"   New subcategories: {len(merge_report['new_subcategories'])}")
        print(f"   Final dataset size: {len(self.merged_df)}")
        print(f"   Final dimension distribution: {merge_report['dimension_distribution']}")
        
        return merge_report
    
    def balance_dimensions(self, target_questions_per_dimension=None):
        """Balance dimensions by sampling or duplicating questions"""
        print(f"\n⚖️  Balancing dimensions...")
        
        current_counts = self.merged_df['dimension'].value_counts()
        print(f"Current distribution: {current_counts.to_dict()}")
        
        if target_questions_per_dimension is None:
            target_questions_per_dimension = current_counts.max()
        
        print(f"Target questions per dimension: {target_questions_per_dimension}")
        
        balanced_dfs = []
        
        for dimension in ['creativity', 'teamwork', 'soft_skills', 'hard_skills']:
            dimension_df = self.merged_df[self.merged_df['dimension'] == dimension].copy()
            current_count = len(dimension_df)
            
            if current_count == 0:
                print(f"⚠️  No questions found for dimension: {dimension}")
                continue
            
            if current_count < target_questions_per_dimension:
                # Need to duplicate some questions
                needed = target_questions_per_dimension - current_count
                print(f"📈 {dimension}: Adding {needed} questions (current: {current_count})")
                
                # Sample with replacement
                additional = dimension_df.sample(n=needed, replace=True, random_state=42).copy()
                
                # Update question IDs for duplicates
                for idx, row in additional.iterrows():
                    additional.loc[idx, 'question_id'] = self.generate_question_id()
                
                dimension_df = pd.concat([dimension_df, additional], ignore_index=True)
                
            elif current_count > target_questions_per_dimension:
                # Need to sample down
                print(f"📉 {dimension}: Sampling down to {target_questions_per_dimension} (current: {current_count})")
                dimension_df = dimension_df.sample(n=target_questions_per_dimension, random_state=42)
            
            balanced_dfs.append(dimension_df)
        
        # Combine balanced dataframes
        self.merged_df = pd.concat(balanced_dfs, ignore_index=True)
        
        # Update dimension counts
        final_counts = self.merged_df['dimension'].value_counts()
        print(f"✅ Balanced distribution: {final_counts.to_dict()}")
        
        return final_counts.to_dict()
    
    def save_merged_dataset(self, output_path=None, create_backup=True):
        """Save the merged dataset to CSV"""
        if output_path is None:
            output_path = self.all_questions_path
        
        print(f"\n💾 Saving merged dataset...")
        
        # Create backup of original if requested
        if create_backup and output_path == self.all_questions_path:
            backup_path = self.all_questions_path.with_suffix('.backup.csv')
            if self.all_questions_path.exists():
                self.all_questions_path.replace(backup_path)
                print(f"📄 Backup created: {backup_path}")
        
        try:
            # Prepare the final dataframe with proper formatting
            output_df = self.merged_df.copy()
            
            # Ensure proper column order
            column_order = ['question_id', 'dimension', 'subdimension', 'question_text', 'target_year_level', 'response_scale']
            output_df = output_df[column_order]
            
            # Sort by question_id
            output_df['id_num'] = output_df['question_id'].str.extract(r'sa_(\d+)')[0].astype(int)
            output_df = output_df.sort_values('id_num').drop('id_num', axis=1)
            
            # Save with comment header
            with open(output_path, 'w', newline='', encoding='utf-8') as f:
                f.write("# 1=Strongly Disagree;2=Disagree;3=Neutral;4=Agree;5=Strongly Agree\n")
                output_df.to_csv(f, index=False)
            
            print(f"✅ Merged dataset saved: {output_path}")
            print(f"📊 Total questions: {len(output_df)}")
            
            return True
            
        except Exception as e:
            print(f"❌ Error saving dataset: {e}")
            return False
    
    def generate_report(self, merge_report, output_dir=None):
        """Generate comprehensive merge report"""
        if output_dir is None:
            output_dir = self.base_dir
        
        report = {
            'merge_timestamp': datetime.now().isoformat(),
            'summary': {
                'total_existing_questions': len(self.existing_df),
                'total_new_questions': merge_report['questions_added'],
                'total_final_questions': len(self.merged_df),
                'datasets_processed': len(merge_report['datasets_processed']),
                'new_subcategories_added': len(merge_report['new_subcategories'])
            },
            'dimension_analysis': {
                'original_distribution': self.existing_df['dimension'].value_counts().to_dict(),
                'final_distribution': merge_report['dimension_distribution'],
                'balance_achieved': len(set(merge_report['dimension_distribution'].values())) == 1
            },
            'new_subcategories': merge_report['new_subcategories'],
            'dataset_details': merge_report['datasets_processed'],
            'errors': merge_report['errors']
        }
        
        # Save JSON report
        report_path = Path(output_dir) / f"merge_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
        with open(report_path, 'w', encoding='utf-8') as f:
            json.dump(report, f, indent=2, ensure_ascii=False)
        
        # Print summary
        print(f"\n📋 MERGE REPORT SUMMARY")
        print("=" * 50)
        print(f"📊 Original questions: {report['summary']['total_existing_questions']}")
        print(f"➕ New questions added: {report['summary']['total_new_questions']}")
        print(f"📈 Final total: {report['summary']['total_final_questions']}")
        print(f"📁 Datasets processed: {report['summary']['datasets_processed']}")
        print(f"🆕 New subcategories: {report['summary']['new_subcategories_added']}")
        
        if report['new_subcategories']:
            print(f"\n🏷️  NEW SUBCATEGORIES ADDED:")
            for subcategory in report['new_subcategories']:
                print(f"   • {subcategory}")
        
        if report['errors']:
            print(f"\n⚠️  ERRORS ENCOUNTERED: {len(report['errors'])}")
            for error in report['errors'][:5]:  # Show first 5
                print(f"   • {error}")
            if len(report['errors']) > 5:
                print(f"   ... and {len(report['errors']) - 5} more (see full report)")
        
        print(f"\n📄 Full report saved: {report_path}")
        
        return report


def main():
    """Main execution function"""
    print("🚀 DATASET MERGING TOOL")
    print("=" * 60)
    
    # Initialize merger
    merger = DatasetMerger()
    
    # Load existing data
    if not merger.load_existing_data():
        print("❌ Failed to load existing data. Exiting.")
        return
    
    # Load new datasets
    if not merger.load_new_datasets():
        print("❌ No new datasets found to merge. Exiting.")
        return
    
    # Perform merge
    merge_report = merger.merge_datasets(
        balance_dimensions=True,
        balance_year_levels=True
    )
    
    # Balance dimensions (optional - uncomment if you want equal distribution)
    # merger.balance_dimensions()
    
    # Save merged dataset
    success = merger.save_merged_dataset(create_backup=True)
    
    if success:
        # Generate comprehensive report
        merger.generate_report(merge_report)
        print("\n🎉 MERGE COMPLETED SUCCESSFULLY!")
    else:
        print("\n❌ MERGE FAILED!")


if __name__ == "__main__":
    main()
