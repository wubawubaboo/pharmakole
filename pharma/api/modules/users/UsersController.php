<?php
require_once __DIR__.'/../../helpers.php';
require_once __DIR__.'/../../auth.php';
require_once __DIR__.'/../../logger.php';

class UsersController{
private $pdo; private $model;
public function __construct(){
    $cfg = include __DIR__.'/../../../config/config.php';
    $dsn = "mysql:host={$cfg['db']['host']};dbname={$cfg['db']['dbname']};charset=utf8mb4";
    $this->pdo = new PDO($dsn, $cfg['db']['user'], $cfg['db']['pass'], [PDO::ATTR_ERRMODE=>PDO::ERRMODE_EXCEPTION]);
    require_once __DIR__.'/UsersModel.php'; $this->model = new UsersModel($this->pdo);
    ActivityLogger::init($this->pdo);
}

public function handle($method, $get, $post, $body){
    $path = $_SERVER['REQUEST_URI'];
    
    if($method === 'POST' && strpos($path, '/api/users/login') !== false){
        $data = json_decode($body,true);
        if (!is_array($data) || !isset($data['username']) || !isset($data['password'])) {
            jsonResponse(['error'=>'Invalid request or missing username/password.'], 400);
            return;
        }
        $u = $this->model->authenticate($data['username'], $data['password']);
        if($u){
            ActivityLogger::log('login_success', 'User logged in successfully.', $u['username']); // <-- ADD LOG
            jsonResponse(['success'=>true,'user'=>$u]);
        } else {
            ActivityLogger::log('login_fail', 'Failed login attempt.', $data['username'] ?? 'unknown'); // <-- ADD LOG
            jsonResponse(['error'=>'Invalid credentials'],401);
        }
        return;
    }
    
    authenticate();

    if($method === 'POST' && strpos($path, '/api/users/create') !== false){
        $data = json_decode($body,true);
        if (!is_array($data) || !isset($data['username']) || !isset($data['password']) || !isset($data['role']) || !isset($data['full_name'])) {
            jsonResponse(['error' => 'Missing required fields for user creation.'], 400);
            return;
        }
        $id = $this->model->createUser($data);
        ActivityLogger::log('create_user', 'Created new user: ' . $data['full_name'], 'admin'); // <-- ADD LOG
        jsonResponse(['success'=>true,'id'=>$id]);
        return;
    }
    
    if($method === 'GET' && strpos($path, '/api/users/list') !== false){
        $users = $this->model->listUsers();
        jsonResponse(['data' => $users]);
        return;
    }

    if($method === 'POST' && strpos($path, '/api/users/update') !== false){
        $data = json_decode($body, true);
        $id = $data['id'] ?? 0;
        if (empty($id) || !isset($data['username']) || !isset($data['role']) || !isset($data['full_name'])) {
             jsonResponse(['error'=>'Missing required fields (id, username, role, full_name)'], 400);
             return;
        }
        $this->model->updateUser($id, $data);
        ActivityLogger::log('update_user', 'Updated user: ' . $data['full_name'], 'admin'); // <-- ADD LOG
        jsonResponse(['success'=>true, 'id' => $id]);
        return;
    }

    if($method === 'POST' && strpos($path, '/api/users/delete') !== false){
        $data = json_decode($body, true);
        $id = $data['id'] ?? 0;
        if (empty($id)) {
             jsonResponse(['error'=>'User ID is required.'], 400);
             return;
        }
        $this->model->deleteUser($id);
        ActivityLogger::log('delete_user', 'Deleted user with ID: ' . $id, 'admin'); // <-- ADD LOG
        jsonResponse(['success'=>true]);
        return;
    }

    jsonResponse(['error'=>'Endpoint not found'],404);
}
}