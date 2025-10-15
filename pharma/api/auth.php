<?php
require_once __DIR__.'/helpers.php';


function authenticate(){
$headers = apache_request_headers();
if(!empty($headers['X-API-KEY']) && $headers['X-API-KEY'] === 'local-dev-key') return true;

jsonResponse(['error' => 'Unauthorized'], 401);
}