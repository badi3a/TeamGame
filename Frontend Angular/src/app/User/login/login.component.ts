import { Component } from '@angular/core';
import { FormBuilder, FormGroup, Validators } from '@angular/forms';
import { UserService } from '../../services/user.service';
import { Router } from '@angular/router';
import { Auth, GoogleAuthProvider, signInWithPopup } from '@angular/fire/auth';

@Component({
  selector: 'app-login',
  templateUrl: './login.component.html',
  styleUrls: ['./login.component.css'],
})
export class LoginComponent {
  loginForm: FormGroup;
  message = '';
  error = '';

  constructor(private fb: FormBuilder, private userService: UserService, private router: Router, private auth: Auth ) {
    this.loginForm = this.fb.group({
      email: ['', [Validators.required, Validators.email]],
      password: ['', Validators.required],
    });
  }

  onSubmit(): void {
    if (this.loginForm.invalid) {
      this.error = 'Please enter valid credentials.';
      return;
    }

   this.userService.login(this.loginForm.value).subscribe({
  next: (res) => {
    localStorage.setItem('user', JSON.stringify(res.user)); 
    this.router.navigate(['/accueil']);
  },
  error: (err) => {
    this.error = err.error?.error || 'Login failed.';
  }
});

  }

 loginWithGoogle() {
  const provider = new GoogleAuthProvider();
  signInWithPopup(this.auth, provider)
    .then(result => {
      const user = result.user;
      let firstname = '';
      let lastname = '';
      if (user.displayName) {
        const names = user.displayName.split(' ');
        firstname = names[0];
        lastname = names.slice(1).join(' ');
      }

      const googleUserData = {
        uid: user.uid,
        email: user.email,
        firstname: firstname,
        lastname: lastname,
        displayName: user.displayName,
        photoURL: user.photoURL,
      };
      this.userService.registerGoogleUser(googleUserData).subscribe({
        next: res => {
          localStorage.setItem('user', JSON.stringify(googleUserData));
          this.router.navigate(['/accueil']);
        },
        error: err => {
          console.error('Erreur backend:', err);
          this.error = 'Erreur lors de l\'enregistrement utilisateur Google.';
        }
      });
    })
    .catch(error => {
      console.error('Erreur Google Sign-in:', error);
      this.error = 'Connexion Google échouée.';
    });
}

}
