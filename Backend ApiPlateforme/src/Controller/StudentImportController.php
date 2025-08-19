<?php

namespace App\Controller;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Attribute\Route;
use App\Service\FirebaseRestService;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\Mailer\MailerInterface;
use Symfony\Component\Mime\Email;

use DateTime;

class StudentImportController extends AbstractController
{
    private FirebaseRestService $firebaseService;

    public function __construct(FirebaseRestService $firebaseService)
    {
        $this->firebaseService = $firebaseService;
    }


#[Route('/student/import', name: 'app_student_import')]
    public function index(): Response
    {
        return $this->render('student_import/index.html.twig', [
            'controller_name' => 'StudentImportController',
        ]);
    }

#[Route('/student/import-students/{classe}', name: 'import_students', methods: ['POST'])]
    public function importStudents(Request $request, string $classe, MailerInterface $mailer): JsonResponse
    {
        $file = $request->files->get('file');
        if (!$file || strtolower($file->getClientOriginalExtension()) !== 'csv')
        {
            return new JsonResponse(['error' => 'Invalid CSV file'], 400);
        }

        $handle = fopen($file->getPathname(), 'r');
        if ($handle === false)
        {
            return new JsonResponse(['error' => 'Unable to open file'], 500);
        }

        $header = fgetcsv($handle);

        while (($data = fgetcsv($handle)) !== false)
        {
            if (count($data) < 6)
            {
                continue;
            }

            [$firstname, $lastname, $email, $sexe, $nationalite, $dateOfBirth] = $data;

            if (!filter_var($email, FILTER_VALIDATE_EMAIL))
            {
                continue;
            }

             try {
            $dateOfBirthObj = new \DateTime($dateOfBirth);
              } catch (\Exception $e) {
               continue;
              }

            $plainPassword = bin2hex(random_bytes(4)); 
            $hashedPassword = password_hash($plainPassword, PASSWORD_BCRYPT);

            $userData = [
                            'firstname' => $firstname,
                            'lastname' => $lastname,
                            'email' => $email,
                            'sexe' => $sexe,
                            'nationalite' => $nationalite,
                            'password' => $hashedPassword,
                            'userRole' => 'etudiant',
                            'createdAt' => new \DateTime(),
                            'classe' => $classe,
                            'dateOfBirth' => $dateOfBirthObj, 

                        ];

            try
            {
                $this->firebaseService->createUserWithoutId($userData);
                $emailMessage = (new Email())
                                ->from('admin@quizmaster.com')
                                ->to($email)
                                ->subject('Your login credentials')
                                ->text("Dear $firstname $lastname,\n\nYou will find below your credentials to access the platform:\nEmail: $email\nPassword: $plainPassword\n\nBest regards.");

                $mailer->send($emailMessage);

            }
            catch (\Exception $e)
            {
                // Log ou ignorer
            }
        }

        fclose($handle);

        return new JsonResponse(['message' => 'Students imported and notified by email successfully']);
    }

#[Route('/api/classes', name: 'get_classes', methods: ['GET'])]
    public function getClasses(): JsonResponse
    {
        $classes = $this->firebaseService->getAllClasses();
        return new JsonResponse($classes);
    }

#[Route('/api/class/{classe}/students', name: 'get_students_by_class', methods: ['GET'])]
    public function getStudentsByClass(string $classe): JsonResponse
    {
        $students = $this->firebaseService->getStudentsByClass($classe);
        return new JsonResponse($students);
    }

#[Route('/api/students', name: 'add_student', methods: ['POST'])]
public function addStudent(Request $request, MailerInterface $mailer): JsonResponse
{
    $data = json_decode($request->getContent(), true);

    if (!isset($data['email']) || !filter_var($data['email'], FILTER_VALIDATE_EMAIL)) {
        return new JsonResponse(['error' => 'Email invalide'], 400);
    }

    $plainPassword = bin2hex(random_bytes(4)); // 🔐 8 caractères aléatoires
    $data['password'] = password_hash($plainPassword, PASSWORD_BCRYPT);
    $data['createdAt'] = new \DateTime();

    try {
        $this->firebaseService->createUserWithoutId($data);

        $emailMessage = (new Email())
            ->from('admin@quizmaster.com')
            ->to($data['email'])
            ->subject('Your student account')
            ->text("Hello {$data['firstname']} {$data['lastname']},\n\nYour account has been created successfully.\nEmail: {$data['email']}\nPassword: $plainPassword\n\nThank you.");

        $mailer->send($emailMessage);

        return new JsonResponse(['message' => 'Student added and notified successfully']);
    } catch (\Exception $e) {
        return new JsonResponse(['error' => $e->getMessage()], 500);
    }
}


#[Route('/api/students/{email}', name: 'update_student', methods: ['PUT'])]
    public function updateStudent(string $email, Request $request): JsonResponse
    {
        $data = json_decode($request->getContent(), true);
        try {
            $this->firebaseService->updateUserByEmail($email, $data);
            return new JsonResponse(['message' => 'Student updated successfully']);
        }
        catch (\Exception $e)
        {
            return new JsonResponse(['error' => $e->getMessage()], 500);
        }
    }

#[Route('/api/students/{email}', name: 'delete_student', methods: ['DELETE'])]
    public function deleteStudent(string $email): JsonResponse
    {
        try {
            $this->firebaseService->deleteStudentByEmail($email);
            return new JsonResponse(['message' => 'Student deleted successfully']);
        }
        catch (\Exception $e)
        {
            return new JsonResponse(['error' => $e->getMessage()], 500);
        }
    }

#[Route('/api/class/{classe}', name: 'delete_class', methods: ['DELETE'])]
    public function deleteClass(string $classe): JsonResponse
    {
        try {
            $this->firebaseService->deleteStudentsByClass($classe);
            return new JsonResponse(['message' => "Class '$classe' and its students deleted successfully"]);
        }
        catch (\Exception $e)
        {
            return new JsonResponse(['error' => $e->getMessage()], 500);
        }
    }
}
