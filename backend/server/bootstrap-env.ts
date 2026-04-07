import dotenv from 'dotenv';
// Load .env early (module side-effect) before other modules that might import the DB.
dotenv.config({ override: true });
