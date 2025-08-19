import { Component, OnInit } from '@angular/core';
import dayGridPlugin from '@fullcalendar/daygrid';
import { QuizService, Quiz } from '../services/quiz.service';

@Component({
  selector: 'app-calendar',
  templateUrl: './calendar.component.html',
  styleUrls: ['./calendar.component.css']
})
export class CalendarComponent implements OnInit {
  calendarOptions: any = {
    plugins: [dayGridPlugin],
    initialView: 'dayGridMonth',
    events: [], 
    locale: 'fr',
  };

  constructor(private quizService: QuizService) {}

  ngOnInit() {
    this.loadQuizzes();
  }

  loadQuizzes() {
    this.quizService.getQuizzes().subscribe({
      next: (quizzes: Quiz[]) => {
        this.calendarOptions.events = quizzes.map(q => ({
          title: q.nameQuiz,
          date: q.dateCreation,
        }));
      },
      error: (err) => {
        console.error('Erreur chargement des quiz', err);
      }
    });
  }
}
