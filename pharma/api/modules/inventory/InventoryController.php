<?php
require_once __DIR__.'/../../helpers.php';
require_once __DIR__.'/../../auth.php';
require_once __DIR__.'/../../logger.php';


class InventoryController {
private $pdo;
private $model;
public function __construct(){
    $cfg = include __DIR__.'/../../../config/config.php';
    $dsn = "mysql:host={$cfg['db']['host']};dbname={$cfg['db']['dbname']};charset=utf8mb4";
    $this->pdo = new PDO($dsn, $cfg['db']['user'], $cfg['db']['pass'], [PDO::ATTR_ERRMODE=>PDO::ERRMODE_EXCEPTION]);
    require_once __DIR__.'/InventoryModel.php';
    $this->model = new InventoryModel($this->pdo);
    ActivityLogger::init($this->pdo);
}


public function handle($method, $get, $post, $body){
    authenticate(); 
    
    $path = $_SERVER['REQUEST_URI'];

    if($method === 'GET' && strpos($path, '/api/inventory/list') !== false){
        $q = $get['q'] ?? '';
        $r = $this->model->listProducts($q);
        jsonResponse(['data'=>$r]);
        return;
    }
    else if($method === 'POST' && strpos($path, '/api/inventory/create') !== false){
        $data = json_decode($body, true);
        $id = $this->model->createProduct($data);
        ActivityLogger::log('create_product', 'Created product: ' . $data['name']);
        jsonResponse(['success'=>true,'id'=>$id]);
        return;
    }

    else if($method === 'POST' && strpos($path, '/api/inventory/update') !== false){
        $data = json_decode($body, true);
        $id = $data['id'] ?? 0;
        if (empty($id)) {
             jsonResponse(['error'=>'Product ID is required.'], 400);
             return;
        }
        $this->model->updateProduct($id, $data);
        ActivityLogger::log('update_product', 'Updated product: ' . $data['name']); 
        jsonResponse(['success'=>true,'id'=>$id]);
        return;
    }

    else if($method === 'POST' && strpos($path, '/api/inventory/delete') !== false){
        $data = json_decode($body, true);
        $id = $data['id'] ?? 0;
         if (empty($id)) {
             jsonResponse(['error'=>'Product ID is required.'], 400);
             return;
        }
        $this->model->deleteProduct($id);
        ActivityLogger::log('delete_product', 'Deleted product ID: ' . $id);
        jsonResponse(['success'=>true]);
        return;
    }
    else if($method === 'GET' && strpos($path, '/api/inventory/low') !== false){
        $r = $this->model->listLowStock();
        jsonResponse(['low_stock'=>$r]);
        return;
    }

    else if($method === 'GET' && strpos($path, '/api/inventory/expiry') !== false){
        $r = $this->model->listNearExpiry();
        jsonResponse(['near_expiry'=>$r]);
        return;
    }

    else if($method === 'POST' && strpos($path, '/api/inventory/adjust') !== false){
        $data = json_decode($body, true);
        
        $adjustment_amount = $data['adjustment_amount'] ?? $data['new_quantity'] ?? 0;
        $product_id = $data['id'] ?? 0;
        $reason = $data['reason'] ?? '';

        if (empty($product_id) || $adjustment_amount == 0) {
            jsonResponse(['error' => 'Product ID and a non-zero adjustment amount are required.'], 400);
            return;
        }

        try {
            $this->model->adjustStock($product_id, (int)$adjustment_amount, $reason);
            ActivityLogger::log('adjust_stock', "Adjusted stock for product ID $product_id by $adjustment_amount. Reason: $reason", 'system');
            jsonResponse(['success'=>true]);
        } catch (Exception $e) {
            jsonResponse(['error' => $e->getMessage()], 500);
        }
        return;
    }

    jsonResponse(['error'=>'Endpoint not found'],404);
    return;
}
}