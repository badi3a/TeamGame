import { Injectable } from '@angular/core';
import { HttpClient, HttpErrorResponse } from '@angular/common/http';
import { Observable, of } from 'rxjs';
import { catchError, map } from 'rxjs/operators';

export interface User {
  email?: string;
  firstname?: string;
  lastname?: string;
  address?: string;
  city?: string;
  country?: string;
  avatarUrl?: string;
  sexe?: string;
  photoBase64?: string;
  dateOfBirth?: string;   
  phoneNumber?: string;
  biography?: string;
}


@Injectable({
  providedIn: 'root',
})
export class UserService {
  private apiUrl = 'http://127.0.0.1:8001/api';

  constructor(private http: HttpClient) {}

 register(user: any): Observable<any> {
  return this.http.post(`${this.apiUrl}/register`, user);
}
login(credentials: { email: string; password: string }): Observable<any> {
  return this.http.post(`${this.apiUrl}/login`, credentials);
}
updateProfile(user: User): Observable<any> {
  return this.http.put(`${this.apiUrl}/update-profile`, user);
}
registerGoogleUser(userData: any) {
  return this.http.post('http://127.0.0.1:8001/api/register-google', userData);
}
 updateUserPhoto(email: string, photoBase64: string): Observable<any> {
    return this.http.post(`${this.apiUrl}/user/update-photo`, { email, photoBase64 });
  }

getClasses(): Observable<string[]> {
  return this.http.get<string[]>('http://127.0.0.1:8001/api/classes');
}

getStudentsByClass(classe: string): Observable<any[]> {
  return this.http.get<any[]>(`http://127.0.0.1:8001/api/class/${classe}/students`);
}
addStudent(student: any): Observable<any> {
  return this.http.post(`${this.apiUrl}/students`, student);
}

updateStudent(email: string, data: any): Observable<any> {
  return this.http.put(`${this.apiUrl}/students/${email}`, data);
}


deleteStudent(email: string): Observable<any> {
  return this.http.delete(`${this.apiUrl}/students/${email}`);
}
deleteClass(classe: string): Observable<any> {
  return this.http.delete(`${this.apiUrl}/class/${classe}`);
}

getGenderStatistics(): Observable<{ malePercent: number; femalePercent: number }> {
    return this.http.get<{ malePercent: number; femalePercent: number }>(`${this.apiUrl}/gender-statistics`).pipe(
      map(response => ({
        malePercent: response.malePercent ?? 0,
        femalePercent: response.femalePercent ?? 0
      })),
      catchError(this.handleError<{ malePercent: number; femalePercent: number }>('getGenderStatistics', { malePercent: 0, femalePercent: 0 }))
    );
  }

  getPendingQuizzesCount(email: string): Observable<{ count: number }> {
    return this.http.get<{ count: number }>(`${this.apiUrl}/pending-quizzes-count?email=${encodeURIComponent(email)}`).pipe(
      catchError(this.handleError<{ count: number }>('getPendingQuizzesCount', { count: 0 }))
    );
  }

  getCompletedQuizzesCount(email: string): Observable<{ count: number }> {
    return this.http.get<{ count: number }>(`${this.apiUrl}/completed-quizzes-count?email=${encodeURIComponent(email)}`).pipe(
      catchError(this.handleError<{ count: number }>('getCompletedQuizzesCount', { count: 0 }))
    );
  }

  getCategoryStatistics(): Observable<any[]> {
    return this.http.get<any[]>(`${this.apiUrl}/category-statistics`).pipe(
      catchError(this.handleError<any[]>('getCategoryStatistics', [['Category', 'Question Count'], ['No Data', 0]]))
    );
  }

 getCompletedQuizNames(email: string): Observable<string[]> {
    return this.http.get<{ names: string[] }>(`${this.apiUrl}/completed-quiz-names?email=${encodeURIComponent(email)}`, {
      headers: { 'Origin': 'http://localhost:4200' }
    }).pipe(
      map(response => {
        console.log('Completed quiz names API response:', response);
        return response.names || [];
      }),
      catchError((error: HttpErrorResponse) => {
        console.error('Completed quiz names error:', error.message);
        return of([]);
      })
    );
  }

  private handleError<T>(operation = 'operation', result?: T) {
    return (error: any): Observable<T> => {
      console.error(`${operation} failed: ${error.message}`);
      return of(result as T);
    };
  }

  
}
