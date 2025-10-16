<?php
// Front controller - Refactored for .htaccess

// --- Global Error & Exception Handling (No changes needed here) ---
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

// --- End of Error Handling ---
require_once __DIR__.'/helpers.php';
require_once __DIR__.'/auth.php';

// --- REFACTORED ROUTING LOGIC ---

// The .htaccess file now gives us the clean path directly. No more server variable magic.
$path = $_GET['path'] ?? '/';
$method = $_SERVER['REQUEST_METHOD'];

// A simple function to check if the path starts with a given prefix
function startsWith($haystack, $needle) {
    // We add a leading slash to the needle for a more reliable match
    return strpos($haystack,$needle) === 0;
}

// The path from .htaccess will be like 'users/login', so we check against that.
if (startsWith($path, 'inventory')) {
    require_once __DIR__.'/modules/inventory/InventoryController.php';
    $ctrl = new InventoryController();
    $ctrl->handle($method, $_GET, $_POST, file_get_contents('php://input'));
    exit;
} else if (startsWith($path, 'sales')) {
    require_once __DIR__.'/modules/sales/SalesController.php';
    $ctrl = new SalesController();
    $ctrl->handle($method, $_GET, $_POST, file_get_contents('php://input'));
    exit;
} else if (startsWith($path, 'reports')) {
    require_once __DIR__.'/modules/reports/ReportsController.php';
    $ctrl = new ReportsController();
    $ctrl->handle($method, $_GET, $_POST, file_get_contents('php://input'));
    exit;
} else if (startsWith($path, 'users')) {
    require_once __DIR__.'/modules/users/UsersController.php';
    $ctrl = new UsersController();
    $ctrl->handle($method, $_GET, $_POST, file_get_contents('php://input'));
    exit;
}


jsonResponse(['error' => 'Endpoint not found', 'requested_path' => $path], 404);