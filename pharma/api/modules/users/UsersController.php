<?php

class UsersController{
private $pdo; private $model;
public function __construct(){$cfg = include __DIR__.'/../../../../config/config.php';$dsn = "mysql:host={$cfg['db']['host']};dbname={$cfg['db']['dbname']};charset=utf8mb4"; $this->pdo = new PDO($dsn, $cfg['db']['user'], $cfg['db']['pass'], [PDO::ATTR_ERRMODE=>PDO::ERRMODE_EXCEPTION]);
require_once __DIR__.'/UsersModel.php'; $this->model = new UsersModel($this->pdo);}
public function handle($method, $get, $post, $body){
$path = $_SERVER['REQUEST_URI'];
if($method === 'POST' && strpos($path, '/api/users/create') !== false){$data = json_decode($body,true);
$id = $this->model->createUser($data);
jsonResponse(['success'=>true,'id'=>$id]);
}
if($method === 'POST' && strpos($path, '/api/users/login') !== false){$data = json_decode($body,true);
$u = $this->model->authenticate($data['username'], $data['password']);
if($u){ jsonResponse(['success'=>true,'user'=>$u],200); } 
else { jsonResponse(['error'=>'Invalid credentials'],401); }
}
jsonResponse(['error'=>'Endpoint not found'],404);
}
}