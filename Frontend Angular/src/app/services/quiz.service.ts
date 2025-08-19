// src/app/services/quiz.service.ts
import { HttpClient } from '@angular/common/http';
import { Injectable } from '@angular/core';
import { Observable } from 'rxjs';

export interface Quiz {
  idQuiz?: string;
  idTeacher: string;
  idCategory: string[];
  dateCreation: string;
  isAccessible: boolean;
  accessCode: string;
  nameQuiz: string; 
}

@Injectable({
  providedIn: 'root',
})
export class QuizService {
  private apiUrl = 'http://127.0.0.1:8000/quizzes';

  constructor(private http: HttpClient) {}

  getQuizzes(): Observable<Quiz[]> {
    return this.http.get<Quiz[]>(this.apiUrl);
  }

  getQuiz(id: string): Observable<Quiz> {
    return this.http.get<Quiz>(`${this.apiUrl}/${id}`);
  }

  createQuiz(quiz: Quiz): Observable<Quiz> {
    return this.http.post<Quiz>(this.apiUrl, quiz);
  }

  updateQuiz(id: string, quiz: Quiz): Observable<Quiz> {
    return this.http.put<Quiz>(`${this.apiUrl}/${id}`, quiz);
  }

  deleteQuiz(id: string): Observable<any> {
    return this.http.delete(`${this.apiUrl}/${id}`);
  }  
  getQuizNames(): Observable<string[]> {
  return this.http.get<string[]>(`${this.apiUrl}/names/`);
}

}
