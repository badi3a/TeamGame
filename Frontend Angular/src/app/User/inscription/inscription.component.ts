import { Component } from '@angular/core';
import { FormBuilder, FormGroup, Validators, AbstractControl, ValidationErrors } from '@angular/forms';
import { UserService } from '../../services/user.service';
import { Router } from '@angular/router';

@Component({
  selector: 'app-inscription',
  templateUrl: './inscription.component.html',
  styleUrls: ['./inscription.component.css'],
})
export class InscriptionComponent {
  inscriptionForm: FormGroup;
  message: string = '';
  error: string = '';
  submitted: boolean = false; 
  isSubmitting: boolean = false;

  constructor(private fb: FormBuilder, private userService: UserService, private router: Router) {
    this.inscriptionForm = this.fb.group({
      email: ['', [Validators.required, Validators.email]],
      password: ['', [Validators.required, this.passwordValidator]],
      firstname: ['', Validators.required],
      lastname: ['', Validators.required],
      sexe: ['', Validators.required],
    });
  }

  passwordValidator(control: AbstractControl): ValidationErrors | null {
    const value = control.value;
    if (!value) return null;

    const hasUpperCase = /[A-Z]/.test(value);
    const hasLowerCase = /[a-z]/.test(value);
    const hasNumber = /\d/.test(value);
    const hasSpecialChar = /[\W_]/.test(value); // special characters
    const isLongEnough = value.length >= 8;

    const valid = hasUpperCase && hasLowerCase && hasNumber && hasSpecialChar && isLongEnough;

    return valid ? null : { 'invalidPassword': true };
  }

 onSubmit(): void {
  if (this.isSubmitting) return; 
  this.submitted = true;

  if (this.inscriptionForm.valid) {
    this.isSubmitting = true;

    this.userService.register(this.inscriptionForm.value).subscribe({
      next: () => {
        this.message = 'Registration successful!';
        this.error = '';
        this.inscriptionForm.reset();
        this.submitted = false;
        this.isSubmitting = false;

        this.router.navigate(['/login']);
      },
      error: (err) => {
  if (err.status === 409) {
    this.error = 'Email already in use. Please choose another.';
  } else {
    this.error = err.error?.error || 'Registration failed.';
  }
  this.message = '';
  this.isSubmitting = false;
}
,
    });
  } else {
    this.error = 'Please fill the form correctly.';
    this.message = '';
  }
}

playSound(sound: string): void {
  const audio = new Audio(`assets/sounds/${sound}.mp3`);
  audio.play();
}

onReset() {
  this.inscriptionForm.reset();
this.router.navigate(['/login']);}


}
