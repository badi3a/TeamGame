<?php

namespace App\Service;
use Symfony\Contracts\HttpClient\HttpClientInterface;

class FirebaseRestService
{
    private HttpClientInterface $client;
    private string $projectId;
    private string $database;
    private string $accessToken;

    public function __construct(HttpClientInterface $client, string $projectId, string $serviceAccountPath)
    {
        $this->client = $client;
        $this->projectId = $projectId;
        $this->database = '(default)';
        $this->accessToken = $this->authenticateWithFirebase($serviceAccountPath);
    }

    private function authenticateWithFirebase(string $serviceAccountPath): string
    {
        $json = json_decode(file_get_contents($serviceAccountPath), true);

        $now = time();
        $jwtHeader = ['alg' => 'RS256', 'typ' => 'JWT'];
        $jwtClaimSet = [
            'iss' => $json['client_email'],
            'scope' => 'https://www.googleapis.com/auth/datastore',
            'aud' => $json['token_uri'],
            'iat' => $now,
            'exp' => $now + 3600,
        ];

        $base64UrlHeader = rtrim(strtr(base64_encode(json_encode($jwtHeader)), '+/', '-_'), '=');
        $base64UrlPayload = rtrim(strtr(base64_encode(json_encode($jwtClaimSet)), '+/', '-_'), '=');

        $signatureInput = $base64UrlHeader . '.' . $base64UrlPayload;

        $privateKey = openssl_pkey_get_private($json['private_key']);
        openssl_sign($signatureInput, $signature, $privateKey, 'sha256WithRSAEncryption');
        $base64UrlSignature = rtrim(strtr(base64_encode($signature), '+/', '-_'), '=');

        $jwt = $signatureInput . '.' . $base64UrlSignature;

        $response = $this->client->request('POST', $json['token_uri'], [
            'headers' => ['Content-Type' => 'application/x-www-form-urlencoded'],
            'body' => [
                'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
                'assertion' => $jwt,
            ],
        ]);

        $data = $response->toArray();
        return $data['access_token'];
    }

    public function createUserWithoutId(array $userData): array
    {
        $url = sprintf(
            'https://firestore.googleapis.com/v1/projects/%s/databases/%s/documents/users',
            $this->projectId,
            $this->database
        );

        $firestoreData = [
            'fields' => [
                'email' => ['stringValue' => $userData['email']],
                'password' => ['stringValue' => $userData['password']],
                'firstname' => ['stringValue' => $userData['firstname']],
                'lastname' => ['stringValue' => $userData['lastname']],
                'sexe' => ['stringValue' => $userData['sexe']],
                'createdAt' => ['timestampValue' => $userData['createdAt']->format(DATE_ATOM)],
                'userRole' => ['stringValue' => $userData['userRole']],
            ],
        ];

        if (isset($userData['classe'])){
            $firestoreData['fields']['classe'] = ['stringValue' => $userData['classe']];
        }if (isset($userData['nationalite'])){
            $firestoreData['fields']['nationalite'] = ['stringValue' => $userData['nationalite']];
        }if (isset($userData['dateOfBirth']))
        {
            if ($userData['dateOfBirth'] instanceof \DateTime){
                $firestoreData['fields']['dateOfBirth'] = [
                    'timestampValue' => $userData['dateOfBirth']->format(DATE_ATOM)
                ];
            }else{
                $firestoreData['fields']['dateOfBirth'] = [
                            'stringValue' => $userData['dateOfBirth']
                        ];
            }
        }

        $response = $this->client->request('POST', $url, [
                                               'headers' => [
                                                       'Authorization' => 'Bearer ' . $this->accessToken,
                                               ],
                                               'json' => $firestoreData,
                                           ]);

        return $response->toArray();
    }

    public function getUserByEmail(string $email): ?array
    {
        $url = sprintf(
            'https://firestore.googleapis.com/v1/projects/%s/databases/%s/documents/users?pageSize=1000',
            $this->projectId,
            $this->database
        );

        $response = $this->client->request('GET', $url, [
            'headers' => [
                'Authorization' => 'Bearer ' . $this->accessToken,
            ],
        ]);

        $data = $response->toArray();

        foreach ($data['documents'] ?? [] as $doc)
        {
            if (($doc['fields']['email']['stringValue'] ?? '') === $email)
            {
                return $doc;
            }
        }

        return null;
    }

