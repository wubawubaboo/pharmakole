<?php
require_once __DIR__.'/helpers.php';

function authenticate(){
    $headers = apache_request_headers();
    $apiKey = $headers['X-API-KEY'] ?? $headers['x-api-key'] ?? '';
    if ($apiKey !== 'local-dev-key') {
        jsonResponse(['error' => 'Unauthorized'], 401);
        exit;
    }
}