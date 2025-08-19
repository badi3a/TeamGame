import { Injectable } from '@angular/core';
import { initializeApp } from 'firebase/app';
import { getFirestore, collection, getDocs, doc, getDoc } from 'firebase/firestore';
import { environment } from '../../environments/environment';

export interface Badge {
  color: string;
  description: string;
  icon: string;
  name: string;
  userId: string;
  userName?: string;
  score: number;
  earnedAt: string;
  earnedTimestamp: number;
  quizName?: string;
  categoryIsland?: string;
  idQuiz: string;
  categoryId: string;
}

@Injectable({ providedIn: 'root' })
export class BadgeService {
  private db;

  constructor() {
    const app = initializeApp(environment.firebase);
    this.db = getFirestore(app);
  }

async getAllBadgesWithUser(): Promise<Badge[]> {
  const badgesCol = collection(this.db, 'badges');
  const badgeSnapshot = await getDocs(badgesCol);

  const allBadges: Badge[] = [];

  for (const docSnap of badgeSnapshot.docs) {
    const docData = docSnap.data() as any;
    const badgesArray = docData.badges || [];

    for (const badge of badgesArray) {
      const userId = badge.userId || docData.userId || '';
      const quizId = badge.quizId || docData.quizId || '';
      const categoryId = badge.categoryId || docData.categoryId || '';

      // Nom utilisateur
      let userName = '';
      if (userId) {
        const userDoc = await getDoc(doc(this.db, 'users', userId));
        if (userDoc.exists()) {
          const userData = userDoc.data();
          userName = `${userData['firstname'] || ''} ${userData['lastname'] || ''}`.trim();
        }
      }

      // Nom quiz
      let quizName = '';
      if (quizId) {
        const quizDoc = await getDoc(doc(this.db, 'quizzes', quizId));
        if (quizDoc.exists()) {
          quizName = quizDoc.data()['nameQuiz'] || '';
        }
      }

      // Nom île
      let categoryIsland = '';
      if (categoryId) {
        const categoryDoc = await getDoc(doc(this.db, 'categories', categoryId));
        if (categoryDoc.exists()) {
          categoryIsland = categoryDoc.data()['island'] || '';
        }
      }

      // Date
      let earnedAtFormatted = '';
      if (badge.earnedAt?.toDate) {
        earnedAtFormatted = badge.earnedAt.toDate().toLocaleString();
      } else if (badge.earnedTimestamp) {
        earnedAtFormatted = new Date(badge.earnedTimestamp * 1000).toLocaleString();
      } else if (docData.earnedTimestamp) {
        earnedAtFormatted = new Date(docData.earnedTimestamp * 1000).toLocaleString();
      }

      allBadges.push({
        color: badge.color || '',
        description: badge.description || '',
        icon: badge.icon || '',
        name: badge.name || '',
        userId,
        userName,
        score: badge.score ?? docData.score ?? 0,
        earnedAt: earnedAtFormatted,
        earnedTimestamp: badge.earnedTimestamp || docData.earnedTimestamp || 0,
        quizName,
        categoryIsland,
        idQuiz: quizId,
        categoryId
      });
    }
  }

  return allBadges;
}

}
