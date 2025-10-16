<?php
require_once __DIR__.'/helpers.php';

function authenticate(){
    $apiKey = null;

    // Method 1: Try apache_request_headers() first (works on many Apache setups)
    $headers = apache_request_headers();
    if (isset($headers['X-API-KEY'])) {
        $apiKey = $headers['X-API-KEY'];
    } 
    // Method 2: Fallback to checking the $_SERVER superglobal (more reliable)
    // Headers like 'X-API-KEY' are often transformed to 'HTTP_X_API_KEY'
    else if (isset($_SERVER['HTTP_X_API_KEY'])) {
        $apiKey = $_SERVER['HTTP_X_API_KEY'];
    }

    // Now, check if the extracted key is correct
    if ($apiKey !== null && $apiKey === 'local-dev-key') {
        return true; // Authentication successful
    }

    // If we get here, authentication failed.
    jsonResponse(['error' => 'Unauthorized. Missing or invalid API Key.'], 401);
}
