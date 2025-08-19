import { Component, OnInit } from '@angular/core';
import { UserService } from '../../services/user.service';

@Component({
  selector: 'app-profil',
  templateUrl: './profil.component.html',
  styleUrls: ['./profil.component.css']
})
export class ProfilComponent implements OnInit {
  user: any = {
    firstname: '',
    lastname: '',
    email: '',
    sexe: '',
    dateOfBirth: '',   // ✅ cohérent avec backend
    phoneNumber: '',   // ✅ cohérent avec backend
    address: '',
    city: '',
    country: '',
    biography: '',     // ✅ cohérent avec backend
    photoBase64: ''
  };

  constructor(private userService: UserService) {}

  ngOnInit(): void {
    const storedUser = localStorage.getItem('user');
    if (storedUser) {
      this.user = { ...this.user, ...JSON.parse(storedUser) };

      if (this.user.photoBase64 && !this.user.photoBase64.startsWith('data:image')) {
        this.user.photoBase64 = 'data:image/png;base64,' + this.user.photoBase64;
      }
    }
  }

  onFileSelected(event: any): void {
    const file: File = event.target.files[0];
    if (file) {
      const reader = new FileReader();
      reader.onload = () => {
        this.user.photoBase64 = reader.result as string;
        const base64WithoutPrefix = this.user.photoBase64.split(',')[1];

        this.userService.updateUserPhoto(this.user.email, base64WithoutPrefix)
          .subscribe({
            next: () => {
              localStorage.setItem('user', JSON.stringify(this.user));
            },
            error: (err) => {
              console.error('Erreur lors de la sauvegarde de l\'image', err);
            }
          });
      };
      reader.readAsDataURL(file);
    }
  }

  saveProfile() {
    this.userService.updateProfile(this.user).subscribe({
      next: () => {
        localStorage.setItem('user', JSON.stringify(this.user));
      },
      error: (err) => {
        console.error('Erreur lors de la mise à jour du profil', err);
      }
    });
  }
}
