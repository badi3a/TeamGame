import { Component, OnInit } from '@angular/core';
import { Category, CategoryService } from '../services/category.service';
import { Quiz, QuizService } from '../services/quiz.service';
import { Question, QuestionService } from '../services/question.service';

@Component({
  selector: 'app-quiz-dashboard',
  templateUrl: './quiz-dashboard.component.html',
  styleUrls: ['./quiz-dashboard.component.css']
})
export class QuizDashboardComponent implements OnInit {
 aiMode: 'one' | 'category' | 'full' | null = null;

  categories: Category[] = [];
  newCategoryIsland = '';
  newSubcategory: { [key: string]: string } = {};
  editSubcategory: { [key: string]: { old: string, new: string } } = {};
  selectedCategoryId: string | null = null;
  
  filterCategory: string = '';
  filterAccessible: string | boolean = '';
  filterDate: string = '';
  filterName: string = '';

  quizzes: Quiz[] = [];
  newQuiz: Quiz = {
    idTeacher: '',             
    idCategory: [],
    dateCreation: new Date().toISOString(),
    isAccessible: true,
    accessCode: '',
    nameQuiz: '' 
  };
   editingQuizId: string | null = null;

  questions: Question[] = [];
  newQuestion: Question = { content: '', idQuiz: '', idCategory: '' };
  editingQuestionId: string | null = null;
  quizNames: string[] = [];
  
  filterQuestionQuiz: string = '';
  filterQuestionCategory: string = '';

 //Recherche et génération intelligente
 keyword: string = '';
 dimensions: string[] = [];
 subdimensions: string[] = [];
 selectedDimension: string = '';
 selectedSubdimension: string = '';
 targetYear: number = 1;
 totalQuestions: number = 8;

 popupMessage: string | null = null;
 popupConfirmAction: (() => void) | null = null;


  constructor(
    private categoryService: CategoryService,
    private quizService: QuizService,
    private questionService: QuestionService,
  ) {}

  ngOnInit() {
    this.loadAll();
    this.loadQuizNames(); 
  }


  showPopup(message: string): void {
  this.popupMessage = message;
  this.popupConfirmAction = null;

  setTimeout(() => {
    if (!this.popupConfirmAction) this.popupMessage = null;
  }, 3000);
  }

  loadAll() {
    this.loadCategories();
    this.loadQuizzes();
    this.loadQuestions();
    this.loadDimensions(); 
  }

  toggleAccessibility(quiz: any) {
  quiz.isAccessible = !quiz.isAccessible;
  if (this.editingQuizId !== quiz.idQuiz) {
    this.editingQuizId = quiz.idQuiz;
    this.newQuiz = { ...quiz }; 
    this.updateQuiz();
    this.editingQuizId = null; 
  }
  }

  filteredQuizzes(): Quiz[] {
  return this.quizzes.filter(quiz => {
    const matchName = !this.filterName || quiz.nameQuiz.toLowerCase().includes(this.filterName.toLowerCase());

    const matchCategory = !this.filterCategory ||
      quiz.idCategory.some(catId =>
        this.getCategoryNames([catId]).toLowerCase().includes(this.filterCategory.toLowerCase())
      );

    const matchAccessible = this.filterAccessible === '' ||
      quiz.isAccessible === (this.filterAccessible === 'true' || this.filterAccessible === true);

    const matchDate = !this.filterDate ||
      new Date(quiz.dateCreation).toISOString().split('T')[0] === this.filterDate;

    return matchName && matchCategory && matchAccessible && matchDate;
  });
  }

 filteredQuestions(): Question[] {
  return this.questions.filter(q => {
    const matchQuiz = !this.filterQuestionQuiz || this.getQuizName(q.idQuiz).toLowerCase().includes(this.filterQuestionQuiz.toLowerCase());
    const matchCategory = !this.filterQuestionCategory || this.getCategoryName(q.idCategory).toLowerCase().includes(this.filterQuestionCategory.toLowerCase());
    return matchQuiz && matchCategory;
  });
 }

  loadCategories() {
    this.categoryService.getCategories().subscribe(data => this.categories = data);
  }

  createCategory() {
    if (!this.newCategoryIsland.trim()) return;
    this.categoryService.addCategory({ island: this.newCategoryIsland, subcategories: [] }).subscribe(() => {
      this.newCategoryIsland = '';
      this.loadCategories();
      this.showPopup("Category added!");
    });
  }

  deleteCategory(id: string) {
    this.categoryService.deleteCategory(id).subscribe(() => {
      if (this.selectedCategoryId === id) {
        this.selectedCategoryId = null;
      }
      this.loadCategories();
      this.showPopup("Category deleted!");
    });
  }

  toggleSubcategories(idCategory: string) {
    this.selectedCategoryId = this.selectedCategoryId === idCategory ? null : idCategory;
  }

