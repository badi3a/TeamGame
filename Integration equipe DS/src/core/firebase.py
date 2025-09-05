import firebase_admin
from firebase_admin import credentials, firestore

# Initialize Firebase with real credentials
cred = credentials.Certificate("firebase_credentials.json")
firebase_admin.initialize_app(cred)
db = firestore.client()  # client Firestore
