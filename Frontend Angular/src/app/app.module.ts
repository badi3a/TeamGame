import { NgModule } from '@angular/core';
import { BrowserModule } from '@angular/platform-browser';
import { AppRoutingModule } from './app-routing.module';
import { AppComponent } from './app.component';
import { AccueilComponent } from './accueil/accueil.component';
import { GroupesComponent } from './groupes/groupes.component';
import { LoginComponent } from './User/login/login.component';
import { InscriptionComponent } from './User/inscription/inscription.component';
import { FormsModule } from '@angular/forms';
import { ProfilComponent } from './User/profil/profil.component';
import { CalendarComponent } from './calendar/calendar.component';
import { HttpClientModule } from '@angular/common/http';
import { ReactiveFormsModule } from '@angular/forms';
import { provideFirebaseApp, initializeApp } from '@angular/fire/app';
import { provideAuth, getAuth } from '@angular/fire/auth';
import { provideAnalytics, getAnalytics } from '@angular/fire/analytics';
import { environment } from '../environments/environment';
import { ForgetPasswordComponent } from './User/forget-password/forget-password.component';
import { StudentImportComponent } from './student-import/student-import.component';
import { QuizDashboardComponent } from './quiz-dashboard/quiz-dashboard.component';
import { ChatbotComponent } from './chatbot/chatbot.component';
import { FullCalendarModule } from '@fullcalendar/angular'; 
import dayGridPlugin from '@fullcalendar/daygrid';
import { AvatarListComponent } from './avatar-list/avatar-list.component';


@NgModule({
  declarations: [
    AppComponent,
    AccueilComponent,
    GroupesComponent,
    LoginComponent,
    InscriptionComponent,
    ProfilComponent,
    CalendarComponent,
    ForgetPasswordComponent,
    StudentImportComponent,
    QuizDashboardComponent,
    ChatbotComponent,
    AvatarListComponent,
  
  ],
  imports: [
    BrowserModule,
    AppRoutingModule,
    FormsModule,
    ReactiveFormsModule,
    HttpClientModule,
    FullCalendarModule,
    provideFirebaseApp(() => initializeApp(environment.firebase)),
    provideAnalytics(() => getAnalytics()),
    provideAuth(() => getAuth()),
  ],
  providers: [],
  bootstrap: [AppComponent]
})
export class AppModule { }
