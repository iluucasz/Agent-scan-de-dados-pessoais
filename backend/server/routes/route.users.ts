import { Router } from "express";
import { UsersService } from "../services/users.service";
import { UsersController } from "../controllers/users.controller";
import { authToken } from "../middlewares/authToken";
import { resolveOrgScope } from "../middlewares/org-scope.middleware";

const usersService = new UsersService();
const usersController = new UsersController(usersService);
const router = Router();

// Registro de usuário
router.post('/api/users', (req, res) => usersController.register(req, res));

// Login de usuário - migrado para AuthController (/api/auth/login)

// Listar usuários
router.get('/api/users', authToken, resolveOrgScope, (req, res) => usersController.getUsers(req, res));

// Atualizar usuário
router.put('/api/users/:id([0-9a-fA-F\\-]{36})', authToken, (req, res) => usersController.updateUser(req, res));

// Atualização parcial de usuário via PATCH
router.patch('/api/users/:id([0-9a-fA-F\\-]{36})', authToken, (req, res) => usersController.updateUser(req, res));

// Remover usuário
router.delete('/api/users/:id([0-9a-fA-F\\-]{36})', authToken, (req, res) => usersController.deleteUser(req, res));

// Rota para obter o usuário autenticado
router.get('/api/auth/me', authToken, resolveOrgScope, (req, res) => usersController.me(req, res));

export default router; 