# 🌐 TeamGame – Branche Web

## 📌 Description

La branche **Web** du projet **TeamGame** regroupe :

- **Frontend Angular 16** : Interface enseignant avec dashboard interactif, gestion des étudiants, gestion des quiz, avatars, groupes, calendrier et chatbot.
- **Backend API Platform (Symfony)** : Gestion des utilisateurs (enseignants & étudiants), import CSV, statistiques, authentification (Firebase + Google).
- **Firebase** : Utilisé comme système d’authentification et de stockage.
- **Backend FastAPI (complémentaire,branche Backend)** : Gestion des quiz, avatars, groupes (clustering).

---

## 🚀 Fonctionnalités

### 🔹 Frontend Angular 16

**Technologie : Angular 16**

#### 📂 Dossiers principaux :
```
src/app/
 ├── accueil/             # Page d’accueil avec statistiques
 ├── avatar-list/         # Gestion des avatars & scores (FastAPI)
 ├── calendar/            # Calendrier (FullCalendar)
 ├── chatbot/             # Chatbot IA (Gemini + mydata.json)
 ├── groupes/             # Gestion des groupes (FastAPI clustering)
 ├── guards/              # Guards de rôles et permissions
 ├── quiz-dashboard/      # CRUD Quiz, catégories,sous-catégories, question, filtres (FastAPI)
 ├── services/            # Services Angular (user,score,quiz,question,password-reset,cluster,category,badge,avatar)
 ├── student-import/      # Import CSV étudiants (API Platform)
 ├── user/                # Login, register, profil, reset-password (API Platform + Firebase)
 ├── app-routing.module.ts 
 ├── app.component.ts / .html / .css # Sidebar
 └── app.module.ts
```

#### 📊 Fonctionnalités principales :
- **Dashboard interactif (enseignants)**
- **Accueil** : Statistiques (catégories, genres, quiz en attente, quiz complétés)
- **Avatars (AvatarList)** : Classement des étudiants avec îles, badges, scores, quiz *(via FastAPI)*
- **Groupes** : Clustering automatique (CSV) + ajout/suppression manuelle *(via FastAPI)*
- **Quiz** :
  - CRUD complet (catégories, sous-catégories, quiz accessibles ou non)
  - Questions manuelles ou générées par IA Gemini
  - Filtres 
- **Calendrier** : Visualisation des quiz avec **FullCalendar**
- **Import Étudiants (CSV)** : Affectation automatique aux classes + génération d’identifiants sécurisés envoyés par mail *(via API Platform)*
- **Utilisateurs** :
  - Inscription / Connexion
  - Connexion via Google
  - Réinitialisation mot de passe (Firebase email)
  - Gestion du profil (ajout photo, mise à jour infos)
- **Chatbot** :
  - Mode FAQ via fichier `mydata.json`
  - Mode **IA** (Gemini API)
- **Guards Angular** : Protection des routes selon rôle (enseignant/étudiant)

---

### 🔹 Backend API Platform (Symfony)

**Technologie : Symfony 6.4 + API Platform 3.4**

#### 📂 Dossiers principaux :
```
config/
 ├── firebase_credentials.json   # Identifiants Firebase Admin
 ├── routes.yaml                 # Routing Symfony
 ├── services.yaml               # Déclaration des services

src/
 ├── ApiResource/                
 ├── Controller/                 
 │    ├── LoginController.php          # Connexion utilisateur
 │    ├── PasswordResetController.php  # Reset mot de passe
 │    ├── RegisterController.php       # Inscription
 │    ├── RegisterGoogleController.php # Auth via Google
 │    ├── StatController.php           # Statistiques
 │    └── StudentImportController.php  # Import CSV étudiants
 ├── Entity/                      
 ├── Repository/                
 └── Service/                    
      ├── EmailService.php        # Envoi d’emails
      └── FirebaseRestService.php # Communication Firebase
```

