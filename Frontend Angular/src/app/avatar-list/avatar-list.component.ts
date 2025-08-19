import { Component, OnInit } from '@angular/core';
import { AvatarService, Avatar } from '../services/avatar.service';
import { ScoreService, Score } from '../services/score.service';
import { QuizService, Quiz } from '../services/quiz.service';
import { BadgeService, Badge } from '../services/badge.service';
import { firstValueFrom } from 'rxjs';

interface UserBadgeGroup {
  userName: string;
  badges: Badge[];
}

type AvatarWithExtras = Avatar & {
  scores?: Score[];
  showDetails: boolean;
  showBadges: boolean; 
};

@Component({
  selector: 'app-avatar-list',
  templateUrl: './avatar-list.component.html',
  styleUrls: ['./avatar-list.component.css']
})
export class AvatarListComponent implements OnInit {
  avatars: AvatarWithExtras[] = [];
  quizzesMap: Map<string, string> = new Map();
  userBadgeGroups: UserBadgeGroup[] = [];
selectedClass: string | null = null;

  islandGroups: { [key: string]: AvatarWithExtras[] } = {
    'Island 1': [],
    'Island 2': [],
    'Island 3': [],
    'Island 4': []
  };

  selectedIslandName: string | null = null;
  selectedIslandStudents: AvatarWithExtras[] = [];

  constructor(
    private avatarService: AvatarService,
    private scoreService: ScoreService,
    private quizService: QuizService,
    private badgeService: BadgeService
  ) {}

  async ngOnInit() {
    // Badges
    this.badgeService.getAllBadgesWithUser().then(data => {
      this.userBadgeGroups = this.groupByUser(data);
    });

    // Avatars
    this.avatars = (await this.avatarService.getAvatars()).map(a => ({
      ...a,
      showDetails: false,
      showBadges: false 
    }));

    // Quizzes
    const quizzes: Quiz[] = await firstValueFrom(this.quizService.getQuizzes());
    quizzes.forEach(q => this.quizzesMap.set(q.idQuiz!, q.nameQuiz));

    // Scores + répartition îles
    for (const avatar of this.avatars) {
      if (avatar.user_id) {
        avatar.scores = await this.scoreService.getScoresByUser(avatar.user_id);
        avatar.scores.forEach(score => {
          score.quizName = this.quizzesMap.get(score.idQuiz) || 'Nom du quiz non trouvé';
        });

        // Déterminer l'île
        if (avatar.scores.length > 0 && avatar.scores[0].island_position) {
          const islandName = this.normalizeIslandName(avatar.scores[0].island_position);
          if (this.islandGroups[islandName]) {
            this.islandGroups[islandName].push(avatar);
          }
        }
      } else {
        avatar.scores = [];
      }
    }
  }

  private normalizeIslandName(name: string): string {
    const lower = name.trim().toLowerCase();
    if (lower.includes('1')) return 'Island 1';
    if (lower.includes('2')) return 'Island 2';
    if (lower.includes('3')) return 'Island 3';
    if (lower.includes('4')) return 'Island 4';
    return 'Island 1';
  }

  private groupByUser(badges: Badge[]): UserBadgeGroup[] {
    const grouped: { [key: string]: Badge[] } = {};
    badges.forEach(badge => {
      const key = badge.userId || 'inconnu';
      if (!grouped[key]) {
        grouped[key] = [];
      }
      grouped[key].push(badge);
    });
    return Object.keys(grouped).map(userId => ({
      userName: grouped[userId][0].userName || 'Utilisateur inconnu',
      badges: grouped[userId]
    }));
  }

  toggleDetails(avatar: AvatarWithExtras) {
    avatar.showDetails = !avatar.showDetails;
  }

  toggleBadges(avatar: AvatarWithExtras) {
    avatar.showBadges = !avatar.showBadges;
  }

  getIslandDisplayName(key: string): string {
    switch (key) {
      case 'Island 1': return 'Creativity';
      case 'Island 2': return 'Teamwork';
      case 'Island 3': return 'Hard Skills';
      case 'Island 4': return 'Soft Skills';
      default: return key;
    }
  }

  getProgressColor(avatar: any): string {
    const progress = this.getProgress(avatar);
    const ratio = progress / 5;
    const r = Math.round(255 - (255 * ratio));
    const g = Math.round(0 + (200 * ratio));
    return `rgb(${r},${g},0)`;
  }

  getIslandImageFile(key: string): string {
    switch (key) {
      case 'Island 1': return 'island1.jpg';
      case 'Island 2': return 'island2.jpg';
      case 'Island 3': return 'island3.jpg';
      case 'Island 4': return 'island4.jpg';
      default: return 'default.jpg';
    }
  }

  getUserBadges(userName?: string) {
    if (!userName) return [];
    const group = this.userBadgeGroups.find(g => g.userName === userName);
    return group ? group.badges : [];
  }

  getProgress(avatar: AvatarWithExtras): number {
    if (!avatar.scores || avatar.scores.length === 0) return 0;
    return avatar.scores[0]?.totalScore || 0;
  }

  openIslandPopup(islandName: string) {
    this.selectedIslandName = this.getIslandDisplayName(islandName);
    this.selectedIslandStudents = this.islandGroups[islandName] || [];
  }

  closeIslandPopup() {
    this.selectedIslandName = null;
    this.selectedIslandStudents = [];
  }
  
selectedStudent: AvatarWithExtras | null = null;

openStudentPopup(avatar: AvatarWithExtras) {
  this.selectedStudent = avatar;
}

closeStudentPopup() {
  this.selectedStudent = null;
}

  
}