    public function createGoogleUser(array $userData): array
    {
        $url = sprintf(
            'https://firestore.googleapis.com/v1/projects/%s/databases/%s/documents/users',
            $this->projectId,
            $this->database
        );

        $firestoreData = [
            'fields' => [
                'email' => ['stringValue' => $userData['email']],
                'displayName' => ['stringValue' => $userData['displayName']],
                'createdAt' => ['timestampValue' => $userData['createdAt']->format(DATE_ATOM)],
                'userRole' => ['stringValue' => $userData['userRole']],
            ],
        ];

        $response = $this->client->request('POST', $url, [
            'headers' => [
                'Authorization' => 'Bearer ' . $this->accessToken,
            ],
            'json' => $firestoreData,
        ]);

        return $response->toArray();
    }

    public function updateGoogleUser(string $documentName, array $userData): array
    {
        $url = sprintf(
            'https://firestore.googleapis.com/v1/%s?updateMask.fieldPaths=displayName&updateMask.fieldPaths=photoURL',
            $documentName
        );

        $firestoreData = [
            'fields' => [
                'displayName' => ['stringValue' => $userData['displayName']],
                'photoURL' => ['stringValue' => $userData['photoURL']],
            ],
        ];

        $response = $this->client->request('PATCH', $url, [
            'headers' => [
                'Authorization' => 'Bearer ' . $this->accessToken,
            ],
            'json' => $firestoreData,
        ]);

        return $response->toArray();
    }

    public function updateUserPhoto(string $documentName, array $firestoreData): array
    {
        $url = sprintf(
            'https://firestore.googleapis.com/v1/%s?updateMask.fieldPaths=photoBase64',
            $documentName
        );

        $response = $this->client->request('PATCH', $url, [
            'headers' => [
                'Authorization' => 'Bearer ' . $this->accessToken,
            ],
            'json' => $firestoreData,
        ]);

        return $response->toArray();
    }

    public function updateUserFields(string $documentName, array $firestoreData, array $fieldsToUpdate): array
    {
        $updateMask = implode('&updateMask.fieldPaths=', $fieldsToUpdate);

        $url = sprintf(
            'https://firestore.googleapis.com/v1/%s?updateMask.fieldPaths=%s',
            $documentName,
            $updateMask
        );

        $response = $this->client->request('PATCH', $url, [
            'headers' => [
                'Authorization' => 'Bearer ' . $this->accessToken,
            ],
            'json' => $firestoreData,
        ]);

        return $response->toArray();
    }

    public function getAllClasses(): array
    {
        $url = sprintf(
            'https://firestore.googleapis.com/v1/projects/%s/databases/%s/documents/users?pageSize=1000',
            $this->projectId,
            $this->database
        );

        $response = $this->client->request('GET', $url, [
            'headers' => [
                'Authorization' => 'Bearer ' . $this->accessToken,
            ],
        ]);

        $data = $response->toArray();
        $classes = [];

        foreach ($data['documents'] ?? [] as $doc)
        {
            $fields = $doc['fields'] ?? [];
            if (
                isset($fields['classe']['stringValue']) &&
                isset($fields['userRole']['stringValue']) &&
                $fields['userRole']['stringValue'] === 'etudiant'
            )
            {
                $classe = $fields['classe']['stringValue'];
                if (!in_array($classe, $classes))
                {
                    $classes[] = $classe;
                }
            }
        }

        return $classes;
    }

