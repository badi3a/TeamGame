# Projet Stage d'Été – Consignes Git

Bienvenue dans le dépôt du projet de stage d’été encadré par **Badia Bouhdid** et **Rim Douss**.  
Merci de lire attentivement les consignes suivantes avant toute contribution.

---

## 1. Organisation des branches

- **main** : Documentation uniquement (ce fichier + instructions).  
- **master** : Branche d’intégration finale (gérée uniquement par Badia & Louay).  
- **application-mobile** : Branche de développement mobile (responsable : Louay).  
- **backend** : Branche de développement backend (responsables : Zouhour & Ahmed).  
- **web** : Branche de développement web (front + back) (responsable : Maram).  

---

## 2. Cloner le projet et se placer sur la bonne branche

⚠️ Ne jamais travailler directement sur `main` ni sur `master`.  

```bash
# Cloner le projet
git clone <URL_DU_DEPOT>

# Se déplacer dans le dossier du projet
cd <NOM_DU_PROJET>

# Vérifier les branches disponibles
git branch -a

# Créer et basculer sur la branche correspondante à votre partie
git checkout -b <nom_de_votre_branche> origin/<nom_de_votre_branche>
## Exemples :  

### Pour Louay (mobile) :
```bash
git checkout -b application-mobile origin/application-mobile
### Pour Zouhour & Ahmed (backend) :
```bash
git checkout -b backend origin/backend
### Pour Maram (web) :

git checkout -b web origin/web
# Ajouter vos modifications
## Vérifier les fichiers modifiés
git status

##Ajouter vos changements
git add .

## Sauvegarder vos modifications avec un message clair
git commit -m "Ajout de la fonctionnalité X"

## Envoyer sur la branche distante
git push origin <nom_de_votre_branche>

#4. Rappel important
✅ Chaque branche doit contenir un README spécifique avec :

Les bibliothèques utilisées

Les commandes nécessaires pour exécuter l’application

❌ Ne jamais fusionner manuellement vers master → cette intégration sera faite uniquement par Badia & Louay.