#### 📊 Fonctionnalités principales :
- **Gestion Utilisateurs** :
  - Register / Login / Reset Password / Update Profile
  - Authentification via Google
  - Rôles : enseignant, étudiant
- **Import Étudiants (CSV)** :
  - Affectation à une classe
  - Génération identifiant + mot de passe sécurisé
  - Envoi automatique d’un mail avec identifiants
- **Statistiques** utilisateurs & classes
- **Firebase** utilisé comme système d’authentification et stockage
---

## 
## 📚 Bibliothèques utilisées

### 🔹 Frontend Angular 16
- **@angular/fire** → intégration Firebase  
- **firebase** → SDK officiel Firebase  
- **@fullcalendar/angular**, **@fullcalendar/core**, **@fullcalendar/daygrid** → calendrier (planning quiz)  
- **angular-calendar** + **date-fns** → gestion avancée des événements et dates  
- **bootstrap** → UI responsive  
- **chart.js** → graphiques statistiques  
- **apexcharts** → visualisations interactives (charts avancés)  
- **d3** → manipulation et visualisation de données  
- **css-select** → utilitaire de sélection CSS (extraction/parsing de DOM)  

---

### 🔹 Backend API Platform (Symfony)
- **api-platform/doctrine-orm** & **api-platform/symfony** → API REST/GraphQL  
- **kreait/firebase-php** → SDK Firebase pour PHP  
- **google/auth** → Authentification Google OAuth  
- **nelmio/cors-bundle** → gestion CORS (API cross-domain)  
- **symfony/mailer** → envoi d’emails (reset password, notifications)  
- **symfony/http-client** → appels API externes (Firebase, Google, etc.)  
- **symfony/uid** → UUID & identifiants uniques  

⚙️ Installation & Lancement

### 1️⃣ Cloner le projet
```bash
git clone https://github.com/badi3a/TeamGame.git
cd TeamGame
git checkout Web
```

