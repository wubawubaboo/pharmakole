<?php
// Front controller - minimal routing

// --- MODIFICATION: Global Error & Exception Handling ---

// Step 1: Prevent PHP from displaying any startup errors or warnings.
// This ensures no HTML output contaminates our JSON responses.
ini_set('display_errors', 0);
error_reporting(E_ALL);

// Step 2: Set a global exception handler.
// This function will catch any uncaught exception, log it,
// and send a clean JSON error message to the app.
set_exception_handler(function($exception) {
    // Log the detailed error to a file for your own debugging.
    // Make sure the 'storage/logs' directory exists and is writable.
    $log_file = __DIR__ . '/../../storage/logs/errors.log';
    $error_message = date('Y-m-d H:i:s') . " | " . $exception->getMessage() . "\n" . $exception->getTraceAsString() . "\n\n";
    file_put_contents($log_file, $error_message, FILE_APPEND);
    
    // Send a generic, safe, and valid JSON error to the Flutter app.
    http_response_code(500); // Internal Server Error
    header('Content-Type: application/json');
    echo json_encode([
        'error' => 'An unexpected server error occurred. Please contact support.'
    ]);
    exit;
});

// Step 3: Set an error handler.
// This converts all traditional PHP warnings and notices into exceptions,
// which can then be caught by our new exception handler.
set_error_handler(function($severity, $message, $file, $line) {
    if (!(error_reporting() & $severity)) {
        return;
    }
    throw new ErrorException($message, 0, $severity, $file, $line);
});

// --- End of Error Handling Setup ---
// Front controller - minimal routing
require_once __DIR__.'/helpers.php';
require_once __DIR__.'/auth.php';


$path = $_GET['path'] ?? $_SERVER['REQUEST_URI'];
$method = $_SERVER['REQUEST_METHOD'];


if(strpos($path, '/api/inventory') !== false){
require_once __DIR__.'/modules/inventory/InventoryController.php';
$ctrl = new InventoryController();
$ctrl->handle($method, $_GET, $_POST, file_get_contents('php://input'));
exit;
}


else if(strpos($path, '/api/sales') !== false){
require_once __DIR__.'/modules/sales/SalesController.php';
$ctrl = new SalesController();
$ctrl->handle($method, $_GET, $_POST, file_get_contents('php://input'));
exit;
}


else if(strpos($path, '/api/reports') !== false){
require_once __DIR__.'/modules/reports/ReportsController.php';
$ctrl = new ReportsController();
$ctrl->handle($method, $_GET, $_POST, file_get_contents('php://input'));
exit;
}


else if(strpos($path, '/api/users') !== false){
require_once __DIR__.'/modules/users/UsersController.php';
$ctrl = new UsersController();
$ctrl->handle($method, $_GET, $_POST, file_get_contents('php://input'));
exit;
}


jsonResponse(['message' => 'POS Backend running', 'path' => $path]);