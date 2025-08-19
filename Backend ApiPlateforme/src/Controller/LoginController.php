<?php

namespace App\Controller;
use App\Service\FirebaseRestService;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\Routing\Annotation\Route;

class LoginController extends AbstractController
{
    private FirebaseRestService $firebaseService;

    public function __construct(FirebaseRestService $firebaseService)
    {
        $this->firebaseService = $firebaseService;
    }

    
#[Route('/api/login', name: 'api_login', methods: ['POST'])]
    public function login(Request $request): JsonResponse
    {
        $data = json_decode($request->getContent(), true);

        $email = $data['email'] ?? null;
        $password = $data['password'] ?? null;

        if (!$email || !$password)
        {
            return $this->json(['error' => 'Email and password are required.'], 400);
        }

        try {
            $user = $this->firebaseService->getUserByEmail($email);
            if (!$user)
            {
                return $this->json(['error' => 'User not found.'], 404);
            }

            // Vérifier le rôle
            $userRole = $user['fields']['userRole']['stringValue'] ?? '';
            if (strtolower($userRole) !== 'enseignant')
            {
                return $this->json(['error' => 'Access denied: only Enseignant role allowed.'], 403);
            }

            $storedHash = $user['fields']['password']['stringValue'] ?? '';
            if (!password_verify($password, $storedHash))
            {
                return $this->json(['error' => 'Invalid password.'], 401);
            }

           $userInfo = [
    'email' => $user['fields']['email']['stringValue'] ?? '',
    'firstname' => $user['fields']['firstname']['stringValue'] ?? '',
    'lastname' => $user['fields']['lastname']['stringValue'] ?? '',
    'sexe' => $user['fields']['sexe']['stringValue'] ?? '',
    'photoBase64' => $user['fields']['photoBase64']['stringValue'] ?? null,
    'userRole' => $userRole,
    'dateOfBirth' => $user['fields']['dateOfBirth']['stringValue'] ?? null,
    'phoneNumber' => $user['fields']['phoneNumber']['stringValue'] ?? null,
    'address' => $user['fields']['address']['stringValue'] ?? null,
    'city' => $user['fields']['city']['stringValue'] ?? null,
    'country' => $user['fields']['country']['stringValue'] ?? null,
    'biography' => $user['fields']['biography']['stringValue'] ?? null,
];


            return $this->json(['message' => 'Login successful', 'user' => $userInfo], 200);
        }
        catch (\Exception $e)
        {
            return $this->json(['error' => 'Login failed: ' . $e->getMessage()], 500);
        }
    }

}
