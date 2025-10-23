<?php
ini_set('display_errors', 0);
error_reporting(E_ALL);

set_exception_handler(function($exception) {
    // --- IMPROVEMENT: Clean output buffer before sending response ---
    if (ob_get_level()) {
        ob_end_clean();
    }
    
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


$path = $_GET['path'] ?? '/';
$method = $_SERVER['REQUEST_METHOD'];

function startsWith($haystack, $needle) {
    return strpos($haystack, $needle) === 0;
}

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
} else if (startsWith($path, 'suppliers')) {
    require_once __DIR__.'/modules/suppliers/SuppliersController.php';
    $ctrl = new SuppliersController();
    $ctrl->handle($method, $_GET, $_POST, file_get_contents('php://input'));
    exit;
} else if (startsWith($path, 'restock')) {
    require_once __DIR__.'/modules/restock/RestockController.php';
    $ctrl = new RestockController();
    $ctrl->handle($method, $_GET, $_POST, file_get_contents('php://input'));
    exit;
}

jsonResponse(['error' => 'Endpoint not found', 'requested_path' => $path], 404);