import { Component } from '@angular/core';
import { Router, NavigationEnd } from '@angular/router';

@Component({
  selector: 'app-root',
  templateUrl: './app.component.html',
  styleUrls: ['./app.component.css'],
})
export class AppComponent {
  title = 'Mon Application';
  showSidebar = true;
  userFullName: string = '';
  userPhoto: string | null = null;

  constructor(private router: Router) {
    this.router.events.subscribe((event) => {
      if (event instanceof NavigationEnd) {
        this.showSidebar = !(event.url === '/login' || event.url === '/inscription'  || event.url === '/forget-password');

        const userData = localStorage.getItem('user');
        if (userData) {
          const user = JSON.parse(userData);
          this.userFullName = `${user.firstname || ''} ${user.lastname || ''}`.trim();
          if (user.photoBase64) {
            if (!user.photoBase64.startsWith('data:image')) {
              this.userPhoto = 'data:image/png;base64,' + user.photoBase64;
            } else {
              this.userPhoto = user.photoBase64;
            }
          } else {
            this.userPhoto = null; 
          }
        } else {
          this.userFullName = '';
          this.userPhoto = null;
        }
      }
    });
  }
  logout(): void {
    localStorage.removeItem('user');
    this.router.navigate(['/login']);
  }
}
