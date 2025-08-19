import { Component, OnInit } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { UserService } from '../services/user.service';

@Component({
  selector: 'app-student-import',
  templateUrl: './student-import.component.html',
  styleUrls: ['./student-import.component.css']
})
export class StudentImportComponent implements OnInit {
  selectedFile: File | null = null;
  selectedClass: string = '';
  uploadMessage: string = '';
  classes: string[] = [];
  students: any[] = [];
  displayedClass: string = '';

  newStudent = { firstname: '', lastname: '', email: '', sexe: 'male', nationalite: '', classe: '', dateOfBirth: '' };
  editStudent = { firstname: '', lastname: '', email: '', sexe: '', nationalite: '', classe: '', dateOfBirth: '' };
  editIndex: number = -1;

  popupMessage: string | null = null;
  popupConfirmAction: (() => void) | null = null;

  showPopup(message: string): void {
  this.popupMessage = message;
  this.popupConfirmAction = null;

  setTimeout(() => {
    if (!this.popupConfirmAction) this.popupMessage = null;
  }, 3000);
  }

  showConfirmation(message: string, onConfirm: () => void): void {
  this.popupMessage = message;
  this.popupConfirmAction = onConfirm;
  }

  constructor(private http: HttpClient, private userService: UserService) {}

  ngOnInit(): void {
    this.userService.getClasses().subscribe((res) => {
      this.classes = res;
    });
  }

  onFileSelected(event: any) {
    this.selectedFile = event.target.files[0];
  }

  onImport() {
    if (!this.selectedFile || !this.selectedClass) {
      this.uploadMessage = 'Please select a CSV file and a class.';
      return;
    }

    const formData = new FormData();
    formData.append('file', this.selectedFile);

    this.http.post<{ message: string }>(
      `http://127.0.0.1:8001/student/import-students/${this.selectedClass}`,
      formData
    ).subscribe({
      next: (res) => {
        this.uploadMessage = res.message;
        this.selectedFile = null;
        this.selectedClass = '';
        this.showStudents(this.displayedClass);
      },
      error: (err) => {
        this.uploadMessage = `Error: ${err.status} ${err.statusText}`;
      }
    });
  }

  showStudents(classe: string) {
    this.displayedClass = classe;
    this.userService.getStudentsByClass(classe).subscribe((res) => {
      this.students = res;
    });
  }

  addStudent() {
    const student = {
      ...this.newStudent,
      userRole: 'etudiant',
      createdAt: new Date()
    };

    this.userService.addStudent(student).subscribe({
      next: () => {
        this.showStudents(this.newStudent.classe);
        this.newStudent = { firstname: '', lastname: '', email: '', sexe: 'male', nationalite: '', classe: '' , dateOfBirth: '' };
        this.showPopup("Student added. A password has been sent to their email.");
      },
      error: (err) => {
        console.error('Error adding student:', err);
        this.showPopup("An error occurred while adding.");
      }
    });
  }

  startEdit(index: number) {
    this.editIndex = index;
    this.editStudent = { ...this.students[index] };
  }

  saveEdit() {
  const { email, ...dataWithoutEmail } = this.editStudent;
  if (!email) {
    console.error("Email is required");
    return;
  }
  console.log("Update student:", email, dataWithoutEmail);
  this.userService.updateStudent(email, dataWithoutEmail).subscribe({
    next: () => {
      this.showStudents(this.editStudent.classe);
      this.editIndex = -1;
      this.showPopup('Student updated successfully');
    },
    error: (err) => {
      console.error('Error updating student:', err);
      this.showPopup('Erreur lors de la mise à jour: ' + (err.error?.message || err.message));
    }
  });
}

  deleteStudent(email: string) {
    this.userService.deleteStudent(email).subscribe(() => {
      this.showStudents(this.displayedClass);
    });
  }

deleteClass(classe: string) {
  this.showConfirmation(
    `Are you sure you want to delete the class "${classe}" and all its students?`,
    () => {
      this.userService.deleteClass(classe).subscribe({
        next: () => {
          this.classes = this.classes.filter(c => c !== classe);
          if (this.displayedClass === classe) {
            this.students = [];
            this.displayedClass = '';
          }
          this.showPopup('Class deleted successfully.');
        },
        error: (err) => {
          this.showPopup('Error deleting class: ' + err.message);
        }
      });
      this.popupMessage = null; 
    }
  );
}

}
