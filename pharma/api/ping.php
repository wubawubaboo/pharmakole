<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');

echo json_encode(['status' => 'ok', 'message' => 'API connection successful']);
