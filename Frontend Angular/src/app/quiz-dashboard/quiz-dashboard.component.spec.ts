import { ComponentFixture, TestBed } from '@angular/core/testing';

import { QuizDashboardComponent } from './quiz-dashboard.component';

describe('QuizDashboardComponent', () => {
  let component: QuizDashboardComponent;
  let fixture: ComponentFixture<QuizDashboardComponent>;

  beforeEach(() => {
    TestBed.configureTestingModule({
      declarations: [QuizDashboardComponent]
    });
    fixture = TestBed.createComponent(QuizDashboardComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
