<?php
// Front controller - minimal routing
require_once __DIR__.'/helpers.php';
require_once __DIR__.'/auth_middleware.php';


$path = $_GET['path'] ?? $_SERVER['REQUEST_URI'];
$method = $_SERVER['REQUEST_METHOD'];


if(strpos($path, '/api/inventory') !== false){
require_once __DIR__.'/modules/inventory/InventoryController.php';
$ctrl = new InventoryController();
$ctrl->handle($method, $_GET, $_POST, file_get_contents('php://input'));
exit;
}


if(strpos($path, '/api/sales') !== false){
require_once __DIR__.'/modules/sales/SalesController.php';
$ctrl = new SalesController();
$ctrl->handle($method, $_GET, $_POST, file_get_contents('php://input'));
exit;
}


if(strpos($path, '/api/reports') !== false){
require_once __DIR__.'/modules/reports/ReportsController.php';
$ctrl = new ReportsController();
$ctrl->handle($method, $_GET, $_POST, file_get_contents('php://input'));
exit;
}


if(strpos($path, '/api/users') !== false){
require_once __DIR__.'/modules/users/UsersController.php';
$ctrl = new UsersController();
$ctrl->handle($method, $_GET, $_POST, file_get_contents('php://input'));
exit;
}


jsonResponse(['message' => 'POS Backend running', 'path' => $path]);