    public function getStudentsByClass(string $classe): array
    {
        $url = sprintf(
            'https://firestore.googleapis.com/v1/projects/%s/databases/%s/documents/users?pageSize=1000',
            $this->projectId,
            $this->database
        );

        $response = $this->client->request('GET', $url, [
            'headers' => [
                'Authorization' => 'Bearer ' . $this->accessToken,
            ],
        ]);

        $data = $response->toArray();
        $students = [];

        foreach ($data['documents'] ?? [] as $doc)
        {
            $fields = $doc['fields'] ?? [];

            if (
                isset($fields['userRole']['stringValue']) &&
                $fields['userRole']['stringValue'] === 'etudiant' &&
                isset($fields['classe']['stringValue']) &&
                $fields['classe']['stringValue'] === $classe
            )
            {
                $students[] = [
                    'firstname' => $fields['firstname']['stringValue'] ?? '',
                    'lastname' => $fields['lastname']['stringValue'] ?? '',
                    'email' => $fields['email']['stringValue'] ?? '',
                    'sexe' => $fields['sexe']['stringValue'] ?? '',
                    'nationalite'  => $fields['nationalite']['stringValue'] ?? '',
                    'classe'       => $fields['classe']['stringValue'] ?? '',
                    'dateOfBirth' => isset($fields['dateOfBirth']['stringValue'])
                    ? $fields['dateOfBirth']['stringValue']
                    : (isset($fields['dateOfBirth']['timestampValue'])
                ? date('Y-m-d', strtotime($fields['dateOfBirth']['timestampValue']))
                : ''),
                ];
            }
        }

        return $students;
    }

    public function updateUserByEmail(string $email, array $updatedData): void
    {
        $users = $this->getAllUsers();
        foreach ($users as $doc)
        {
            $fields = $doc['fields'];
            if (($fields['email']['stringValue'] ?? '') === $email)
            {
                $docName = $doc['name'];

                unset($updatedData['email']);

                $updateMask = [];
                foreach (array_keys($updatedData) as $field)
                {
                    $updateMask[] = 'updateMask.fieldPaths=' . $field;
                }
                $queryString = implode('&', $updateMask);

                $url = sprintf(
                           'https://firestore.googleapis.com/v1/%s?%s',
                           $docName,
                           $queryString
                       );

                $body = ['fields' => []];
                foreach ($updatedData as $key => $value)
                {
                    $body['fields'][$key] = ['stringValue' => $value];
                }

                $this->client->request('PATCH', $url, [
                                           'headers' => ['Authorization' => 'Bearer ' . $this->accessToken],
                                           'json' => $body
                                       ]);
                return;
            }
        }
        throw new \Exception("Utilisateur introuvable avec l'email : $email");
    }


    public function deleteStudentByEmail(string $email): void
    {
        $users = $this->getAllUsers();

        foreach ($users as $doc)
        {
            $fields = $doc['fields'] ?? [];
            if (($fields['email']['stringValue'] ?? '') === $email)
            {
                $docName = $doc['name']; // full Firestore document path

                // La requête DELETE doit être faite sur l'URL complète du document Firestore (ex: projects/.../documents/users/abc123)
                $this->client->request('DELETE', "https://firestore.googleapis.com/v1/$docName", [
                    'headers' => [
                        'Authorization' => 'Bearer ' . $this->accessToken,
                    ],
                ]);
                return;
            }
        }

        throw new \Exception("Étudiant introuvable avec l'email : $email");
    }

    public function getAllUsers(): array
    {
        $url = sprintf(
            'https://firestore.googleapis.com/v1/projects/%s/databases/%s/documents/users?pageSize=1000',
            $this->projectId,
            $this->database
        );

        $response = $this->client->request('GET', $url, [
            'headers' => [
                'Authorization' => 'Bearer ' . $this->accessToken,
            ],
        ]);

        $data = $response->toArray();
        return $data['documents'] ?? [];
    }

