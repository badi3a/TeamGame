import { Component, OnInit, AfterViewInit, OnDestroy, ChangeDetectorRef } from '@angular/core';
import { UserService } from '../services/user.service';
import Chart from 'chart.js/auto';

declare var google: any;

@Component({
  selector: 'app-accueil',
  templateUrl: './accueil.component.html',
  styleUrls: ['./accueil.component.css']
})
export class AccueilComponent implements OnInit, AfterViewInit, OnDestroy {
  categoryStats: any[] = [['Category', 'Question Count'], ['No Data', 0]];
  genderStats: { malePercent: number; femalePercent: number } | null = null;
  pendingQuizzesCount: number | null = null;
  completedQuizzesCount: number | null = null;
  groupCount: number = 2;
  error: string | null = null;
  userName: string = '';
  userEmail: string = '';
  genderChart: Chart | undefined;
  activeTab: string = 'all';
  tasks: { text: string; completed: boolean }[] = [
    { text: 'Grade Web Development quizzes', completed: false },
    { text: 'Prepare Python lecture notes', completed: true },
    { text: 'Review Angular group project', completed: false }
  ];
  filteredTasks: { text: string; completed: boolean }[] = this.tasks;
  completedQuizNames: string[] = [];

  constructor(private userService: UserService, private changeDetector: ChangeDetectorRef) {}

  ngOnInit(): void {
    const userData = localStorage.getItem('user');
    if (userData) {
      const user = JSON.parse(userData);
      this.userName = `${user.firstname} ${user.lastname}`;
      this.userEmail = user.email;
      console.log('User Email:', this.userEmail);
    } else {
      this.error = 'User data not found in localStorage.';
    }

    this.loadCategoryStatistics();
    this.loadGenderStatistics();
    this.loadPendingQuizzesCount();
    this.loadCompletedQuizzesCount();
    this.loadCompletedQuizNames();

    if (typeof google === 'undefined') {
      console.error('Google Charts script not found. Adding script dynamically.');
      const script = document.createElement('script');
      script.src = 'https://www.gstatic.com/charts/loader.js';
      script.onload = () => {
        console.log('Google Charts loaded dynamically.');
        google.charts.load('current', { packages: ['corechart'] });
        google.charts.setOnLoadCallback(() => {
          console.log('Google Charts ready, drawing chart if data exists.');
          this.drawCategoryChart();
        });
      };
      script.onerror = () => console.error('Failed to load Google Charts script.');
      document.head.appendChild(script);
    } else {
      google.charts.load('current', { packages: ['corechart'] });
      google.charts.setOnLoadCallback(() => {
        console.log('Google Charts already loaded, drawing chart if data exists.');
        this.drawCategoryChart();
      });
    }
  }

  ngAfterViewInit() {
    this.updateGenderChart();
  }

  ngOnDestroy() {
    if (this.genderChart) {
      this.genderChart.destroy();
    }
  }

  private loadCategoryStatistics(): void {
    this.userService.getCategoryStatistics().subscribe({
      next: (stats: any[]) => {
        console.log('Category stats received:', stats);
        this.categoryStats = stats.length > 0 ? stats : [['Category', 'Question Count'], ['No Data', 0]];
        this.drawCategoryChart();
      },
      error: (err: Error) => {
        console.error('Failed to load category statistics:', err.message);
        this.error = 'Failed to load category statistics: ' + err.message;
        this.categoryStats = [['Category', 'Question Count'], ['No Data', 0]];
        this.drawCategoryChart();
      }
    });
  }

  private drawCategoryChart(): void {
    if (!this.categoryStats || this.categoryStats.length === 0 || !google?.visualization?.ColumnChart) {
      console.warn('Cannot draw chart: invalid categoryStats or Google Charts not available', { categoryStats: this.categoryStats });
      this.categoryStats = [['Category', 'Question Count'], ['No Data', 0]];
    }

    const data = google.visualization.arrayToDataTable(this.categoryStats);
    const colors = ['cornflowerblue', 'olivedrab', 'orange', 'tomato', 'crimson', 'purple', 'turquoise', 'forestgreen', 'navy', 'gray'];
    const options = {
      backgroundColor: 'transparent',
      colors: colors.slice(0, this.categoryStats.length - 1),
      chartArea: { width: '90%', height: '70%' },
      vAxis: { title: 'Number of Questions', minValue: 0, textStyle: { fontSize: 12 } },
      hAxis: { title: 'Category Name', textStyle: { fontSize: 12 } },
      legend: { position: 'none' },
      bar: { groupWidth: '75%' },
      animation: { duration: 1200, easing: 'out', startup: true },
      height: 256
    };

    const chartElement = document.getElementById('category-pie-chart');
    if (!chartElement) {
      console.error('Chart container #category-pie-chart not found.');
      return;
    }

    const chart = new google.visualization.ColumnChart(chartElement);
    chart.draw(data, options);
  }

