from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from routers import quiz, question, category, answer, score, group

app = FastAPI(title="Quiz API")

# 🛡️ Middleware CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:4200"],  # autorise Angular
    allow_credentials=True,
    allow_methods=["*"],                      # autorise GET, POST, PUT, DELETE, etc.
    allow_headers=["*"],                      # autorise tous les headers (Content-Type, etc.)
)

# ✅ Routes
app.include_router(quiz.router, prefix="/quizzes", tags=["quizzes"])
app.include_router(question.router, prefix="/questions", tags=["questions"])
app.include_router(category.router, prefix="/categories", tags=["categories"])
app.include_router(answer.router, prefix="/answers", tags=["answers"])
app.include_router(score.router, prefix="/scores", tags=["scores"])
app.include_router(group.router, prefix="/groups", tags=["groups"])

@app.get("/")
def root():
    return {"message": "Bienvenue dans l'API Quiz"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8002)
