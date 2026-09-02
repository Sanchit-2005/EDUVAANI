import mysql from 'mysql2/promise';

let pool;

export function getDatabase() {
  if (pool) return pool;
  pool = mysql.createPool({
    host: process.env.MYSQL_HOST,
    port: Number(process.env.MYSQL_PORT ?? 3306),
    user: process.env.MYSQL_USER,
    password: process.env.MYSQL_PASSWORD,
    database: process.env.MYSQL_DATABASE,
    waitForConnections: true,
    connectionLimit: 5,
    enableKeepAlive: true
  });
  return pool;
}

export async function checkDatabase() {
  const database = getDatabase();
  await database.query('SELECT 1');
}