    public function deleteStudentsByClass(string $classe): void
    {
        $users = $this->getAllUsers();

        foreach ($users as $doc)
        {
            $fields = $doc['fields'] ?? [];
            if (($fields['classe']['stringValue'] ?? '') === $classe && ($fields['userRole']['stringValue'] ?? '') === 'etudiant')
            {
                $docName = $doc['name'];
                $this->client->request('DELETE', "https://firestore.googleapis.com/v1/$docName", [
                    'headers' => [
                        'Authorization' => 'Bearer ' . $this->accessToken,
                    ],
                ]);
            }
        }
    }
    public function getnbrQuestionByCategory(string $idCategory): int
    {
        if (empty($idCategory))
        {
            error_log("Invalid idCategory: empty");
            return 0;
        }

        $url = sprintf(
            'https://firestore.googleapis.com/v1/projects/%s/databases/%s/documents:runQuery',
            $this->projectId,
            $this->database
        );

        $query = [
            'structuredQuery' => [
                'from' => [['collectionId' => 'questions']],
                'where' => [
                    'fieldFilter' => [
                        'field' => ['fieldPath' => 'idCategory'],
                        'op' => 'EQUAL',
                        'value' => ['stringValue' => $idCategory],
                    ],
                ],
                'limit' => 1000,
            ],
        ];

        $questionCount = 0;
        $nextPageToken = null;

        try {
            do {
                $queryUrl = $url;
                if ($nextPageToken)
                {
                    $query['pageToken'] = $nextPageToken;
                }
                $response = $this->client->request('POST', $queryUrl, [
                    'headers' => [
                        'Authorization' => 'Bearer ' . $this->accessToken,
                        'Content-Type' => 'application/json',
                    ],
                    'json' => $query,
                ]);
                $data = $response->toArray();
                $nextPageToken = $data['nextPageToken'] ?? null;
                $questionCount += count(array_filter($data, fn($item) => isset($item['document'])));
            }
            while ($nextPageToken);
            return $questionCount;
        }
        catch (\Exception $e)
        {
            error_log("Error fetching questions by category: " . $e->getMessage());
            return 0;
        }
    }


    public function getCompletedQuizNames(string $teacherEmail): array
    {
        $url = sprintf(
            'https://firestore.googleapis.com/v1/projects/%s/databases/%s/documents:runQuery',
            $this->projectId,
            $this->database
        );

        $query = [
            'structuredQuery' => [
                'from' => [['collectionId' => 'quizzes']],
                'where' => [
                    'compositeFilter' => [
                        'op' => 'AND',
                        'filters' => [
                            [
                                'fieldFilter' => [
                                    'field' => ['fieldPath' => 'statut'],
                                    'op' => 'EQUAL',
                                    'value' => ['stringValue' => 'complet'],
                                ],
                            ],
                            [
                                'fieldFilter' => [
                                    'field' => ['fieldPath' => 'idTeacher'],
                                    'op' => 'EQUAL',
                                    'value' => ['stringValue' => $teacherEmail],
                                ],
                            ],
                        ],
                    ],
                ],
                'limit' => 1000,
            ],
        ];

        $quizNames = [];
        $nextPageToken = null;

        try {
            do {
                $queryUrl = $url;
                if ($nextPageToken)
                {
                    $query['pageToken'] = $nextPageToken;
                }
                error_log("Query sent for completed quiz names for $teacherEmail: " . json_encode($query));
                $response = $this->client->request('POST', $queryUrl, [
                    'headers' => [
                        'Authorization' => 'Bearer ' . $this->accessToken,
                        'Content-Type' => 'application/json',
                    ],
                    'json' => $query,
                ]);
                $data = $response->toArray();
                error_log("Response received for completed quiz names for $teacherEmail: " . json_encode($data));
                $nextPageToken = $data['nextPageToken'] ?? null;
                foreach ($data as $item)
                {
                    if (isset($item['document']['fields']['nameQuiz']['stringValue']))
                    {
                        $quizNames[] = $item['document']['fields']['nameQuiz']['stringValue'];
                        error_log("Added quiz name: " . $item['document']['fields']['nameQuiz']['stringValue']);
                    }
                }
            }
            while ($nextPageToken);
            error_log("Completed quiz names for $teacherEmail: " . json_encode($quizNames));
            return $quizNames;
        }
        catch (\Exception $e)
        {
            error_log("Error in getCompletedQuizNames for $teacherEmail: " . $e->getMessage());
            return [];
        }
    }