### 2️⃣ Lancer le Frontend Angular
```bash
cd "Frontend Angular"
npm install
ng serve
```
➡️ Accessible sur : [http://localhost:4200](http://localhost:4200)

### 3️⃣ Lancer le Backend API Platform (Symfony)
```bash
cd "Backend ApiPlateforme"
composer install
symfony server:start --port=8001
```
➡️ Accessible sur : [http://127.0.0.1:8001](http://127.0.0.1:8001)

---

## 🔑 Configuration

### 📂 `environment.ts` (Angular)
```ts
export const environment = {
  production: false,
  firebase: {
    apiKey: "XXXX",
    authDomain: "quizmaster-XXXX.firebaseapp.com",
    projectId: "quizmaster-XXXX",
    storageBucket: "quizmaster-XXXX.appspot.com",
    messagingSenderId: "XXXX",
    appId: "XXXX",
    measurementId: "XXXX"
  },
  GEMINI_API_KEY: "XXXX"
};
```

### 📂 `firebase_credentials.json` (API Platform)
Clé **Service Account Firebase** pour :  
- Authentification utilisateurs  
- Stockage complémentaire  

---

## 📊 Aperçu des Ports
- **Frontend Angular** → [http://localhost:4200](http://localhost:4200)  
- **Backend FastAPI** → [http://127.0.0.1:8000](http://127.0.0.1:8000)  
- **Backend API Platform (Symfony)** → [http://127.0.0.1:8001](http://127.0.0.1:8001)  

---

## 🖥️ Interfaces principales
- **Login** :
  
  <img width="693" height="769" alt="image" src="https://github.com/user-attachments/assets/d529cc50-bf42-4ceb-b1cc-9b9bc40417cd" />

- **Mot de passe oublié** :
  
  <img width="723" height="390" alt="image" src="https://github.com/user-attachments/assets/f8113e2d-227a-45f0-869a-40d3e17ac584" />

- **Inscription** : 
  <img width="941" height="738" alt="image" src="https://github.com/user-attachments/assets/d073060f-a0dd-4e50-979c-e289377175bf" />

- **Dashboard** : 
 <img width="940" height="458" alt="image" src="https://github.com/user-attachments/assets/6e401f83-8688-4f69-b2a0-60e72c730b1d" />

- **My Profile** : 
  <img width="940" height="463" alt="image" src="https://github.com/user-attachments/assets/b7880fd6-ff41-4784-9591-e2937cb6777c" />

- **My Classes** : 
  <img width="940" height="448" alt="image" src="https://github.com/user-attachments/assets/e6d5eb4f-b2fb-4626-8a86-6c811d48a0d3" />
  <img width="940" height="602" alt="image" src="https://github.com/user-attachments/assets/2278beb9-7b9c-43e5-b1dd-5e643c6fb7b2" />

- **My Quizzes** :
  <img width="940" height="452" alt="image" src="https://github.com/user-attachments/assets/13f4bce9-9ea6-481b-9c71-cf96b4757085" />
  <img width="940" height="833" alt="image" src="https://github.com/user-attachments/assets/56592ec1-2b88-4867-83b7-2cbb5c246a30" />
  <img width="940" height="377" alt="image" src="https://github.com/user-attachments/assets/92adce21-414b-4d6c-b4da-cf8020254ffb" />
  <img width="940" height="579" alt="image" src="https://github.com/user-attachments/assets/f0a0f536-ae54-4c56-b615-61b79a7f481a" />
  <img width="940" height="321" alt="image" src="https://github.com/user-attachments/assets/74dd4ce5-9791-45c5-8ad8-db42dcd137e3" />
  <img width="940" height="225" alt="image" src="https://github.com/user-attachments/assets/04b01313-2d84-4c6e-898f-960a5f393ca1" />
  <img width="940" height="221" alt="image" src="https://github.com/user-attachments/assets/ca34d664-dca1-4449-a742-40a3507069df" />
  <img width="940" height="215" alt="image" src="https://github.com/user-attachments/assets/ac3c3733-87b8-46b7-b167-bc801dc10737" />
  <img width="940" height="483" alt="image" src="https://github.com/user-attachments/assets/f58b5e28-b673-4dc6-b199-5e102dc87068" />

- **Students** :
  <img width="940" height="460" alt="image" src="https://github.com/user-attachments/assets/476d871b-aad1-4ff7-923e-82248bca9fa5" />
  <img width="940" height="460" alt="image" src="https://github.com/user-attachments/assets/ecd8e263-a66c-456b-8885-2ad233156857" />
  <img width="940" height="458" alt="image" src="https://github.com/user-attachments/assets/559c17e8-8913-4c60-a62a-3f9bd77261c1" />
  <img width="940" height="469" alt="image" src="https://github.com/user-attachments/assets/8021e52e-5ec1-4169-b066-64aadbdd1284" />
  <img width="940" height="227" alt="image" src="https://github.com/user-attachments/assets/f368a0a9-75f3-4fa5-bc6e-08a535bc78dc" />
  <img width="940" height="581" alt="image" src="https://github.com/user-attachments/assets/4411048e-c376-413d-aa94-0f1334dd690f" />

- **Calendar** : Calendrier des quiz avec FullCalendar.
  <img width="940" height="452" alt="image" src="https://github.com/user-attachments/assets/0f45afeb-aba9-4290-8593-6de546676050" />

- **Chatbot** : Assistance via FAQ (mydata.json) + IA Gemini.
  <img width="940" height="452" alt="image" src="https://github.com/user-attachments/assets/20f2bf38-efbf-4c1a-999f-32f9e9ec2fbb" />

- **My Groups** : Gestion des groupes (clustering CSV, ajout/suppression).
  <img width="940" height="458" alt="image" src="https://github.com/user-attachments/assets/bb4844df-9aba-4069-82ae-fcd3372096af" />
  <img width="940" height="450" alt="image" src="https://github.com/user-attachments/assets/abacc2d6-fd4d-4f11-abd5-953eae6b4a8e" />

