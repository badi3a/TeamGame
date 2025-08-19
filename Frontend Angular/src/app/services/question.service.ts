import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';

export interface Question {
  idQuestion?: string;
  content: string;
  idQuiz: string;
  idCategory: string;
}

export interface QuestionGenerateRequest {
  idQuiz: string;
  idCategory: string;
  subdimension?: string;
  target_year_level: number;
}

export interface QuestionGenerateResponse {
  question: Question;
  generation_metadata: any;
}

export interface CategoryQuestionsRequest {
  idQuiz: string;
  idCategory: string;
  num_questions: number;
  target_year_level: number;
}

export interface CategoryQuestionsResponse {
  questions: Question[];
  generation_metadata: any;
}

export interface FullQuizRequest {
  idQuiz: string;
  total_questions: number;
  target_year_level: number;
}

export interface FullQuizResponse {
  questions: Question[];
  generation_metadata: any;
}

@Injectable({
  providedIn: 'root',
})
export class QuestionService {
  private apiUrl = 'http://localhost:8000/questions';

  constructor(private http: HttpClient) {}

  getAll(): Observable<Question[]> {
    return this.http.get<Question[]>(this.apiUrl);
  }

  getById(id: string): Observable<Question> {
    return this.http.get<Question>(`${this.apiUrl}/${id}`);
  }

  getByQuiz(quizId: string): Observable<Question[]> {
    return this.http.get<Question[]>(`${this.apiUrl}/by_quiz/${quizId}`);
  }

  search(keyword: string): Observable<Question[]> {
    return this.http.get<Question[]>(`${this.apiUrl}/search/?keyword=${keyword}`);
  }

  add(question: Question): Observable<Question> {
    return this.http.post<Question>(this.apiUrl, question);
  }

  update(id: string, question: Question): Observable<Question> {
    return this.http.put<Question>(`${this.apiUrl}/${id}`, question);
  }

  delete(id: string): Observable<any> {
    return this.http.delete(`${this.apiUrl}/${id}`);
  }

  // IA
  generateQuestion(data: QuestionGenerateRequest): Observable<QuestionGenerateResponse> {
    return this.http.post<QuestionGenerateResponse>(`${this.apiUrl}/generate`, data);
  }

  generateCategoryQuestions(data: CategoryQuestionsRequest): Observable<CategoryQuestionsResponse> {
    return this.http.post<CategoryQuestionsResponse>(`${this.apiUrl}/generate-category`, data);
  }

  generateFullQuiz(data: FullQuizRequest): Observable<FullQuizResponse> {
    return this.http.post<FullQuizResponse>(`${this.apiUrl}/generate-full-quiz`, data);
  }

  // Dimensions
  getDimensions(): Observable<{ dimensions: string[] }> {
    return this.http.get<{ dimensions: string[] }>(`${this.apiUrl}/dimensions`);
  }

  getSubdimensions(dimension: string): Observable<{ subdimensions: string[], dimension: string }> {
    return this.http.get<{ subdimensions: string[], dimension: string }>(
      `${this.apiUrl}/subdimensions/${dimension}`
    );
  }
}
