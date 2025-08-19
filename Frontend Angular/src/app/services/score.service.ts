// src/app/services/score.service.ts
import { Injectable } from '@angular/core';
import { initializeApp } from 'firebase/app';
import { getFirestore, collection, query, where, getDocs } from 'firebase/firestore';
import { environment } from '../../environments/environment';

export interface Score {
  idScore: string;
  idQuiz: string;
  idUser: string;
  island_position?: string; 
  scoreCategory1: number;
  scoreCategory2: number;
  scoreCategory3: number;
  scoreCategory4: number;
  totalScore: number;
  quizName?: string; 
}


@Injectable({ providedIn: 'root' })
export class ScoreService {
  private db;

  constructor() {
    const app = initializeApp(environment.firebase);
    this.db = getFirestore(app);
  }

  async getScoresByUser(userId: string): Promise<Score[]> {
    const scoresCol = collection(this.db, 'scores');
    const q = query(scoresCol, where('idUser', '==', userId));
    const snapshot = await getDocs(q);

    return snapshot.docs.map(doc => ({
      idScore: doc.id,
      ...doc.data()
    })) as Score[];
  }
}
