<?php
require_once __DIR__.'/helpers.php';

function authenticate(){
    // --- TEMPORARY DEBUGGING ---
    // This will stop the script and show us all headers the server sees.
    $headers = apache_request_headers();
    jsonResponse(['debug_message' => 'Headers received by PHP', 'headers' => $headers]);
    exit; // Stop execution after sending the debug info.
    // --- END TEMPORARY DEBUGGING ---
}