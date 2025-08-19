<?php
namespace App\Controller;

use App\Service\FirebaseRestService;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\Routing\Annotation\Route;
use Symfony\Component\Mime\Email;
use Symfony\Component\Mailer\MailerInterface;

class PasswordResetController extends AbstractController
{
    private FirebaseRestService $firebaseService;

    public function __construct(FirebaseRestService $firebaseService)
    {
        $this->firebaseService = $firebaseService;
    }

    #[Route('/api/forgot-password', name: 'api_forgot_password', methods: ['POST'])]
    public function forgotPassword(Request $request, MailerInterface $mailer): JsonResponse
    {
        $data = json_decode($request->getContent(), true);
        $email = $data['email'] ?? null;

        if (!$email) {
            return $this->json(['error' => 'Email is required'], 400);
        }

        $user = $this->firebaseService->getUserByEmail($email);
        if ($user === null) {
            return $this->json(['error' => 'User not found'], 404);
        }

        $otp = random_int(100000, 999999);
        $expiration = (new \DateTime('+10 minutes'))->format(DATE_ATOM);

        $documentName = $user['name'];

        $fields = [
            'resetCode' => ['stringValue' => (string)$otp],
            'resetExpiresAt' => ['stringValue' => $expiration],
        ];

        try {
            $this->firebaseService->updateUserFields($documentName, ['fields' => $fields], ['resetCode', 'resetExpiresAt']);
        } catch (\Exception $e) {
            return $this->json(['error' => 'Failed to update reset code: ' . $e->getMessage()], 500);
        }

        try {
            $emailMessage = (new Email())
                ->from('admin@Qquizmaster.com')  
                ->to($email)
                ->subject('Password Reset Code')
                ->text("Your password reset code is: $otp. It expires in 10 minutes.");

            $mailer->send($emailMessage);
        } catch (\Exception $e) {
            return $this->json(['error' => 'Failed to send email: ' . $e->getMessage()], 500);
        }

        return $this->json(['message' => 'Password reset code sent']);
    }

    #[Route('/api/verify-reset-code', name: 'api_verify_reset_code', methods: ['POST'])]
    public function verifyResetCode(Request $request): JsonResponse
    {
        $data = json_decode($request->getContent(), true);
        $email = $data['email'] ?? null;
        $code = $data['code'] ?? null;

        if (!$email || !$code) {
            return $this->json(['error' => 'Email and code are required'], 400);
        }

        $user = $this->firebaseService->getUserByEmail($email);
        if ($user === null) {
            return $this->json(['error' => 'User not found'], 404);
        }

        $storedCode = $user['fields']['resetCode']['stringValue'] ?? null;
        $expiresAtStr = $user['fields']['resetExpiresAt']['stringValue'] ?? null;

        if (!$storedCode || !$expiresAtStr) {
            return $this->json(['error' => 'No reset code found, please request a new one'], 400);
        }

        $expiresAt = new \DateTime($expiresAtStr);

        if ($storedCode !== $code) {
            return $this->json(['error' => 'Invalid reset code'], 400);
        }

        if ($expiresAt < new \DateTime()) {
            return $this->json(['error' => 'Reset code expired'], 400);
        }

        return $this->json(['message' => 'Reset code verified']);
    }

    #[Route('/api/reset-password', name: 'api_reset_password', methods: ['POST'])]
    public function resetPassword(Request $request): JsonResponse
    {
        $data = json_decode($request->getContent(), true);
        $email = $data['email'] ?? null;
        $newPassword = $data['password'] ?? null;

        if (!$email || !$newPassword) {
            return $this->json(['error' => 'Email and new password are required'], 400);
        }

        $user = $this->firebaseService->getUserByEmail($email);
        if ($user === null) {
            return $this->json(['error' => 'User not found'], 404);
        }

        $hashedPassword = password_hash($newPassword, PASSWORD_BCRYPT);

        $documentName = $user['name'];

        $fields = [
            'password' => ['stringValue' => $hashedPassword],
            'resetCode' => ['nullValue' => null],
            'resetExpiresAt' => ['nullValue' => null],
        ];

        try {
            $this->firebaseService->updateUserFields($documentName, ['fields' => $fields], ['password', 'resetCode', 'resetExpiresAt']);
        } catch (\Exception $e) {
            return $this->json(['error' => 'Failed to update password: ' . $e->getMessage()], 500);
        }

        return $this->json(['message' => 'Password updated successfully']);
    }
    #[Route('/api/forgot-password', name: 'api_forgot_password_get', methods: ['GET'])]
public function forgotPasswordTestGet(): JsonResponse
{
    return $this->json(['message' => 'GET route test']);
}

}
