import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';

@Injectable({ providedIn: 'root' })
export class PasswordResetService {
  private baseUrl = 'http://127.0.0.1:8001/api';

  constructor(private http: HttpClient) {}

  forgotPassword(email: string): Observable<any> {
    return this.http.post(`${this.baseUrl}/forgot-password`, { email });
  }

  verifyCode(email: string, code: string): Observable<any> {
    return this.http.post(`${this.baseUrl}/verify-reset-code`, { email, code });
  }

  resetPassword(email: string, password: string): Observable<any> {
    return this.http.post(`${this.baseUrl}/reset-password`, { email, password });
  }
}
