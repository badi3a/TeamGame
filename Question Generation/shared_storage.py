import os
import json
from datetime import datetime
import stat

class QuizStorage:
    def __init__(self):
        self.storage_dir = "quiz_storage"
        self.quizzes_file = os.path.join(self.storage_dir, "generated_quizzes.json")
        self.responses_file = os.path.join(self.storage_dir, "student_responses.json")
        self._ensure_storage_exists()
    
    def _ensure_storage_exists(self):
        """Create storage directory and files if they don't exist"""
        try:
            if not os.path.exists(self.storage_dir):
                os.makedirs(self.storage_dir)
                # Set permissions to be writable
                os.chmod(self.storage_dir, stat.S_IRWXU | stat.S_IRWXG | stat.S_IRWXO)
            
            if not os.path.exists(self.quizzes_file):
                with open(self.quizzes_file, 'w') as f:
                    json.dump([], f)
                os.chmod(self.quizzes_file, stat.S_IRWXU | stat.S_IRWXG | stat.S_IRWXO)
            
            if not os.path.exists(self.responses_file):
                with open(self.responses_file, 'w') as f:
                    json.dump([], f)
                os.chmod(self.responses_file, stat.S_IRWXU | stat.S_IRWXG | stat.S_IRWXO)
                
        except Exception as e:
            raise Exception(f"Failed to create storage: {str(e)}")
    
    def save_quiz(self, quiz_data, quiz_title="Untitled Quiz"):
        """Save a generated quiz"""
        try:
            quiz_record = {
                "id": f"quiz_{int(datetime.now().timestamp())}",
                "title": quiz_title,
                "created_at": datetime.now().isoformat(),
                "data": quiz_data
            }
            
            # Read existing quizzes
            try:
                with open(self.quizzes_file, 'r') as f:
                    quizzes = json.load(f)
            except (FileNotFoundError, json.JSONDecodeError):
                quizzes = []
            
            quizzes.append(quiz_record)
            
            # Write back with error handling
            with open(self.quizzes_file, 'w') as f:
                json.dump(quizzes, f, indent=2)
            
            return quiz_record["id"]
            
        except Exception as e:
            raise Exception(f"Failed to save quiz: {str(e)}")
    
    def get_all_quizzes(self):
        """Get all saved quizzes"""
        try:
            with open(self.quizzes_file, 'r') as f:
                return json.load(f)
        except (FileNotFoundError, json.JSONDecodeError):
            return []
        except Exception as e:
            raise Exception(f"Failed to load quizzes: {str(e)}")
    
    def get_quiz_by_id(self, quiz_id):
        """Get a specific quiz by ID"""
        try:
            quizzes = self.get_all_quizzes()
            for quiz in quizzes:
                if quiz["id"] == quiz_id:
                    return quiz
            return None
        except Exception as e:
            raise Exception(f"Failed to get quiz: {str(e)}")
    
    def save_responses(self, quiz_id, student_name, responses, scores):
        """Save student responses"""
        try:
            response_record = {
                "quiz_id": quiz_id,
                "student_name": student_name,
                "submitted_at": datetime.now().isoformat(),
                "responses": responses,
                "scores": scores
            }
            
            # Read existing responses
            try:
                with open(self.responses_file, 'r') as f:
                    all_responses = json.load(f)
            except (FileNotFoundError, json.JSONDecodeError):
                all_responses = []
            
            all_responses.append(response_record)
            
            # Write back with error handling
            with open(self.responses_file, 'w') as f:
                json.dump(all_responses, f, indent=2)
                
        except Exception as e:
            raise Exception(f"Failed to save responses: {str(e)}")
    
    def get_responses_for_quiz(self, quiz_id):
        """Get all responses for a specific quiz"""
        try:
            with open(self.responses_file, 'r') as f:
                all_responses = json.load(f)
            
            return [r for r in all_responses if r["quiz_id"] == quiz_id]
            
        except (FileNotFoundError, json.JSONDecodeError):
            return []
        except Exception as e:
            raise Exception(f"Failed to get responses: {str(e)}")
