import { Injectable } from '@angular/core';
import { initializeApp } from 'firebase/app';
import { getFirestore, collection, getDocs, doc, getDoc } from 'firebase/firestore';
import { environment } from '../../environments/environment';
import { User } from './user.service'; 

export interface Avatar {
  id: string;
  image_avatar: string;
  user_id?: string;
  userName?: string; 

}

@Injectable({ providedIn: 'root' })
export class AvatarService {
  private db;

  constructor() {
    const app = initializeApp(environment.firebase);
    this.db = getFirestore(app);
  }

  async getAvatars(): Promise<Avatar[]> {
    const avatarsCol = collection(this.db, 'avatars');
    const avatarSnapshot = await getDocs(avatarsCol);

    const avatarsWithUser: Avatar[] = [];

    for (const docSnap of avatarSnapshot.docs) {
      const avatarData = { id: docSnap.id, ...docSnap.data() } as Avatar;

      if (avatarData.user_id) {
        const userDoc = await getDoc(doc(this.db, 'users', avatarData.user_id));
        if (userDoc.exists()) {
          const userData = userDoc.data() as User;
          avatarData.userName = `${userData.firstname || ''} ${userData.lastname || ''}`;
        }
      }

      avatarsWithUser.push(avatarData);
    }

    return avatarsWithUser;
  }
}