    public function getPendingQuizzesCount(string $teacherEmail): int
    {
        $url = sprintf(
            'https://firestore.googleapis.com/v1/projects/%s/databases/%s/documents:runQuery',
            $this->projectId,
            $this->database
        );

        $query = [
            'structuredQuery' => [
                'from' => [['collectionId' => 'quizzes']],
                'where' => [
                    'compositeFilter' => [
                        'op' => 'AND',
                        'filters' => [
                            [
                                'fieldFilter' => [
                                    'field' => ['fieldPath' => 'isAccessible'],
                                    'op' => 'EQUAL',
                                    'value' => ['booleanValue' => true],
                                ],
                            ],
                            [
                                'fieldFilter' => [
                                    'field' => ['fieldPath' => 'idTeacher'],
                                    'op' => 'EQUAL',
                                    'value' => ['stringValue' => $teacherEmail],
                                ],
                            ],
                        ],
                    ],
                ],
                'limit' => 1000,
            ],
        ];

        $quizCount = 0;
        $nextPageToken = null;

        try {
            do {
                $queryUrl = $url;
                if ($nextPageToken)
                {
                    $query['pageToken'] = $nextPageToken;
                }
                error_log("Query sent for $teacherEmail: " . json_encode($query));
                $response = $this->client->request('POST', $queryUrl, [
                    'headers' => [
                        'Authorization' => 'Bearer ' . $this->accessToken,
                        'Content-Type' => 'application/json',
                    ],
                    'json' => $query,
                ]);
                $data = $response->toArray();
                error_log("Response received for $teacherEmail: " . json_encode($data));
                $nextPageToken = $data['nextPageToken'] ?? null;
                foreach ($data as $item)
                {
                    if (isset($item['document']) && isset($item['document']['fields']['isAccessible']['booleanValue']))
                    {
                        $isAccessible = $item['document']['fields']['isAccessible']['booleanValue'];
                        $idTeacher = $item['document']['fields']['idTeacher']['stringValue'] ?? 'undefined';
                        error_log("Quiz checked - isAccessible: $isAccessible, idTeacher: $idTeacher");
                        if ($isAccessible === true)
                        {
                            $quizCount++;
                            error_log("Incremented for quiz with isAccessible: true");
                        }
                    }
                }
            }
            while ($nextPageToken);
            error_log("Final pending quiz count for $teacherEmail: $quizCount");
            return $quizCount;
        }
        catch (\Exception $e)
        {
            error_log("Error in getPendingQuizzesCount for $teacherEmail: " . $e->getMessage());
            return 0;
        }
    }

    public function getCompletedQuizzesCount(string $teacherEmail): int
    {
        $url = sprintf(
            'https://firestore.googleapis.com/v1/projects/%s/databases/%s/documents:runQuery',
            $this->projectId,
            $this->database
        );

        $query = [
            'structuredQuery' => [
                'from' => [['collectionId' => 'quizzes']],
                'where' => [
                    'compositeFilter' => [
                        'op' => 'AND',
                        'filters' => [
                            [
                                'fieldFilter' => [
                                    'field' => ['fieldPath' => 'statut'],
                                    'op' => 'EQUAL',
                                    'value' => ['stringValue' => 'complet'],
                                ],
                            ],
                            [
                                'fieldFilter' => [
                                    'field' => ['fieldPath' => 'idTeacher'],
                                    'op' => 'EQUAL',
                                    'value' => ['stringValue' => $teacherEmail],
                                ],
                            ],
                        ],
                    ],
                ],
                'limit' => 1000,
            ],
        ];

        $quizCount = 0;
        $nextPageToken = null;

        try {
            do {
                $queryUrl = $url;
                if ($nextPageToken)
                {
                    $query['pageToken'] = $nextPageToken;
                }
                error_log("Query sent for $teacherEmail (completed): " . json_encode($query));
                $response = $this->client->request('POST', $queryUrl, [
                    'headers' => [
                        'Authorization' => 'Bearer ' . $this->accessToken,
                        'Content-Type' => 'application/json',
                    ],
                    'json' => $query,
                ]);
                $data = $response->toArray();
                error_log("Response received for $teacherEmail (completed): " . json_encode($data));
                $nextPageToken = $data['nextPageToken'] ?? null;
                $quizCount += count(array_filter($data, fn($item) => isset($item['document'])));
            }
            while ($nextPageToken);
            error_log("Final completed quiz count for $teacherEmail: $quizCount");
            return $quizCount;
        }
        catch (\Exception $e)
        {
            error_log("Error in getCompletedQuizzesCount for $teacherEmail: " . $e->getMessage());
            return 0;
        }
    }