  addSubcategory(idCategory: string) {
    const sub = this.newSubcategory[idCategory];
    if (!sub || !sub.trim()) return;
    this.categoryService.addSubcategory(idCategory, sub).subscribe(() => {
      this.newSubcategory[idCategory] = '';
      this.loadCategories();
      this.showPopup("Subcategory added!");

    });
  }

  startEditSubcategory(idCategory: string, oldSub: string) {
    this.editSubcategory[idCategory] = { old: oldSub, new: oldSub };
  }

  saveEditSubcategory(idCategory: string) {
    const edit = this.editSubcategory[idCategory];
    if (!edit) return;
    this.categoryService.editSubcategory(idCategory, edit.old, edit.new).subscribe(() => {
      delete this.editSubcategory[idCategory];
      this.loadCategories();
      this.showPopup("Subcategory updated!");
    });
  }

  cancelEditSubcategory(idCategory: string) {
    delete this.editSubcategory[idCategory];
  }

  deleteSubcategory(idCategory: string, sub: string) {
    this.categoryService.deleteSubcategory(idCategory, sub).subscribe(() => this.loadCategories());
          this.showPopup("Subcategory deleted!");
  }

  getCategoryNames(ids: string[]): string {
    return ids
      .map(id => {
        const cat = this.categories.find(c => c.idCategory === id);
        return cat ? cat.island : 'Unknown category';
      })
      .join(', ');
  }

 loadQuizzes() {
  this.quizService.getQuizzes().subscribe(data => {
    this.quizzes = data;
    console.log('Quizzes loaded:', this.quizzes);
  }, error => {
    console.error('Error loading quizzes:', error);
  });
 }

  generateAccessCode(): string {
    const hex = Math.floor(Math.random() * 0xffffff).toString(16).toUpperCase();
    return hex.padStart(6, '0');
  }

  createQuiz() {
  const currentUser = JSON.parse(localStorage.getItem('user') || '{}');
  const idTeacher = currentUser.email || '';
  if (!idTeacher) {
    alert("User not connected or ID missing.");
    return;
  }
  if (!this.newQuiz.accessCode.trim()) {
    this.newQuiz.accessCode = this.generateAccessCode();
  }
  const quizToSend = {
    idTeacher: idTeacher,
    idCategory: [...this.newQuiz.idCategory],
    dateCreation: new Date().toISOString(),
    isAccessible: this.newQuiz.isAccessible,
    accessCode: this.newQuiz.accessCode.trim(),
    nameQuiz: this.newQuiz.nameQuiz.trim()
  };

  if (quizToSend.idCategory.length === 0) {
    this.showPopup("Select at least one category.");
    return;
  }
  if(!quizToSend.nameQuiz.trim()) {
    this.showPopup("Please enter the quiz name.");
    return;
  }
  if (quizToSend.nameQuiz.length > 50) {
    this.showPopup("Quiz name is too long (max 50 characters).");
    return;
  }
  if (quizToSend.accessCode.length > 6) {
    this.showPopup("Access code must be 6 characters long.");
    return;
  }
  if (quizToSend.idCategory.length === 0) {
    this.showPopup("Select at least one category.");
    return;
  }
  if (quizToSend.idCategory.length > 4) {
    this.showPopup("Limit reached: A quiz can't have more than 4 categories.");
    return;
  }
  while (quizToSend.idCategory.length < 4) {
    const lastCat = quizToSend.idCategory.length > 0
      ? quizToSend.idCategory[quizToSend.idCategory.length - 1]
      : "unknown";  
        const defaultCategories = ["creativity", "teamwork", "soft_skills", "hard_skills"];

    quizToSend.idCategory.push(lastCat);
  }
  this.quizService.createQuiz(quizToSend).subscribe(() => {
    this.newQuiz = {
      idTeacher: '',
      idCategory: [],
      dateCreation: new Date().toISOString(),
      isAccessible: true,
      accessCode: '',
      nameQuiz: ''
    };
    this.loadQuizzes();
    this.showPopup("Quiz created successfully!");
  }, err => {
    alert("Error creating quiz: " + err.message);
  });
 }

 getQuizName(idQuiz: string): string {
  if (!idQuiz) return 'ID quiz vide';
  const quiz = this.quizzes.find(q => q.idQuiz === idQuiz);
  if (!quiz) {
    console.warn(`Quiz with id "${idQuiz}" not found in the list.`);
    return 'Unknown quiz';
  }
  return quiz.nameQuiz;
 }

 editQuiz(quiz: Quiz) {
    this.newQuiz = { ...quiz };
    this.editingQuizId = quiz.idQuiz || null;
  }

  updateQuiz() {
    if (!this.editingQuizId) return;
    this.quizService.updateQuiz(this.editingQuizId, this.newQuiz).subscribe(() => {
      this.resetForm();
      this.loadQuizzes();
      this.showPopup("Quiz updated!");
    });
  }

  // ✅ Show a confirmation popup
  showConfirmation(message: string, onConfirm: () => void): void {
  this.popupMessage = message;
  this.popupConfirmAction = onConfirm;
  }

