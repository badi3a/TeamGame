import { Component } from '@angular/core';
import { PasswordResetService } from '../../services/password-reset.service';

@Component({
  selector: 'app-forget-password',
  templateUrl: './forget-password.component.html',
  styleUrls: ['./forget-password.component.css'],
})
export class ForgetPasswordComponent {
  email = '';
  message = '';
  step = 1;
  code = '';
  newPassword = '';

  constructor(private passwordService: PasswordResetService) {}

  sendCode() {
    this.passwordService.forgotPassword(this.email).subscribe({
      next: res => {
        this.message = res.message;
        this.step = 2;
      },
      error: err => {
        this.message = err.error?.error || 'Erreur inconnue';
        console.error(err);
      }
    });
  }

  verifyCode() {
    this.passwordService.verifyCode(this.email, this.code).subscribe({
      next: res => {
        this.message = res.message;
        this.step = 3;
      },
      error: err => {
        this.message = err.error?.error || 'Erreur inconnue';
        console.error(err);
      }
    });
  }

  resetPassword() {
    this.passwordService.resetPassword(this.email, this.newPassword).subscribe({
      next: res => {
        this.message = res.message;
        this.step = 4;
      },
      error: err => {
        this.message = err.error?.error || 'Erreur inconnue';
        console.error(err);
      }
    });
  }
}
