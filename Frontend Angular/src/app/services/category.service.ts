import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';

export interface Category {
  idCategory?: string;
  island: string;
  subcategories: string[];
}

@Injectable({
  providedIn: 'root',
})
export class CategoryService {
  private apiUrl = 'http://localhost:8000/categories';

  constructor(private http: HttpClient) {}

  getCategories(): Observable<Category[]> {
    return this.http.get<Category[]>(this.apiUrl);
  }
  
  addCategory(category: Category): Observable<Category> {
    return this.http.post<Category>(this.apiUrl, category);
  }

  deleteCategory(idCategory: string): Observable<void> {
    return this.http.delete<void>(`${this.apiUrl}/${idCategory}`);
  }

  addSubcategory(idCategory: string, subcategory: string): Observable<{ detail: string }> {
    return this.http.post<{ detail: string }>(
      `${this.apiUrl}/${idCategory}/subcategories`,
      subcategory,
      { headers: { 'Content-Type': 'text/plain' } }
    );
  }
  
  editSubcategory(idCategory: string, oldSub: string, newSub: string): Observable<{ detail: string }> {
    return this.http.put<{ detail: string }>(
      `${this.apiUrl}/${idCategory}/subcategories/${oldSub}`,
      newSub,
      { headers: { 'Content-Type': 'text/plain' } }
    );
  }

  deleteSubcategory(idCategory: string, subcategory: string): Observable<{ detail: string }> {
    return this.http.delete<{ detail: string }>(`${this.apiUrl}/${idCategory}/subcategories/${subcategory}`);
  }

  getAll(): Observable<Category[]> {
    return this.http.get<Category[]>(this.apiUrl);
  }
}