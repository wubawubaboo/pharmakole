<?php
// Front controller - minimal routing

// --- MODIFICATION: Global Error & Exception Handling ---
ini_set('display_errors', 0);
error_reporting(E_ALL);

set_exception_handler(function($exception) {
    $log_file = __DIR__ . '/../../storage/logs/errors.log';
    $error_message = date('Y-m-d H:i:s') . " | " . $exception->getMessage() . "\n" . $exception->getTraceAsString() . "\n\n";
    file_put_contents($log_file, $error_message, FILE_APPEND);
    
    http_response_code(500);
    header('Content-Type: application/json');
    echo json_encode(['error' => 'An unexpected server error occurred. Please contact support.']);
    exit;
});

set_error_handler(function($severity, $message, $file, $line) {
    if (!(error_reporting() & $severity)) {
        return;
    }
    throw new ErrorException($message, 0, $severity, $file, $line);
});

// --- End of Error Handling Setup ---
require_once __DIR__.'/helpers.php';
require_once __DIR__.'/auth.php';

$path = $_GET['path'] ?? $_SERVER['REQUEST_URI'];
$method = $_SERVER['REQUEST_METHOD'];

// --- FIX: Made the endpoint matching more flexible ---
if (strpos($path, '/inventory') !== false) {
    require_once __DIR__.'/modules/inventory/InventoryController.php';
    $ctrl = new InventoryController();
    $ctrl->handle($method, $_GET, $_POST, file_get_contents('php://input'));
    exit;
} else if (strpos($path, '/sales') !== false) {
    require_once __DIR__.'/modules/sales/SalesController.php';
    $ctrl = new SalesController();
    $ctrl->handle($method, $_GET, $_POST, file_get_contents('php://input'));
    exit;
} else if (strpos($path, '/reports') !== false) {
    require_once __DIR__.'/modules/reports/ReportsController.php';
    $ctrl = new ReportsController();
    $ctrl->handle($method, $_GET, $_POST, file_get_contents('php://input'));
    exit;
} else if (strpos($path, '/users') !== false) {
    require_once __DIR__.'/modules/users/UsersController.php';
    $ctrl = new UsersController();
    $ctrl->handle($method, $_GET, $_POST, file_get_contents('php://input'));
    exit;
}

// This is the fallback response if no route matches
jsonResponse(['message' => 'POS Backend running', 'path' => $path]);