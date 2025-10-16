<?php
require_once __DIR__.'/../..//config/../..//config/config.php';

class InventoryController {
private $pdo;
private $model;
public function __construct(){
$cfg = include __DIR__.'/../../../../config/config.php';
$dsn = "mysql:host={$cfg['db']['host']};dbname={$cfg['db']['dbname']};charset=utf8mb4";
$this->pdo = new PDO($dsn, $cfg['db']['user'], $cfg['db']['pass'], [PDO::ATTR_ERRMODE=>PDO::ERRMODE_EXCEPTION]);
require_once __DIR__.'/InventoryModel.php';
$this->model = new InventoryModel($this->pdo);
}


public function handle($method, $get, $post, $body){
authenticate();
$path = $_SERVER['REQUEST_URI'];

if($method === 'GET' && strpos($path, '/api/inventory/list') !== false){
    $r = $this->model->listProducts();
    jsonResponse(['data'=>$r]);
    return;
}
if($method === 'POST' && strpos($path, '/api/inventory/create') !== false){
$data = json_decode($body, true);
$id = $this->model->createProduct($data);
jsonResponse(['success'=>true,'id'=>$id]);
    return;
}


if($method === 'GET' && strpos($path, '/api/inventory/low') !== false){
$r = $this->model->listLowStock();
jsonResponse(['low_stock'=>$r]);
return;
}


if($method === 'POST' && strpos($path, '/api/inventory/adjust') !== false){
$data = json_decode($body, true);
$this->model->adjustStock($data['id'], $data['new_quantity'], $data['reason'] ?? '');
jsonResponse(['success'=>true]);
return;
}


jsonResponse(['error'=>'Endpoint not found'],404);
return;
}
}