  deleteQuiz(id: string) {
  this.showConfirmation("Delete this quiz?", () => {
    this.quizService.deleteQuiz(id).subscribe({
      next: () => {
        this.loadQuizzes();
        this.popupConfirmAction = null;
        this.popupMessage = "Quiz deleted!";
        setTimeout(() => this.popupMessage = null, 3000);
      },
      error: () => {
        this.popupConfirmAction = null;
        this.popupMessage = "Error deleting quiz";
        setTimeout(() => this.popupMessage = null, 3000);
      }
    });
  });
 }
  resetForm() {
    this.newQuiz = {
      idTeacher: '',
      idCategory: [],
      dateCreation: new Date().toISOString(),
      isAccessible: true,
      accessCode: '',
      nameQuiz: ''
    };
    this.editingQuizId = null;
  }

 loadQuizNames() {
  this.quizService.getQuizNames().subscribe(names => {
    this.quizNames = names;
    console.log("List of quiz names:", this.quizNames);
  }, err => {
    console.error("Error loading quiz names", err);
  });
 }

  getQuizAccessCode(idQuiz: string): string {
    const quiz = this.quizzes.find(q => q.idQuiz === idQuiz);
    return quiz ? quiz.accessCode : 'Unknown quiz';
  }

  loadQuestions() {
    this.questionService.getAll().subscribe(data => this.questions = data);
  }

  addQuestion() {
  if (!this.newQuestion.idQuiz || !this.newQuestion.content.trim()) {
    this.showPopup("Content and quiz must be provided.");
    return;
  }

  if (!this.newQuestion.idCategory || this.newQuestion.idCategory.length === 0) {
    this.showPopup("Select at least one category.");
    return;
  }

  this.questionService.add(this.newQuestion).subscribe(() => {
    this.newQuestion = { content: '', idQuiz: '', idCategory: '' };
    this.loadQuestions();
    this.showPopup("Question added!");
  });
}
  editQuestion(question: Question) {
  this.editingQuestionId = question.idQuestion!;
  this.newQuestion = { ...question };
  }

  updateQuestion() {
  if (!this.editingQuestionId) return;
  if (!this.newQuestion.idQuiz || !this.newQuestion.content.trim()) {
    this.showPopup("Content and quiz must be provided.");
    return;
  }
  this.questionService.update(this.editingQuestionId, this.newQuestion).subscribe(() => {
    this.editingQuestionId = null;
    this.newQuestion = { content: '', idQuiz: '', idCategory: '' };
    this.loadQuestions();
    this.showPopup("Question updated!");

  });
 }

 cancelEdit() {
  this.editingQuestionId = null;
  this.newQuestion = { content: '', idQuiz: '', idCategory: '' };
 }

  deleteQuestion(id: string) {
    this.questionService.delete(id).subscribe(() => this.loadQuestions());
    this.showPopup("Question deleted!");
  }

  getCategoryName(idCategory: string): string {
    const cat = this.categories.find(c => c.idCategory === idCategory);
    return cat ? cat.island : 'Unknown category';
  }

  searchQuestions() {
   if (!this.keyword.trim()) return;
   this.questionService.search(this.keyword).subscribe(data => this.questions = data);
  }

  loadDimensions() {
   this.questionService.getDimensions().subscribe(d => this.dimensions = d.dimensions);
  }

  loadSubdimensions() {
  if (this.selectedDimension) {
    this.questionService.getSubdimensions(this.selectedDimension).subscribe(d => {
      this.subdimensions = d.subdimensions;
    });
  }
 }

 generateAIQuestion() {
  const req = {
    idQuiz: this.newQuestion.idQuiz,
    idCategory: this.newQuestion.idCategory,
    subdimension: this.selectedSubdimension,
    target_year_level: this.targetYear
  };
  this.questionService.generateQuestion(req).subscribe(res => {
     this.showPopup("Question generated: " + res.question.content);
    this.loadQuestions();
  });
 }

 generateCategoryQuestions() {
  const request = {
    idQuiz: this.newQuestion.idQuiz,
    idCategory: this.newQuestion.idCategory,
    num_questions: this.totalQuestions,
    target_year_level: this.targetYear
  };
  this.questionService.generateCategoryQuestions(request).subscribe(() => {
     this.showPopup("Questions generated!");
    this.loadQuestions();
  });
 }

 generateFullQuiz() {
  if (!this.newQuestion.idQuiz) {
     this.showPopup("You must select a quiz.");
    return;
  }

 const request = {
  idQuiz: this.newQuestion.idQuiz,
  total_questions: this.totalQuestions,
  target_year_level: this.targetYear
 };

  console.log("Request sent to /generate-full-quiz:", request);
  this.questionService.generateFullQuiz(request).subscribe({
    next: () => {
       this.showPopup("Quiz generated!");
      this.loadQuestions();
    },
    error: (err) => {
      console.error("Backend error:", err);

      const message = err.error?.detail || JSON.stringify(err.error) || 'Unknown error';
       this.showPopup("Error generating full quiz: " + message);
    }
  });
}
}
