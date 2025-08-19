<?php

namespace App\Controller;
use App\Service\FirebaseRestService;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Annotation\Route;

class StatController extends AbstractController
{
#[Route('/api/gender-statistics', name: 'firebase_gender_statistics', methods: ['GET', 'OPTIONS'])]
    public function getGenderStatistics(Request $request, FirebaseRestService $firebaseService): JsonResponse
    {
        if ($request->getMethod() === 'OPTIONS')
        {
            return $this->handleOptionsRequest();
        }

        try {
            $stats = $firebaseService->getGenderStatistics();
            $response = new JsonResponse([
                'malePercent' => $stats['malePercent'] ?? 0,
                'femalePercent' => $stats['femalePercent'] ?? 0
            ]);
            $this->addCorsHeaders($response);
            return $response;
        }
        catch (\Exception $e)
        {
            error_log("Error in StatController::getGenderStatistics: " . $e->getMessage());
            $response = new JsonResponse(['malePercent' => 0, 'femalePercent' => 0]);
            $this->addCorsHeaders($response);
            return $response;
        }
    }

#[Route('/api/pending-quizzes-count', name: 'pending_quizzes_count', methods: ['GET', 'OPTIONS'])]
    public function getPendingQuizzesCount(Request $request, FirebaseRestService $firebaseService): JsonResponse
    {
        if ($request->getMethod() === 'OPTIONS')
        {
            return $this->handleOptionsRequest();
        }

        try {
            $email = $request->query->get('email');
            if (!$email)
            {
                $response = new JsonResponse(['error' => 'Teacher email is required.'], 400);
                $this->addCorsHeaders($response);
                return $response;
            }
            $count = $firebaseService->getPendingQuizzesCount($email);
            $response = new JsonResponse(['count' => $count]);
            $this->addCorsHeaders($response);
            return $response;
        }
        catch (\Exception $e)
        {
            error_log("Error in getPendingQuizzesCount: " . $e->getMessage());
            $response = new JsonResponse(['count' => 0]);
            $this->addCorsHeaders($response);
            return $response;
        }
    }

#[Route('/api/completed-quizzes-count', name: 'completed_quizzes_count', methods: ['GET', 'OPTIONS'])]
    public function getCompletedQuizzesCount(Request $request, FirebaseRestService $firebaseService): JsonResponse
    {
        if ($request->getMethod() === 'OPTIONS')
        {
            return $this->handleOptionsRequest();
        }

        try {
            $email = $request->query->get('email');
            if (!$email)
            {
                $response = new JsonResponse(['error' => 'Teacher email is required.'], 400);
                $this->addCorsHeaders($response);
                return $response;
            }
            $count = $firebaseService->getCompletedQuizzesCount($email);
            $response = new JsonResponse(['count' => $count]);
            $this->addCorsHeaders($response);
            return $response;
        }
        catch (\Exception $e)
        {
            error_log("Error in getCompletedQuizzesCount: " . $e->getMessage());
            $response = new JsonResponse(['count' => 0]);
            $this->addCorsHeaders($response);
            return $response;
        }
    }

#[Route('/api/completed-quiz-names', name: 'api_completed_quiz_names', methods: ['GET', 'OPTIONS'])]
    public function getCompletedQuizNames(Request $request, FirebaseRestService $firebaseService): JsonResponse
    {
        if ($request->getMethod() === 'OPTIONS')
        {
            return $this->handleOptionsRequest();
        }

        try {
            $email = $request->query->get('email');
            if (!$email)
            {
                $response = new JsonResponse(['error' => 'Email parameter is required'], 400);
                $this->addCorsHeaders($response);
                return $response;
            }
            $quizNames = $firebaseService->getCompletedQuizNames($email);
            $response = new JsonResponse(['names' => $quizNames]);
            $this->addCorsHeaders($response);
            return $response;
        }
        catch (\Exception $e)
        {
            error_log("Error in getCompletedQuizNames: " . $e->getMessage());
            $response = new JsonResponse(['names' => []]);
            $this->addCorsHeaders($response);
            return $response;
        }
    }

#[Route('/api/category-statistics', name: 'category_statistics', methods: ['GET', 'OPTIONS'])]
    public function getCategoryStatistics(Request $request, FirebaseRestService $firebaseService): JsonResponse
    {
        if ($request->getMethod() === 'OPTIONS')
        {
            return $this->handleOptionsRequest();
        }

        try {
            $stats = $firebaseService->getCategoryStatistics();
            $response = new JsonResponse($stats ?: [['Category', 'Question Count'], ['No Data', 0]]);
            $this->addCorsHeaders($response);
            return $response;
        }
        catch (\Exception $e)
        {
            error_log("Error in StatController::getCategoryStatistics: " . $e->getMessage());
            $response = new JsonResponse([['Category', 'Question Count'], ['No Data', 0]]);
            $this->addCorsHeaders($response);
            return $response;
        }
    }

#[Route('/api/questions-count-by-category/{idCategory}', name: 'questions_count_by_category', methods: ['GET', 'OPTIONS'])]
    public function getQuestionsCountByCategory(string $idCategory, Request $request, FirebaseRestService $firebaseService): JsonResponse
    {
        if ($request->getMethod() === 'OPTIONS')
        {
            return $this->handleOptionsRequest();
        }

        try {
            $count = $firebaseService->getnbrQuestionByCategory($idCategory);
            $response = new JsonResponse(['count' => $count]);
            $this->addCorsHeaders($response);
            return $response;
        }
        catch (\Exception $e)
        {
            error_log("Error in getQuestionsCountByCategory: " . $e->getMessage());
            $response = new JsonResponse(['count' => 0]);
            $this->addCorsHeaders($response);
            return $response;
        }
    }

    private function handleOptionsRequest(): Response
    {
        $response = new Response();
        $this->addCorsHeaders($response);
        return $response;
    }

    private function addCorsHeaders(Response $response): void
    {
        $response->headers->set('Access-Control-Allow-Origin', 'http://localhost:4200');
        $response->headers->set('Access-Control-Allow-Methods', 'GET, POST, PATCH, DELETE, OPTIONS');
        $response->headers->set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
        $response->headers->set('Access-Control-Allow-Credentials', 'true');
        $response->headers->set('Access-Control-Max-Age', '86400');
    }
}
