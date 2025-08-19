import { HttpClient } from '@angular/common/http';
import { Injectable } from '@angular/core';
import { Observable } from 'rxjs';

export interface ClusterResponse {
  algorithm: string;
  score: number;
  group_size: number;
  group_counts: any;
  groups: Record<string, any[]>;
}

@Injectable({
  providedIn: 'root'
})
export class ClusterService {
  private apiUrl = 'http://127.0.0.1:8000/cluster';

  constructor(private http: HttpClient) {}

  uploadCsv(file: File, groupSize: number, className: string): Observable<ClusterResponse> {
    const form = new FormData();
    form.append('file', file, file.name);
    form.append('group_size', String(groupSize));
    form.append('class_name', className ?? ''); // évite undefined/null

    return this.http.post<ClusterResponse>(this.apiUrl, form);
  }
}
