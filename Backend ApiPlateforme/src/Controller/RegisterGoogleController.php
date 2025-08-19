<?php

namespace App\Controller;
use App\Service\FirebaseRestService;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\Routing\Annotation\Route;

class RegisterGoogleController extends AbstractController
{
    private FirebaseRestService $firebaseService;

    public function __construct(FirebaseRestService $firebaseService)
    {
        $this->firebaseService = $firebaseService;
    }
    
    #[Route('/api/register-google', name: 'api_register_google', methods: ['POST'])]
    public function registerGoogle(Request $request): JsonResponse
    {
        $data = json_decode($request->getContent(), true);

        if (!$data || !isset($data['email']) || !isset($data['uid'])) {
            return $this->json(['error' => 'UID et email sont requis'], 400);
        }
        $existingUser = $this->firebaseService->getUserByEmail($data['email']);

        $userData = [
            'email' => $data['email'],
            'displayName' => $data['displayName'] ?? '',
            'createdAt' => new \DateTime(),
            'userRole' => 'enseignant', 
        ];

        try {
            if ($existingUser === null) {
                $result = $this->firebaseService->createGoogleUser($userData);
            } else {
                $result = $this->firebaseService->updateGoogleUser($existingUser['name'], $userData);
            }
            return $this->json([
                'message' => 'Utilisateur Google enregistré avec succès',
                'firestore_document' => $result['name'] ?? null
            ], 201);

        } catch (\Exception $e) {
            return $this->json(['error' => 'Erreur lors de l\'enregistrement : ' . $e->getMessage()], 500);
        }
    }
    
}