    public function getCategoryStatistics(): array
    {
        try {
            $url = sprintf(
                'https://firestore.googleapis.com/v1/projects/%s/databases/%s/documents/categories?pageSize=1000',
                $this->projectId,
                $this->database
            );

            $response = $this->client->request('GET', $url, [
                'headers' => [
                    'Authorization' => 'Bearer ' . $this->accessToken,
                ],
            ]);

            $data = $response->toArray();
            if (empty($data['documents']))
            {
                error_log("No categories found, returning default stats");
                return [['Category', 'Question Count'], ['No Data', 0]];
            }

            $categories = [];
            foreach ($data['documents'] ?? [] as $doc)
            {
                $fields = $doc['fields'] ?? [];
                $categories[] = [
                    'id' => basename($doc['name']),
                    'island' => $fields['island']['stringValue'] ?? 'Unknown',
                ];
            }

            $stats = [['Category', 'Question Count']];
            foreach ($categories as $category)
            {
                $count = $this->getnbrQuestionByCategory($category['id']);
                $stats[] = [$category['island'], $count];
            }
            return $stats;
        }
        catch (\Exception $e)
        {
            error_log("Error in getCategoryStatistics: " . $e->getMessage());
            return [['Category', 'Question Count'], ['No Data', 0]];
        }
    }

    public function getAccessToken(): string
    {
        return $this->accessToken;
    }
    public function getGenderStatistics(): array
    {
        try {
            $url = sprintf(
                'https://firestore.googleapis.com/v1/projects/%s/databases/%s/documents/users?pageSize=1000',
                $this->projectId,
                $this->database
            );

            error_log("Fetching gender stats from URL: $url");
            $response = $this->client->request('GET', $url, [
                'headers' => [
                    'Authorization' => 'Bearer ' . $this->accessToken,
                ],
            ]);

            $data = $response->toArray();
            error_log("Firestore response: " . json_encode($data));
            $genderStats = ['male' => 0, 'female' => 0];
            $totalStudents = 0;

            foreach ($data['documents'] ?? [] as $doc)
            {
                $fields = $doc['fields'] ?? [];
                $sexe = $fields['sexe']['stringValue'] ?? '';
                $userRole = $fields['userRole']['stringValue'] ?? '';
                error_log("Processing document: sexe=$sexe, userRole=$userRole");

                if ($userRole === 'etudiant')
                {
                    if (in_array(strtolower($sexe), ['male', 'homme'], true))
                    {
                        $genderStats['male']++;
                        $totalStudents++;
                        error_log("Counted as male: $sexe");
                    }
                    elseif (in_array(strtolower($sexe), ['female', 'femme'], true))
                    {
                        $genderStats['female']++;
                        $totalStudents++;
                        error_log("Counted as female: $sexe");
                    }
                    else
                    {
                        error_log("Unrecognized sexe value: $sexe");
                    }
                }
                else
                {
                    error_log("Skipping non-etudiant user: userRole=$userRole");
                }
            }

            error_log("Raw counts: male={$genderStats['male']}, female={$genderStats['female']}, total=$totalStudents");
            $result = [
                          'malePercent' => $totalStudents > 0 ? round(($genderStats['male'] / $totalStudents) * 100, 2) : 0,
                          'femalePercent' => $totalStudents > 0 ? round(($genderStats['female'] / $totalStudents) * 100, 2) : 0
                      ];
            error_log("Gender Stats: " . json_encode($result));

            return $result;
        }
        catch (\Exception $e)
        {
            error_log("Error in getGenderStatistics: " . $e->getMessage());
            return ['malePercent' => 0, 'femalePercent' => 0];
        }
    }

}
