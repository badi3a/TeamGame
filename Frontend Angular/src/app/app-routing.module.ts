import { NgModule } from '@angular/core';
import { RouterModule, Routes } from '@angular/router';
import { AccueilComponent } from './accueil/accueil.component';
import { GroupesComponent } from './groupes/groupes.component';
import { LoginComponent } from './User/login/login.component';
import { InscriptionComponent } from './User/inscription/inscription.component';
import { ProfilComponent } from './User/profil/profil.component';
import { CalendarComponent } from './calendar/calendar.component';
import { AuthGuard } from './guards/auth.guard';
import { ForgetPasswordComponent } from './User/forget-password/forget-password.component';
import { StudentImportComponent } from './student-import/student-import.component';
import { QuizDashboardComponent } from './quiz-dashboard/quiz-dashboard.component';
import { ChatbotComponent } from './chatbot/chatbot.component';
import { AvatarListComponent } from './avatar-list/avatar-list.component'; 

const routes: Routes = [
  { path: '', redirectTo: 'accueil', pathMatch: 'full' },
  { path: 'accueil', component: AccueilComponent , canActivate: [AuthGuard] },
  { path: 'groupes', component: GroupesComponent , canActivate: [AuthGuard]},
  { path: 'login', component: LoginComponent },
  { path: 'inscription', component: InscriptionComponent },
  { path: 'profil', component: ProfilComponent , canActivate: [AuthGuard]},
  { path: 'Calendar', component: CalendarComponent , canActivate: [AuthGuard]},
  { path: 'forget-password', component: ForgetPasswordComponent },
  { path: 'StudentImport', component: StudentImportComponent ,canActivate: [AuthGuard]},
  { path: 'quizDashboard', component: QuizDashboardComponent ,canActivate: [AuthGuard]},
  { path: 'Chatbot', component: ChatbotComponent ,canActivate: [AuthGuard]},
  { path: 'avatar-list', component: AvatarListComponent ,canActivate: [AuthGuard]},
];

@NgModule({
  imports: [RouterModule.forRoot(routes)],
  exports: [RouterModule]
})
export class AppRoutingModule { }
