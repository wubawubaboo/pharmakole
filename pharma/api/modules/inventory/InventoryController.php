<?php
require_once __DIR__.'/../../helpers.php';
require_once __DIR__.'/../../auth.php';


class InventoryController {
private $pdo;
private $model;
public function __construct(){
    $cfg = include __DIR__.'/../../../config/config.php';
    $dsn = "mysql:host={$cfg['db']['host']};dbname={$cfg['db']['dbname']};charset=utf8mb4";
    $this->pdo = new PDO($dsn, $cfg['db']['user'], $cfg['db']['pass'], [PDO::ATTR_ERRMODE=>PDO::ERRMODE_EXCEPTION]);
    require_once __DIR__.'/InventoryModel.php';
    $this->model = new InventoryModel($this->pdo);
}


public function handle($method, $get, $post, $body){
    authenticate(); 
    
    $path = $_SERVER['REQUEST_URI'];

    // --- MODIFIED: Handle search query ---
    if($method === 'GET' && strpos($path, '/api/inventory/list') !== false){
        $q = $get['q'] ?? '';
        $r = $this->model->listProducts($q);
        jsonResponse(['data'=>$r]);
        return;
    }
    else if($method === 'POST' && strpos($path, '/api/inventory/create') !== false){
        $data = json_decode($body, true);
        $id = $this->model->createProduct($data);
        jsonResponse(['success'=>true,'id'=>$id]);
        return;
    }
    // --- NEW: Handle product update ---
    else if($method === 'POST' && strpos($path, '/api/inventory/update') !== false){
        $data = json_decode($body, true);
        $id = $data['id'] ?? 0;
        if (empty($id)) {
             jsonResponse(['error'=>'Product ID is required.'], 400);
             return;
        }
        $this->model->updateProduct($id, $data);
        jsonResponse(['success'=>true,'id'=>$id]);
        return;
    }
     // --- NEW: Handle product delete ---
    else if($method === 'POST' && strpos($path, '/api/inventory/delete') !== false){
        $data = json_decode($body, true);
        $id = $data['id'] ?? 0;
         if (empty($id)) {
             jsonResponse(['error'=>'Product ID is required.'], 400);
             return;
        }
        $this->model->deleteProduct($id);
        jsonResponse(['success'=>true]);
        return;
    }
    else if($method === 'GET' && strpos($path, '/api/inventory/low') !== false){
        $r = $this->model->listLowStock();
        jsonResponse(['low_stock'=>$r]);
        return;
    }
    // --- NEW: Handle expiry alert ---
    else if($method === 'GET' && strpos($path, '/api/inventory/expiry') !== false){
        $r = $this->model->listNearExpiry();
        jsonResponse(['near_expiry'=>$r]);
        return;
    }
    else if($method === 'POST' && strpos($path, '/api/inventory/adjust') !== false){
        $data = json_decode($body, true);
        $this->model->adjustStock($data['id'], $data['new_quantity'], $data['reason'] ?? '');
        jsonResponse(['success'=>true]);
        return;
    }

    jsonResponse(['error'=>'Endpoint not found'],404);
    return;
}
}