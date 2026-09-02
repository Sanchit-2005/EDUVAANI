import 'dotenv/config';
import cors from 'cors';
import express from 'express';
import { apiRouter } from './routes/api_routes.js';
import { checkDatabase } from './config/database.js';

const app = express();
app.use(cors());
app.use(express.json({ limit: '1mb' }));

app.get('/api/health', async (_, response) => {
  await checkDatabase();
  response.json({ status: 'ok', database: 'connected' });
});
app.use('/api', apiRouter);

app.use((_, response) => response.status(404).json({ error: 'Route not found.' }));
app.use((error, _, response, __) => {
  console.error(error);
  response.status(500).json({ error: 'Unexpected server error.' });
});

const port = Number(process.env.PORT ?? 3000);
app.listen(port, () => console.log(`EduVaani backend listening on port ${port}`));