  private loadGenderStatistics(): void {
    this.userService.getGenderStatistics().subscribe({
      next: (stats: { malePercent: number; femalePercent: number }) => {
        console.log('Gender stats received:', stats);
        this.genderStats = stats && (stats.malePercent >= 0 || stats.femalePercent >= 0) ? stats : { malePercent: 0, femalePercent: 0 };
        this.updateGenderChart();
      },
      error: (err: Error) => {
        console.error('Failed to load gender statistics:', err.message);
        this.error = 'Failed to load gender statistics: ' + err.message;
        this.genderStats = { malePercent: 0, femalePercent: 0 };
        this.updateGenderChart();
      }
    });
  }

  private updateGenderChart(): void {
    setTimeout(() => {
      if (this.genderChart) {
        this.genderChart.destroy();
      }
      const canvas = document.getElementById('genderChart') as HTMLCanvasElement | null;
      if (canvas && this.genderStats) {
        this.genderChart = new Chart(canvas, {
          type: 'pie',
          data: {
            labels: ['Male', 'Female'],
            datasets: [{
              data: [this.genderStats.malePercent, this.genderStats.femalePercent],
              backgroundColor: ['#5093ce', '#dd6864'],
              hoverBackgroundColor: ['#78acd9', '#e6918e']
            }]
          },
          options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
              legend: { display: false },
              tooltip: {
                callbacks: {
                  label: (context) => {
                    const label = context.label || '';
                    const value = context.parsed || 0;
                    return `${label}: ${value}%`;
                  }
                }
              }
            }
          }
        });

        const legendContainer = document.getElementById('gender_legend');
        if (legendContainer && this.genderChart) {
          const labels = this.genderChart.data.labels || [];
          const colors = (this.genderChart.data.datasets[0].backgroundColor as string[]) || [];
          let legendHTML = '<ul class="pie-legend flex flex-col space-y-1 text-xs">';
          labels.forEach((label, index) => {
            const percent = index === 0 ? this.genderStats!.malePercent : this.genderStats!.femalePercent;
            const color = colors[index];
            legendHTML += `<li class="flex items-center"><span class="w-3 h-3 mr-1 inline-block" style="background-color:${color};"></span>${label}: ${percent}%</li>`;
          });
          legendHTML += '</ul>';
          legendContainer.innerHTML = legendHTML;
        }
      }
    }, 0);
  }

  private loadPendingQuizzesCount(): void {
    if (!this.userEmail) {
      this.error = 'User email not available.';
      this.pendingQuizzesCount = 0;
      return;
    }
    console.log('Loading pending quizzes for email:', this.userEmail);
    this.userService.getPendingQuizzesCount(this.userEmail).subscribe({
      next: (data: { count: number }) => {
        this.pendingQuizzesCount = data.count;
        console.log('Pending Quizzes Count:', this.pendingQuizzesCount);
      },
      error: (err: Error) => {
        console.error('Error loading pending quizzes:', err);
        this.error = 'Failed to load pending quizzes count: ' + err.message;
        this.pendingQuizzesCount = 0;
      }
    });
  }

  private loadCompletedQuizzesCount(): void {
    if (!this.userEmail) {
      this.error = 'User email not available.';
      this.completedQuizzesCount = 0;
      return;
    }
    console.log('Loading completed quizzes for email:', this.userEmail);
    this.userService.getCompletedQuizzesCount(this.userEmail).subscribe({
      next: (data: { count: number }) => {
        this.completedQuizzesCount = data.count;
        console.log('Completed Quizzes Count:', this.completedQuizzesCount);
      },
      error: (err: Error) => {
        console.error('Error loading completed quizzes:', err);
        this.error = 'Failed to load completed quizzes count: ' + err.message;
        this.completedQuizzesCount = 0;
      }
    });
  }

  private loadCompletedQuizNames(): void {
    if (!this.userEmail) {
      this.error = 'User email not available.';
      this.completedQuizNames = [];
      return;
    }
    console.log('Loading completed quiz names for email:', this.userEmail);
    this.userService.getCompletedQuizNames(this.userEmail).subscribe({
      next: (names: string[]) => {
        console.log('Completed quiz names received:', names);
        this.completedQuizNames = names || [];
        this.changeDetector.detectChanges();
      },
      error: (err: Error) => {
        console.error('Error loading completed quiz names:', err);
        this.error = 'Failed to load completed quiz names: ' + err.message;
        this.completedQuizNames = [];
      }
    });
  }

  setActiveTab(tab: string): void {
    this.activeTab = tab;
    this.filteredTasks = this.tasks.filter(task => {
      if (this.activeTab === 'all') return true;
      if (this.activeTab === 'pending') return !task.completed;
      if (this.activeTab === 'completed') return task.completed;
      return false;
    });
  }

  toggleTask(task: { text: string; completed: boolean }): void {
    task.completed = !task.completed;
    this.setActiveTab(this.activeTab);
  }

  editTask(task: { text: string; completed: boolean }): void {
    const newText = prompt('Edit task:', task.text);
    if (newText) {
      task.text = newText;
      this.setActiveTab(this.activeTab);
    }
  }

  deleteTask(task: { text: string; completed: boolean }): void {
    if (confirm('Delete this task?')) {
      this.tasks = this.tasks.filter(t => t !== task);
      this.setActiveTab(this.activeTab);
    }
  }
}