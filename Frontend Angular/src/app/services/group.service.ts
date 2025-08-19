import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';

export interface Group {
  idGroup?: string;
  groupName: string;
  className?: string; // Nouveau champ
  accessible?: boolean; // 👈 Nouveau champ ajouté
  members: string[];
}

@Injectable({
  providedIn: 'root'
})
export class GroupService {
  private apiUrl = 'http://127.0.0.1:8000/groups';

  constructor(private http: HttpClient) {}

  getGroups(): Observable<Group[]> {
    return this.http.get<Group[]>(this.apiUrl);
  }

  createGroup(group: Group): Observable<Group> {
    return this.http.post<Group>(this.apiUrl, group);
  }

  deleteGroup(id: string): Observable<any> {
    return this.http.delete(`${this.apiUrl}/${id}`);
  }

  addMember(id: string, memberName: string): Observable<Group> {
    return this.http.post<Group>(`${this.apiUrl}/${id}/add_member`, null, {
      params: { member_name: memberName }
    });
  }

  removeMember(id: string, memberName: string): Observable<Group> {
    return this.http.post<Group>(`${this.apiUrl}/${id}/remove_member`, null, {
      params: { member_name: memberName }
    });
  }
  toggleAccess(id: string): Observable<Group> {
  return this.http.post<Group>(`${this.apiUrl}/${id}/toggle_access`, {});
}
// Modifier le service pour gérer accessibilité par classe
setClassAccess(className: string, accessible: boolean): Observable<any> {
  return this.http.post(`${this.apiUrl}/class_access`, { className, accessible });
}

}
