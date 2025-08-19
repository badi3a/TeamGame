import { Component, OnInit } from '@angular/core';
import { ClusterService, ClusterResponse } from '../services/cluster.service';
import { GroupService, Group } from '../services/group.service';

interface Student {
  first_name: string;
  last_name: string;
  gender: number;
  age: number;
  nationality: number;
  hard_skills: number;
  soft_skills: number;
  teamwork: number;
  creativity: number;
  class: string;
  group: number;
  heterogeneous_group: number;
}

interface GroupWithExpansion {
  name: string;
  students: Student[];
  expanded: boolean;
}

@Component({
  selector: 'app-groupes',
  templateUrl: './groupes.component.html',
  styleUrls: ['./groupes.component.css']
})
export class GroupesComponent implements OnInit {
  selectedFile?: File;
  groupSize: number = 4;
  responseData?: ClusterResponse;
  errorMsg?: string;
  loading = false;

  groups: Group[] = [];
  newGroupName = '';
  newClassName = ''; 

  selectedClass = '';
  classes: string[] = []; 

  selectedClassFilter = '';
  selectedGroupFilter: Group | null = null;

  displayGroups: GroupWithExpansion[] = [];
  expandedClasses = new Set<string>();
  expandedGroups = new Set<string>();
  constructor(private clusterService: ClusterService, private groupService: GroupService) {}

  ngOnInit(): void {
    this.loadGroups();
  }
selectClass(className: string) {
  this.selectedClassFilter = className;
  this.selectedGroupFilter = null; 
}

selectGroup(group: Group) {
  this.selectedGroupFilter = group;
}

classAccess: { [className: string]: boolean } = {};

loadGroups(): void {
  this.groupService.getGroups().subscribe(data => {
    this.groups = data;

    this.classes = Array.from(new Set(this.groups.map(g => g.className || '')));
    this.classes.forEach(c => {
      const groupsInClass = this.groups.filter(g => g.className === c);
      this.classAccess[c] = groupsInClass.some(g => g.accessible === true);
    });
  });
}
toggleClassAccess(className: string) {
  this.classAccess[className] = !this.classAccess[className];
  
  this.groupService.setClassAccess(className, this.classAccess[className])
    .subscribe(() => {
      this.groups.filter(g => g.className === className)
                 .forEach(g => g.accessible = this.classAccess[className]);
      
      const status = this.classAccess[className] ? 'accessible' : 'non accessible';
      this.showPopup(`Classe "${className}" est maintenant ${status}.`);
    });
}
getFilteredGroups(): Group[] {
  if (!this.selectedClassFilter) return [];
  return this.groups.filter(g => g.className === this.selectedClassFilter);
}
  createGroup(): void {
  if (!this.newGroupName.trim()) return;

  const group: Group = { 
    groupName: this.newGroupName, 
    className: this.newClassName?.trim() || '',  
    members: [] 
  };

  this.groupService.createGroup(group).subscribe(() => {
    this.newGroupName = '';
    this.newClassName = ''; 
    this.loadGroups();
  });
}
  onFileSelected(event: Event): void {
    const input = event.target as HTMLInputElement;
    if (input.files && input.files.length > 0) {
      this.selectedFile = input.files[0];
      this.errorMsg = '';
    }
  }
  onSubmit(): void {
  if (!this.selectedFile) {
    this.errorMsg = "Sélectionne un fichier CSV.";
    return;
  }
  if (!this.groupSize || this.groupSize <= 0) {
    this.errorMsg = "La taille de groupe doit être positive.";
    return;
  }
  if (!this.newClassName.trim()) {
  this.errorMsg = "Veuillez saisir un nom de classe.";
  return;
}

  this.loading = true;
  this.clusterService.uploadCsv(
    this.selectedFile,
    this.groupSize,
    this.newClassName?.trim() || ''
  ).subscribe({
    next: (res) => {
      this.responseData = res;
      this.errorMsg = undefined;
      this.prepareDisplayGroups();
      this.loading = false;
    },
    error: (err) => {
      this.errorMsg = err.error?.detail || err.message;
      this.responseData = undefined;
      this.displayGroups = [];
      this.loading = false;
    }
  });
}
  prepareDisplayGroups(): void {
    if (!this.responseData) return;
    this.displayGroups = Object.entries(this.responseData.groups).map(([groupName, studentsData]) => ({
      name: groupName,
      students: studentsData as Student[],
      expanded: false
    }));
  }

  toggleGroup(group: GroupWithExpansion) {
    group.expanded = !group.expanded;
  }
  newMemberName = ''; 

addMember(group: Group, memberName: string): void {
  if (!memberName.trim()) return;
  this.groupService.addMember(group.idGroup!, memberName.trim()).subscribe(updatedGroup => {
    const g = this.groups.find(gr => gr.idGroup === group.idGroup);
    if (g) g.members = updatedGroup.members;
    if (this.selectedGroupFilter && this.selectedGroupFilter.idGroup === group.idGroup) {
      this.selectedGroupFilter.members = updatedGroup.members;
    }
    this.newMemberName = '';
  });
}

removeMember(group: Group, memberName: string): void {
  this.groupService.removeMember(group.idGroup!, memberName).subscribe(updatedGroup => {
    const g = this.groups.find(gr => gr.idGroup === group.idGroup);
    if (g) g.members = updatedGroup.members;
    if (this.selectedGroupFilter && this.selectedGroupFilter.idGroup === group.idGroup) {
      this.selectedGroupFilter.members = updatedGroup.members;
    }
  });
}
popupMessage: string | null = null;
  popupConfirmAction: (() => void) | null = null;
  showPopup(message: string): void {
    this.popupMessage = message;
    this.popupConfirmAction = null;
    setTimeout(() => {
      if (!this.popupConfirmAction) this.popupMessage = null;
    }, 3000);
  }

  showConfirmation(message: string, onConfirm: () => void) {
    this.popupMessage = message;
    this.popupConfirmAction = onConfirm;
  }

  confirmPopupYes() {
    if (this.popupConfirmAction) this.popupConfirmAction();
    this.popupMessage = null;
    this.popupConfirmAction = null;
  }

  confirmPopupNo() {
    this.popupMessage = null;
    this.popupConfirmAction = null;
  }

deleteGroup(id?: string): void {
    if (!id) return;
    this.showConfirmation("Voulez-vous vraiment supprimer ce groupe ?", () => {
      this.groupService.deleteGroup(id).subscribe(() => {
        this.loadGroups();
        this.selectedGroupFilter = null;
        this.showPopup("Groupe supprimé !");
      });
    });
  }

toggleGroupAccess(group: Group) {
  this.groupService.toggleAccess(group.idGroup!).subscribe(updatedGroup => {
    group.accessible = updatedGroup.accessible;
  });
}
}
